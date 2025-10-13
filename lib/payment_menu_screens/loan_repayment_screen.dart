import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';

// LoanRepaymentScreen: Allows admins to process loan repayments for employees
class LoanRepaymentScreen extends StatefulWidget {
  final User user; // User data from HomeScreen
  final ApiService apiService; // ApiService for backend calls

  const LoanRepaymentScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<LoanRepaymentScreen> createState() => _LoanRepaymentScreenState();
}

class _LoanRepaymentScreenState extends State<LoanRepaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountRepaidController = TextEditingController();
  final _interestController = TextEditingController();
  final _repaymentDateController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedEmployeeId;
  DateTime? _repaymentDate;
  int? _selectedCompanyId;
  String? _companyName;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _loans = [];
  Map<String, dynamic>? _selectedLoan;
  bool _isLoadingCompanies = false;
  bool _isLoadingEmployees = false;
  bool _isLoadingLoans = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  double _totalAmountRepaid = 0.0;
  double _totalRepaymentsForEmployee = 0.0;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    // Restrict access to admins only
    if (widget.user.role.toLowerCase() != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Access denied: Only admins can process loan repayments')),
        );
        Navigator.pop(context);
      });
      return;
    }

    // Set company details
    final userCompanyId = widget.user.companyId != null
        ? int.tryParse(widget.user.companyId.toString())
        : null;
    if (userCompanyId == null) {
      setState(() {
        _errorMessage = 'No valid company ID for user';
      });
      return;
    }
    _fetchCompanies();
  }

  @override
  void dispose() {
    _amountRepaidController.removeListener(_calculateTotalAmountRepaid);
    _interestController.removeListener(_calculateTotalAmountRepaid);
    _amountRepaidController.dispose();
    _interestController.dispose();
    _repaymentDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Fetch Companies: Sets the user's company only
  Future<void> _fetchCompanies() async {
    setState(() => _isLoadingCompanies = true);
    try {
      final userCompanyId = widget.user.companyId != null
          ? int.tryParse(widget.user.companyId.toString())
          : null;
      if (userCompanyId == null) {
        throw Exception('No valid company ID for user');
      }
      setState(() {
        _companies = [
          {
            'id': userCompanyId,
            'company_name': widget.user.companyName ?? 'Unknown'
          }
        ];
        _selectedCompanyId = userCompanyId;
        _companyName = widget.user.companyName ?? 'Unknown';
        _isLoadingCompanies = false;
        _errorMessage = null;
      });
      if (_selectedCompanyId != null) {
        _fetchEmployees();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load company: $e';
        _isLoadingCompanies = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load company: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch Employees: Retrieves employees for the user's company
  Future<void> _fetchEmployees() async {
    if (_selectedCompanyId == null) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final userCompanyId = widget.user.companyId != null
          ? int.tryParse(widget.user.companyId.toString())
          : null;
      if (userCompanyId == null || _selectedCompanyId != userCompanyId) {
        throw Exception(
            'Unauthorized access to company ID $_selectedCompanyId');
      }
      final employees =
          await widget.apiService.getEmployeeList(_selectedCompanyId!);
      setState(() {
        _employees = employees;
        _selectedEmployeeId = null;
        _selectedLoan = null;
        _loans = [];
        _totalRepaymentsForEmployee = 0.0;
        _isLoadingEmployees = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Unauthorized access for company ID $_selectedCompanyId: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load employees: Access denied: $e';
        _isLoadingEmployees = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load employees: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _fetchEmployees,
          ),
        ),
      );
    }
  }

  // Fetch Loans: Retrieves active loans for the selected employee
  Future<void> _fetchLoans() async {
    if (_selectedCompanyId == null || _selectedEmployeeId == null) return;
    setState(() => _isLoadingLoans = true);
    try {
      final userCompanyId = widget.user.companyId != null
          ? int.tryParse(widget.user.companyId.toString())
          : null;
      if (userCompanyId == null || _selectedCompanyId != userCompanyId) {
        throw Exception(
            'Unauthorized access to company ID $_selectedCompanyId');
      }
      final loans = await widget.apiService
          .fetchLoansForEmployee(_selectedEmployeeId!, _selectedCompanyId!);
      setState(() {
        _loans = loans.map((loan) {
          if (kDebugMode) {
            if (loan['amount'] == null) {
              print('Null amount for loan ID: ${loan['loan_id']}');
            }
            if (loan['remaining_amount'] == null) {
              print('Null remaining_amount for loan ID: ${loan['loan_id']}');
            }
          }
          return {
            'loan_id': loan['loan_id'],
            'employee_id': loan['employee_id'],
            'company_id': loan['company_id'],
            'loan_amount': loan['amount']?.toDouble(),
            'loan_rate': loan['interest_rate']?.toDouble(),
            'loan_period': loan['loan_period'],
            'outstanding_balance': loan['remaining_amount']?.toDouble(),
            'date_issued': loan['created_at'],
          };
        }).toList();
        _selectedLoan = _loans.isNotEmpty ? _loans[0] : null;
        _isLoadingLoans = false;
        _errorMessage = null;
      });
      if (_selectedEmployeeId != null) {
        _fetchTotalRepayments();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Unauthorized access for company ID $_selectedCompanyId: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load loans: Access denied: $e';
        _isLoadingLoans = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load loans: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _fetchLoans,
          ),
        ),
      );
    }
  }

  // Fetch Total Repayments: Retrieves total repayment amount for the selected employee
  Future<void> _fetchTotalRepayments() async {
    if (_selectedCompanyId == null || _selectedEmployeeId == null) return;
    try {
      final userCompanyId = widget.user.companyId != null
          ? int.tryParse(widget.user.companyId.toString())
          : null;
      if (userCompanyId == null || _selectedCompanyId != userCompanyId) {
        throw Exception(
            'Unauthorized access to company ID $_selectedCompanyId');
      }
      final total = await widget.apiService.fetchLoanRepayment(
        _selectedEmployeeId!,
        _selectedCompanyId!,
        _selectedMonth,
        _selectedYear,
      );
      setState(() {
        _totalRepaymentsForEmployee = total;
        _errorMessage = null;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Unauthorized access for company ID $_selectedCompanyId: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load total repayments: Access denied: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load total repayments: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _fetchTotalRepayments,
          ),
        ),
      );
    }
  }

  // Calculate Total Amount Repaid: Updates total amount based on amount repaid and interest
  void _calculateTotalAmountRepaid() {
    final amountRepaid = double.tryParse(_amountRepaidController.text) ?? 0.0;
    final interest = double.tryParse(_interestController.text) ?? 0.0;
    setState(() {
      _totalAmountRepaid = amountRepaid + interest;
    });
  }

  // Select Repayment Date: Shows a date picker for repayment date
  Future<void> _selectRepaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
    if (picked != null) {
      setState(() {
        _repaymentDate = picked;
        _repaymentDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // Process Loan Repayment: Submits repayment data to the backend
  Future<void> _processLoanRepayment() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _repaymentDate == null ||
        _selectedLoan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please complete all required fields and select a valid loan')),
      );
      return;
    }

    final amountRepaid = double.parse(_amountRepaidController.text);
    final interest = double.parse(_interestController.text);
    final outstandingBalance =
        _selectedLoan!['outstanding_balance']?.toDouble() ?? 0.0;

    if (amountRepaid + interest > outstandingBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Repayment amount cannot exceed outstanding balance of ${_currencyFormat.format(outstandingBalance)}')),
      );
      return;
    }

    final userCompanyId = widget.user.companyId != null
        ? int.tryParse(widget.user.companyId.toString())
        : null;
    if (userCompanyId == null || _selectedCompanyId != userCompanyId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unauthorized access to selected company')),
      );
      return;
    }

    final repaymentData = {
      'loan_id': _selectedLoan!['loan_id'],
      'employee_id': _selectedEmployeeId,
      'company_id': _selectedCompanyId,
      'amount_repaid': amountRepaid,
      'interest': interest,
      'total_amount_repaid': _totalAmountRepaid,
      'repayment_date': DateFormat('yyyy-MM-dd').format(_repaymentDate!),
    };

    setState(() => _isSubmitting = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Processing loan repayment...'),
          backgroundColor: Colors.teal[700],
        ),
      );

      await widget.apiService
          .processLoanRepayment(repaymentData, _selectedCompanyId!);

      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == _selectedEmployeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loan Repayment Processed: ${employee['fullname']}, Amount: ${_currencyFormat.format(amountRepaid)}, Interest: ${_currencyFormat.format(interest)}, Total: ${_currencyFormat.format(_totalAmountRepaid)}, ${DateFormat.yMMMd().format(_repaymentDate!)}',
          ),
          backgroundColor: Colors.teal[700],
        ),
      );

      _amountRepaidController.clear();
      _interestController.clear();
      _repaymentDateController.clear();
      setState(() {
        _selectedEmployeeId = null;
        _selectedLoan = null;
        _loans = [];
        _repaymentDate = null;
        _totalAmountRepaid = 0.0;
        _totalRepaymentsForEmployee = 0.0;
      });
      await _fetchLoans();
      await _fetchTotalRepayments();
    } catch (e) {
      String errorMessage = 'Failed to process repayment: $e';
      if (e is UnauthorizedAccessException) {
        errorMessage = 'Unauthorized: Please log in again';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
      } else if (e is ServerException) {
        errorMessage = 'Server error (${e.statusCode}): ${e.message}';
      } else if (e is NetworkException) {
        errorMessage = 'Network error: Please check your connection';
      }
      if (kDebugMode) {
        print('Unauthorized access for company ID $_selectedCompanyId: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _processLoanRepayment,
          ),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Build Dropdown: Creates a styled dropdown widget
  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    bool isEnabled = true,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.teal[900],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          decoration: InputDecoration(
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
          value: value,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemBuilder(item),
                      style: TextStyle(color: Colors.teal[900]),
                    ),
                  ))
              .toList(),
          onChanged: isEnabled ? onChanged : null,
          validator: validator ??
              (value) => value == null ? 'Please select $label' : null,
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
          isExpanded: true,
        ),
      ],
    );
  }

  // Build Text Field: Creates a styled text input field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    bool readOnly = false,
    String? hintText,
    String? prefixText,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
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
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixText: prefixText,
        prefixStyle:
            prefixText != null ? TextStyle(color: Colors.teal[900]) : null,
        suffixText: suffixText,
        suffixStyle:
            suffixText != null ? TextStyle(color: Colors.teal[900]) : null,
      ),
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) return 'Please enter $label';
            if (isNumber && !readOnly) {
              final num = double.tryParse(value);
              if (num == null || num <= 0)
                return 'Please enter a valid positive amount';
              if (label.contains('Amount Repaid') && num > 100000) {
                return 'Amount repaid cannot exceed KES 100,000';
              }
              if (label.contains('Interest') && num > 50000) {
                return 'Interest cannot exceed KES 50,000';
              }
            }
            return null;
          },
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  // Build Date Picker: Creates a date picker field
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repayment Date',
          style: TextStyle(
            color: Colors.teal[900],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _repaymentDateController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Select Date',
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
            suffixIcon: IconButton(
              icon: Icon(Icons.calendar_today, color: Colors.teal[700]),
              onPressed: _selectRepaymentDate,
            ),
          ),
          validator: (value) =>
              _repaymentDate == null ? 'Please select a repayment date' : null,
          style: TextStyle(color: Colors.grey[800]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Loan Repayment - $_companyName'),
            backgroundColor: Colors.teal[800],
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  _fetchCompanies();
                  if (_selectedEmployeeId != null) {
                    _fetchLoans();
                    _fetchTotalRepayments();
                  }
                },
                tooltip: 'Refresh Data',
              ),
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => print('Notifications tapped'),
                tooltip: 'Notifications',
              ),
              IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () => print('Profile tapped'),
                tooltip: 'Profile',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
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
                            style: TextStyle(
                                color: Colors.teal[900], fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _fetchCompanies();
                              if (_selectedEmployeeId != null) {
                                _fetchLoans();
                                _fetchTotalRepayments();
                              }
                            },
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Repayment Form
                          Card(
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
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Company: $_companyName',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[900],
                                      ),
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Employee Dropdown
                                    _buildDropdown<String>(
                                      label: 'Employee',
                                      value: _selectedEmployeeId,
                                      items: _isLoadingEmployees ||
                                              _employees.isEmpty
                                          ? []
                                          : _employees
                                              .map((e) =>
                                                  e['employee_id'].toString())
                                              .toList(),
                                      itemBuilder: (id) {
                                        final employee = _employees.firstWhere(
                                          (emp) =>
                                              emp['employee_id'].toString() ==
                                              id,
                                          orElse: () => {'fullname': 'Unknown'},
                                        );
                                        return '${employee['employee_id']} - ${employee['fullname']}';
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedEmployeeId = value;
                                          _selectedLoan = null;
                                          _loans = [];
                                          _amountRepaidController.clear();
                                          _interestController.clear();
                                          _totalAmountRepaid = 0.0;
                                          _totalRepaymentsForEmployee = 0.0;
                                        });
                                        if (value != null) {
                                          _fetchLoans();
                                        }
                                      },
                                      isEnabled: !_isLoadingEmployees &&
                                          _employees.isNotEmpty,
                                    ),
                                    if (_isLoadingEmployees)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: CircularProgressIndicator(
                                            color: Colors.teal[700]),
                                      ),
                                    if (_employees.isEmpty &&
                                        !_isLoadingEmployees)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'No employees available for this company',
                                          style:
                                              TextStyle(color: Colors.red[700]),
                                        ),
                                      ),
                                    const SizedBox(height: 16.0),
                                    // Loan Dropdown
                                    _buildDropdown<Map<String, dynamic>>(
                                      label: 'Loan',
                                      value: _selectedLoan,
                                      items: _isLoadingLoans || _loans.isEmpty
                                          ? []
                                          : _loans,
                                      itemBuilder: (loan) =>
                                          'Loan ID: ${loan['loan_id']} - ${_currencyFormat.format(loan['loan_amount'] ?? 0.0)} (Balance: ${_currencyFormat.format(loan['outstanding_balance'] ?? 0.0)})',
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedLoan = value;
                                          _amountRepaidController.clear();
                                          _interestController.clear();
                                          _totalAmountRepaid = 0.0;
                                        });
                                      },
                                      isEnabled:
                                          !_isLoadingLoans && _loans.isNotEmpty,
                                      validator: (value) => value == null &&
                                              _selectedEmployeeId != null
                                          ? 'Please select a loan'
                                          : null,
                                    ),
                                    if (_isLoadingLoans)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: CircularProgressIndicator(
                                            color: Colors.teal[700]),
                                      ),
                                    if (_loans.isEmpty &&
                                        !_isLoadingLoans &&
                                        _selectedEmployeeId != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'No active loans for this employee',
                                          style:
                                              TextStyle(color: Colors.red[700]),
                                        ),
                                      ),
                                    if (_selectedLoan != null) ...[
                                      const SizedBox(height: 16.0),
                                      // Loan Details
                                      Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Loan Details',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal[900],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Loan Amount: ${_currencyFormat.format(_selectedLoan!['loan_amount'] ?? 0.0)}',
                                                style: TextStyle(
                                                    color: Colors.grey[800]),
                                              ),
                                              Text(
                                                'Interest Rate: ${_selectedLoan!['loan_rate']?.toStringAsFixed(2) ?? '0.00'}%',
                                                style: TextStyle(
                                                    color: Colors.grey[800]),
                                              ),
                                              Text(
                                                'Loan Period: ${_selectedLoan!['loan_period'] ?? 0} months',
                                                style: TextStyle(
                                                    color: Colors.grey[800]),
                                              ),
                                              Text(
                                                'Outstanding Balance: ${_currencyFormat.format(_selectedLoan!['outstanding_balance'] ?? 0.0)}',
                                                style: TextStyle(
                                                    color: Colors.grey[800]),
                                              ),
                                              Text(
                                                'Date Issued: ${DateFormat.yMMMd().format(DateTime.parse(_selectedLoan!['date_issued'] ?? DateTime.now().toIso8601String()))}',
                                                style: TextStyle(
                                                    color: Colors.grey[800]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16.0),
                                    ],
                                    // Amount Repaid
                                    _buildTextField(
                                      controller: _amountRepaidController,
                                      label: 'Amount Repaid',
                                      isNumber: true,
                                      prefixText: 'KES ',
                                      hintText: 'e.g., 5000.00',
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Interest
                                    _buildTextField(
                                      controller: _interestController,
                                      label: 'Interest',
                                      isNumber: true,
                                      prefixText: 'KES ',
                                      hintText: 'e.g., 250.00',
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Repayment Date
                                    _buildDatePicker(),
                                    const SizedBox(height: 16.0),
                                    // Total Amount Repaid
                                    Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Amount Repaid',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal[900],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _currencyFormat
                                                  .format(_totalAmountRepaid),
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
                                    const SizedBox(height: 16.0),
                                    // Repayment Summary
                                    if (_selectedEmployeeId != null) ...[
                                      Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Repayment Summary for $_selectedMonth/$_selectedYear',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal[900],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildDropdown<int>(
                                                      label: 'Month',
                                                      value: _selectedMonth,
                                                      items: List.generate(12,
                                                          (index) => index + 1),
                                                      itemBuilder: (month) =>
                                                          month
                                                              .toString()
                                                              .padLeft(2, '0'),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _selectedMonth =
                                                              value!;
                                                          _totalRepaymentsForEmployee =
                                                              0.0;
                                                        });
                                                        _fetchTotalRepayments();
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: _buildDropdown<int>(
                                                      label: 'Year',
                                                      value: _selectedYear,
                                                      items: List.generate(
                                                          10,
                                                          (index) =>
                                                              DateTime.now()
                                                                  .year -
                                                              5 +
                                                              index),
                                                      itemBuilder: (year) =>
                                                          year.toString(),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _selectedYear =
                                                              value!;
                                                          _totalRepaymentsForEmployee =
                                                              0.0;
                                                        });
                                                        _fetchTotalRepayments();
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Total Repayments: ${_currencyFormat.format(_totalRepaymentsForEmployee)}',
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
                                      const SizedBox(height: 16.0),
                                    ],
                                    // Submit Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _processLoanRepayment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: _isSubmitting
                                            ? CircularProgressIndicator(
                                                color: Colors.white)
                                            : const Text('Save Repayment',
                                                style: TextStyle(fontSize: 16)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
