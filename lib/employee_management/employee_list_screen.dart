import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final http.Client _httpClient = http.Client();
  final ApiService apiService = ApiService(client: http.Client());

  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> filteredEmployees = [];
  bool isLoading = true;
  String? selectedCompany;
  List<String> companyNames = ['All Companies'];

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  void fetchEmployees() async {
    try {
      final data = await apiService.getEmployeeList();
      setState(() {
        employees = data;
        filteredEmployees = data;
        companyNames = ['All Companies'] +
            data
                .map((e) => e['company_name'] as String?)
                .where((name) => name != null && name.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load employees: $e')),
      );
    }
  }

  void filterEmployees(String? company) {
    setState(() {
      selectedCompany = company;
      if (company == null || company == 'All Companies') {
        filteredEmployees = employees;
      } else {
        filteredEmployees =
            employees.where((e) => e['company_name'] == company).toList();
      }
    });
  }

  Future<void> _exportToCSV() async {
    if (filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      // Prepare CSV data
      final List<List<dynamic>> rows = [
        [
          'Employee ID',
          'Full Name',
          'Company Name',
          'National ID',
          'KRA PIN',
          'Position',
          'NSSF',
          'NHIF',
          'Tel',
          'Basic Salary',
          'House Allowance',
          'Gross Pay',
          'Bank Name',
          'Account Number',
        ],
        ...filteredEmployees.map((employee) => [
              employee['employee_id'] ?? '',
              employee['fullname'] ?? '',
              employee['company_name'] ?? '',
              employee['national_id'] ?? '',
              employee['kra_pin'] ?? '',
              employee['position'] ?? '',
              employee['nssf'] ?? '',
              employee['nhif'] ?? '',
              employee['tel'] ?? '',
              employee['basic'] ?? '',
              employee['house_allowance'] ?? '',
              employee['gross_pay'] ?? '',
              employee['bank_name'] ?? '',
              employee['account_number'] ?? '',
            ]),
      ];

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/employee_list_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee list exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    }
  }

  Future<void> _exportToPDF() async {
    if (filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      const columns = [
        'Employee ID',
        'Full Name',
        'Company Name',
        'National ID',
        'KRA PIN',
        'Position',
        'NSSF',
        'NHIF',
        'Tel',
        'Basic Salary',
        'House Allowance',
        'Gross Pay',
        'Bank Name',
        'Account Number',
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, // Changed to landscape
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Employee List',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold), // Font size 8
              ),
            ),
            pw.SizedBox(height: 10), // Reduced spacing
            pw.Table.fromTextArray(
              headers: columns,
              data: filteredEmployees
                  .map((employee) => [
                        employee['employee_id'] ?? '',
                        employee['fullname'] ?? '',
                        employee['company_name'] ?? '',
                        employee['national_id'] ?? '',
                        employee['kra_pin'] ?? '',
                        employee['position'] ?? '',
                        employee['nssf'] ?? '',
                        employee['nhif'] ?? '',
                        employee['tel'] ?? '',
                        employee['basic'] ?? '',
                        employee['house_allowance'] ?? '',
                        employee['gross_pay'] ?? '',
                        employee['bank_name'] ?? '',
                        employee['account_number'] ?? '',
                      ])
                  .toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold), // Font size 8
              cellStyle: const pw.TextStyle(fontSize: 8), // Font size 8
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(2), // Reduced padding
            ),
          ],
        ),
      );

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/employee_list_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee list exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to PDF: $e')),
      );
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
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
        title: 'Employee Management',
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
                    child: _buildDropdown(
                      value: selectedCompany ?? 'All Companies',
                      items: companyNames,
                      itemBuilder: (company) => company,
                      onChanged: (value) => filterEmployees(value),
                    ),
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                child: isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]))
                    : filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              'No employees available',
                              style: TextStyle(
                                  color: Colors.teal[900], fontSize: 16),
                            ),
                          )
                        : Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              width: MediaQuery.of(context).size.width -
                                  32, // Full width minus padding
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
                                    columnSpacing: 16.0,
                                    dataRowHeight: 60,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.teal[100]),
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'Employee ID',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Full Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Company Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'National ID',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'KRA PIN',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Position',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'NSSF',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'NHIF',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Tel',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Basic Salary',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'House Allowance',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Gross Pay',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Bank Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Account Number',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal),
                                        ),
                                      ),
                                    ],
                                    rows: filteredEmployees.map((employee) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(
                                              employee['employee_id'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['fullname'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['company_name'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['national_id'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['kra_pin'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['position'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(employee['nssf'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(employee['nhif'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(employee['tel'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(employee['basic'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['house_allowance'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['gross_pay'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['bank_name'] ?? '',
                                              style: TextStyle(
                                                  color: Colors.grey[800]))),
                                          DataCell(Text(
                                              employee['account_number'] ?? '',
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
                child: isLoading
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
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
                          ElevatedButton(
                            onPressed: _exportToPDF,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Export to PDF'),
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
