import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class P10Screen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;
  const P10Screen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  

  @override
  _P10ScreenState createState() => _P10ScreenState();
}

class _P10ScreenState extends State<P10Screen> {
  late final ApiService _apiService;
  List<Map<String, dynamic>> _p10Data = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;

  int? selectedCompanyId;
  int selectedYear = DateTime.now().year;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(
      client: http.Client(),
      user: User.fromMap(widget.user),
    );
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    try {
      final companies = await _apiService.getCompanies();
      final userCompanyId = widget.user['company_id'] as int?;
      final isAdmin = widget.user['role'] == 'admin';

      setState(() {
        _companies = companies;
        if (isAdmin) {
          companyIds = companies
              .map((c) => c['id'] as int?)
              .where((id) => id != null)
              .cast<int>()
              .toSet()
              .toList();
          companyIdToName = {
            for (var c in companies)
              if (c['id'] != null)
                c['id'] as int: c['company_name']?.toString() ?? 'Unknown'
          };
          companyIds.insert(0, 0); // 0 for 'All Companies'
          companyIdToName[0] = 'All Companies';
        } else if (userCompanyId != null) {
          final userCompany = companies.firstWhere(
            (c) => c['id'] == userCompanyId,
            orElse: () => {
              'id': userCompanyId,
              'company_name':
                  widget.user['company_name']?.toString() ?? 'Unknown'
            },
          );
          companyIds = [userCompanyId];
          companyIdToName = {
            userCompanyId: userCompany['company_name']?.toString() ?? 'Unknown'
          };
        }
        selectedCompanyId = companyIds.isNotEmpty ? companyIds[0] : null;
      });

      if (selectedCompanyId != null) {
        _fetchP10Data();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load companies: $e')),
      );
    }
  }

  Future<void> _fetchP10Data() async {
    if (selectedCompanyId == null) {
      setState(() {
        _p10Data = [];
        _employees = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> employees = [];
      List<Map<String, dynamic>> p10Data = [];

      if (selectedCompanyId == 0) {
        // Admins: Fetch all companies
        for (var companyId in companyIds.where((id) => id != 0)) {
          final companyEmployees = await _apiService.getEmployeeList(companyId);
          employees.addAll(companyEmployees);
          for (var employee in companyEmployees) {
            final p9Data = await _apiService.fetchP9Data(
              employeeId: employee['employee_id'].toString(),
              companyId: companyId,
              year: selectedYear,
            );
            if (p9Data.isNotEmpty) {
              p10Data.add(_aggregateP9Data(employee, p9Data));
            }
          }
        }
      } else {
        employees = await _apiService.getEmployeeList(selectedCompanyId!);
        for (var employee in employees) {
          final p9Data = await _apiService.fetchP9Data(
            employeeId: employee['employee_id'].toString(),
            companyId: selectedCompanyId!,
            year: selectedYear,
          );
          if (p9Data.isNotEmpty) {
            p10Data.add(_aggregateP9Data(employee, p9Data));
          }
        }
      }

      setState(() {
        _employees = employees;
        _p10Data = p10Data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load P10 data: $e')),
      );
    }
  }

  Map<String, dynamic> _aggregateP9Data(
      Map<String, dynamic> employee, List<Map<String, dynamic>> p9Data) {
    final numberFormat = NumberFormat('#,##0.00', 'en_US');
    return {
      'employee_id': employee['employee_id'].toString(),
      'fullname': employee['fullname']?.toString() ?? 'Unknown',
      'kra_pin': employee['kra_pin']?.toString() ?? 'N/A',
      'company_id': employee['company_id'] ?? selectedCompanyId,
      'company_name':
          companyIdToName[employee['company_id'] ?? selectedCompanyId] ??
              'Unknown',
      'basic_salary': p9Data.fold(0.0,
          (sum, item) => sum + (item['hasData'] ? item['basic_salary'] : 0.0)),
      'gross_pay': p9Data.fold(0.0,
          (sum, item) => sum + (item['hasData'] ? item['gross_pay'] : 0.0)),
      'taxable_income': p9Data.fold(
          0.0,
          (sum, item) =>
              sum + (item['hasData'] ? item['chargeable_pay'] : 0.0)),
      'paye_deduction': p9Data.fold(0.0,
          (sum, item) => sum + (item['hasData'] ? item['tax_charged'] : 0.0)),
      'paye_tax': p9Data.fold(
          0.0, (sum, item) => sum + (item['hasData'] ? item['paye_tax'] : 0.0)),
    };
  }

  Future<Uint8List> _generateP10Pdf() async {
    final pdf = pw.Document();
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    final company = _companies.firstWhere(
      (c) => c['id'] == selectedCompanyId,
      orElse: () => {
        'company_name': selectedCompanyId == 0
            ? 'Multiple Companies'
            : companyIdToName[selectedCompanyId] ?? 'N/A',
        'kra_pin': 'N/A'
      },
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'KENYA REVENUE AUTHORITY\nP10 - ANNUAL TAX DEDUCTION SUMMARY YEAR $selectedYear',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Employer\'s Name: ${company['company_name'] ?? 'N/A'}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Employer\'s P.I.N: ${company['kra_pin'] ?? 'N/A'}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 10),

              // Table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FixedColumnWidth(80), // Employee Name
                  1: pw.FixedColumnWidth(60), // PIN
                  2: pw.FixedColumnWidth(60), // Basic Salary
                  3: pw.FixedColumnWidth(60), // Gross Pay
                  4: pw.FixedColumnWidth(60), // Taxable Income
                  5: pw.FixedColumnWidth(60), // PAYE Deduction
                  6: pw.FixedColumnWidth(60), // PAYE Tax
                },
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Employee Name',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('KRA PIN',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Basic Salary\nKshs.',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Gross Pay\nKshs.',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Taxable Income\nKshs.',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('PAYE Deduction\nKshs.',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('PAYE Tax\nKshs.',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),

                  // Data Rows
                  ..._p10Data.map((data) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(data['fullname'],
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.left),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(data['kra_pin'],
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              numberFormat.format(data['basic_salary']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(numberFormat.format(data['gross_pay']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              numberFormat.format(data['taxable_income']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              numberFormat.format(data['paye_deduction']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(numberFormat.format(data['paye_tax']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                      ],
                    );
                  }).toList(),

                  // Totals Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('TOTALS',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child:
                            pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p10Data.fold(0.0,
                                (sum, item) => sum + item['basic_salary'])),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p10Data.fold(
                                0.0, (sum, item) => sum + item['gross_pay'])),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p10Data.fold(0.0,
                                (sum, item) => sum + item['taxable_income'])),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p10Data.fold(0.0,
                                (sum, item) => sum + item['paye_deduction'])),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p10Data.fold(
                                0.0, (sum, item) => sum + item['paye_tax'])),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                ],
              ),

              // Footer
              pw.SizedBox(height: 10),
              pw.Text(
                  'Total PAYE Tax: Kshs. ${numberFormat.format(_p10Data.fold(0.0, (sum, item) => sum + item['paye_tax']))}',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                  'Total Taxable Income: Kshs. ${numberFormat.format(_p10Data.fold(0.0, (sum, item) => sum + item['taxable_income']))}',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
              pw.Text('Submitted by Employer',
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _downloadP10() async {
    if (_p10Data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No P10 data available to download')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdfContent = await _generateP10Pdf();

      String baseDir = Platform.isWindows
          ? r'C:\p10_forms'
          : '${(await getApplicationDocumentsDirectory()).path}/p10_forms';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final companyName = selectedCompanyId == 0
          ? 'all_companies'
          : companyIdToName[selectedCompanyId]
                  ?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ??
              'unknown';
      final filename = 'p10_${companyName}_$selectedYear.pdf';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      await Printing.sharePdf(bytes: pdfContent, filename: filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('P10 Form saved as $filename to $baseDir'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save P10 form: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'P10 Forms',
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
        child: Padding(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isAdmin)
                        _buildDropdown(
                          value: selectedCompanyId,
                          items: companyIds,
                          itemBuilder: (id) => companyIdToName[id] ?? 'Unknown',
                          onChanged: (value) {
                            setState(() {
                              selectedCompanyId = value;
                              _fetchP10Data();
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
                            _fetchP10Data();
                          });
                        },
                      ),
                      ElevatedButton(
                        onPressed: _fetchP10Data,
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _downloadP10,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Download P10 Form'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Colors.teal[700],
                        ),
                      )
                    : _p10Data.isEmpty
                        ? Center(
                            child: Text(
                              'No data available for selected filters',
                              style: TextStyle(
                                color: Colors.teal[900],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                                child: DataTable(
                                  columnSpacing: 16,
                                  dataRowHeight: 60,
                                  headingRowColor:
                                      WidgetStateProperty.all(Colors.teal[100]),
                                  columns: [
                                    _buildDataColumn('Employee Name'),
                                    _buildDataColumn('KRA PIN'),
                                    _buildDataColumn('Basic Salary'),
                                    _buildDataColumn('Gross Pay'),
                                    _buildDataColumn('Taxable Income'),
                                    _buildDataColumn('PAYE Deduction'),
                                    _buildDataColumn('PAYE Tax'),
                                  ],
                                  rows: _p10Data.map((data) {
                                    final numberFormat =
                                        NumberFormat('#,##0.00', 'en_US');
                                    return DataRow(
                                      cells: [
                                        _buildDataCell(data['fullname']),
                                        _buildDataCell(data['kra_pin']),
                                        _buildDataCell(numberFormat
                                            .format(data['basic_salary'])),
                                        _buildDataCell(numberFormat
                                            .format(data['gross_pay'])),
                                        _buildDataCell(numberFormat
                                            .format(data['taxable_income'])),
                                        _buildDataCell(numberFormat
                                            .format(data['paye_deduction'])),
                                        _buildDataCell(numberFormat
                                            .format(data['paye_tax'])),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
              ),
            ],
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
          color: Colors.teal[900],
          fontSize: 14,
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Text(
        text,
        style: TextStyle(
          color: Colors.grey[800],
          fontSize: 12,
        ),
      ),
    );
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
}
