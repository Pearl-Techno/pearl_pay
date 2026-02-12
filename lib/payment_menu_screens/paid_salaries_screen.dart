import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// Constants
class PaidSalariesConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
  static const Color greyColor = Color(0xFF9E9E9E);
}

// Salary Status Helper
class SalaryStatusHelper {
  static bool isPaid(String status) {
    final lowerStatus = status.toLowerCase();
    return lowerStatus == 'paid' || lowerStatus == 'already paid';
  }

  static Color getStatusColor(String status) {
    return isPaid(status) ? PaidSalariesConstants.successColor : PaidSalariesConstants.greyColor;
  }

  static String getStatusText(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'paid' || lowerStatus == 'already paid') {
      return 'Paid';
    }
    return status;
  }
}

class PaidSalariesScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;
  
  const PaidSalariesScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  PaidSalariesScreenState createState() => PaidSalariesScreenState();
}

class PaidSalariesScreenState extends State<PaidSalariesScreen> {
  late final ApiService _apiService;
  
  List<Map<String, dynamic>> _salaries = [];
  List<Map<String, dynamic>> _filteredSalaries = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Statistics
  double _totalPaidAmount = 0.0;
  int _totalPaidEmployees = 0;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(
      client: http.Client(),
      user: widget.user,
    );
    _fetchSalaries();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchSalaries() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      if (kDebugMode) {
        print('Fetching salaries for month: $_selectedMonth, year: $_selectedYear');
      }

