import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';

// Constants - Using same colors as other screens
class ReportConstants {
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
  static const Color warningColor = Color(0xFFFF9800);
}

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const ReportsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  ReportsScreenState createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];
  int? _selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};
  String _selectedReportType = 'Payroll';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  final ScrollController _horizontalScrollController = ScrollController();

  final reportTypes = ['Payroll', 'Leave', 'Employee'];

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ReportConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(
          color: ReportConstants.textColor,
          fontWeight: FontWeight.w600,
        )),
        content: Text('Are you sure you want to log out?', style: TextStyle(
          color: ReportConstants.subtitleColor,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(
              color: ReportConstants.subtitleColor,
            )),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ReportConstants.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final userCompanyId = widget.user['company_id'] != null
          ? int.tryParse(widget.user['company_id'].toString())
          : null;
      final userCompanyName =
          widget.user['company_name']?.toString() ?? 'Unknown';

      if (userCompanyId == null) {
        throw Exception('User company ID is not available');
      }

      // Optionally fetch companies to validate user's company
      final companies = await widget.apiService.getCompanies();
      final userCompany = companies.firstWhere(
        (c) => int.tryParse(c['id']?.toString() ?? '') == userCompanyId,
        orElse: () => {
          'id': userCompanyId,
          'company_name': userCompanyName,
        },
      );

      setState(() {
        companyIds = [userCompanyId];
        companyIdToName = {
          userCompanyId:
              userCompany['company_name']?.toString() ?? userCompanyName,
        };
        _selectedCompanyId = userCompanyId;
      });

      await _fetchReportData();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load company data: $e');
    }
  }

  Future<void> _fetchReportData() async {
    if (_selectedCompanyId == null) {
      setState(() {
        _reportData = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isAdmin = widget.user['role'] == 'admin';
      var reportData = await _fetchReportForCompany(_selectedCompanyId!);

      if (!isAdmin && widget.user['employee_id'] != null) {
        reportData = reportData
            .where((data) => data['employee_id'] == widget.user['employee_id'])
            .toList();
      }

      // Check for date mismatch in Payroll report
      if (_selectedReportType == 'Payroll' && reportData.isNotEmpty) {
        final sampleDate =
            DateTime.tryParse(reportData.first['payment_date'] ?? '');
        if (sampleDate != null &&
            (sampleDate.month != _startDate.month ||
                sampleDate.year != _startDate.year)) {
          if (kDebugMode) {
            print(
                'Warning: Payroll data for ${_startDate.month}/${_startDate.year} not found, received ${sampleDate.month}/${sampleDate.year}');
          }
          _showInfoSnackBar(
              'Showing payroll data for ${DateFormat('MMM yyyy').format(sampleDate)} instead of ${DateFormat('MMM yyyy').format(_startDate)}');
        }
      }

      setState(() {
        _reportData = reportData;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching report data: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load report data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReportForCompany(
      int companyId) async {
    final month = _startDate.month;
    final year = _startDate.year;

    switch (_selectedReportType) {
      case 'Payroll':
        return await widget.apiService
            .getPayrollSummary(companyId, month, year);
      case 'Leave':
        return await widget.apiService.getLeaveReport(companyId, month, year);
      case 'Employee':
        return await widget.apiService
            .getEmployeeReport(companyId, month, year);
      default:
        return [];
    }
  }

  Future<void> _exportToCsv() async {
    if (_reportData.isEmpty) {
      _showWarningSnackBar('No report data available to export');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final numberFormat = NumberFormat('#,##0.00', 'en_US');
      final companyName = companyIdToName[_selectedCompanyId] ?? 'Unknown';
      final period = DateFormat('MMM yyyy').format(_startDate);

      List<List<dynamic>> csvData = [];
      switch (_selectedReportType) {
        case 'Payroll':
          csvData = [
            ['Payroll Report for', companyName, period],
            [
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
            ],
            ..._reportData
                .map((data) => [
                      data['id']?.toString() ?? 'N/A',
                      data['employee_id']?.toString() ?? 'N/A',
                      data['fullname']?.toString() ?? 'Unknown',
                      numberFormat.format(data['gross_pay'] ?? 0),
                      numberFormat.format(data['basic_pay'] ?? 0),
                      numberFormat.format(data['non_cash_benefits'] ?? 0),
                      numberFormat.format(data['other_earnings'] ?? 0),
                      numberFormat.format(data['overtime_amount'] ?? 0),
                      numberFormat.format(data['absenteeism_deduction'] ?? 0),
                      numberFormat.format(data['taxable_income'] ?? 0),
                      numberFormat.format(data['nhif_deduction'] ?? 0),
                      numberFormat.format(data['paye_deduction'] ?? 0),
                      numberFormat.format(data['nssf_deduction'] ?? 0),
                      numberFormat.format(data['pension_contributions'] ?? 0),
                      numberFormat.format(data['loan_repayment'] ?? 0),
                      numberFormat.format(data['other_deductions'] ?? 0),
                      numberFormat.format(data['housing_levy'] ?? 0),
                      numberFormat.format(data['housing_levy_relief'] ?? 0),
                      numberFormat.format(data['net_pay'] ?? 0),
                      data['status']?.toString() ?? 'N/A',
                      data['payment_date']?.toString() ?? 'N/A',
                      data['company_name']?.toString() ?? 'Unknown',
                    ]),
          ];
          break;
        case 'Leave':
          csvData = [
            ['Leave Report for', companyName, period],
            [
              'Employee ID',
              'Employee Name',
              'Start Date',
              'End Date',
              'Reason',
              'Status',
              'Created At'
            ],
            ..._reportData
                .map((data) => [
                      data['employee_id']?.toString() ?? 'N/A',
                      data['employee_name']?.toString() ?? 'Unknown',
                      data['start_date']?.toString() ?? 'N/A',
                      data['end_date']?.toString() ?? 'N/A',
                      data['reason']?.toString() ?? 'N/A',
                      data['status']?.toString() ?? 'N/A',
                      data['created_at']?.toString() ?? 'N/A',
                    ]),
          ];
          break;
        case 'Employee':
          csvData = [
            ['Employee Report for', companyName, period],
            [
              'Employee ID',
              'Full Name',
              'Email',
              'Department',
              'Hire Date',
              'Status'
            ],
            ..._reportData
                .map((data) => [
                      data['employee_id']?.toString() ?? 'N/A',
                      data['fullname']?.toString() ?? 'Unknown',
                      data['email']?.toString() ?? 'N/A',
                      data['department']?.toString() ?? 'N/A',
                      data['hire_date']?.toString() ?? 'N/A',
                      data['status']?.toString() ?? 'N/A',
                    ]),
          ];
          break;
      }

      final csvString = const ListToCsvConverter().convert(csvData);

      String baseDir = Platform.isWindows
          ? r'C:\reports'
          : '${(await getApplicationDocumentsDirectory()).path}/reports';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filename =
          '${_selectedReportType.toLowerCase()}_report_${companyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateFormat('MMM_yyyy').format(_startDate)}.csv';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsString(csvString);

      _showSuccessSnackBar('CSV exported to $filePath');
    } catch (e) {
      _showErrorSnackBar('Failed to export CSV: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Snackbar helpers
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
        backgroundColor: ReportConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
        backgroundColor: ReportConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ReportConstants.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ReportConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    String? label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ReportConstants.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ReportConstants.primaryColor.withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButton<T>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(
                      color: ReportConstants.textColor,
                      fontSize: 14,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: ReportConstants.cardColor,
        icon: Icon(Icons.arrow_drop_down, color: ReportConstants.primaryColor),
        hint: label != null
            ? Text(label, style: TextStyle(color: ReportConstants.subtitleColor))
            : null,
        isExpanded: true,
      ),
    );
  }

  Widget _buildMonthYearPicker({
    required DateTime date,
    required String label,
    required ValueChanged<DateTime> onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: ReportConstants.primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: ReportConstants.textColor,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) {
          onDateSelected(DateTime(pickedDate.year, pickedDate.month));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: ReportConstants.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ReportConstants.primaryColor.withAlpha(77)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ReportConstants.textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Icon(Icons.calendar_today, 
                    color: ReportConstants.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM yyyy').format(date),
                  style: TextStyle(
                    color: ReportConstants.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data) {
    Color statusColor = ReportConstants.greyColor;
    final status = (data['status']?.toString() ?? '').toLowerCase();
    
    if (status.contains('approved') || status.contains('completed')) {
      statusColor = ReportConstants.successColor;
    } else if (status.contains('pending')) {
      statusColor = ReportConstants.warningColor;
    } else if (status.contains('rejected') || status.contains('cancelled')) {
      statusColor = ReportConstants.errorColor;
    }

    switch (_selectedReportType) {
      case 'Payroll':
        return const SizedBox();
      case 'Leave':
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              color: ReportConstants.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ReportConstants.primaryColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event, color: ReportConstants.primaryColor),
              ),
              title: Text(
                data['employee_name'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ReportConstants.textColor,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${data['start_date']} to ${data['end_date']}',
                    style: TextStyle(color: ReportConstants.subtitleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${data['reason'] ?? 'N/A'}',
                    style: TextStyle(color: ReportConstants.subtitleColor),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withAlpha(77)),
                ),
                child: Text(
                  data['status']?.toString() ?? 'N/A',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      case 'Employee':
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              color: ReportConstants.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ReportConstants.primaryColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: ReportConstants.primaryColor),
              ),
              title: Text(
                data['fullname'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ReportConstants.textColor,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Email: ${data['email'] ?? 'N/A'}',
                    style: TextStyle(color: ReportConstants.subtitleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Department: ${data['department'] ?? 'N/A'}',
                    style: TextStyle(color: ReportConstants.subtitleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hire Date: ${data['hire_date'] ?? 'N/A'}',
                    style: TextStyle(color: ReportConstants.subtitleColor),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withAlpha(77)),
                ),
                child: Text(
                  data['status']?.toString() ?? 'N/A',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildPayrollDataTable() {
    final numberFormat = NumberFormat('#,##0.00', 'en_US');
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width - 32,
        decoration: BoxDecoration(
          color: ReportConstants.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          thickness: 8.0,
          radius: const Radius.circular(4),
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Container(
              constraints: const BoxConstraints(minWidth: 2200),
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 8.0,
                radius: const Radius.circular(4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 16.0,
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 60,
                    headingRowColor: WidgetStateProperty.all(ReportConstants.primaryColor.withAlpha(26)),
                    columns: [
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
                    ],
                    rows: _reportData.map((data) {
                      Color statusColor = ReportConstants.greyColor;
                      final status = (data['status']?.toString() ?? '').toLowerCase();
                      
                      if (status.contains('approved') || status.contains('completed')) {
                        statusColor = ReportConstants.successColor;
                      } else if (status.contains('pending')) {
                        statusColor = ReportConstants.warningColor;
                      } else if (status.contains('rejected') || status.contains('cancelled')) {
                        statusColor = ReportConstants.errorColor;
                      }

                      return DataRow(cells: [
                        _buildDataCell(data['id']?.toString() ?? 'N/A'),
                        _buildDataCell(data['employee_id']?.toString() ?? 'N/A'),
                        _buildDataCell(data['fullname']?.toString() ?? 'Unknown'),
                        _buildDataCell(numberFormat.format(data['gross_pay'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['basic_pay'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['non_cash_benefits'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['other_earnings'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['overtime_amount'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['absenteeism_deduction'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['taxable_income'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['nhif_deduction'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['paye_deduction'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['nssf_deduction'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['pension_contributions'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['loan_repayment'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['other_deductions'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['housing_levy'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['housing_levy_relief'] ?? 0)),
                        _buildDataCell(numberFormat.format(data['net_pay'] ?? 0)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withAlpha(77)),
                            ),
                            child: Text(
                              data['status']?.toString() ?? 'N/A',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _buildDataCell(data['payment_date']?.toString() ?? 'N/A'),
                        _buildDataCell(data['company_name']?.toString() ?? 'Unknown'),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: ReportConstants.textColor,
          fontSize: 12,
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Text(
        text,
        style: TextStyle(
          color: ReportConstants.textColor,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReportConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Reports Dashboard',
        backgroundColor: ReportConstants.primaryColor,
        onNotificationTap: () {
          // Handle notifications
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: ReportConstants.cardColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ReportConstants.greyColor.withAlpha(77),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ReportConstants.primaryColor.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: ReportConstants.primaryColor),
                    ),
                    title: Text('Profile: ${widget.user['username']}',
                        style: TextStyle(
                          color: ReportConstants.textColor,
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('Role: ${widget.user['role']}',
                        style: TextStyle(color: ReportConstants.subtitleColor)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      icon: Icon(Icons.logout, size: 20),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ReportConstants.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: ReportConstants.primaryColor,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ReportConstants.primaryColor,
                          ReportConstants.secondaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16), boxShadow: [
                      BoxShadow(
                        color: ReportConstants.primaryColor.withAlpha(77),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.analytics,
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
                                'Reports Dashboard',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Generate and export various reports',
                                style: TextStyle(color: Colors.white.withAlpha(230),
                                  fontSize: 14,),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Controls Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ReportConstants.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Report Type',
                                      style: TextStyle(
                                        color: ReportConstants.textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDropdown(
                                      value: _selectedReportType,
                                      items: reportTypes,
                                      itemBuilder: (type) => type,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedReportType = value!;
                                          _fetchReportData();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Period',
                                      style: TextStyle(
                                        color: ReportConstants.textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildMonthYearPicker(
                                      date: _startDate,
                                      label: 'Select Month',
                                      onDateSelected: (date) {
                                        setState(() {
                                          _startDate = date;
                                          _fetchReportData();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _fetchReportData,
                                  icon: Icon(Icons.refresh, size: 20),
                                  label: const Text('Generate Report'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ReportConstants.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _exportToCsv,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.download, size: 20),
                                  label: Text(_isLoading ? 'Exporting...' : 'Export to CSV'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ReportConstants.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Results Section
                  Text(
                    'Report Results (${_reportData.length} records)',
                    style: TextStyle(
                      color: ReportConstants.textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _reportData.isEmpty
                        ? Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: ReportConstants.cardColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 80,
                                  color: ReportConstants.greyColor.withAlpha(128),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Report Data Available',
                                    style: TextStyle(
                                      color: ReportConstants.textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Generate a report using the controls above',
                                    style: TextStyle(
                                      color: ReportConstants.subtitleColor,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _selectedReportType == 'Payroll'
                            ? _buildPayrollDataTable()
                            : ListView.builder(
                                itemCount: _reportData.length,
                                itemBuilder: (context, index) =>
                                    _buildReportCard(_reportData[index]),
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}