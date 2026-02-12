import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// Constants
class DeductionsConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
}

class DeductionsScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const DeductionsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  int? _companyId;
  String? _companyName;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _filteredDeductions = [];
  bool _isLoadingDeductions = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final ScrollController _scrollController = ScrollController();
  int? _editingDeductionId;

  // Statistics
  double _totalDeductionsAmount = 0.0;
  int _totalDeductionsCount = 0;
  double _averageDeductionAmount = 0.0;

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
        _showErrorSnackBar('Access denied: Only admins can manage deductions');
        Navigator.pop(context);
      });
      return;
    }

    _companyId = widget.user.companyId;
    _companyName = widget.user.companyName ?? 'Unknown';

    if (_companyId == null || _companyId! <= 0) {
      setState(() {
        _errorMessage = 'No valid company assigned to this user';
        _isLoadingDeductions = false;
      });
    } else {
      _fetchEmployees();
      _fetchDeductions();
    }
  }

  void _onSearchChanged() {
    _filterDeductions();
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
        _errorMessage = null;
      });

      // Re-filter deductions to ensure employee names are mapped correctly
      if (_deductions.isNotEmpty) {
        _filterDeductions();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
      });
    }
  }

  Future<void> _fetchDeductions() async {
    if (_companyId == null || _companyId! <= 0) return;
    setState(() => _isLoadingDeductions = true);
    try {
      // Use fetchDeductionsList method instead of fetchDeductions
      final deductions = await widget.apiService.fetchDeductionsList(
        _companyId!,
        month: _selectedMonth,
        year: _selectedYear,
      );
      
      if (!mounted) return;

      _deductions = deductions;
      _filterDeductions();

      setState(() {
        _isLoadingDeductions = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load deductions: $e';
        _isLoadingDeductions = false;
      });
    }
  }

  void _calculateStatistics() {
    _totalDeductionsAmount = _filteredDeductions.fold(0.0, (sum, deduction) {
      final amount = deduction['amount'] is String
          ? double.tryParse(deduction['amount'] as String) ?? 0.0
          : (deduction['amount']?.toDouble() ?? 0.0);
      return sum + amount;
    });
    
    _totalDeductionsCount = _filteredDeductions.length;
    _averageDeductionAmount = _totalDeductionsCount > 0 
        ? _totalDeductionsAmount / _totalDeductionsCount 
        : 0.0;
  }

  void _filterDeductions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDeductions = _deductions.where((deduction) {
        // Filter by company
        if (_companyId != null && deduction['company_id'] != null) {
          if (deduction['company_id'].toString() != _companyId.toString()) {
            return false;
          }
        }

        final employee = _employees.firstWhere(
          (emp) => emp['employee_id'].toString() == deduction['employee_id'].toString(),
          orElse: () => {},
        );

        if (employee.isEmpty) return false;

        final fullname = (employee['fullname']?.toString() ?? '').toLowerCase();
        final description = (deduction['description']?.toString() ?? '').toLowerCase();
        final amount = (deduction['amount']?.toString() ?? '').toLowerCase();
        
        return query.isEmpty ||
            fullname.contains(query) ||
            description.contains(query) ||
            amount.contains(query);
      }).toList();
      _calculateStatistics();
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
            colorScheme: ColorScheme.light(primary: DeductionsConstants.primaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: DeductionsConstants.primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _selectedDate == null) {
      _showErrorSnackBar('Please complete all required fields and select a date');
      return;
    }

    final deductionData = {
      'employee_id': _selectedEmployeeId!,
      'company_id': _companyId,
      'description': _descriptionController.text.trim(),
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
    };

    try {
      // Add loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Saving deduction...'),
            ],
          ),
        ),
      );

      if (_editingDeductionId != null) {
        await widget.apiService.updateDeduction(_editingDeductionId!, deductionData);
      } else {
        await widget.apiService.addDeduction(deductionData, _companyId!);
      }

      if (!mounted) return;

      // Update month/year to match the deduction date
      setState(() {
        _selectedMonth = _selectedDate!.month;
        _selectedYear = _selectedDate!.year;
      });
      
      // Refresh the deductions list
      await _fetchDeductions();

      if (!mounted) return;

      // Find employee name for success message
      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == _selectedEmployeeId,
        orElse: () => {'fullname': 'Unknown Employee'},
      );
      
      // Remove loading dialog
      Navigator.pop(context);
      
      _showSuccessSnackBar(
        _editingDeductionId != null
            ? 'Deduction updated successfully'
            : 'Deduction added successfully for ${employee['fullname']}'
      );

      // Reset form
      _resetForm();
      
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Failed to add deduction: $e');
    }
  }

  void _resetForm() {
    _descriptionController.clear();
    _amountController.clear();
    setState(() {
      _selectedEmployeeId = _employees.isNotEmpty
          ? _employees[0]['employee_id'].toString()
          : null;
      _selectedDate = null;
      _editingDeductionId = null;
    });
  }

  void _showDeductionForm({Map<String, dynamic>? deduction}) {
    if (deduction != null) {
      setState(() {
        _editingDeductionId = int.tryParse(deduction['id'].toString());
        _selectedEmployeeId = deduction['employee_id'].toString();
        _descriptionController.text = deduction['description'] ?? '';
        _amountController.text = deduction['amount'].toString();
        _selectedDate = DateTime.parse(deduction['date']);
      });
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddDeductionSheet(),
    );
  }

  Future<void> _confirmDeleteDeduction(Map<String, dynamic> deduction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deduction'),
        content: Text('Are you sure you want to delete the deduction for ${deduction['description']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteDeduction(int.tryParse(deduction['id'].toString()) ?? 0);
    }
  }

  Future<void> _deleteDeduction(int id) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await widget.apiService.deleteDeduction(id);

      if (!mounted) return;
      Navigator.pop(context);

      _showSuccessSnackBar('Deduction deleted successfully');
      _fetchDeductions();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Failed to delete deduction: $e');
    }
  }

  Future<void> _exportToCSV() async {
    if (_filteredDeductions.isEmpty) {
      _showErrorSnackBar('No deductions available to export');
      return;
    }

    try {
      final headers = ['Company', 'Employee', 'Description', 'Amount (KES)', 'Date'];
      final rows = [
        headers,
        ..._filteredDeductions.map((deduction) {
          final employee = _employees.firstWhere(
            (emp) => emp['employee_id'].toString() == deduction['employee_id'].toString(),
            orElse: () => {'fullname': 'Unknown Employee'},
          );
          final dateStr = deduction['date'] != null
              ? DateFormat.yMMMd().format(DateTime.parse(deduction['date']))
              : 'N/A';
          final amount = deduction['amount'] is String
              ? double.tryParse(deduction['amount']) ?? 0.0
              : (deduction['amount']?.toDouble() ?? 0.0);
          return [
            _companyName ?? 'Unknown',
            employee['fullname'] ?? 'Unknown',
            deduction['description'] ?? 'Unknown',
            amount.toStringAsFixed(2),
            dateStr,
          ];
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'deductions_${_companyName?.replaceAll(' ', '_') ?? 'unknown'}_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsString(csv);

      _showSuccessSnackBar('Deductions exported to $filePath');
    } catch (e) {
      _showErrorSnackBar('Failed to export to CSV: $e');
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
        backgroundColor: DeductionsConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeductionsConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Deductions Management',
        backgroundColor: DeductionsConstants.primaryColor,
        onNotificationTap: () {
          // Handle notifications
        },
        onProfileTap: () {
          // Handle profile
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
        onPressed: () => _showDeductionForm(),
        backgroundColor: DeductionsConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Deduction'),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DeductionsConstants.primaryColor, DeductionsConstants.secondaryColor],
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
                    Icons.money_off,
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
                        'Deductions Management',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage employee deductions and payroll adjustments',
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
                });
                _fetchDeductions();
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
                });
                _fetchDeductions();
              }
            },
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              _fetchEmployees();
              _fetchDeductions();
            },
            icon: Icon(Icons.refresh, color: DeductionsConstants.primaryColor),
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
        color: DeductionsConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: 'Search deductions by employee or description...',
          hintStyle: TextStyle(color: DeductionsConstants.subtitleColor),
          prefixIcon: Icon(Icons.search, color: DeductionsConstants.subtitleColor),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
        style: TextStyle(
          color: DeductionsConstants.textColor,
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
            title: 'Total Deductions',
            value: 'KES ${_totalDeductionsAmount.toStringAsFixed(2)}',
            icon: Icons.money_off,
            color: DeductionsConstants.warningColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Deductions Count',
            value: _totalDeductionsCount.toString(),
            icon: Icons.list_alt,
            color: DeductionsConstants.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Average Deduction',
            value: 'KES ${_averageDeductionAmount.toStringAsFixed(2)}',
            icon: Icons.trending_down,
            color: DeductionsConstants.primaryColor,
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
        color: DeductionsConstants.cardColor,
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
                    color: DeductionsConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: DeductionsConstants.textColor,
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
          color: DeductionsConstants.cardColor,
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
    if (_isLoadingDeductions) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    if (_filteredDeductions.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildDeductionsTable()),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: DeductionsConstants.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Deductions...',
            style: TextStyle(
              color: DeductionsConstants.subtitleColor,
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
              color: DeductionsConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                color: DeductionsConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: DeductionsConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _fetchEmployees();
                _fetchDeductions();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DeductionsConstants.primaryColor,
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
              Icons.money_off_outlined,
              size: 80,
              color: DeductionsConstants.subtitleColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Deductions Found',
              style: TextStyle(
                color: DeductionsConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No deductions recorded for the selected filters',
              style: TextStyle(
                color: DeductionsConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the filters or add new deductions',
              style: TextStyle(
                color: DeductionsConstants.subtitleColor,
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
        color: DeductionsConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: DeductionsConstants.backgroundColor.withAlpha(128)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: DeductionsConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Deductions Records',
            style: TextStyle(
              color: DeductionsConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredDeductions.length} records',
            style: TextStyle(
              color: DeductionsConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _exportToCSV,
            icon: Icon(Icons.download, color: DeductionsConstants.primaryColor),
            tooltip: 'Export to CSV',
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionsTable() {
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
              color: DeductionsConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: DeductionsConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(DeductionsConstants.backgroundColor),
            columns: _buildTableColumns(),
            rows: _filteredDeductions.asMap().entries.map((entry) {
              final index = entry.key;
              final deduction = entry.value;
              return DataRow(
                color: WidgetStateProperty.all(
                  index % 2 == 0 ? DeductionsConstants.cardColor : DeductionsConstants.backgroundColor,
                ),
                cells: [
                  _buildEmployeeCell(deduction),
                  _buildDataCell(deduction['description'] ?? 'No description'),
                  _buildAmountCell(deduction['amount']),
                  _buildDateCell(deduction['date']),
                  _buildActionsCell(deduction),
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
      _buildDataColumn('Description'),
      _buildDataColumn('Amount (KES)'),
      _buildDataColumn('Date'),
      _buildDataColumn('Actions'),
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
            color: DeductionsConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildEmployeeCell(Map<String, dynamic> deduction) {
    final employee = _employees.firstWhere(
      (emp) => emp['employee_id'].toString() == deduction['employee_id'].toString(),
      orElse: () => {'fullname': 'Unknown Employee'},
    );
    return _buildDataCell(employee['fullname'] ?? 'Unknown');
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Tooltip(
        message: text,
        child: Text(
          text,
          style: TextStyle(
            color: DeductionsConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataCell _buildAmountCell(dynamic amount) {
    final value = amount is String
        ? double.tryParse(amount) ?? 0.0
        : (amount?.toDouble() ?? 0.0);
    final formattedValue = 'KES ${value.toStringAsFixed(2)}';
    
    return DataCell(
      Tooltip(
        message: formattedValue,
        child: Text(
          formattedValue,
          style: TextStyle(
            color: DeductionsConstants.warningColor,
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

  DataCell _buildActionsCell(Map<String, dynamic> deduction) {
    return DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: DeductionsConstants.secondaryColor),
            onPressed: () => _showDeductionForm(deduction: deduction),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: () => _confirmDeleteDeduction(deduction),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
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
        color: DeductionsConstants.cardColor,
        borderRadius: BorderRadius.circular(12),        
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            itemBuilder(item),
            style: TextStyle(
              color: DeductionsConstants.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        )).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelText: labelText,
          labelStyle: TextStyle(color: DeductionsConstants.subtitleColor, fontSize: 14),
          prefixIcon: Icon(icon, color: DeductionsConstants.primaryColor, size: 20),
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
            borderSide: BorderSide(color: DeductionsConstants.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        dropdownColor: DeductionsConstants.cardColor,
        icon: Icon(Icons.arrow_drop_down, color: DeductionsConstants.primaryColor),
        style: TextStyle(color: DeductionsConstants.textColor, fontSize: 14),
      ),
    );
  }

  Widget _buildAddDeductionSheet() {
    return Container(
      decoration: BoxDecoration(
        color: DeductionsConstants.cardColor,
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
                color: DeductionsConstants.subtitleColor.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _editingDeductionId != null ? 'Edit Deduction' : 'Add New Deduction',
              style: TextStyle(
                color: DeductionsConstants.textColor,
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
                      _buildSheetTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hintText: 'e.g., Loan Repayment, Advance Deduction',
                      ),
                      const SizedBox(height: 16),
                      _buildSheetTextField(
                        controller: _amountController,
                        label: 'Amount',
                        isNumber: true,
                        hintText: 'e.g., 5000.00',
                      ),
                      const SizedBox(height: 16),
                      _buildSheetDatePicker(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DeductionsConstants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_editingDeductionId != null ? 'Update Deduction' : 'Add Deduction'),
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

  Widget _buildSheetEmployeeDropdown() {
    if (_employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DeductionsConstants.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No employees available. Please try refreshing.',
            style: TextStyle(color: DeductionsConstants.subtitleColor),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Employee *',
          style: TextStyle(
            color: DeductionsConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DeductionsConstants.subtitleColor.withAlpha(77)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedEmployeeId,
            items: _employees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee['employee_id']?.toString(),
                child: Text(
                  '${employee['employee_id']} - ${employee['fullname']}',
                  style: TextStyle(color: DeductionsConstants.textColor),
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
              prefixIcon: Icon(Icons.person, color: DeductionsConstants.primaryColor),
              border: InputBorder.none,
              filled: true,
              fillColor: DeductionsConstants.backgroundColor,
            ),
            validator: (value) => value == null ? 'Please select an employee' : null,
            dropdownColor: DeductionsConstants.cardColor,
            icon: Icon(Icons.arrow_drop_down, color: DeductionsConstants.primaryColor),
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
            color: DeductionsConstants.textColor,
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
            hintStyle: TextStyle(color: DeductionsConstants.subtitleColor),
            prefixIcon: isNumber ? Icon(Icons.attach_money, color: DeductionsConstants.primaryColor) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DeductionsConstants.subtitleColor.withAlpha(77)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DeductionsConstants.subtitleColor.withAlpha(77)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DeductionsConstants.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: DeductionsConstants.backgroundColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            if (isNumber) {
              final num = double.tryParse(value);
              if (num == null || num <= 0) {
                return 'Please enter a valid positive amount';
              }
              if (num > 1000000) {
                return 'Amount cannot exceed KES 1,000,000';
              }
            } else if (value.length > 100) {
              return 'Description cannot exceed 100 characters';
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
          'Deduction Date *',
          style: TextStyle(
            color: DeductionsConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DeductionsConstants.subtitleColor.withAlpha(77)),
          ),
          child: ListTile(
            onTap: () => _selectDate(context),
            leading: Icon(Icons.calendar_today, color: DeductionsConstants.primaryColor),
            title: Text(
              _selectedDate == null
                  ? 'Select Deduction Date'
                  : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null 
                    ? DeductionsConstants.subtitleColor 
                    : DeductionsConstants.textColor,
              ),
            ),
            trailing: Icon(Icons.arrow_drop_down, color: DeductionsConstants.primaryColor),
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