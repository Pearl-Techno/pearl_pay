import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// Constants
class AddLoanConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
}

class AddLoanScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AddLoanScreen({
    super.key,
    required this.apiService,
    required this.user,
  });

  @override
  AddLoanScreenState createState() => AddLoanScreenState();
}

class AddLoanScreenState extends State<AddLoanScreen> {
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
    _initializeUser();
    _setupControllers();
  }

  void _initializeUser() {
    try {
      _userModel = User(
        companyId: int.parse(widget.user['company_id']?.toString() ?? '0'),
        employeeId: widget.user['employee_id']?.toString() ?? 'N/A',
        role: (widget.user['role']?.toString() ?? 'unknown').toLowerCase(),
        userId: widget.user['user_id']?.toString(),
        username: widget.user['username']?.toString(),
        companyName: widget.user['company_name']?.toString(),
      );

      if (_userModel.role != 'admin') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorSnackBar('Access denied: Only admins can add loans');
          Navigator.pop(context);
        });
        return;
      }

      _companyId = _userModel.companyId;
      _companyName = _userModel.companyName ?? 'Unknown';

      if (_companyId != 0) {
        _fetchEmployees();
      } else {
        setState(() {
          _errorMessage = 'No company assigned to this user';
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorSnackBar('Invalid user data: $e');
        Navigator.pop(context);
      });
    }
  }

  void _setupControllers() {
    _amountController.addListener(_debouncedCalculateLoanDetails);
    _loanPeriodController.addListener(_debouncedCalculateLoanDetails);
    _interestRateController.addListener(_debouncedCalculateLoanDetails);
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

  void _debouncedCalculateLoanDetails() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _calculateLoanDetails();
      }
    });
  }

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
          _monthlyPayment = _loanAmount / loanPeriod;
        }
        _totalRepayment = _monthlyPayment * loanPeriod;
        _interestAmount = _totalRepayment - _loanAmount;

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
    });
  }

  Future<void> _addNewLoan() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _createdAt == null) {
      _showErrorSnackBar('Please complete all required fields and select a date');
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

      if (!mounted) return;
      _showSuccessSnackBar('Loan added successfully for $_selectedEmployeeName');
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Failed to add loan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCreationDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AddLoanConstants.primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AddLoanConstants.primaryColor),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AddLoanConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AddLoanConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Add New Loan',
        backgroundColor: AddLoanConstants.primaryColor,
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          if (kDebugMode) print('Profile tapped');
        },
      ),
      body: _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AddLoanConstants.subtitleColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                color: AddLoanConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: AddLoanConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchEmployees,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AddLoanConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _buildLoanForm(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AddLoanConstants.primaryColor, AddLoanConstants.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Loan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a new loan for an employee',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.business, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Company: $_companyName',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: AddLoanConstants.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmployeeDropdown(),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _amountController,
                label: 'Loan Amount',
                icon: Icons.attach_money,
                isNumber: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _loanPeriodController,
                      label: 'Loan Period (Months)',
                      icon: Icons.calendar_today,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _interestRateController,
                      label: 'Interest Rate (%)',
                      icon: Icons.trending_up,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDatePicker(),
              const SizedBox(height: 24),
              if (_loanAmount > 0) _buildLoanDetailsCard(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Employee *',
          style: TextStyle(
            color: AddLoanConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AddLoanConstants.subtitleColor.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonFormField<String>(
            key: ValueKey(_selectedEmployeeId),
            initialValue: _selectedEmployeeId,
            items: _employees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee['employee_id']?.toString(),
                child: Text(
                  '${employee['employee_id']} - ${employee['fullname']}',
                  style: TextStyle(color: AddLoanConstants.textColor),
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
                            emp['employee_id'].toString() == newValue)['fullname'];
                      });
                    }
                  },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.person, color: AddLoanConstants.primaryColor),
              border: InputBorder.none,
              filled: true,
              fillColor: AddLoanConstants.backgroundColor,
            ),
            validator: (value) => value == null ? 'Please select an employee' : null,
            dropdownColor: AddLoanConstants.cardColor,
            icon: Icon(Icons.arrow_drop_down, color: AddLoanConstants.primaryColor),
            style: TextStyle(color: AddLoanConstants.textColor, fontSize: 14),
          ),
        ),
        if (_isLoadingEmployees)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                CircularProgressIndicator(
                  color: AddLoanConstants.primaryColor,
                  strokeWidth: 2,
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading employees...',
                  style: TextStyle(color: AddLoanConstants.subtitleColor),
                ),
              ],
            ),
          ),
        if (_employees.isEmpty && !_isLoadingEmployees)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'No employees available for this company',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(
            color: AddLoanConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            labelText: label,
            labelStyle: TextStyle(color: AddLoanConstants.subtitleColor),
            prefixIcon: Icon(icon, color: AddLoanConstants.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AddLoanConstants.subtitleColor.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AddLoanConstants.subtitleColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AddLoanConstants.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: AddLoanConstants.backgroundColor,
          ),
          validator: (value) => value == null || value.isEmpty
              ? 'Please enter $label'
              : isNumber &&
                      (double.tryParse(value) == null || double.parse(value) <= 0)
                  ? 'Please enter a valid positive number'
                  : null,
          style: TextStyle(color: AddLoanConstants.textColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Creation Date *',
          style: TextStyle(
            color: AddLoanConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AddLoanConstants.subtitleColor.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            onTap: _selectCreationDate,
            leading: Icon(Icons.calendar_today, color: AddLoanConstants.primaryColor),
            title: Text(
              _createdAt == null
                  ? 'Select Creation Date'
                  : DateFormat('MMMM dd, yyyy').format(_createdAt!),
              style: TextStyle(
                color: _createdAt == null 
                    ? AddLoanConstants.subtitleColor 
                    : AddLoanConstants.textColor,
                fontSize: 14,
              ),
            ),
            trailing: Icon(Icons.arrow_drop_down, color: AddLoanConstants.primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ],
    );
  }

  Widget _buildLoanDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AddLoanConstants.successColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AddLoanConstants.successColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: AddLoanConstants.successColor),
                const SizedBox(width: 8),
                Text(
                  'Loan Calculation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AddLoanConstants.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLoanDetailRow('Loan Amount', _loanAmount),
            _buildLoanDetailRow('Monthly Payment', _monthlyPayment),
            _buildLoanDetailRow('Interest Rate', _interestRate, isPercentage: true),
            _buildLoanDetailRow('Interest Amount', _interestAmount),
            _buildLoanDetailRow('Total Repayment', _totalRepayment, isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanDetailRow(String label, double value, {
    bool isPercentage = false,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AddLoanConstants.subtitleColor,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            isPercentage 
                ? '${value.toStringAsFixed(2)}%'
                : 'KES ${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: isHighlighted ? AddLoanConstants.successColor : AddLoanConstants.textColor,
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading || _employees.isEmpty ? null : _addNewLoan,
        style: ElevatedButton.styleFrom(
          backgroundColor: AddLoanConstants.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Add Loan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}