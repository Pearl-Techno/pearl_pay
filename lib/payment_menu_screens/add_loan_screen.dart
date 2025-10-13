import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// AddLoanScreen: Allows admins to add a new loan for an employee
class AddLoanScreen extends StatefulWidget {
  final Map<String, dynamic> user; // User data from HomeScreen
  final ApiService apiService; // ApiService for backend calls

  const AddLoanScreen({
    Key? key,
    required this.apiService,
    required this.user,
  }) : super(key: key);

  @override
  _AddLoanScreenState createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late User _userModel;
  int? _companyId;
  String? _companyName;
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  List<Map<String, dynamic>> _employees = [];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _loanPeriodController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  DateTime? _createdAt;

  bool _isLoading = false;
  bool _isLoadingEmployees = false;
  String? _errorMessage;
  double _loanAmount = 0.0;
  double _monthlyPayment = 0.0;
  double _interestRate = 0.0;
  double _interestAmount = 0.0;
  double _totalRepayment = 0.0;

  @override
  void initState() {
    super.initState();
    // Convert user map to User object
    try {
      _userModel = User(
        companyId: int.parse(widget.user['company_id']?.toString() ?? '0'),
        employeeId: widget.user['employee_id']?.toString() ?? 'N/A',
        role: (widget.user['role']?.toString() ?? 'unknown').toLowerCase(),
        userId: widget.user['user_id']?.toString(),
        username: widget.user['username']?.toString(),
        companyName: widget.user['company_name']?.toString(),
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid user data: $e')),
        );
        Navigator.pop(context);
      });
      return;
    }

    // Restrict access to admins only
    if (_userModel.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Access denied: Only admins can add loans')),
        );
        Navigator.pop(context);
      });
      return;
    }

    // Set company details from user
    _companyId = _userModel.companyId;
    _companyName = _userModel.companyName ?? 'Unknown';

    // Add listeners with debounce
    _amountController.addListener(_debouncedCalculateLoanDetails);
    _loanPeriodController.addListener(_debouncedCalculateLoanDetails);
    _interestRateController.addListener(_debouncedCalculateLoanDetails);

    // Fetch employees for the user's company
    if (_companyId != 0) {
      _fetchEmployees();
    } else {
      setState(() {
        _errorMessage = 'No company assigned to this user';
        _isLoadingEmployees = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_debouncedCalculateLoanDetails);
    _loanPeriodController.removeListener(_debouncedCalculateLoanDetails);
    _interestRateController.removeListener(_debouncedCalculateLoanDetails);
    _amountController.dispose();
    _loanPeriodController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  // Debounced calculation to prevent excessive updates
  void _debouncedCalculateLoanDetails() {
    // Simple debounce using setState delay
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        _calculateLoanDetails();
      }
    });
  }

  // Fetch Employees: Retrieves employees for the user's company
  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId == 0) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      setState(() {
        _employees = employees;
        _selectedEmployeeId = null;
        _selectedEmployeeName = null;
        _isLoadingEmployees = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoadingEmployees = false;
      });
    }
  }

  // Calculate Loan Details: Computes loan repayment details
  void _calculateLoanDetails() {
    setState(() {
      _loanAmount = double.tryParse(_amountController.text) ?? 0.0;
      int loanPeriod = int.tryParse(_loanPeriodController.text) ?? 0;
      _interestRate = double.tryParse(_interestRateController.text) ?? 0.0;

      if (loanPeriod > 0 && _loanAmount > 0 && _interestRate >= 0) {
        double monthlyRate = _interestRate / 100 / 12;
        double denominator = pow(1 + monthlyRate, loanPeriod) - 1;
        if (denominator > 0) {
          _monthlyPayment = _loanAmount *
              (monthlyRate * pow(1 + monthlyRate, loanPeriod)) /
              denominator;
        } else {
          _monthlyPayment =
              _loanAmount / loanPeriod; // Fallback for zero interest
        }
        _totalRepayment = _monthlyPayment * loanPeriod;
        _interestAmount = _totalRepayment - _loanAmount;

        // Guard against NaN or Infinity
        if (_monthlyPayment.isNaN || _monthlyPayment.isInfinite) {
          _monthlyPayment = 0.0;
        }
        if (_totalRepayment.isNaN || _totalRepayment.isInfinite) {
          _totalRepayment = _loanAmount;
        }
        if (_interestAmount.isNaN || _interestAmount.isInfinite) {
          _interestAmount = 0.0;
        }
      } else {
        _monthlyPayment = 0.0;
        _totalRepayment = _loanAmount;
        _interestAmount = 0.0;
      }

      if (kDebugMode) {
        print('Loan Amount: $_loanAmount');
        print('Monthly Payment: $_monthlyPayment');
        print('Interest Rate: $_interestRate%');
        print('Interest Amount: $_interestAmount');
        print('Total Repayment: $_totalRepayment');
      }
    });
  }

  // Add New Loan: Submits the loan data to the backend
  Future<void> _addNewLoan() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _createdAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please complete all required fields and select a date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final loanData = {
        'employee_id': _selectedEmployeeId,
        'amount': double.parse(_amountController.text),
        'loan_period': int.parse(_loanPeriodController.text),
        'interest_rate': double.parse(_interestRateController.text) / 100,
        'created_at': DateFormat('yyyy-MM-dd').format(_createdAt!),
      };

      await widget.apiService.addLoan(loanData, _companyId!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan added successfully for $_selectedEmployeeName'),
          backgroundColor: Colors.teal[700],
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add loan: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _addNewLoan,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Select Creation Date: Shows a date picker for loan creation date
  Future<void> _selectCreationDate() async {
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
        _createdAt = pickedDate;
      });
    }
  }

  // Build Text Field: Creates a styled text input field
  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
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
          ? 'Please enter $label'
          : isNumber &&
                  (double.tryParse(value) == null || double.parse(value) <= 0)
              ? 'Please enter a valid positive number'
              : null,
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  // Build Employee Dropdown: Creates a dropdown for selecting an employee
  Widget _buildEmployeeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          value: _selectedEmployeeId,
          items: _employees.map((employee) {
            return DropdownMenuItem<String>(
              value: employee['employee_id']?.toString(),
              child: Text(
                '${employee['employee_id']} - ${employee['fullname']}',
                style: TextStyle(color: Colors.teal[900]),
              ),
            );
          }).toList(),
          onChanged: _isLoadingEmployees || _employees.isEmpty
              ? null
              : (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedEmployeeId = newValue;
                      _selectedEmployeeName = _employees.firstWhere((emp) =>
                          emp['employee_id'].toString() ==
                          newValue)['fullname'];
                    });
                  }
                },
          validator: (value) =>
              value == null ? 'Please select an employee' : null,
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
        ),
        if (_isLoadingEmployees)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: CircularProgressIndicator(color: Colors.teal[700]),
          ),
        if (_employees.isEmpty && !_isLoadingEmployees)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'No employees available for this company',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
      ],
    );
  }

  // Build Date Picker: Creates a date picker for loan creation date
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _selectCreationDate,
          icon: Icon(Icons.calendar_today, color: Colors.teal[700]),
          label: Text(
            _createdAt == null
                ? 'Select Creation Date'
                : DateFormat('yyyy-MM-dd').format(_createdAt!),
            style: TextStyle(color: Colors.teal[700]),
          ),
        ),
        if (_createdAt == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please select a creation date',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        if (_createdAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Creation Date: ${DateFormat('yyyy-MM-dd').format(_createdAt!)}',
              style: TextStyle(fontSize: 16, color: Colors.teal[900]),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add New Loan - $_companyName',
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
        child: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.teal[900], fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchEmployees,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                            // Company Name Display
                            Text(
                              'Company: $_companyName',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[900],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Employee Dropdown
                            _buildEmployeeDropdown(),
                            const SizedBox(height: 16),

                            // Loan Amount Field
                            _buildTextField(_amountController, 'Loan Amount',
                                isNumber: true),
                            const SizedBox(height: 16),

                            // Loan Period Field
                            _buildTextField(
                                _loanPeriodController, 'Loan Period (Months)',
                                isNumber: true),
                            const SizedBox(height: 16),

                            // Interest Rate Field
                            _buildTextField(
                                _interestRateController, 'Interest Rate (%)',
                                isNumber: true),
                            const SizedBox(height: 16),

                            // Creation Date Picker
                            _buildDatePicker(),
                            const SizedBox(height: 20),

                            // Loan Details Display
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
                                      'Loan Details',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[900],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Loan Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(_loanAmount)}',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                    Text(
                                      'Monthly Payment: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(_monthlyPayment)}',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                    Text(
                                      'Interest Rate: ${_interestRate.toStringAsFixed(2)}%',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                    Text(
                                      'Interest Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(_interestAmount)}',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                    Text(
                                      'Total Repayment: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(_totalRepayment)}',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Save Loan Button
                            ElevatedButton(
                              onPressed: _isLoading || _employees.isEmpty
                                  ? null
                                  : _addNewLoan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('Save Loan'),
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
