import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class RepayLoanScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;
  final String employeeId;

  const RepayLoanScreen({
    required this.employeeId,
    required this.user,
    required this.apiService,
    super.key,
  });

  @override
  _RepayLoanScreenState createState() => _RepayLoanScreenState();
}

class _RepayLoanScreenState extends State<RepayLoanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> loans = [];
  Map<String, dynamic>? selectedLoan;
  String? _employeeName;
  double repayAmount = 0.0;
  double interest = 0.0;
  double totalRepaid = 0.0;
  DateTime? repayDate;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.user['role'] != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Access denied: Only admins can process repayments')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _fetchEmployeeAndLoans();
  }

  Future<void> _fetchEmployeeAndLoans() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch employee details to get name
      final employees =
          await widget.apiService.getEmployeeList(widget.user['company_id']);
      final employee = employees.firstWhere(
        (e) => e['employee_id'].toString() == widget.employeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      _employeeName = employee['fullname'] ?? 'Unknown';

      // Fetch loans
      final fetchedLoans = await widget.apiService
          .fetchLoansForEmployee(widget.employeeId, widget.user['company_id']);

      if (fetchedLoans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No active loans found for this employee')),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        loans = fetchedLoans;
        selectedLoan = loans.first;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
        isLoading = false;
      });
    }
  }

  void _calculateRepayment() {
    if (selectedLoan == null || repayAmount <= 0) {
      setState(() {
        interest = 0.0;
        totalRepaid = 0.0;
      });
      return;
    }

    setState(() {
      // Calculate interest on remaining amount
      interest =
          (selectedLoan!['remaining_amount'] * selectedLoan!['interest_rate'])
              .roundToDouble();
      totalRepaid = repayAmount + interest;
    });

    print(
        'Calculated repayment: Interest = $interest, Total Repaid = $totalRepaid');
  }

  Future<void> _processRepayment() async {
    if (!_formKey.currentState!.validate() ||
        selectedLoan == null ||
        repayDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    if (repayAmount > selectedLoan!['remaining_amount']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Repayment amount exceeds remaining loan balance')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final repaymentData = {
        'employee_id': widget.employeeId,
        'amount': repayAmount,
        'repayment_date': DateFormat('yyyy-MM-dd').format(repayDate!),
      };

      print(
          'Processing loan repayment for loan ID: ${selectedLoan!['loan_id']}');
      await widget.apiService
          .processLoanRepayment(repaymentData, widget.user['company_id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Loan repayment processed successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error processing loan repayment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process loan repayment: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _processRepayment,
          ),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectRepayDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.teal[700]!),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal[700]),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        repayDate = pickedDate;
        print(
            'Selected repayment date: ${DateFormat('yyyy-MM-dd').format(pickedDate)}');
      });
    }
  }

  Widget _buildTextField(String label, {required Function(String) onChanged}) {
    return TextFormField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[900]),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[700]!)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty || double.tryParse(value) == null) {
          return 'Please enter a valid $label';
        }
        final amount = double.parse(value);
        if (amount <= 0) {
          return '$label must be greater than 0';
        }
        if (selectedLoan != null &&
            amount > selectedLoan!['remaining_amount']) {
          return 'Amount exceeds remaining loan balance';
        }
        return null;
      },
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  Widget _buildLoanDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      decoration: InputDecoration(
        labelText: 'Select Loan',
        labelStyle: TextStyle(color: Colors.teal[900]),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal[700]!)),
        filled: true,
        fillColor: Colors.white,
      ),
      value: selectedLoan,
      items: loans.map((loan) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: loan,
          child: Text(
            'Loan ID: ${loan['loan_id']} - Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(loan['amount'])}',
            style: TextStyle(color: Colors.teal[900]),
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          selectedLoan = newValue;
          repayAmount = 0.0;
          interest = 0.0;
          totalRepaid = 0.0;
        });
      },
      validator: (value) => value == null ? 'Please select a loan' : null,
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _selectRepayDate,
          icon: Icon(Icons.calendar_today, color: Colors.teal[700]),
          label: Text(
            repayDate == null
                ? 'Select Repayment Date'
                : DateFormat('yyyy-MM-dd').format(repayDate!),
            style: TextStyle(color: Colors.teal[700]),
          ),
        ),
        if (_formKey.currentState?.validate() == false && repayDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please select a repayment date',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Repay Loan',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          print('Profile tapped');
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
                          style:
                              TextStyle(color: Colors.teal[900], fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchEmployeeAndLoans,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.teal[50]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Employee and Loan Details
                                Text(
                                  'Employee: $_employeeName',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.teal[900],
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),

                                // Loan Dropdown
                                _buildLoanDropdown(),
                                const SizedBox(height: 16),

                                // Loan Details Display
                                if (selectedLoan != null) ...[
                                  Text(
                                    'Loan Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(selectedLoan!['amount'] ?? 0)}',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  Text(
                                    'Remaining Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(selectedLoan!['remaining_amount'] ?? 0)}',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  Text(
                                    'Interest Rate: ${(selectedLoan!['interest_rate'] * 100).toStringAsFixed(2)}%',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  Text(
                                    'Loan Period: ${selectedLoan!['loan_period'] ?? 'Unknown'} months',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  Text(
                                    'Created At: ${selectedLoan!['created_at'] ?? 'N/A'}',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Repayment Amount Field
                                _buildTextField(
                                  'Repayment Amount',
                                  onChanged: (value) {
                                    setState(() {
                                      repayAmount =
                                          double.tryParse(value) ?? 0.0;
                                      _calculateRepayment();
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Repayment Date Picker
                                _buildDatePicker(),
                                const SizedBox(height: 20),

                                // Calculated Interest and Total Repaid
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Repayment Details',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal[900]),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Interest: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(interest)}',
                                          style: TextStyle(
                                              color: Colors.grey[800]),
                                        ),
                                        Text(
                                          'Total Repaid: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalRepaid)}',
                                          style: TextStyle(
                                              color: Colors.grey[800]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Process Repayment Button
                                ElevatedButton(
                                  onPressed:
                                      isLoading ? null : _processRepayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 50, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text('Process Repayment'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
