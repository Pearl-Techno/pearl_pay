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

class PayrollSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const PayrollSummaryScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PayrollSummaryScreenState createState() => _PayrollSummaryScreenState();
}

class _PayrollSummaryScreenState extends State<PayrollSummaryScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _payrollSummary = {};
  List<Map<String, dynamic>> _salaries = [];
  String _companyName = 'Unknown';
  int? _companyId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeCompany();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load company data: $e')),
      );
    }
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

      // Check for month mismatch
      if (salaries.isNotEmpty) {
        final sampleDate =
            DateTime.tryParse(salaries.first['payment_date'] ?? '');
        if (sampleDate != null &&
            (sampleDate.month != _selectedMonth ||
                sampleDate.year != _selectedYear)) {
          if (kDebugMode) {
            print(
                'Warning: Data for ${_selectedMonth}/${_selectedYear} not found, received ${sampleDate.month}/${sampleDate.year}');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Showing data for ${DateFormat('MMM yyyy').format(sampleDate)} instead of ${DateFormat('MMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}'),
            ),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payroll summary available to export')),
      );
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
            .toList(),
      ];

      final csvData = [...summaryCsvData, ...detailedCsvData];
      final csvString = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final filename =
          'payroll_summary_${_companyName.replaceAll(' ', '_')}_$monthYear.csv';
      final filePath = '${directory.path}/$filename';

      final file = File(filePath);
      await file.writeAsString(csvString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _exportToCsv,
          ),
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
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
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: ListTile(
          leading: Icon(icon, color: Colors.teal[700]),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.teal[900],
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Payroll Summary - $_companyName',
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
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
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
                          const SizedBox(height: 16),
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
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildDropdown(
                                      value: _selectedMonth,
                                      items: List.generate(
                                          12, (index) => index + 1),
                                      itemBuilder: (month) => DateFormat('MMMM')
                                          .format(
                                              DateTime(_selectedYear, month)),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedMonth = value!;
                                          _fetchPayrollSummary();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildDropdown(
                                      value: _selectedYear,
                                      items: List.generate(
                                          10,
                                          (index) =>
                                              DateTime.now().year - index),
                                      itemBuilder: (year) => year.toString(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedYear = value!;
                                          _fetchPayrollSummary();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _fetchPayrollSummary,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _payrollSummary.isEmpty
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
                                    child: Text('No payroll data available')),
                              ),
                            )
                          : Column(
                              children: [
                                _buildSummaryCard(
                                  icon: Icons.account_balance_wallet,
                                  title: 'Total Salaries',
                                  subtitle:
                                      'KES ${numberFormat.format(_payrollSummary['total_salaries'] ?? 0)}',
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryCard(
                                  icon: Icons.money_off,
                                  title: 'Total Taxes',
                                  subtitle:
                                      'KES ${numberFormat.format(_payrollSummary['total_taxes'] ?? 0)}',
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryCard(
                                  icon: Icons.remove_circle_outline,
                                  title: 'Total Deductions',
                                  subtitle:
                                      'KES ${numberFormat.format(_payrollSummary['total_deductions'] ?? 0)}',
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_salaries.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.teal[50]!],
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
                                  constraints:
                                      const BoxConstraints(minWidth: 2200),
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
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Employee ID',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Full Name',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Gross Pay (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Basic Pay (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Non-Cash Benefits (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Other Earnings (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Overtime Amount (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Absenteeism Deduction (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Taxable Income (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'NHIF Deduction (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'PAYE Deduction (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'NSSF Deduction (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Pension Contributions (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Loan Repayment (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Other Deductions (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Housing Levy (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text(
                                                  'Housing Levy Relief (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Net Pay (KES)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Status',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Payment Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                          DataColumn(
                                              label: Text('Company Name',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.teal))),
                                        ],
                                        rows: _salaries.map((salary) {
                                          return DataRow(cells: [
                                            DataCell(Text(
                                                salary['id']?.toString() ??
                                                    'N/A',
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                salary['employee_id']
                                                        ?.toString() ??
                                                    'N/A',
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                salary['fullname']
                                                        ?.toString() ??
                                                    'Unknown',
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['gross_pay'] ?? 0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['basic_pay'] ?? 0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(salary[
                                                        'non_cash_benefits'] ??
                                                    0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['other_earnings'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['overtime_amount'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(salary[
                                                        'absenteeism_deduction'] ??
                                                    0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['taxable_income'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['nhif_deduction'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['paye_deduction'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['nssf_deduction'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(salary[
                                                        'pension_contributions'] ??
                                                    0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['loan_repayment'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(salary[
                                                        'other_deductions'] ??
                                                    0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['housing_levy'] ??
                                                        0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(salary[
                                                        'housing_levy_relief'] ??
                                                    0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                numberFormat.format(
                                                    salary['net_pay'] ?? 0),
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                salary['status']?.toString() ??
                                                    'N/A',
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                salary['payment_date']
                                                        ?.toString() ??
                                                    'N/A',
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                            DataCell(Text(
                                                salary['company_name']
                                                        ?.toString() ??
                                                    'Unknown',
                                                style: TextStyle(
                                                    color: Colors.grey[800]))),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                          child: ElevatedButton(
                            onPressed: _isExporting ? null : _exportToCsv,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isExporting
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Export Summary to CSV'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }
}