      final salaries = await _apiService.getSalaries(
        widget.user.companyId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      
      if (kDebugMode) {
        print('API returned ${salaries.length} salaries');
      }

      _processSalaries(salaries);
      
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load paid salaries: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  void _processSalaries(List<Map<String, dynamic>> salaries) {
    // Filter for paid salaries
    final paidSalaries = salaries.where((salary) {
      final status = salary['status']?.toString().toLowerCase() ?? '';
      return SalaryStatusHelper.isPaid(status);
    }).toList();

    // Calculate statistics
    _calculateStatistics(paidSalaries);

    // Apply search filter
    _applySearchFilter(paidSalaries);

    if (mounted) {
      setState(() {
        _salaries = paidSalaries;
        _isLoading = false;
      });
    }

    if (kDebugMode) {
      print('Processed ${paidSalaries.length} paid salaries');
    }
  }

  void _calculateStatistics(List<Map<String, dynamic>> salaries) {
    _totalPaidAmount = salaries.fold(0.0, (sum, salary) {
      final netPay = double.tryParse(salary['net_pay']?.toString() ?? '0') ?? 0.0;
      return sum + netPay;
    });
    
    _totalPaidEmployees = salaries.length;
  }

  void _applySearchFilter(List<Map<String, dynamic>> salaries) {
    final searchText = _searchController.text.toLowerCase();
    
    if (searchText.isEmpty) {
      _filteredSalaries = salaries;
    } else {
      _filteredSalaries = salaries.where((salary) {
        final fullName = salary['fullname']?.toString().toLowerCase() ?? '';
        final employeeId = salary['employee_id']?.toString().toLowerCase() ?? '';
        return fullName.contains(searchText) || employeeId.contains(searchText);
      }).toList();
    }
  }

  void _onSearchChanged() {
    _applySearchFilter(_salaries);
    if (mounted) {
      setState(() {});
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaidSalariesConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Paid Salaries',
        backgroundColor: PaidSalariesConstants.primaryColor,
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
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PaidSalariesConstants.primaryColor, PaidSalariesConstants.secondaryColor],
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
                        'Paid Salaries',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage and view salary payment history',
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
            itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear, month)),
            onChanged: (value) {
              setState(() {
                _selectedMonth = value!;
                _fetchSalaries();
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
                _fetchSalaries();
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
        initialValue: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(
                      color: PaidSalariesConstants.textColor,
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
          hintStyle: TextStyle(color: PaidSalariesConstants.subtitleColor),
          prefixIcon: Icon(icon, color: PaidSalariesConstants.primaryColor),
        ),
        icon: Icon(Icons.arrow_drop_down, color: PaidSalariesConstants.primaryColor),
        dropdownColor: PaidSalariesConstants.cardColor,
        style: TextStyle(
          color: PaidSalariesConstants.textColor,
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _fetchSalaries,
        icon: Icon(Icons.refresh, color: PaidSalariesConstants.primaryColor),
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
              color: PaidSalariesConstants.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                hintText: 'Search employees...',
                hintStyle: TextStyle(color: PaidSalariesConstants.subtitleColor),
                prefixIcon: Icon(Icons.search, color: PaidSalariesConstants.subtitleColor),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: TextStyle(
                color: PaidSalariesConstants.textColor,
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
            title: 'Total Paid',
            value: 'KES ${_totalPaidAmount.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: PaidSalariesConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Employees Paid',
            value: _totalPaidEmployees.toString(),
            icon: Icons.people,
            color: PaidSalariesConstants.accentColor,
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
        color: PaidSalariesConstants.cardColor,
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
                    color: PaidSalariesConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: PaidSalariesConstants.textColor,
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
      child: Container(
        decoration: BoxDecoration(
          color: PaidSalariesConstants.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_filteredSalaries.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildSalaryTable()),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: PaidSalariesConstants.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Paid Salaries...',
            style: TextStyle(
              color: PaidSalariesConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching data for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: TextStyle(
              color: PaidSalariesConstants.subtitleColor,
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
              Icons.payments_outlined,
              size: 80,
                  color: PaidSalariesConstants.greyColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Paid Salaries Found',
              style: TextStyle(
                color: PaidSalariesConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No paid salaries available for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
              style: TextStyle(
                color: PaidSalariesConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Salaries will appear here once they are processed and marked as paid',
              style: TextStyle(
                color: PaidSalariesConstants.subtitleColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchSalaries,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PaidSalariesConstants.primaryColor,
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: PaidSalariesConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: PaidSalariesConstants.backgroundColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: PaidSalariesConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Paid Salaries List',
            style: TextStyle(
              color: PaidSalariesConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredSalaries.length} records',
            style: TextStyle(
              color: PaidSalariesConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryTable() {
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
              color: PaidSalariesConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: PaidSalariesConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(PaidSalariesConstants.backgroundColor),
            columns: _buildTableColumns(),
            rows: _filteredSalaries.map(_buildDataRow).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      _buildDataColumn('Employee ID'),
      _buildDataColumn('Full Name'),
      _buildDataColumn('Gross Pay'),
      _buildDataColumn('Basic Pay'),
      _buildDataColumn('Net Pay'),
      _buildDataColumn('Status'),
      _buildDataColumn('Payment Date'),
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
            color: PaidSalariesConstants.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> salary) {
    return DataRow(
      cells: [
        _buildDataCell(salary['employee_id']?.toString() ?? 'N/A', isBold: true),
        _buildDataCell(salary['fullname'] ?? 'N/A'),
        _buildCurrencyCell(salary['gross_pay']),
        _buildCurrencyCell(salary['basic_pay']),
        _buildCurrencyCell(salary['net_pay'], isHighlighted: true),
        _buildStatusCell(salary['status'] ?? 'N/A'),
        _buildDataCell(_formatDate(salary['payment_date'])),
      ],
    );
  }

  DataCell _buildDataCell(String text, {bool isBold = false}) {
    return DataCell(
      Tooltip(
        message: text,
        child: Text(
          text,
          style: TextStyle(
            color: PaidSalariesConstants.textColor,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  DataCell _buildCurrencyCell(dynamic amount, {bool isHighlighted = false}) {
    final value = double.tryParse(amount?.toString() ?? '0.0') ?? 0.0;
    final formattedValue = 'KES ${value.toStringAsFixed(2)}';
    
    return DataCell(
      Tooltip(
        message: formattedValue,
        child: Text(
          formattedValue,
          style: TextStyle(
            color: isHighlighted ? PaidSalariesConstants.successColor : PaidSalariesConstants.textColor,
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  DataCell _buildStatusCell(String status) {
    final isPaid = SalaryStatusHelper.isPaid(status);
    final statusText = SalaryStatusHelper.getStatusText(status);
    
    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPaid ? PaidSalariesConstants.successColor.withAlpha(26) : Colors.grey.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPaid ? PaidSalariesConstants.successColor : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaid ? Icons.check_circle : Icons.pending,
              size: 12,
              color: isPaid ? PaidSalariesConstants.successColor : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                color: isPaid ? PaidSalariesConstants.successColor : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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