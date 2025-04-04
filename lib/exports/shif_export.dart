import 'dart:io';

import 'package:csv/csv.dart'; // Add this package to pubspec.yaml
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class SHIFExport {
  final String title = 'SHIF Export';
  final IconData icon = Icons.medical_services;
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
    return _SHIFExportDetailsPage(apiService: _apiService);
  }
}

class _SHIFExportDetailsPage extends StatefulWidget {
  final ApiService apiService;

  const _SHIFExportDetailsPage({required this.apiService});

  @override
  _SHIFExportDetailsPageState createState() => _SHIFExportDetailsPageState();
}

class _SHIFExportDetailsPageState extends State<_SHIFExportDetailsPage> {
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
    _fetchSHIFData();
  }

  Future<void> _fetchSHIFData() async {
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
        final hasSHIF =
            (double.tryParse(salary['nhif_deduction']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && matchesCompany && hasSHIF;
      }).toList();

      final shifEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        return shifEmployeeIds.contains(employee['employee_id'].toString());
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        final nameParts = _splitFullName(employee['fullname']);
        return {
          'employee_id': employee['employee_id'] ?? 'N/A',
          'first_name': nameParts['firstName'] ?? 'N/A',
          'last_name': nameParts['lastName'] ?? 'N/A',
          'national_id': employee['national_id'] ?? 'N/A',
          'nhif_number': employee['nhif'] ?? 'N/A',
          'amount': salary['nhif_deduction'] ?? '0.0',
          'phone_number': employee['tel'] ?? 'N/A',
          'company_name': employee['company_name'] ?? 'N/A',
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
        SnackBar(content: Text('Failed to load SHIF data: $e')),
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
        ['Employee ID', 'NHIF Number', 'Amount'],
        ..._filteredEmployees.map((employee) {
          final numberFormat = NumberFormat('#,##0.00', 'en_US');
          return [
            employee['employee_id'] ?? 'N/A',
            employee['nhif_number'] ?? 'N/A',
            numberFormat.format(
                double.tryParse(employee['amount']?.toString() ?? '0.0') ??
                    0.0),
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath = '${directory.path}/shif_contributions_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SHIF Contributions exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export contributions: $e')),
      );
    }
  }

  Future<void> _exportDetailedReport() async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      final List<List<dynamic>> rows = [
        [
          'Employee ID',
          'First Name',
          'Last Name',
          'National ID',
          'NHIF Number',
          'Amount',
          'Phone Number',
          'Company Name'
        ],
        ..._filteredEmployees.map((employee) {
          final numberFormat = NumberFormat('#,##0.00', 'en_US');
          return [
            employee['employee_id'] ?? 'N/A',
            employee['first_name'] ?? 'N/A',
            employee['last_name'] ?? 'N/A',
            employee['national_id'] ?? 'N/A',
            employee['nhif_number'] ?? 'N/A',
            numberFormat.format(
                double.tryParse(employee['amount']?.toString() ?? '0.0') ??
                    0.0),
            employee['phone_number'] ?? 'N/A',
            employee['company_name'] ?? 'N/A',
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath = '${directory.path}/shif_detailed_report_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SHIF Detailed Report exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export detailed report: $e')),
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
        [
          'Employee ID',
          'First Name',
          'Last Name',
          'National ID',
          'NHIF Number',
          'Amount',
          'Phone Number'
        ],
        ..._filteredEmployees.map((employee) {
          final numberFormat = NumberFormat('#,##0.00', 'en_US');
          return [
            employee['employee_id'] ?? 'N/A',
            employee['first_name'] ?? 'N/A',
            employee['last_name'] ?? 'N/A',
            employee['national_id'] ?? 'N/A',
            employee['nhif_number'] ?? 'N/A',
            numberFormat.format(
                double.tryParse(employee['amount']?.toString() ?? '0.0') ??
                    0.0),
            employee['phone_number'] ?? 'N/A',
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filePath = '${directory.path}/shif_export_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SHIF data exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    }
  }

  Map<String, String> _splitFullName(String? fullName) {
    final nameParts = (fullName ?? 'N/A').trim().split(' ');
    if (nameParts.isEmpty) {
      return {'firstName': 'N/A', 'lastName': 'N/A'};
    }
    if (nameParts.length == 1) {
      return {'firstName': nameParts[0], 'lastName': ''};
    }
    return {
      'firstName': nameParts[0],
      'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    };
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
        title: 'SHIF Export',
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
                                  _fetchSHIFData();
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
                                  _fetchSHIFData();
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
                                  _fetchSHIFData();
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
                              'No SHIF data available for selected filters',
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
                                          label: Text('Employee ID',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('First Name',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Last Name',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('National ID',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('NHIF Number',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Amount',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.teal))),
                                      DataColumn(
                                          label: Text('Phone Number',
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
                                              employee['employee_id'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['first_name'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['last_name'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['national_id'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['nhif_number'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['amount']?.toString() ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['phone_number'] ?? 'N/A',
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
                            onPressed: _exportDetailedReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export Detailed Report'),
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
