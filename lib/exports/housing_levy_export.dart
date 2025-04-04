import 'dart:io';

import 'package:csv/csv.dart'; // Add this package to pubspec.yaml
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class HousingLevyExport {
  final String title = 'Housing Levy Export';
  final IconData icon = Icons.home;
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
    return _HousingLevyExportDetailsPage(apiService: _apiService);
  }
}

class _HousingLevyExportDetailsPage extends StatefulWidget {
  final ApiService apiService;

  const _HousingLevyExportDetailsPage({required this.apiService});

  @override
  _HousingLevyExportDetailsPageState createState() =>
      _HousingLevyExportDetailsPageState();
}

class _HousingLevyExportDetailsPageState
    extends State<_HousingLevyExportDetailsPage> {
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
    _fetchHousingLevyData();
  }

  Future<void> _fetchHousingLevyData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await widget.apiService.getEmployeeList();
      final salaries = await widget.apiService.getSalaries();

      final companyNames = ['All Companies'] +
          employees
              .map((e) => e['company_name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .toSet()
              .cast<String>()
              .toList();

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == selectedMonth &&
            paymentDate.year == selectedYear;
        final matchesCompany = selectedCompany == null ||
            selectedCompany == 'All Companies' ||
            salary['company_name'] == selectedCompany;
        final hasHousingLevy =
            (double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && matchesCompany && hasHousingLevy;
      }).toList();

      final housingLevyEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        return housingLevyEmployeeIds
            .contains(employee['employee_id'].toString());
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        return {
          'employee_id': employee['employee_id'] ?? 'N/A',
          'fullname': employee['fullname'] ?? 'N/A',
          'company_name': employee['company_name'] ?? 'N/A',
          'national_id': employee['national_id'] ?? 'N/A',
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'gross_pay': salary['gross_pay'] ?? '0.0',
          'housing_levy':
              salary['housing_levy'] ?? '0.0', // Include housing levy amount
        };
      }).toList();

      setState(() {
        _employees = employees;
        _filteredEmployees = filteredEmployees;
        _companyNames = companyNames;
        selectedCompany ??= 'All Companies';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load Housing Levy data: $e')),
      );
    }
  }

  Future<void> _exportContributions() async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      final List<List<dynamic>> rows = [
        ['National ID', 'Name', 'KRA PIN', 'Housing Levy Amount'],
        ..._filteredEmployees.map((employee) {
          final numberFormat = NumberFormat('#,##0.00', 'en_US');
          return [
            employee['national_id'] ?? 'N/A',
            employee['fullname'] ?? 'N/A',
            employee['kra_pin'] ?? 'N/A',
            numberFormat.format(double.tryParse(
                    employee['housing_levy']?.toString() ?? '0.0') ??
                0.0),
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath =
          '${directory.path}/housing_levy_contributions_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Housing Levy Contributions exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export contributions: $e')),
      );
    }
  }

  Future<void> _exportSummary() async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      final totalHousingLevy = _filteredEmployees.fold<double>(
          0.0,
          (sum, employee) =>
              sum +
              (double.tryParse(employee['housing_levy']?.toString() ?? '0.0') ??
                  0.0));
      final totalGrossPay = _filteredEmployees.fold<double>(
          0.0,
          (sum, employee) =>
              sum +
              (double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ??
                  0.0));

      final List<List<dynamic>> rows = [
        ['Total Employees', 'Total Gross Pay', 'Total Housing Levy'],
        [
          _filteredEmployees.length,
          NumberFormat('#,##0.00', 'en_US').format(totalGrossPay),
          NumberFormat('#,##0.00', 'en_US').format(totalHousingLevy),
        ],
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath = '${directory.path}/housing_levy_summary_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Housing Levy Summary exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export summary: $e')),
      );
    }
  }

  Future<void> _exportToCSV() async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      final List<List<dynamic>> rows = [
        ['National ID', 'Name', 'KRA PIN', 'Gross Pay', 'Housing Levy Amount'],
        ..._filteredEmployees.map((employee) {
          final numberFormat = NumberFormat('#,##0.00', 'en_US');
          return [
            employee['national_id'] ?? 'N/A',
            employee['fullname'] ?? 'N/A',
            employee['kra_pin'] ?? 'N/A',
            numberFormat.format(
                double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ??
                    0.0),
            numberFormat.format(double.tryParse(
                    employee['housing_levy']?.toString() ?? '0.0') ??
                0.0),
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath = '${directory.path}/housing_levy_export_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Housing Levy data exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
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
        title: 'Housing Levy Export',
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
                                  _fetchHousingLevyData();
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
                                  _fetchHousingLevyData();
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
                                  _fetchHousingLevyData();
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
                              'No Housing Levy data available for selected filters',
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
                                          label: Text('National ID',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Name',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('KRA PIN',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Gross Pay',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Housing Levy',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                    ],
                                    rows: _filteredEmployees.map((employee) {
                                      final numberFormat =
                                          NumberFormat('#,##0.00', 'en_US');
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(
                                              employee['national_id'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['fullname'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['kra_pin'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['housing_levy']?.toString() ?? '0.0') ?? 0.0)}',
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
                            onPressed: _exportContributions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export Contributions'),
                          ),
                          ElevatedButton(
                            onPressed: _exportSummary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export Summary'),
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
