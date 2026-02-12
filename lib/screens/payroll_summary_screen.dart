import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';

// Premium Design Constants
class PayrollSummaryConstants {
  // Main color palette
  static const Color primaryColor = Color(0xFF0A2463);
  static const Color secondaryColor = Color(0xFF3E92CC);
  static const Color accentColor = Color(0xFF1DD3B0);
  static const Color successColor = Color(0xFF00B894);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color warningColor = Color(0xFFFFA502);
  
  // Background & Surface colors
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFAFCFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Status colors
  static const Color paidColor = Color(0xFF00B894);
  static const Color pendingColor = Color(0xFFFFA502);
  static const Color failedColor = Color(0xFFFF4757);
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, Color(0xFF2EC4B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> strongShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 40,
      offset: const Offset(0, 12),
    ),
  ];
  
  // Borders
  static BorderRadius borderRadiusLarge = BorderRadius.circular(24);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(16);
  static BorderRadius borderRadiusSmall = BorderRadius.circular(12);
}

class PayrollSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const PayrollSummaryScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  PayrollSummaryScreenState createState() => PayrollSummaryScreenState();
}

class PayrollSummaryScreenState extends State<PayrollSummaryScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _payrollSummary = {};
  List<Map<String, dynamic>> _salaries = [];
  String _companyName = 'Unknown';
  int? _companyId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeCompany();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  Future<void> _initializeCompany() async {
    setState(() => _isLoading = true);
    try {
      final userCompanyId = widget.user['company_id'] != null
          ? int.tryParse(widget.user['company_id'].toString())
          : null;
      final userCompanyName =
          widget.user['company_name']?.toString() ?? 'Unknown';

      if (userCompanyId == null || userCompanyId == 0) {
        throw Exception('No valid company ID for user');
      }

      setState(() {
        _companyId = userCompanyId;
        _companyName = userCompanyName;
      });

      await _fetchPayrollSummary();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing company: $e');
      }
      setState(() {
        _isLoading = false;
        _companyName = widget.user['company_name']?.toString() ?? 'Unknown';
      });
      _showErrorSnackBar('Failed to load company data: $e');
    }
  }

  Future<void> _fetchPayrollSummary() async {
    setState(() => _isLoading = true);
    try {
      if (_companyId == null) {
        throw Exception('No company selected');
      }

      final salaries = await widget.apiService.getPayrollSummary(
        _companyId!,
        _selectedMonth,
        _selectedYear,
      );

      if (salaries.isNotEmpty) {
        final sampleDate =
            DateTime.tryParse(salaries.first['payment_date'] ?? '');
        if (sampleDate != null &&
            (sampleDate.month != _selectedMonth ||
                sampleDate.year != _selectedYear)) {
          if (kDebugMode) {
            print('Warning: Data for $_selectedMonth/$_selectedYear not found, received ${sampleDate.month}/${sampleDate.year}');
          }
          _showSuccessSnackBar(
              'Showing data for ${DateFormat('MMM yyyy').format(sampleDate)} instead of ${DateFormat('MMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}');
        }
      }

      final summary = _aggregateSalaries(salaries);

      setState(() {
        _salaries = salaries;
        _payrollSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'Failed to fetch payroll data';
      if (e.toString().contains('Invalid request method')) {
        errorMessage = 'Invalid request configuration. Please contact support.';
      } else if (e.toString().contains('Unauthorized')) {
        errorMessage = 'Access denied to payroll data';
      }
      if (kDebugMode) {
        print('Error fetching payroll for company ID $_companyId: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar(errorMessage);
    }
  }

  Map<String, dynamic> _aggregateSalaries(List<Map<String, dynamic>> salaries) {
    double totalSalaries = 0;
    double totalTaxes = 0;
    double totalDeductions = 0;

    for (var salary in salaries) {
      totalSalaries += (salary['gross_pay'] ?? 0).toDouble();
      totalTaxes += (salary['paye_deduction'] ?? 0).toDouble();
      totalDeductions += ((salary['nhif_deduction'] ?? 0).toDouble() +
              (salary['nssf_deduction'] ?? 0).toDouble() +
              (salary['pension_contributions'] ?? 0).toDouble() +
              (salary['loan_repayment'] ?? 0).toDouble() +
              (salary['other_deductions'] ?? 0).toDouble() +
              (salary['housing_levy'] ?? 0).toDouble() +
              (salary['absenteeism_deduction'] ?? 0).toDouble()) -
          (salary['housing_levy_relief'] ?? 0).toDouble();
    }

    return {
      'total_salaries': totalSalaries.round(),
      'total_taxes': totalTaxes.round(),
      'total_deductions': totalDeductions.round(),
    };
  }

  Future<void> _exportToCsv() async {
    if (_salaries.isEmpty) {
      _showErrorSnackBar('No payroll summary available to export');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final numberFormat = NumberFormat('#,##0.00', 'en_US');
      final monthYear = DateFormat('MMM_yyyy')
          .format(DateTime(_selectedYear, _selectedMonth))
          .replaceAll(' ', '_');

      final summaryCsvData = [
        ['Payroll Summary for', _companyName, monthYear.replaceAll('_', ' ')],
        ['Metric', 'Amount (KES)'],
        [
          'Total Salaries',
          numberFormat.format(_payrollSummary['total_salaries'] ?? 0)
        ],
        [
          'Total Taxes',
          numberFormat.format(_payrollSummary['total_taxes'] ?? 0)
        ],
        [
          'Total Deductions',
          numberFormat.format(_payrollSummary['total_deductions'] ?? 0)
        ],
        [],
      ];

      final headers = [
        'ID',
        'Employee ID',
        'Full Name',
        'Gross Pay (KES)',
        'Basic Pay (KES)',
        'Non-Cash Benefits (KES)',
        'Other Earnings (KES)',
        'Overtime Amount (KES)',
        'Absenteeism Deduction (KES)',
        'Taxable Income (KES)',
        'NHIF Deduction (KES)',
        'PAYE Deduction (KES)',
        'NSSF Deduction (KES)',
        'Pension Contributions (KES)',
        'Loan Repayment (KES)',
        'Other Deductions (KES)',
        'Housing Levy (KES)',
        'Housing Levy Relief (KES)',
        'Net Pay (KES)',
        'Status',
        'Payment Date',
        'Company Name'
      ];

      final detailedCsvData = [
        headers,
        ..._salaries
            .map((salary) => [
                  salary['id']?.toString() ?? 'N/A',
                  salary['employee_id']?.toString() ?? 'N/A',
                  salary['fullname']?.toString() ?? 'Unknown',
                  numberFormat.format(salary['gross_pay'] ?? 0),
                  numberFormat.format(salary['basic_pay'] ?? 0),
                  numberFormat.format(salary['non_cash_benefits'] ?? 0),
                  numberFormat.format(salary['other_earnings'] ?? 0),
                  numberFormat.format(salary['overtime_amount'] ?? 0),
                  numberFormat.format(salary['absenteeism_deduction'] ?? 0),
                  numberFormat.format(salary['taxable_income'] ?? 0),
                  numberFormat.format(salary['nhif_deduction'] ?? 0),
                  numberFormat.format(salary['paye_deduction'] ?? 0),
                  numberFormat.format(salary['nssf_deduction'] ?? 0),
                  numberFormat.format(salary['pension_contributions'] ?? 0),
                  numberFormat.format(salary['loan_repayment'] ?? 0),
                  numberFormat.format(salary['other_deductions'] ?? 0),
                  numberFormat.format(salary['housing_levy'] ?? 0),
                  numberFormat.format(salary['housing_levy_relief'] ?? 0),
                  numberFormat.format(salary['net_pay'] ?? 0),
                  salary['status']?.toString() ?? 'N/A',
                  salary['payment_date']?.toString() ?? 'N/A',
                  salary['company_name']?.toString() ?? 'Unknown',
                ])
            ,
      ];

      final csvData = [...summaryCsvData, ...detailedCsvData];
      final csvString = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final filename =
          'payroll_summary_${_companyName.replaceAll(' ', '_')}_$monthYear.csv';
      final filePath = '${directory.path}/$filename';

      final file = File(filePath);
      await file.writeAsString(csvString);

      _showSuccessSnackBar('Payroll summary exported successfully to $filePath');
    } catch (e) {
      _showErrorSnackBar('Failed to export: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PayrollSummaryConstants.successColor,
            borderRadius: PayrollSummaryConstants.borderRadiusMedium,
            boxShadow: PayrollSummaryConstants.mediumShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PayrollSummaryConstants.errorColor,
            borderRadius: PayrollSummaryConstants.borderRadiusMedium,
            boxShadow: PayrollSummaryConstants.mediumShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _fetchPayrollSummary,
        ),
      ),
    );
  }

  // Premium UI Components
  Widget _buildHeaderSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: PayrollSummaryConstants.primaryGradient,
        boxShadow: PayrollSummaryConstants.mediumShadow,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button and Title
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payroll Summary',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          _companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Export Button
                  IconButton(
                    onPressed: _isExporting ? null : _exportToCsv,
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                    tooltip: 'Export to CSV',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Date Filters
              _buildDateFilters(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: PayrollSummaryConstants.borderRadiusMedium,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedMonth,
                  items: List.generate(12, (index) => index + 1),
                  itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear, month)),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                      _fetchPayrollSummary();
                    });
                  },
                  hintText: 'Select Month',
                  icon: Icons.calendar_month_rounded,
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
                      _fetchPayrollSummary();
                    });
                  },
                  hintText: 'Select Year',
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: PayrollSummaryConstants.borderRadiusMedium,
                ),
                child: IconButton(
                  onPressed: _fetchPayrollSummary,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Viewing: ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: PayrollSummaryConstants.borderRadiusMedium,
        boxShadow: PayrollSummaryConstants.subtleShadow,
      ),
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: PayrollSummaryConstants.borderRadiusMedium,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: PayrollSummaryConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: PayrollSummaryConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              itemBuilder(item),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: PayrollSummaryConstants.primaryColor,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    if (_payrollSummary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Total Salaries',
              value: 'KES ${NumberFormat('#,##0').format(_payrollSummary['total_salaries'] ?? 0)}',
              icon: Icons.account_balance_wallet_rounded,
              color: PayrollSummaryConstants.successColor,
              subtitle: 'Gross payroll amount',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Total Taxes',
              value: 'KES ${NumberFormat('#,##0').format(_payrollSummary['total_taxes'] ?? 0)}',
              icon: Icons.receipt_long_rounded,
              color: PayrollSummaryConstants.primaryColor,
              subtitle: 'PAYE deductions',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Total Deductions',
              value: 'KES ${NumberFormat('#,##0').format(_payrollSummary['total_deductions'] ?? 0)}',
              icon: Icons.money_off_csred_rounded,
              color: PayrollSummaryConstants.errorColor,
              subtitle: 'All deductions',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PayrollSummaryConstants.surfaceColor,
        borderRadius: PayrollSummaryConstants.borderRadiusMedium,
        boxShadow: PayrollSummaryConstants.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: PayrollSummaryConstants.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: PayrollSummaryConstants.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PayrollSummaryConstants.surfaceColor,
        borderRadius: PayrollSummaryConstants.borderRadiusLarge,
        boxShadow: PayrollSummaryConstants.mediumShadow,
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PayrollSummaryConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: PayrollSummaryConstants.textTertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PayrollSummaryConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.table_chart_rounded,
                    color: PayrollSummaryConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payroll Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: PayrollSummaryConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${_salaries.length} records',
                  style: TextStyle(
                    fontSize: 14,
                    color: PayrollSummaryConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Table Content
          Expanded(
            child: Scrollbar(
              controller: _verticalScrollController,
              child: Scrollbar(
                controller: _horizontalScrollController,
                notificationPredicate: (notif) => notif.depth == 1,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      horizontalMargin: 24,
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 60,
                      headingRowHeight: 60,
                      headingTextStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PayrollSummaryConstants.textSecondary,
                      ),
                      headingRowColor: WidgetStateProperty.all(
                        PayrollSummaryConstants.cardColor,
                      ),
                      columns: _buildTableColumns(),
                      rows: _salaries.map((salary) {
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return PayrollSummaryConstants.primaryColor.withValues(alpha: 0.1);
                              }
                              final index = _salaries.indexOf(salary);
                              return index.isEven ? PayrollSummaryConstants.backgroundColor : null;
                            },
                          ),
                          cells: [
                            _buildDataCell(salary['id']?.toString() ?? 'N/A'),
                            _buildDataCell(salary['employee_id']?.toString() ?? 'N/A'),
                            _buildDataCell(salary['fullname']?.toString() ?? 'Unknown'),
                            _buildCurrencyCell(salary['gross_pay']),
                            _buildCurrencyCell(salary['basic_pay']),
                            _buildCurrencyCell(salary['non_cash_benefits']),
                            _buildCurrencyCell(salary['other_earnings']),
                            _buildCurrencyCell(salary['overtime_amount']),
                            _buildCurrencyCell(salary['absenteeism_deduction']),
                            _buildCurrencyCell(salary['taxable_income']),
                            _buildCurrencyCell(salary['nhif_deduction']),
                            _buildCurrencyCell(salary['paye_deduction']),
                            _buildCurrencyCell(salary['nssf_deduction']),
                            _buildCurrencyCell(salary['pension_contributions']),
                            _buildCurrencyCell(salary['loan_repayment']),
                            _buildCurrencyCell(salary['other_deductions']),
                            _buildCurrencyCell(salary['housing_levy']),
                            _buildCurrencyCell(salary['housing_levy_relief']),
                            _buildCurrencyCell(salary['net_pay'], isHighlighted: true),
                            _buildStatusCell(salary['status']?.toString() ?? 'N/A'),
                            _buildDataCell(_formatDate(salary['payment_date'])),
                            _buildDataCell(salary['company_name']?.toString() ?? 'Unknown'),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      _buildDataColumn('ID'),
      _buildDataColumn('Employee ID'),
      _buildDataColumn('Full Name'),
      _buildDataColumn('Gross Pay (KES)'),
      _buildDataColumn('Basic Pay (KES)'),
      _buildDataColumn('Non-Cash Benefits (KES)'),
      _buildDataColumn('Other Earnings (KES)'),
      _buildDataColumn('Overtime Amount (KES)'),
      _buildDataColumn('Absenteeism Deduction (KES)'),
      _buildDataColumn('Taxable Income (KES)'),
      _buildDataColumn('NHIF Deduction (KES)'),
      _buildDataColumn('PAYE Deduction (KES)'),
      _buildDataColumn('NSSF Deduction (KES)'),
      _buildDataColumn('Pension Contributions (KES)'),
      _buildDataColumn('Loan Repayment (KES)'),
      _buildDataColumn('Other Deductions (KES)'),
      _buildDataColumn('Housing Levy (KES)'),
      _buildDataColumn('Housing Levy Relief (KES)'),
      _buildDataColumn('Net Pay (KES)'),
      _buildDataColumn('Status'),
      _buildDataColumn('Payment Date'),
      _buildDataColumn('Company Name'),
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
            color: PayrollSummaryConstants.textSecondary,
            fontSize: 12,
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
            fontSize: 13,
            color: PayrollSummaryConstants.textPrimary,
          ),
        ),
      ),
    );
  }

  DataCell _buildCurrencyCell(dynamic amount, {bool isHighlighted = false}) {
    final value = double.tryParse(amount?.toString() ?? '0.0') ?? 0.0;
    final formattedValue = NumberFormat('#,##0.00').format(value);
    
    return DataCell(
      Tooltip(
        message: 'KES $formattedValue',
        child: Text(
          formattedValue,
          style: TextStyle(
            fontSize: 13,
            color: isHighlighted ? PayrollSummaryConstants.successColor : PayrollSummaryConstants.textPrimary,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  DataCell _buildStatusCell(String status) {
    final isPaid = status.toLowerCase().contains('paid');
    final isPending = status.toLowerCase().contains('pending');
    final color = isPaid 
        ? PayrollSummaryConstants.paidColor 
        : isPending 
            ? PayrollSummaryConstants.pendingColor 
            : PayrollSummaryConstants.failedColor;
    
    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaid ? Icons.check_circle_rounded : 
              isPending ? Icons.pending_rounded : Icons.error_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(PayrollSummaryConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Payroll Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PayrollSummaryConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching data for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: TextStyle(
              fontSize: 14,
              color: PayrollSummaryConstants.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PayrollSummaryConstants.textTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.summarize_outlined,
              size: 40,
              color: PayrollSummaryConstants.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Payroll Data Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: PayrollSummaryConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No payroll records available for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: TextStyle(
              fontSize: 14,
              color: PayrollSummaryConstants.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchPayrollSummary,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PayrollSummaryConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: PayrollSummaryConstants.borderRadiusMedium,
              ),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PayrollSummaryConstants.backgroundColor,
      body: Column(
        children: [
          _buildHeaderSection(),
          if (!_isLoading && _payrollSummary.isNotEmpty) 
            _buildStatisticsCards(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _salaries.isEmpty
                    ? _buildEmptyState()
                    : _buildPayrollTable(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }
}