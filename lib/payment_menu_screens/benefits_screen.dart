import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pearl_pay/services/services.dart';

import '../models/user.dart';
import '../widgets/custom_app_bar.dart';

// Constants
class BenefitsConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
}

class BenefitsScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const BenefitsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  int? _companyId;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _benefits = [];
  List<Map<String, dynamic>> _filteredBenefits = [];
  bool _isLoadingBenefits = false;
  String? _errorMessage;
  String? _selectedBenefitType;
  final List<String> _benefitTypes = ['Cash', 'Non-Cash'];

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _filterEmployeeId;
  final ScrollController _scrollController = ScrollController();

  // Statistics
  double _totalBenefitsAmount = 0.0;
  int _totalBenefitsCount = 0;
  double _averageBenefitAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeScreen() {
    if (widget.user.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorSnackBar('Access denied: Only admins can manage benefits');
        Navigator.pop(context);
      });
      return;
    }

    _companyId = widget.user.companyId;

    if (_companyId != null && _companyId! > 0) {
      _fetchEmployees();
      _fetchBenefits();
    } else {
      setState(() {
        _errorMessage = 'No company assigned to this user';
        _isLoadingBenefits = false;
      });
    }
  }

  void _onSearchChanged() {
    _filterBenefits();
  }

  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId! <= 0) return;
    try {
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _selectedEmployeeId = _employees.isNotEmpty
            ? _employees[0]['employee_id'].toString()
            : null;
        _filterEmployeeId = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
      });
    }
  }

  Future<void> _fetchBenefits() async {
    if (_companyId == null || _companyId! <= 0) return;
    setState(() => _isLoadingBenefits = true);
    try {
      final benefits = await widget.apiService.fetchBenefits(
        _companyId!,
        _selectedMonth,
        _selectedYear,
        _filterEmployeeId ?? '',
      );
      
      if (!mounted) return;
      setState(() {
        _benefits = benefits;
        _calculateStatistics();
        _filterBenefits();
        _isLoadingBenefits = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load benefits: $e';
        _isLoadingBenefits = false;
      });
    }
  }

  void _calculateStatistics() {
    _totalBenefitsAmount = _benefits.fold(0.0, (sum, benefit) {
      final amount = double.tryParse(benefit['amount']?.toString() ?? '0') ?? 0.0;
      return sum + amount;
    });
    
    _totalBenefitsCount = _benefits.length;
    _averageBenefitAmount = _totalBenefitsCount > 0 ? _totalBenefitsAmount / _totalBenefitsCount : 0.0;
  }

  void _filterBenefits() {
    final searchText = _searchController.text.toLowerCase();
    
    if (searchText.isEmpty) {
      _filteredBenefits = _benefits;
    } else {
      _filteredBenefits = _benefits.where((benefit) {
        final employee = _employees.firstWhere(
          (emp) => emp['employee_id'].toString() == benefit['employee_id'].toString(),
          orElse: () => {'fullname': ''},
        );
        final employeeName = employee['fullname']?.toString().toLowerCase() ?? '';
        final description = benefit['description']?.toString().toLowerCase() ?? '';
        final benefitType = benefit['benefit_type']?.toString().toLowerCase() ?? '';
        
        return employeeName.contains(searchText) ||
               description.contains(searchText) ||
               benefitType.contains(searchText);
      }).toList();
    }
    
    setState(() {});
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
            colorScheme: ColorScheme.light(primary: BenefitsConstants.primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: BenefitsConstants.primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _selectedBenefitType == null ||
        _selectedDate == null) {
      _showErrorSnackBar('Please complete all required fields and select a date');
      return;
    }

    final employeeId = _selectedEmployeeId!;
    final benefitType = _selectedBenefitType!;
    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final date = _selectedDate!;

    if (amount <= 0) {
      _showErrorSnackBar('Please enter a valid positive amount');
      return;
    }

    final benefitData = {
      'employee_id': employeeId,
      'benefit_type': benefitType,
      'description': description.isEmpty ? 'No description' : description,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'company_id': _companyId,
    };

    try {
      await widget.apiService.addBenefit(benefitData, _companyId!);

      final benefitDate = DateTime.parse(benefitData['date'] as String);
      if (!mounted) return;
      setState(() {
        _selectedMonth = benefitDate.month;
        _selectedYear = benefitDate.year;
        _filterEmployeeId = employeeId;
      });
      
      await _fetchBenefits();
      if (!mounted) return;

      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == employeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      
      _showSuccessSnackBar(
        'Benefit added successfully for ${employee['fullname']}'
      );

      _descriptionController.clear();
      _amountController.clear();
      setState(() {
        _selectedEmployeeId = _employees.isNotEmpty
            ? _employees[0]['employee_id'].toString()
            : null;
        _selectedBenefitType = null;
        _selectedDate = null;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to add benefit: $e');
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
        backgroundColor: BenefitsConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BenefitsConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Benefits Management',
        backgroundColor: BenefitsConstants.primaryColor,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildAddBenefitSheet(),
          );
        },
        backgroundColor: BenefitsConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('Add Benefit'),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BenefitsConstants.primaryColor, BenefitsConstants.secondaryColor],
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
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration,
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
                        'Benefits Management',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage employee benefits and incentives',
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
            const SizedBox(height: 20),
            _buildDateFilters(),
          ],
        ),
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
            labelText: 'Month',
            itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear, month)),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedMonth = value;
                  _fetchBenefits();
                });
              }
            },
            icon: Icons.calendar_month,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedYear,
            items: List.generate(5, (index) => DateTime.now().year - index),
            labelText: 'Year',
            itemBuilder: (year) => year.toString(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedYear = value;
                  _fetchBenefits();
                });
              }
            },
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterDropdown(
            value: _filterEmployeeId,
            items: [null, ..._employees.map((e) => e['employee_id'].toString())],
            labelText: 'Employee',
            itemBuilder: (id) => id == null
                ? 'All Employees'
                : _employees.firstWhere(
                    (emp) => emp['employee_id'].toString() == id,
                    orElse: () => {'fullname': 'Unknown'},
                  )['fullname'] as String,
            onChanged: (value) {
              setState(() {
                _filterEmployeeId = value;
                _fetchBenefits();
              });
            },
            icon: Icons.person,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              _fetchEmployees();
              _fetchBenefits();
            },
            icon: Icon(Icons.refresh, color: BenefitsConstants.primaryColor),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      decoration: BoxDecoration(
        color: BenefitsConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: 'Search benefits by employee, description, or type...',
          hintStyle: TextStyle(color: BenefitsConstants.subtitleColor),
          prefixIcon: Icon(Icons.search, color: BenefitsConstants.subtitleColor),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
        style: TextStyle(
          color: BenefitsConstants.textColor,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Benefits',
            value: 'KES ${_totalBenefitsAmount.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: BenefitsConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Benefits Count',
            value: _totalBenefitsCount.toString(),
            icon: Icons.list_alt,
            color: BenefitsConstants.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Average Benefit',
            value: 'KES ${_averageBenefitAmount.toStringAsFixed(2)}',
            icon: Icons.trending_up,
            color: BenefitsConstants.primaryColor,
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
        color: BenefitsConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    color: BenefitsConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: BenefitsConstants.textColor,
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
          color: BenefitsConstants.cardColor,
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
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingBenefits) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    if (_filteredBenefits.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildBenefitsTable()),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: BenefitsConstants.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Benefits...',
            style: TextStyle(
              color: BenefitsConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              color: BenefitsConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                color: BenefitsConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: BenefitsConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _fetchEmployees();
                _fetchBenefits();
              },
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BenefitsConstants.primaryColor,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 80,
              color: BenefitsConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Benefits Found',
              style: TextStyle(
                color: BenefitsConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No benefits recorded for the selected filters',
              style: TextStyle(
                color: BenefitsConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the filters or add new benefits',
              style: TextStyle(
                color: BenefitsConstants.subtitleColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: BenefitsConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: BenefitsConstants.backgroundColor.withAlpha(128)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: BenefitsConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Benefits Records',
            style: TextStyle(
              color: BenefitsConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredBenefits.length} records',
            style: TextStyle(
              color: BenefitsConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsTable() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
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
              color: BenefitsConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: BenefitsConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(BenefitsConstants.backgroundColor),
            columns: _buildTableColumns(),
            rows: _filteredBenefits.asMap().entries.map((entry) {
              final index = entry.key;
              final benefit = entry.value;
              return DataRow(
                color: WidgetStateProperty.all(
                  index % 2 == 0 ? BenefitsConstants.cardColor : BenefitsConstants.backgroundColor,
                ),
                cells: [
                  _buildEmployeeCell(benefit),
                  _buildBenefitTypeCell(benefit),
                  _buildDataCell(benefit['description'] ?? 'No description'),
                  _buildAmountCell(benefit['amount']),
                  _buildDateCell(benefit['date']),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      _buildDataColumn('Employee'),
      _buildDataColumn('Type'),
      _buildDataColumn('Description'),
      _buildDataColumn('Amount (KES)'),
      _buildDataColumn('Date'),
    ];
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: BenefitsConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildEmployeeCell(Map<String, dynamic> benefit) {
    final employee = _employees.firstWhere(
      (emp) => emp['employee_id'].toString() == benefit['employee_id'].toString(),
      orElse: () => {'fullname': 'Unknown Employee'},
    );
    return _buildDataCell(employee['fullname'] ?? 'Unknown');
  }

  DataCell _buildBenefitTypeCell(Map<String, dynamic> benefit) {
    final type = benefit['benefit_type'] ?? 'Unknown';
    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: type == 'Cash'
              ? BenefitsConstants.successColor.withAlpha(26)
              : BenefitsConstants.accentColor.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: type == 'Cash' 
                ? BenefitsConstants.successColor
                : BenefitsConstants.accentColor,
            width: 1,
          ),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: type == 'Cash' 
                ? BenefitsConstants.successColor
                : BenefitsConstants.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Tooltip(
        message: text,
        child: Text(
          text,
          style: TextStyle(
            color: BenefitsConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildAmountCell(dynamic amount) {
    final value = double.tryParse(amount?.toString() ?? '0.0') ?? 0.0;
    final formattedValue = 'KES ${value.toStringAsFixed(2)}';
    
    return DataCell(
      Tooltip(
        message: formattedValue,
        child: Text(
          formattedValue,
          style: TextStyle(
            color: BenefitsConstants.successColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  DataCell _buildDateCell(String? dateString) {
    String formattedDate = 'N/A';
    if (dateString != null) {
      try {
        final date = DateTime.tryParse(dateString);
        formattedDate = date != null ? DateFormat('MMM dd, yyyy').format(date) : 'N/A';
      } catch (e) {
        formattedDate = 'N/A';
      }
    }
    
    return _buildDataCell(formattedDate);
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required List<T> items,
    required String labelText,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: BenefitsConstants.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            itemBuilder(item),
            style: TextStyle(
              color: BenefitsConstants.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelText: labelText,
          labelStyle: TextStyle(color: BenefitsConstants.subtitleColor, fontSize: 14),
          prefixIcon: Icon(icon, color: BenefitsConstants.primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BenefitsConstants.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        dropdownColor: BenefitsConstants.cardColor,
        icon: Icon(Icons.arrow_drop_down, color: BenefitsConstants.primaryColor),
        style: TextStyle(color: BenefitsConstants.textColor, fontSize: 14),
      ),
    );
  }

  Widget _buildAddBenefitSheet() {
    return Container(
      decoration: BoxDecoration(
        color: BenefitsConstants.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: BenefitsConstants.subtitleColor.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add New Benefit',
              style: TextStyle(
                color: BenefitsConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSheetEmployeeDropdown(),
                      const SizedBox(height: 16),
                      _buildSheetBenefitTypeDropdown(),
                      const SizedBox(height: 16),
                      _buildSheetTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hintText: 'e.g., Performance Bonus, Company Car',
                      ),
                      const SizedBox(height: 16),
                      _buildSheetTextField(
                        controller: _amountController,
                        label: 'Amount',
                        isNumber: true,
                        hintText: 'e.g., 10000.00',
                      ),
                      const SizedBox(height: 16),
                      _buildSheetDatePicker(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BenefitsConstants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Add Benefit'),
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
    );
  }

  // Additional sheet-specific widgets would be defined here...
  // _buildSheetEmployeeDropdown, _buildSheetBenefitTypeDropdown, etc.
  // These would be similar to the main form widgets but optimized for the bottom sheet

  Widget _buildSheetEmployeeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Employee *',
          style: TextStyle(
            color: BenefitsConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BenefitsConstants.subtitleColor.withAlpha(77)),
          ),
          child: DropdownButtonFormField<String>(
            key: ValueKey(_selectedEmployeeId),
            initialValue: _selectedEmployeeId,
            items: _employees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee['employee_id']?.toString(),
                child: Text(
                  '${employee['employee_id']} - ${employee['fullname']}',
                  style: TextStyle(color: BenefitsConstants.textColor),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedEmployeeId = newValue;
                });
              }
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.person, color: BenefitsConstants.primaryColor),
              border: InputBorder.none,
              filled: true,
              fillColor: BenefitsConstants.backgroundColor,
            ),
            validator: (value) => value == null ? 'Please select an employee' : null,
            dropdownColor: BenefitsConstants.cardColor,
            icon: Icon(Icons.arrow_drop_down, color: BenefitsConstants.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetBenefitTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benefit Type *',
          style: TextStyle(
            color: BenefitsConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BenefitsConstants.subtitleColor.withAlpha(77)),
          ),
          child: DropdownButtonFormField<String>(
            key: ValueKey(_selectedBenefitType),
            initialValue: _selectedBenefitType,
            items: _benefitTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type,
                  style: TextStyle(color: BenefitsConstants.textColor),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedBenefitType = newValue;
                });
              }
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.category, color: BenefitsConstants.primaryColor),
              border: InputBorder.none,
              filled: true,
              fillColor: BenefitsConstants.backgroundColor,
            ),
            validator: (value) => value == null ? 'Please select a benefit type' : null,
            dropdownColor: BenefitsConstants.cardColor,
            icon: Icon(Icons.arrow_drop_down, color: BenefitsConstants.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(
            color: BenefitsConstants.textColor,
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
            hintText: hintText,
            hintStyle: TextStyle(color: BenefitsConstants.subtitleColor),
            prefixIcon: isNumber ? Icon(Icons.attach_money, color: BenefitsConstants.primaryColor) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: BenefitsConstants.subtitleColor.withAlpha(77)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: BenefitsConstants.subtitleColor.withAlpha(77)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: BenefitsConstants.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: BenefitsConstants.backgroundColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter $label';
            if (isNumber && (double.tryParse(value) == null || double.parse(value) <= 0)) {
              return 'Please enter a valid positive amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSheetDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benefit Date *',
          style: TextStyle(
            color: BenefitsConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BenefitsConstants.subtitleColor.withAlpha(77)),
          ),
          child: ListTile(
            onTap: () => _selectDate(context),
            leading: Icon(Icons.calendar_today, color: BenefitsConstants.primaryColor),
            title: Text(
              _selectedDate == null
                  ? 'Select Benefit Date'
                  : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null 
                    ? BenefitsConstants.subtitleColor 
                    : BenefitsConstants.textColor,
              ),
            ),
            trailing: Icon(Icons.arrow_drop_down, color: BenefitsConstants.primaryColor),
          ),
        ),
        if (_selectedDate == null)
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
}