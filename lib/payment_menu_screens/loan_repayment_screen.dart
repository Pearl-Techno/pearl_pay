import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// Constants
class LoanRepaymentConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
}

class LoanRepaymentScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

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
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _allLoans = [];
  Map<String, dynamic>? _selectedLoan;
  bool _isLoadingEmployees = false;
  bool _isLoadingLoans = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  double _totalAmountRepaid = 0.0;
  double _totalRepaymentsForEmployee = 0.0;
  double _totalOutstanding = 0.0;
  double _generalTotalRepaid = 0.0;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _amountRepaidController.addListener(_calculateTotalAmountRepaid);
    _interestController.addListener(_calculateTotalAmountRepaid);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _amountRepaidController.removeListener(_calculateTotalAmountRepaid);
    _interestController.removeListener(_calculateTotalAmountRepaid);
    _amountRepaidController.dispose();
    _interestController.dispose();
    _repaymentDateController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeScreen() {
    if (widget.user.role.toLowerCase() != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorSnackBar('Access denied: Only admins can process loan repayments');
        Navigator.pop(context);
      });
      return;
    }

    final userCompanyId = widget.user.companyId;
    if (userCompanyId <= 0) {
      setState(() {
        _errorMessage = 'No valid company ID for user';
      });
      return;
    }
    _fetchCompanies();
  }

  void _onSearchChanged() {
    // Implement search functionality if needed
  }

  Future<void> _fetchCompanies() async {
    try {
      final userCompanyId = widget.user.companyId;
      if (userCompanyId <= 0) {
        throw Exception('No valid company ID for user');
      }
      setState(() {
        _selectedCompanyId = userCompanyId;
        _companyName = widget.user.companyName ?? 'Unknown';
        _errorMessage = null;
      });
      _fetchEmployeesAndLoans();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load company: $e';
      });
      _showErrorSnackBar('Failed to load company: $e');
    }
  }

  Future<void> _fetchEmployeesAndLoans() async {
    if (_selectedCompanyId == null) return;
    setState(() {
      _isLoadingEmployees = true;
      _isLoadingLoans = true;
    });
    try {
      if (_selectedCompanyId != widget.user.companyId) {
        throw Exception('Unauthorized access to company ID $_selectedCompanyId');
      }
      
      // Fetch employees and loans in parallel or sequence similar to loans_screen.dart
      final currentEmployeeId = _selectedEmployeeId;
      final employees = await widget.apiService.getEmployeeList(_selectedCompanyId!);
      final allLoans = await widget.apiService.fetchLoans(_selectedCompanyId!);

      setState(() {
        _employees = employees;
        _allLoans = allLoans;
        
        // Preserve selected employee if they still exist in the list
        if (currentEmployeeId != null && employees.any((e) => e['employee_id'].toString() == currentEmployeeId)) {
          _selectedEmployeeId = currentEmployeeId;
        } else {
          _selectedEmployeeId = null;
          _selectedLoan = null;
          _loans = [];
          _totalRepaymentsForEmployee = 0.0;
          _totalOutstanding = 0.0;
          _generalTotalRepaid = 0.0;
        }
        
        _isLoadingEmployees = false;
        _isLoadingLoans = false;
        _errorMessage = null;
      });

      if (_selectedEmployeeId != null) {
        _filterLoansForEmployee();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoadingEmployees = false;
        _isLoadingLoans = false;
      });
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }

  void _filterLoansForEmployee() {
    if (_selectedEmployeeId == null) {
      setState(() {
        _loans = [];
        _selectedLoan = null;
        _totalOutstanding = 0.0;
        _generalTotalRepaid = 0.0;
      });
      return;
    }

    // Initial calculation with 0 repayment to show data immediately
    _recalculateLoansWithRepayment(0.0);
    _fetchTotalRepayments();
  }

  void _recalculateLoansWithRepayment(double repaymentAmount) {
    final loans = _allLoans.where((loan) => 
      loan['employee_id'].toString() == _selectedEmployeeId
    ).toList();

    double tempOutstanding = 0.0;
    double tempTotalRepaid = 0.0;
    double remainingRepaymentToDistribute = repaymentAmount;

    final newLoans = loans.map((loan) {
      final amount = _parseAmount(loan['amount']);
      final staticTotalRepaid = _parseAmount(loan['total_amount_repaid']);
      
      double interest = _parseAmount(loan['interest']);
      if (interest == 0 && loan['interest_rate'] != null) {
         final rate = _parseAmount(loan['interest_rate']);
         interest = amount * rate;
      }

      // Calculate base remaining before applying the fetched monthly repayment
      double baseRemaining = (amount + interest) - staticTotalRepaid;
      if (baseRemaining < 0) baseRemaining = 0;

      // Distribute the fetched repayment amount to this loan
      double currentLoanRepayment = 0.0;
      if (remainingRepaymentToDistribute > 0) {
          if (remainingRepaymentToDistribute >= baseRemaining) {
              currentLoanRepayment = baseRemaining;
              remainingRepaymentToDistribute -= baseRemaining;
          } else {
              currentLoanRepayment = remainingRepaymentToDistribute;
              remainingRepaymentToDistribute = 0;
          }
      }

      double finalRemaining = baseRemaining - currentLoanRepayment;
      double finalTotalRepaid = staticTotalRepaid + currentLoanRepayment;
      if (finalRemaining < 0) finalRemaining = 0;

      tempOutstanding += finalRemaining;
      tempTotalRepaid += finalTotalRepaid;

      return {
        'loan_id': loan['loan_id'],
        'employee_id': loan['employee_id'],
        'company_id': loan['company_id'],
        'loan_amount': amount,
        'total_repaid': finalTotalRepaid,
        'interest': interest,
        'loan_rate': _parseAmount(loan['interest_rate']),
        'loan_period': loan['loan_period'],
        'outstanding_balance': finalRemaining,
        'date_issued': loan['created_at'] ?? loan['date_loan'],
      };
    }).toList();

    setState(() {
        _loans = newLoans;
        _totalOutstanding = tempOutstanding;
        _generalTotalRepaid = tempTotalRepaid;

        if (_selectedLoan != null) {
          final currentId = _selectedLoan!['loan_id'];
          try {
            _selectedLoan = _loans.firstWhere((l) => l['loan_id'] == currentId);
          } catch (_) {
            _selectedLoan = _loans.isNotEmpty ? _loans[0] : null;
          }
        } else {
          _selectedLoan = _loans.isNotEmpty ? _loans[0] : null;
        }
    });
  }

  Future<void> _fetchTotalRepayments() async {
    if (_selectedCompanyId == null || _selectedEmployeeId == null) return;
    try {
      if (_selectedCompanyId != widget.user.companyId) {
        throw Exception('Unauthorized access to company ID $_selectedCompanyId');
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
      _recalculateLoansWithRepayment(total);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching total repayments: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load total repayments: Access denied: $e';
      });
      _showErrorSnackBar('Failed to load total repayments: $e');
    }
  }

  void _calculateTotalAmountRepaid() {
    final amountRepaid = double.tryParse(_amountRepaidController.text) ?? 0.0;
    final interest = double.tryParse(_interestController.text) ?? 0.0;
    setState(() {
      _totalAmountRepaid = amountRepaid + interest;
    });
  }

  Future<void> _selectRepaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: LoanRepaymentConstants.primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: LoanRepaymentConstants.primaryColor),
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

  Future<void> _processLoanRepayment() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _repaymentDate == null ||
        _selectedLoan == null) {
      _showErrorSnackBar('Please complete all required fields and select a valid loan');
      return;
    }

    final amountRepaid = double.parse(_amountRepaidController.text);
    final interest = double.parse(_interestController.text);
    final outstandingBalance = _selectedLoan!['outstanding_balance']?.toDouble() ?? 0.0;

    if (amountRepaid + interest > outstandingBalance) {
      _showErrorSnackBar('Repayment amount cannot exceed outstanding balance of ${_currencyFormat.format(outstandingBalance)}');
      return;
    }

    if (_selectedCompanyId != widget.user.companyId) {
      _showErrorSnackBar('Unauthorized access to selected company');
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
      await widget.apiService.processLoanRepayment(repaymentData, _selectedCompanyId!);

      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == _selectedEmployeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      
      _showSuccessSnackBar('Loan repayment processed successfully for ${employee['fullname']}');

      _amountRepaidController.clear();
      _interestController.clear();
      _repaymentDateController.clear();
      setState(() {
        _repaymentDate = null;
        _totalAmountRepaid = 0.0;
      });
      // Refresh data to get updated balances
      await _fetchEmployeesAndLoans();
    } catch (e) {
      if (kDebugMode) {
        print('Error processing repayment: $e');
      }
      setState(() {
        _errorMessage = 'Failed to process repayment: $e';
      });
      _showErrorSnackBar('Failed to process repayment: $e');
    } finally {
      setState(() => _isSubmitting = false);
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
        backgroundColor: LoanRepaymentConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoanRepaymentConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Loan Repayment',
        backgroundColor: LoanRepaymentConstants.primaryColor,
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          if (kDebugMode) print('Profile tapped');
        },
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildStatisticsCards(),
                  const SizedBox(height: 16),
                  _buildContentSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [LoanRepaymentConstants.primaryColor, LoanRepaymentConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
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
                    Icons.payments,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loan Repayment',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Process employee loan repayments',
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

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Outstanding',
            value: _currencyFormat.format(_totalOutstanding),
            icon: Icons.account_balance_wallet,
            color: LoanRepaymentConstants.warningColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'Total Repaid',
            value: _currencyFormat.format(_generalTotalRepaid),
            icon: Icons.done_all,
            color: LoanRepaymentConstants.successColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'Monthly',
            value: _currencyFormat.format(_totalRepaymentsForEmployee),
            icon: Icons.calendar_today,
            color: LoanRepaymentConstants.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LoanRepaymentConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: LoanRepaymentConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: LoanRepaymentConstants.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: LoanRepaymentConstants.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_errorMessage != null) _buildInlineError(),
            _buildEmployeeDropdown(),
            const SizedBox(height: 20),
            if (_selectedEmployeeId != null) _buildLoanDropdown(),
            if (_selectedLoan != null) ...[
              const SizedBox(height: 20),
              _buildLoanDetailsCard(),
              const SizedBox(height: 20),
              _buildRepaymentForm(),
              const SizedBox(height: 20),
              _buildRepaymentSummary(),
            ],
            const SizedBox(height: 24),
            if (_selectedEmployeeId != null && _selectedLoan != null)
              _buildSubmitButton(),
            if (_selectedEmployeeId != null) ...[
              const SizedBox(height: 32),
              _buildRepaidLoansList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[900]),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red[700]),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    // Ensure unique items to prevent DropdownButton assertion error
    final uniqueIds = <String>{};
    final dropdownItems = _employees
        .where((e) => e['employee_id'] != null && uniqueIds.add(e['employee_id'].toString()))
        .map((employee) {
      return DropdownMenuItem<String>(
        value: employee['employee_id'].toString(),
        child: Text(
          '${employee['employee_id']} - ${employee['fullname']}',
          style: TextStyle(color: LoanRepaymentConstants.textColor),
        ),
      );
    }).toList();

    // Ensure selected value exists in items
    String? validSelectedId = _selectedEmployeeId;
    if (validSelectedId != null && !dropdownItems.any((item) => item.value == validSelectedId)) {
      validSelectedId = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Employee *',
          style: TextStyle(
            color: LoanRepaymentConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LoanRepaymentConstants.subtitleColor.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: validSelectedId,
            items: dropdownItems,
            onChanged: (value) {
              setState(() {
                _selectedEmployeeId = value;
                _selectedLoan = null;
                _loans = [];
                _amountRepaidController.clear();
                _interestController.clear();
                _totalAmountRepaid = 0.0;
                _totalRepaymentsForEmployee = 0.0;
                _totalOutstanding = 0.0;
                _generalTotalRepaid = 0.0;
              });
              if (value != null) {
                _filterLoansForEmployee();
              }
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.person, color: LoanRepaymentConstants.primaryColor),
              border: InputBorder.none,
              filled: true,
              fillColor: LoanRepaymentConstants.backgroundColor,
            ),
            validator: (value) => value == null ? 'Please select an employee' : null,
            dropdownColor: LoanRepaymentConstants.cardColor,
            icon: Icon(Icons.arrow_drop_down, color: LoanRepaymentConstants.primaryColor),
          ),
        ),
        if (_isLoadingEmployees)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                CircularProgressIndicator(
                  color: LoanRepaymentConstants.primaryColor,
                  strokeWidth: 2,
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading employees...',
                  style: TextStyle(color: LoanRepaymentConstants.subtitleColor),
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

  Widget _buildLoanDropdown() {
    final activeLoans = _loans.where((loan) {
      final outstanding = loan['outstanding_balance'] as double? ?? 0.0;
      return outstanding > 0.01;
    }).toList();

    final dropdownItems = activeLoans.map((loan) {
      return DropdownMenuItem<Map<String, dynamic>>(
        value: loan,
        child: Text(
          '#${loan['loan_id']} - Bal: ${_currencyFormat.format(loan['outstanding_balance'])} - Paid: ${_currencyFormat.format(loan['total_repaid'])}',
          style: TextStyle(color: LoanRepaymentConstants.textColor, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    // Ensure selected loan exists in items (checking reference equality since _selectedLoan comes from _loans)
    Map<String, dynamic>? validSelectedLoan = _selectedLoan;
    if (validSelectedLoan != null && !dropdownItems.any((item) => item.value == validSelectedLoan)) {
      validSelectedLoan = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Loan *',
          style: TextStyle(
            color: LoanRepaymentConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LoanRepaymentConstants.subtitleColor.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonFormField<Map<String, dynamic>>(
            isExpanded: true,
            initialValue: validSelectedLoan,
            items: dropdownItems,
            onChanged: (value) {
              setState(() {
                _selectedLoan = value;
                _amountRepaidController.clear();
                _interestController.clear();
                _totalAmountRepaid = 0.0;
              });
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.credit_card, color: LoanRepaymentConstants.primaryColor),
              border: InputBorder.none,
              filled: true,
              fillColor: LoanRepaymentConstants.backgroundColor,
            ),
            validator: (value) => value == null && _selectedEmployeeId != null
                ? 'Please select a loan'
                : null,
            dropdownColor: LoanRepaymentConstants.cardColor,
            icon: Icon(Icons.arrow_drop_down, color: LoanRepaymentConstants.primaryColor),
          ),
        ),
        if (_isLoadingLoans)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                CircularProgressIndicator(
                  color: LoanRepaymentConstants.primaryColor,
                  strokeWidth: 2,
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading loans...',
                  style: TextStyle(color: LoanRepaymentConstants.subtitleColor),
                ),
              ],
            ),
          ),
        if (activeLoans.isEmpty && !_isLoadingLoans && _selectedEmployeeId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'No active loans for this employee',
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
          color: LoanRepaymentConstants.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LoanRepaymentConstants.primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: LoanRepaymentConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Loan Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: LoanRepaymentConstants.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLoanDetailRow('Loan Amount', _selectedLoan!['loan_amount'] ?? 0.0),
            _buildLoanDetailRow('Interest', _selectedLoan!['interest'] ?? 0.0),
            _buildLoanDetailRow('Total Paid', _selectedLoan!['total_repaid'] ?? 0.0),
            _buildLoanDetailRow('Interest Rate', _selectedLoan!['loan_rate'] ?? 0.0, isPercentage: true),
            _buildLoanDetailRow('Loan Period', _selectedLoan!['loan_period'] ?? 0, isMonths: true),
            _buildLoanDetailRow('Outstanding Balance', _selectedLoan!['outstanding_balance'] ?? 0.0, isHighlighted: true),
            _buildLoanDetailRow('Date Issued', _formatDate(_selectedLoan!['date_issued']), isDate: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanDetailRow(String label, dynamic value, {
    bool isPercentage = false,
    bool isMonths = false,
    bool isDate = false,
    bool isHighlighted = false,
  }) {
    String displayValue;
    if (isPercentage) {
      displayValue = '${(value as num).toStringAsFixed(2)}%';
    } else if (isMonths) {
      displayValue = '$value months';
    } else if (isDate) {
      displayValue = value.toString();
    } else if (value is num) {
      displayValue = _currencyFormat.format(value);
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: LoanRepaymentConstants.subtitleColor,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            displayValue,
            style: TextStyle(
              color: isHighlighted ? LoanRepaymentConstants.primaryColor : LoanRepaymentConstants.textColor,
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentForm() {
    return Column(
      children: [
        _buildAmountField(
          controller: _amountRepaidController,
          label: 'Amount Repaid',
          hintText: 'e.g., 5000.00',
        ),
        const SizedBox(height: 16),
        _buildAmountField(
          controller: _interestController,
          label: 'Interest',
          hintText: 'e.g., 250.00',
        ),
        const SizedBox(height: 16),
        _buildDatePicker(),
        const SizedBox(height: 16),
        _buildTotalAmountCard(),
      ],
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(
            color: LoanRepaymentConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: hintText,
            hintStyle: TextStyle(color: LoanRepaymentConstants.subtitleColor),
            prefixIcon: Icon(Icons.attach_money, color: LoanRepaymentConstants.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: LoanRepaymentConstants.subtitleColor.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: LoanRepaymentConstants.subtitleColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: LoanRepaymentConstants.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: LoanRepaymentConstants.backgroundColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter $label';
            final num = double.tryParse(value);
            if (num == null || num <= 0) return 'Please enter a valid positive amount';
            if (label.contains('Amount Repaid') && num > 100000) {
              return 'Amount repaid cannot exceed KES 100,000';
            }
            if (label.contains('Interest') && num > 50000) {
              return 'Interest cannot exceed KES 50,000';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repayment Date *',
          style: TextStyle(
            color: LoanRepaymentConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LoanRepaymentConstants.subtitleColor.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            onTap: _selectRepaymentDate,
            leading: Icon(Icons.calendar_today, color: LoanRepaymentConstants.primaryColor),
            title: Text(
              _repaymentDate == null
                  ? 'Select Repayment Date'
                  : DateFormat('MMMM dd, yyyy').format(_repaymentDate!),
              style: TextStyle(
                color: _repaymentDate == null 
                    ? LoanRepaymentConstants.subtitleColor 
                    : LoanRepaymentConstants.textColor,
              ),
            ),
            trailing: Icon(Icons.arrow_drop_down, color: LoanRepaymentConstants.primaryColor),
          ),
        ),
        if (_repaymentDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please select a date',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTotalAmountCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LoanRepaymentConstants.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LoanRepaymentConstants.successColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.calculate, color: LoanRepaymentConstants.successColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount Repaid',
                    style: TextStyle(
                      color: LoanRepaymentConstants.successColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(_totalAmountRepaid),
                    style: TextStyle(
                      color: LoanRepaymentConstants.successColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildRepaymentSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LoanRepaymentConstants.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LoanRepaymentConstants.accentColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: LoanRepaymentConstants.accentColor),
                const SizedBox(width: 8),
                Text(
                  'Repayment Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: LoanRepaymentConstants.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMonthYearDropdown(
                    value: _selectedMonth,
                    items: List.generate(12, (index) => index + 1),
                    label: 'Month',
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value!;
                        _totalRepaymentsForEmployee = 0.0;
                      });
                      _fetchTotalRepayments();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonthYearDropdown(
                    value: _selectedYear,
                    items: List.generate(10, (index) => DateTime.now().year - 5 + index),
                    label: 'Year',
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value!;
                        _totalRepaymentsForEmployee = 0.0;
                      });
                      _fetchTotalRepayments();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total Repayments for ${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear:',
              style: TextStyle(
                color: LoanRepaymentConstants.subtitleColor,
                fontSize: 14,
              ),
            ),
            Text(
              _currencyFormat.format(_totalRepaymentsForEmployee),
              style: TextStyle(
                color: LoanRepaymentConstants.accentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthYearDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LoanRepaymentConstants.textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LoanRepaymentConstants.subtitleColor.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        color: LoanRepaymentConstants.textColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: LoanRepaymentConstants.primaryColor, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepaidLoansList() {
    final repaidLoans = _loans.where((loan) {
      final outstanding = loan['outstanding_balance'] as double? ?? 0.0;
      return outstanding <= 0.01;
    }).toList();

    if (repaidLoans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: LoanRepaymentConstants.subtitleColor),
            const SizedBox(width: 8),
            Text(
              'Repaid Loans History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: LoanRepaymentConstants.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: repaidLoans.length,
          itemBuilder: (context, index) {
            final loan = repaidLoans[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LoanRepaymentConstants.successColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle, color: LoanRepaymentConstants.successColor),
                ),
                title: Text(
                  'Loan #${loan['loan_id']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: LoanRepaymentConstants.textColor,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Amount: ${_currencyFormat.format(loan['loan_amount'])}'),
                    Text('Total Paid: ${_currencyFormat.format(loan['total_repaid'])}'),
                    Text('Date Issued: ${_formatDate(loan['date_issued'])}'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Fully Repaid',
                      style: TextStyle(
                        color: LoanRepaymentConstants.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _processLoanRepayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: LoanRepaymentConstants.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Process Repayment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.tryParse(dateString);
      return date != null ? DateFormat('MMM dd, yyyy').format(date) : 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }
}