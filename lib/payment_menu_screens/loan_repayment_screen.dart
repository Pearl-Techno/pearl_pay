import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class LoanRepaymentScreen extends StatefulWidget {
  const LoanRepaymentScreen({super.key});

  @override
  _LoanRepaymentScreenState createState() => _LoanRepaymentScreenState();
}

class _LoanRepaymentScreenState extends State<LoanRepaymentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService(client: http.Client());

  String? selectedCompany;
  String? selectedEmployeeId;
  String? selectedEmployeeName;
  DateTime? repaymentDate;

  final TextEditingController amountRepaidController = TextEditingController();
  final TextEditingController interestController = TextEditingController();
  final TextEditingController loanAmountController = TextEditingController();
  final TextEditingController loanRateController = TextEditingController();
  final TextEditingController loanPeriodController = TextEditingController();

  double amountRepaid = 0.0;
  double interest = 0.0;
  double totalAmountRepaid = 0.0;

  bool isLoading = false;
  List<Map<String, dynamic>> employees = [];
  List<String> companyNames = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    amountRepaidController.addListener(_calculateTotalAmountRepaid);
    interestController.addListener(_calculateTotalAmountRepaid);
  }

  @override
  void dispose() {
    amountRepaidController.dispose();
    interestController.dispose();
    loanAmountController.dispose();
    loanRateController.dispose();
    loanPeriodController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => isLoading = true);
    try {
      employees = await apiService.getEmployeeList();
      print('Successfully fetched employees: ${employees.length} records');
      companyNames = employees
          .map((e) => e['company_name'] as String? ?? 'Unknown')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      print('Error fetching employees: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch employees: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateTotalAmountRepaid() {
    setState(() {
      amountRepaid = double.tryParse(amountRepaidController.text) ?? 0.0;
      interest = double.tryParse(interestController.text) ?? 0.0;
      totalAmountRepaid = amountRepaid + interest;
    });
  }

  Future<void> _selectRepaymentDate() async {
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
        repaymentDate = pickedDate;
      });
    }
  }

  Future<void> _processLoanRepayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (repaymentDate == null) {
      print('Error: No repayment date selected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a repayment date')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final repaymentData = {
        'employee_id': selectedEmployeeId,
        'repayment_date': DateFormat('yyyy-MM-dd').format(repaymentDate!),
        'amount_repaid': double.tryParse(amountRepaidController.text) ?? 0.0,
        'interest': double.tryParse(interestController.text) ?? 0.0,
        'total_amount_repaid': totalAmountRepaid,
        'loan_amount': double.tryParse(loanAmountController.text) ?? 0.0,
        'loan_rate': double.tryParse(loanRateController.text) ?? 0.0,
        'loan_period': int.tryParse(loanPeriodController.text) ?? 0,
      };

      print('Sending repayment data: $repaymentData');
      await apiService.processLoanRepayment(repaymentData);
      print(
          'Successfully processed loan repayment for employee: $selectedEmployeeId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Loan repayment processed successfully for $selectedEmployeeName'),
          backgroundColor: Colors.teal[700],
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error processing loan repayment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process loan repayment: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = selectedCompany == null
        ? []
        : employees
            .where((e) => (e['company_name'] as String?) == selectedCompany)
            .toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Loan Repayment',
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Company',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: selectedCompany,
                        items: companyNames.map((company) {
                          return DropdownMenuItem<String>(
                            value: company,
                            child: Text(company,
                                style: TextStyle(color: Colors.teal[900])),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCompany = newValue;
                            selectedEmployeeId = null;
                            selectedEmployeeName = null;
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select a company'
                            : null,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.teal[700]),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Employee',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: selectedEmployeeId,
                        items: filteredEmployees.isEmpty
                            ? [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No employees available',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic)),
                                  enabled: false,
                                )
                              ]
                            : filteredEmployees.map((employee) {
                                return DropdownMenuItem<String>(
                                  value: employee['employee_id'].toString(),
                                  child: Text(
                                    '${employee['employee_id']} - ${employee['fullname']}',
                                    style: TextStyle(color: Colors.teal[900]),
                                  ),
                                );
                              }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedEmployeeId = newValue;
                            try {
                              selectedEmployeeName =
                                  filteredEmployees.firstWhere(
                                (emp) =>
                                    emp['employee_id'].toString() == newValue,
                                orElse: () => {'fullname': 'Unknown'},
                              )['fullname'];
                            } catch (e) {
                              print('Error selecting employee name: $e');
                              selectedEmployeeName = 'Unknown';
                            }
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select an employee'
                            : null,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.teal[700]),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _selectRepaymentDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Select Repayment Date'),
                      ),
                      if (repaymentDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Repayment Date: ${DateFormat('yyyy-MM-dd').format(repaymentDate!)}',
                            style: TextStyle(
                                fontSize: 16, color: Colors.teal[900]),
                          ),
                        ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: loanAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Loan Amount',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter loan amount'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: loanRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Loan Rate (%)',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter loan rate'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: loanPeriodController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Loan Period (Months)',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter loan period'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: amountRepaidController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount Repaid',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter amount repaid'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: interestController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Interest',
                          labelStyle: TextStyle(color: Colors.teal[900]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter interest'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Amount Repaid',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[900],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'KES ${totalAmountRepaid.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isLoading ? null : _processLoanRepayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Save Repayment'),
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
