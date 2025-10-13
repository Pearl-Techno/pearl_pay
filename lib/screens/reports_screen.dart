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

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const ReportsScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];
  int? _selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};
  String _selectedReportType = 'Payroll';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  final ScrollController _horizontalScrollController = ScrollController();

  List<Map<String, dynamic>> _companies = [];

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

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
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
        _companies = [userCompany];
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load company data: $e')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Showing payroll data for ${DateFormat('MMM yyyy').format(sampleDate)} instead of ${DateFormat('MMM yyyy').format(_startDate)}'),
            ),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load report data: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available to export')),
      );
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
                    ])
                .toList(),
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
                    ])
                .toList(),
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
                    ])
                .toList(),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported to $filePath'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(color: Colors.teal[900]),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
        hint: label != null
            ? Text(label, style: TextStyle(color: Colors.teal[900]))
            : null,
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
                  primary: Colors.teal[700]!,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.teal[900]!,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.teal[900]),
            ),
            Text(
              DateFormat('MMM yyyy').format(date),
              style: TextStyle(color: Colors.teal[900]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data) {
    switch (_selectedReportType) {
      case 'Payroll':
        return const SizedBox();
      case 'Leave':
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.event, color: Colors.teal),
            title: Text(data['employee_name'] ?? 'Unknown'),
            subtitle: Text(
              'Leave: ${data['start_date']} to ${data['end_date']}\n'
              'Reason: ${data['reason'] ?? 'N/A'}\n'
              'Status: ${data['status'] ?? 'N/A'}',
            ),
          ),
        );
      case 'Employee':
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.teal),
            title: Text(data['fullname'] ?? 'Unknown'),
            subtitle: Text(
              'Email: ${data['email'] ?? 'N/A'}\n'
              'Department: ${data['department'] ?? 'N/A'}\n'
              'Hire Date: ${data['hire_date'] ?? 'N/A'}',
            ),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Reports',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) {
            print('Notifications tapped');
          }
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.teal[700]),
                    title: Text('Profile: ${widget.user['username']}'),
                    subtitle: Text('Role: ${widget.user['role']}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout(context);
                    },
                  ),
                ],
              ),
            ),
          );
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.teal[50]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
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
                              label: 'Select Report Type',
                            ),
                            const SizedBox(height: 16),
                            _buildMonthYearPicker(
                              date: _startDate,
                              label: 'Period',
                              onDateSelected: (date) {
                                setState(() {
                                  _startDate = date;
                                  _endDate = date; // Single month
                                  _fetchReportData();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _fetchReportData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Generate Report'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _exportToCsv,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Export to CSV'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _reportData.isEmpty
                          ? Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.teal[50]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                    child: Text('No report data available')),
                              ),
                            )
                          : _selectedReportType == 'Payroll'
                              ? Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width - 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.teal[50]!
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
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
                                          constraints: const BoxConstraints(
                                              minWidth: 2200),
                                          child: Scrollbar(
                                            thumbVisibility: true,
                                            thickness: 8.0,
                                            radius: const Radius.circular(4),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: DataTable(
                                                columnSpacing: 16.0,
                                                dataRowHeight: 60,
                                                headingRowColor:
                                                    MaterialStateProperty.all(
                                                        Colors.teal[100]),
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('ID',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text('Employee ID',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text('Full Name',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Gross Pay (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Basic Pay (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Non-Cash Benefits (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Other Earnings (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Overtime Amount (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Absenteeism Deduction (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Taxable Income (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'NHIF Deduction (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'PAYE Deduction (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'NSSF Deduction (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Pension Contributions (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Loan Repayment (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Other Deductions (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Housing Levy (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Housing Levy Relief (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Net Pay (KES)',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text('Status',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Payment Date',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                  DataColumn(
                                                      label: Text(
                                                          'Company Name',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .teal))),
                                                ],
                                                rows: _reportData.map((data) {
                                                  return DataRow(cells: [
                                                    DataCell(Text(
                                                        data['id']
                                                                ?.toString() ??
                                                            'N/A',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        data['employee_id']
                                                                ?.toString() ??
                                                            'N/A',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        data['fullname']
                                                                ?.toString() ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['gross_pay'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['basic_pay'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['non_cash_benefits'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['other_earnings'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['overtime_amount'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['absenteeism_deduction'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['taxable_income'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['nhif_deduction'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['paye_deduction'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['nssf_deduction'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['pension_contributions'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['loan_repayment'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['other_deductions'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['housing_levy'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['housing_levy_relief'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        numberFormat.format(
                                                            data['net_pay'] ??
                                                                0),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        data['status']
                                                                ?.toString() ??
                                                            'N/A',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        data['payment_date']
                                                                ?.toString() ??
                                                            'N/A',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                    DataCell(Text(
                                                        data['company_name']
                                                                ?.toString() ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey[800]))),
                                                  ]);
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _reportData.length,
                                  itemBuilder: (context, index) =>
                                      _buildReportCard(_reportData[index]),
                                ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
