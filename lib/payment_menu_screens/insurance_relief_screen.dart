import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart'; // Make sure to import CustomAppBar

// Constants - Using same colors as PaidSalariesScreen
class InsuranceReliefConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
  static const Color greyColor = Color(0xFF9E9E9E);
  static const Color errorColor = Color(0xFFC62828);
}

class InsuranceReliefScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const InsuranceReliefScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<InsuranceReliefScreen> createState() => _InsuranceReliefScreenState();
}

class _InsuranceReliefScreenState extends State<InsuranceReliefScreen> {
  final _formKey = GlobalKey<FormState>();
  final _premiumController = TextEditingController();
  final _percentageController = TextEditingController();
  final _reliefController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  int? _companyId;
  String? _companyName;
  
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _reliefRecords = [];
  List<Map<String, dynamic>> _filteredReliefRecords = [];
  
  bool _isLoadingEmployees = false;
  bool _isLoadingReliefs = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  final NumberFormat _currencyFormat = 
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);
  
  Timer? _debounceTimer;

  // Statistics
  double _totalReliefAmount = 0.0;
  int _totalReliefRecords = 0;

  @override
  void initState() {
    super.initState();
    
    // Restrict access to admins only - same pattern as PaidSalaries
    if (widget.user.role.toLowerCase() != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAccessDenied();
      });
      return;
    }

    _companyId = widget.user.companyId;
    _companyName = widget.user.companyName ?? 'Unknown Company';

    if (_companyId != 0) {
      _initializeData();
    } else {
      setState(() {
        _errorMessage = 'No company assigned to this user';
      });
    }

    _premiumController.addListener(_calculateRelief);
    _percentageController.addListener(_calculateRelief);
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeData() {
    _fetchEmployees();
    _fetchReliefRecords();
  }

  void _showAccessDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Access denied: Only admins can manage insurance reliefs')),
          ],
        ),
        backgroundColor: InsuranceReliefConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    Navigator.pop(context);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filterReliefRecords();
    });
  }

  // Apply the current search text to the loaded relief records and refresh UI.
  void _filterReliefRecords() {
    // Use the already loaded relief records to compute the filtered list.
    _applySearchFilter(_reliefRecords);

    // Ensure UI updates to reflect the filtered results.
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId == 0) return;
    
    setState(() => _isLoadingEmployees = true);
    
    try {
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _isLoadingEmployees = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoadingEmployees = false;
      });
    }
  }

  Future<void> _fetchReliefRecords() async {
    if (_companyId == null || _companyId == 0) return;
    
    setState(() => _isLoadingReliefs = true);
    
    try {
      final reliefRecords = await widget.apiService.getInsuranceRelief(
        companyId: _companyId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      
      _processReliefRecords(reliefRecords);
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load relief records: $e';
        _isLoadingReliefs = false;
      });
    }
  }

  void _processReliefRecords(List<Map<String, dynamic>> reliefRecords) {
    // Calculate statistics
    _calculateStatistics(reliefRecords);
    
    // Apply search filter
    _applySearchFilter(reliefRecords);

    if (mounted) {
      setState(() {
        _reliefRecords = reliefRecords;
        _isLoadingReliefs = false;
        _errorMessage = null;
      });
    }
  }

  void _calculateStatistics(List<Map<String, dynamic>> records) {
    _totalReliefAmount = records.fold(0.0, (sum, record) {
      final reliefAmount = double.tryParse(record['relief_amount']?.toString() ?? '0') ?? 0.0;
      return sum + reliefAmount;
    });
    
    _totalReliefRecords = records.length;
  }

  void _applySearchFilter(List<Map<String, dynamic>> records) {
    final searchText = _searchController.text.toLowerCase();
    
    if (searchText.isEmpty) {
      _filteredReliefRecords = records;
    } else {
      _filteredReliefRecords = records.where((record) {
        final employee = _employees.firstWhere(
          (emp) => emp['employee_id'].toString() == record['employee_id'].toString(),
          orElse: () => {'fullname': 'Unknown Employee'},
        );
        final fullname = (employee['fullname']?.toString() ?? '').toLowerCase();
        final employeeId = (employee['employee_id']?.toString() ?? '').toLowerCase();
        return fullname.contains(searchText) || employeeId.contains(searchText);
      }).toList();
    }
  }

  void _calculateRelief() {
    final premium = double.tryParse(_premiumController.text) ?? 0.0;
    final percentage = double.tryParse(_percentageController.text) ?? 0.0;
    final relief = premium * (percentage / 100);
    
    setState(() {
      _reliefController.text = relief.toStringAsFixed(2);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: InsuranceReliefConstants.primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: InsuranceReliefConstants.primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fix all validation errors');
      return;
    }

    if (_selectedEmployeeId == null || _selectedDate == null) {
      _showErrorSnackBar('Please select an employee and date');
      return;
    }

    final premium = double.parse(_premiumController.text);
    final percentage = double.parse(_percentageController.text);
    final relief = double.parse(_reliefController.text);

    if (relief > 5000) {
      _showErrorSnackBar('Relief amount cannot exceed KES 5,000');
      return;
    }

    final reliefData = {
      'employee_id': _selectedEmployeeId!,
      'company_id': _companyId,
      'premium_amount': premium,
      'relief_percentage': percentage,
      'relief_amount': relief,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
    };

    await _saveRelief(reliefData);
  }

  Future<void> _saveRelief(Map<String, dynamic> reliefData) async {
    setState(() => _isSubmitting = true);

    try {
      _showLoadingSnackBar('Saving insurance relief...');

      await widget.apiService.addInsuranceRelief(reliefData, _companyId!);

      if (!mounted) return;
      final reliefDate = DateTime.parse(reliefData['date'] as String);
      setState(() {
        _selectedMonth = reliefDate.month;
        _selectedYear = reliefDate.year;
      });

      await _fetchReliefRecords();
      if (!mounted) return;
      _resetForm();
      _showSuccessSnackBar(reliefData);

    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to save relief: $e', isRetryable: true);
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _premiumController.clear();
    _percentageController.clear();
    _reliefController.clear();
    setState(() {
      _selectedEmployeeId = null;
      _selectedDate = null;
    });
    _formKey.currentState?.reset();
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: InsuranceReliefConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(Map<String, dynamic> reliefData) {
    final employee = _employees.firstWhere(
      (emp) => emp['employee_id'].toString() == _selectedEmployeeId,
      orElse: () => {'fullname': 'Unknown'},
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Insurance Relief Saved',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${employee['fullname']} - ${_currencyFormat.format(reliefData['relief_amount'])}',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: InsuranceReliefConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message, {bool isRetryable = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: InsuranceReliefConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: isRetryable 
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _submitForm,
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _premiumController.dispose();
    _percentageController.dispose();
    _reliefController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InsuranceReliefConstants.backgroundColor,
      // Add CustomAppBar here with back arrow
      appBar: CustomAppBar(
        title: 'Insurance Relief',
        backgroundColor: InsuranceReliefConstants.primaryColor,
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          if (kDebugMode) print('Profile tapped');
        },
      ),
      body: Column(
        children: [
          // Header Section - Same style as PaidSalariesScreen
          _buildHeaderSection(),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildSearchAndFilters(),
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

  // ... rest of the widget methods remain exactly the same ...
  // _buildHeaderSection(), _buildDateFilters(), _buildFilterDropdown(), 
  // _buildRefreshButton(), _buildSearchAndFilters(), _buildStatisticsCards(),
  // _buildStatCard(), _buildContentSection(), _buildFormCard(), 
  // _buildFormDropdown(), _buildFormTextField(), _buildFormDatePicker(),
  // _buildSubmitButton(), _buildRecordsCard(), _buildTableHeader(),
  // _buildRecordsTable(), _buildLoadingState(), _buildEmptyState()

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [InsuranceReliefConstants.primaryColor, InsuranceReliefConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.health_and_safety,
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
                      'Insurance Relief',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage employee insurance relief calculations',
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _companyName ?? 'Unknown Company',
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _buildDateFilters(),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedMonth,
            items: List.generate(12, (index) => index + 1),
            itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear, month)),
            onChanged: (value) {
              setState(() {
                _selectedMonth = value!;
                _fetchReliefRecords();
              });
            },
            hint: 'Select Month',
            icon: Icons.calendar_month,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedYear,
            items: List.generate(5, (index) => DateTime.now().year - index),
            itemBuilder: (year) => year.toString(),
            onChanged: (value) {
              setState(() {
                _selectedYear = value!;
                _fetchReliefRecords();
              });
            },
            hint: 'Select Year',
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 12),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(
                      color: InsuranceReliefConstants.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(color: InsuranceReliefConstants.subtitleColor),
          prefixIcon: Icon(icon, color: InsuranceReliefConstants.primaryColor),
        ),
        icon: Icon(Icons.arrow_drop_down, color: InsuranceReliefConstants.primaryColor),
        dropdownColor: InsuranceReliefConstants.cardColor,
        style: TextStyle(
          color: InsuranceReliefConstants.textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _initializeData,
        icon: Icon(Icons.refresh, color: InsuranceReliefConstants.primaryColor),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: InsuranceReliefConstants.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                hintText: 'Search employees...',
                hintStyle: TextStyle(color: InsuranceReliefConstants.subtitleColor),
                prefixIcon: Icon(Icons.search, color: InsuranceReliefConstants.subtitleColor),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: TextStyle(
                color: InsuranceReliefConstants.textColor,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Relief',
            value: 'KES ${_totalReliefAmount.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: InsuranceReliefConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Records',
            value: _totalReliefRecords.toString(),
            icon: Icons.list_alt,
            color: InsuranceReliefConstants.accentColor,
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
        color: InsuranceReliefConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
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
                    color: InsuranceReliefConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: InsuranceReliefConstants.textColor,
                    fontSize: 18,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Section
          Expanded(
            flex: 2,
            child: _buildFormCard(),
          ),
          const SizedBox(width: 16),
          // Records Section
          Expanded(
            flex: 3,
            child: _buildRecordsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: InsuranceReliefConstants.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Insurance Relief',
                  style: TextStyle(
                    color: InsuranceReliefConstants.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Employee Dropdown
                _buildFormDropdown(),
                const SizedBox(height: 16),
                
                // Premium Field
                _buildFormTextField(
                  controller: _premiumController,
                  label: 'Premium Amount',
                  isNumber: true,
                  prefixText: 'KES ',
                ),
                const SizedBox(height: 16),
                
                // Percentage Field
                _buildFormTextField(
                  controller: _percentageController,
                  label: 'Relief Percentage',
                  isNumber: true,
                  suffixText: '%',
                ),
                const SizedBox(height: 16),
                
                // Relief Field
                _buildFormTextField(
                  controller: _reliefController,
                  label: 'Calculated Relief',
                  readOnly: true,
                  prefixText: 'KES ',
                  isHighlighted: true,
                ),
                const SizedBox(height: 16),
                
                // Date Picker
                _buildFormDatePicker(),
                const SizedBox(height: 24),
                
                // Submit Button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Employee *',
          style: TextStyle(
            color: InsuranceReliefConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: InsuranceReliefConstants.backgroundColor),
          ),
          child: DropdownButtonFormField<String>(
            key: ValueKey(_selectedEmployeeId),
            initialValue: _selectedEmployeeId,
            items: _isLoadingEmployees
                ? []
                : _employees.map((employee) {
                    return DropdownMenuItem<String>(
                      value: employee['employee_id'].toString(),
                      child: Text(
                        '${employee['employee_id']} - ${employee['fullname']}',
                        style: TextStyle(
                          color: InsuranceReliefConstants.textColor,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEmployeeId = value;
              });
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: _isLoadingEmployees
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: InsuranceReliefConstants.primaryColor,
                        ),
                      ),
                    )
                  : Icon(Icons.arrow_drop_down, color: InsuranceReliefConstants.primaryColor),
            ),
            validator: (value) => value == null ? 'Please select an employee' : null,
            dropdownColor: InsuranceReliefConstants.cardColor,
            style: TextStyle(color: InsuranceReliefConstants.textColor),
          ),
        ),
        if (_employees.isEmpty && !_isLoadingEmployees)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'No employees available',
              style: TextStyle(color: InsuranceReliefConstants.errorColor, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    bool readOnly = false,
    String? prefixText,
    String? suffixText,
    bool isHighlighted = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: InsuranceReliefConstants.textColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: InsuranceReliefConstants.backgroundColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: InsuranceReliefConstants.backgroundColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: InsuranceReliefConstants.primaryColor),
        ),
        filled: true,
        fillColor: isHighlighted 
            ? InsuranceReliefConstants.successColor.withAlpha(13)
            : Colors.white,
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: isHighlighted ? InsuranceReliefConstants.successColor : InsuranceReliefConstants.textColor,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
        suffixText: suffixText,
        suffixStyle: TextStyle(color: InsuranceReliefConstants.textColor),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (isNumber && !readOnly) {
          final num = double.tryParse(value);
          if (num == null || num <= 0) return 'Please enter a valid positive amount';
          if (label.contains('Premium') && num > 100000) {
            return 'Premium cannot exceed KES 100,000';
          }
          if (label.contains('Percentage') && (num < 0 || num > 100)) {
            return 'Percentage must be between 0 and 100';
          }
        }
        return null;
      },
      style: TextStyle(
        color: isHighlighted ? InsuranceReliefConstants.successColor : InsuranceReliefConstants.textColor,
        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildFormDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relief Date *',
          style: TextStyle(
            color: InsuranceReliefConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: InsuranceReliefConstants.backgroundColor),
          ),
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: InsuranceReliefConstants.primaryColor),
            title: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null 
                    ? InsuranceReliefConstants.subtitleColor
                    : InsuranceReliefConstants.textColor,
              ),
            ),
            trailing: Icon(Icons.arrow_drop_down, color: InsuranceReliefConstants.primaryColor),
            onTap: () => _selectDate(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_selectedDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Please select a date',
              style: TextStyle(color: InsuranceReliefConstants.errorColor, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting || _isLoadingEmployees || _employees.isEmpty
            ? null
            : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: InsuranceReliefConstants.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Save Insurance Relief',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildRecordsCard() {
    return Container(
      decoration: BoxDecoration(
        color: InsuranceReliefConstants.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildTableHeader(),
            Expanded(child: _buildRecordsTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: InsuranceReliefConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: InsuranceReliefConstants.backgroundColor.withAlpha(128)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: InsuranceReliefConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Insurance Relief Records',
            style: TextStyle(
              color: InsuranceReliefConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredReliefRecords.length} records',
            style: TextStyle(
              color: InsuranceReliefConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTable() {
    if (_isLoadingReliefs) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_filteredReliefRecords.isEmpty) {
      return _buildEmptyState();
    }
    
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,            
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            headingRowHeight: 56,
            horizontalMargin: 24,
            headingTextStyle: TextStyle(
              color: InsuranceReliefConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: InsuranceReliefConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(InsuranceReliefConstants.backgroundColor),
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Premium (KES)')),
              DataColumn(label: Text('Percentage (%)')),
              DataColumn(label: Text('Relief (KES)')),
              DataColumn(label: Text('Date')),
            ],
            rows: _filteredReliefRecords.map((record) {
              final employee = _employees.firstWhere(
                (emp) => emp['employee_id'].toString() == record['employee_id'].toString(),
                orElse: () => {'fullname': 'Unknown Employee'},
              );
              
              final dateStr = record['date'] != null
                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(record['date']))
                  : 'N/A';
                  
              return DataRow(cells: [
                DataCell(
                  Tooltip(
                    message: employee['fullname'] ?? 'Unknown',
                    child: Text(
                      employee['fullname'] ?? 'Unknown',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                DataCell(Text(_currencyFormat.format(record['premium_amount']?.toDouble() ?? 0.0))),
                DataCell(Text('${record['relief_percentage']?.toStringAsFixed(1)}%')),
                DataCell(
                  Text(
                    _currencyFormat.format(record['relief_amount']?.toDouble() ?? 0.0),
                    style: TextStyle(
                      color: InsuranceReliefConstants.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(Text(dateStr)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: InsuranceReliefConstants.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Relief Records...',
            style: TextStyle(
              color: InsuranceReliefConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching data for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: TextStyle(
              color: InsuranceReliefConstants.subtitleColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 80,
              color: InsuranceReliefConstants.greyColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Relief Records Found',
              style: TextStyle(
                color: InsuranceReliefConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No insurance relief records available for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
              style: TextStyle(
                color: InsuranceReliefConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Records will appear here once insurance reliefs are added',
              style: TextStyle(
                color: InsuranceReliefConstants.subtitleColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReliefRecords,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InsuranceReliefConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
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
              color: InsuranceReliefConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                color: InsuranceReliefConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: InsuranceReliefConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReliefRecords,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InsuranceReliefConstants.primaryColor,
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
}