import 'dart:io';

import 'package:csv/csv.dart'; // Add this package to pubspec.yaml
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class PAYEExport {
  final String title = 'PAYE Export';
  final IconData icon = Icons.account_balance;
  final ApiService _apiService = ApiService(client: http.Client());

  Widget buildCard(BuildContext context) {
    return Card(
      elevation: 6, // Match HomeScreen
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal[700]),
        title: Text(title,
            style: TextStyle(
                color: Colors.teal[900], fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.file_download, color: Colors.teal[700]),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => buildDetailsPage(context)),
          );
        },
      ),
    );
  }

  Widget buildDetailsPage(BuildContext context) {
    return _PAYEExportDetailsPage(apiService: _apiService);
  }
}

class _PAYEExportDetailsPage extends StatefulWidget {
  final ApiService apiService;

  const _PAYEExportDetailsPage({required this.apiService});

  @override
  _PAYEExportDetailsPageState createState() => _PAYEExportDetailsPageState();
}

class _PAYEExportDetailsPageState extends State<_PAYEExportDetailsPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<String> _companyNames = ['All Companies'];
  bool _isLoading = true;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  String? selectedCompany;

  @override
  void initState() {
    super.initState();
    _fetchPAYEData();
  }

  Future<void> _fetchPAYEData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await widget.apiService.getEmployeeList();
      final salaries = await widget.apiService.getSalaries();

      // Debug: Check the number of employees and salaries fetched
      print('Fetched ${employees.length} employees');
      print('Fetched ${salaries.length} salaries');

      final companyNames = ['All Companies'] +
          employees
              .map((e) => e['company_name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .toSet()
              .cast<String>()
              .toList();

      // Filter salaries by month, year, and company
      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        if (paymentDate == null) {
          print('Invalid payment_date for salary: ${salary['payment_date']}');
          return false;
        }
        final matchesMonthYear = paymentDate.month == selectedMonth &&
            paymentDate.year == selectedYear;
        final matchesCompany = selectedCompany == null ||
            selectedCompany == 'All Companies' ||
            salary['company_name'] == selectedCompany;
        return matchesMonthYear && matchesCompany;
      }).toList();

      // Debug: Check the number of filtered salaries
      print(
          'Filtered ${filteredSalaries.length} salaries for month $selectedMonth, year $selectedYear');

      // Get employee IDs from filtered salaries
      final payeEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      // Filter employees based on the employee IDs in filtered salaries
      final filteredEmployees = employees.where((employee) {
        return payeEmployeeIds.contains(employee['employee_id'].toString());
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        return {
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'fullname': employee['fullname'] ?? 'N/A',
          'resident_status': 'RESIDENT',
          'type_of_employee': 'PRIMARY EMPLOYEE',
          'basic_salary': salary['basic_pay']?.toString() ?? '0.0',
          // Use house_allowance from employee data instead of salary data
          'house_allowance': employee['house_allowance']?.toString() ?? '0.00',
          'transport_allowance': salary['transport']?.toString() ?? '0.0',
          'leave_pay': '0',
          'overtime_allowance': salary['overtime_amount']?.toString() ?? '0.0',
          'directors_fee': '0',
          'lumpsum_payment': '0',
          'any_other_allowance': salary['other_earnings']?.toString() ?? '0.0',
          'total_cash_pay': _calculateTotalCashPay(salary, employee),
          'value_of_car_benefit': '0',
          'other_non_cash_benefits':
              salary['non_cash_benefits']?.toString() ?? '0.0',
          'total_non_cash_benefits':
              salary['non_cash_benefits']?.toString() ?? '0.0',
          'value_of_meals': '0',
          'type_of_housing': 'BENEFIT NOT GIVEN',
          'rent_of_house': '0',
          'computed_rent_of_house': '0',
          'rent_recovered_from_employee': '0',
          'net_value_of_the_house': '0',
          'total_gross_pay': salary['gross_pay']?.toString() ?? '0.0',
          'shif': salary['nhif_deduction']?.toString() ?? '0.0',
          'nssf': salary['nssf_deduction']?.toString() ?? '0.0',
          'post_retirement_medication_fund': '0',
          'mortgage_interest': '0',
          'housing_levy': salary['housing_levy']?.toString() ?? '0.0',
          'actual_benefits': _calculateActualBenefits(salary),
          'taxable_pay': salary['taxable_income']?.toString() ?? '0.0',
          'tax_payable_before_reliefs': _calculateTaxBeforeReliefs(salary),
          'monthly_personal_relief': '2400.00',
          'insurance_relief': '0',
          'leave_blank': '',
          'paye': salary['paye_deduction']?.toString() ?? '0.0',
          'company_name': employee['company_name'] ?? 'N/A',
        };
      }).toList();

      // Debug: Check the number of filtered employees
      print('Filtered ${filteredEmployees.length} employees');

      setState(() {
        _employees = employees;
        _filteredEmployees = filteredEmployees;
        _companyNames = companyNames;
        selectedCompany ??= 'All Companies';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching PAYE data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load PAYE data: $e')),
      );
    }
  }

  String _calculateTotalCashPay(
      Map<String, dynamic> salary, Map<String, dynamic> employee) {
    final basic =
        double.tryParse(salary['basic_pay']?.toString() ?? '0.0') ?? 0.0;
    // Use house_allowance from employee data
    final house =
        double.tryParse(employee['house_allowance']?.toString() ?? '0.0') ??
            0.0;
    final transport =
        double.tryParse(salary['transport']?.toString() ?? '0.0') ?? 0.0;
    final overtime =
        double.tryParse(salary['overtime_amount']?.toString() ?? '0.0') ?? 0.0;
    final other =
        double.tryParse(salary['other_earnings']?.toString() ?? '0.0') ?? 0.0;
    return (basic + house + transport + overtime + other).toStringAsFixed(2);
  }

  String _calculateActualBenefits(Map<String, dynamic> salary) {
    final housingLevy =
        double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ?? 0.0;
    return housingLevy.toStringAsFixed(2);
  }

  String _calculateTaxBeforeReliefs(Map<String, dynamic> salary) {
    final taxablePay =
        double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0;
    final paye =
        double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ?? 0.0;
    final relief = 2400.00;
    return (paye + relief).toStringAsFixed(2);
  }

  Future<void> _exportMonthlyPAYE() async {
    await _exportToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported Monthly PAYE as CSV'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportAnnualPAYE() async {
    // Placeholder for annual PAYE export logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Annual PAYE export not implemented yet'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available to export'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final List<List<dynamic>> rows = [
        [
          'KRA PIN',
          'Fullname',
          'Resident Status',
          'Type of employee',
          'Basic salary',
          'House Allowance',
          'Transport Allowance',
          'Leave Pay',
          'Overtime Allowance',
          'Directors fee',
          'Lumpsum payment if any',
          'Any other allowance',
          'Total Cash pay',
          'Value of car benefit',
          'Other non cash benefits',
          'Total non cash benefits',
          'Value of meals',
          'Type of housing',
          'Rent of house',
          'Computed rent of house',
          'Rent recovered from employee',
          'Net value of the house',
          'Total gross pay',
          'Shif',
          'NSSF',
          'Post Retirement medication fund',
          'Mortgage Interest',
          'Housing levy',
          'Actual benefits',
          'Taxable pay',
          'Tax payable before reliefs',
          'Monthly personal relief',
          'Insurance relief',
          'Leave blank',
          'PAYE'
        ],
        ..._filteredEmployees.map((employee) {
          final numberFormat = NumberFormat('#,##0.00', 'en_US');
          return [
            employee['kra_pin'],
            employee['fullname'],
            employee['resident_status'],
            employee['type_of_employee'],
            numberFormat.format(
                double.tryParse(employee['basic_salary'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['house_allowance'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['transport_allowance'] ?? '0.0') ??
                    0.0),
            numberFormat
                .format(double.tryParse(employee['leave_pay'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['overtime_allowance'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['directors_fee'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['lumpsum_payment'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['any_other_allowance'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['total_cash_pay'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['value_of_car_benefit'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['other_non_cash_benefits'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['total_non_cash_benefits'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['value_of_meals'] ?? '0.0') ?? 0.0),
            employee['type_of_housing'],
            numberFormat.format(
                double.tryParse(employee['rent_of_house'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['computed_rent_of_house'] ?? '0.0') ??
                    0.0),
            numberFormat.format(double.tryParse(
                    employee['rent_recovered_from_employee'] ?? '0.0') ??
                0.0),
            numberFormat.format(
                double.tryParse(employee['net_value_of_the_house'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['total_gross_pay'] ?? '0.0') ?? 0.0),
            numberFormat
                .format(double.tryParse(employee['shif'] ?? '0.0') ?? 0.0),
            numberFormat
                .format(double.tryParse(employee['nssf'] ?? '0.0') ?? 0.0),
            numberFormat.format(double.tryParse(
                    employee['post_retirement_medication_fund'] ?? '0.0') ??
                0.0),
            numberFormat.format(
                double.tryParse(employee['mortgage_interest'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['housing_levy'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['actual_benefits'] ?? '0.0') ?? 0.0),
            numberFormat.format(
                double.tryParse(employee['taxable_pay'] ?? '0.0') ?? 0.0),
            numberFormat.format(double.tryParse(
                    employee['tax_payable_before_reliefs'] ?? '0.0') ??
                0.0),
            numberFormat.format(
                double.tryParse(employee['monthly_personal_relief'] ?? '0.0') ??
                    0.0),
            numberFormat.format(
                double.tryParse(employee['insurance_relief'] ?? '0.0') ?? 0.0),
            employee['leave_blank'],
            numberFormat
                .format(double.tryParse(employee['paye'] ?? '0.0') ?? 0.0),
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath = '${directory.path}/paye_export_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PAYE data exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      print('Error exporting to CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    }
  }

  Widget _buildDropdown<T>({
    required T value,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'PAYE Export',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          print('Profile tapped');
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDropdown(
                              value: selectedMonth,
                              items: List.generate(12, (index) => index + 1),
                              itemBuilder: (month) => DateFormat('MMMM')
                                  .format(DateTime(selectedYear, month)),
                              onChanged: (value) {
                                setState(() {
                                  selectedMonth = value!;
                                  _fetchPAYEData();
                                });
                              },
                            ),
                            _buildDropdown(
                              value: selectedYear,
                              items: List.generate(
                                  10, (index) => DateTime.now().year - index),
                              itemBuilder: (year) => year.toString(),
                              onChanged: (value) {
                                setState(() {
                                  selectedYear = value!;
                                  _fetchPAYEData();
                                });
                              },
                            ),
                            _buildDropdown(
                              value: selectedCompany ?? 'All Companies',
                              items: _companyNames,
                              itemBuilder: (company) => company,
                              onChanged: (value) {
                                setState(() {
                                  selectedCompany = value;
                                  _fetchPAYEData();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]))
                    : _filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              'No PAYE data available for selected filters',
                              style: TextStyle(
                                  color: Colors.teal[900], fontSize: 16),
                            ),
                          )
                        : Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.teal[50]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    dataRowHeight: 60,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.teal[100]),
                                    columns: const [
                                      DataColumn(
                                          label: Text('KRA PIN',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Fullname',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Resident Status',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Type of employee',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Basic salary',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('House Allowance',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Transport Allowance',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Leave Pay',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Overtime Allowance',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Directors fee',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Lumpsum payment if any',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Any other allowance',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Total Cash pay',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Value of car benefit',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Other non cash benefits',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Total non cash benefits',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Value of meals',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Type of housing',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Rent of house',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Computed rent of house',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text(
                                              'Rent recovered from employee',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Net value of the house',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Total gross pay',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Shif',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('NSSF',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text(
                                              'Post Retirement medication fund',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Mortgage Interest',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Housing levy',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Actual benefits',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Taxable pay',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text(
                                              'Tax payable before reliefs',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Monthly personal relief',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Insurance relief',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Leave blank',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('PAYE',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                    ],
                                    rows: _filteredEmployees.map((employee) {
                                      final numberFormat =
                                          NumberFormat('#,##0.00', 'en_US');
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(employee['kra_pin'],
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(employee['fullname'],
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['resident_status'],
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['type_of_employee'],
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['basic_salary'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['house_allowance'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['transport_allowance'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['leave_pay'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['overtime_allowance'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['directors_fee'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['lumpsum_payment'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['any_other_allowance'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['total_cash_pay'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['value_of_car_benefit'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['other_non_cash_benefits'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['total_non_cash_benefits'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['value_of_meals'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['type_of_housing'],
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['rent_of_house'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['computed_rent_of_house'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['rent_recovered_from_employee'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['net_value_of_the_house'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['total_gross_pay'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['shif'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['nssf'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['post_retirement_medication_fund'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['mortgage_interest'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['housing_levy'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['actual_benefits'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['taxable_pay'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['tax_payable_before_reliefs'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['monthly_personal_relief'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['insurance_relief'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(employee['leave_blank'],
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['paye'] ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                        ],
                                      );
                                    }).toList(),
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
                child: _isLoading
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _exportMonthlyPAYE,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export Monthly PAYE'),
                          ),
                          ElevatedButton(
                            onPressed: _exportAnnualPAYE,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export Annual PAYE'),
                          ),
                          ElevatedButton(
                            onPressed: _exportToCSV,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export to CSV'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
