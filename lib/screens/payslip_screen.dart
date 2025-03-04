import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services.dart';

class PayslipScreen extends StatefulWidget {
  @override
  _PayslipScreenState createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final ApiService _apiService = ApiService(client: http.Client());
  List _salaries = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  String? selectedCompany;
  List<String> companyNames = ['All Companies'];
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    try {
      final employees = await _apiService.getAllEmployees();
      setState(() {
        companyNames = ['All Companies'] +
            employees
                .map((e) => e['company_name'] as String?)
                .where((name) => name != null && name.isNotEmpty)
                .toSet()
                .cast<String>()
                .toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
    }
  }

  Future<void> _fetchSalaries() async {
    setState(() => _isLoading = true);
    try {
      final salaries = await _apiService.getSalaries();
      final employees = await _apiService.getEmployeeList();
      _employees = employees;

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        if (paymentDate == null) return false;
        final matchesMonth = paymentDate.month == selectedMonth;
        final matchesYear = paymentDate.year == selectedYear;
        final matchesCompany = selectedCompany == null ||
            selectedCompany == 'All Companies' ||
            salary['company_name'] == selectedCompany;
        return matchesMonth && matchesYear && matchesCompany;
      }).toList();

      for (var salary in filteredSalaries) {
        final employeeId = salary['employee_id'].toString();
        final benefits = await _apiService.fetchBenefits(
            employeeId, selectedMonth, selectedYear);
        final deductions = await _apiService.fetchDeductions(
            employeeId, selectedMonth, selectedYear);
        salary['benefits'] = benefits;
        salary['deductions_list'] = deductions;

        final employee = employees.firstWhere(
          (e) => e['employee_id'].toString() == employeeId,
          orElse: () => {},
        );
        salary['kra_pin'] = employee['kra_pin'] ?? salary['kra_pin'];
        salary['position'] = employee['position'] ?? salary['position'];
        salary['house_allowance'] =
            employee['house_allowance'] ?? salary['house_allowance'];
      }

      setState(() {
        _salaries = filteredSalaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load salaries: $e')),
      );
    }
  }

  Future<Uint8List> _generatePdf(Map salary) async {
    final pdf = pw.Document();
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    salary['company_name'] ?? 'N/A',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Payslip',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.blue, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(3),
                        color: PdfColors.blue100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Employee Information',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue),
                          ),
                          pw.SizedBox(height: 5),
                          _buildPdfRow(
                              'Full Name', salary['fullname'] ?? 'N/A'),
                          _buildPdfRow(
                              'Company Name', salary['company_name'] ?? 'N/A'),
                          _buildPdfRow(
                              'Employee ID', salary['employee_id'] ?? 'N/A'),
                          _buildPdfRow('KRA Pin', salary['kra_pin'] ?? 'N/A'),
                          _buildPdfRow('Position', salary['position'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.blue, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(3),
                        color: PdfColors.blue100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Pay Information',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue),
                          ),
                          pw.SizedBox(height: 5),
                          _buildPdfRow(
                              'Pay Date', salary['payment_date'] ?? 'N/A'),
                          _buildPdfRow('Pay Type', 'Monthly'),
                          _buildPdfRow('Period',
                              _getMonthFromPaymentDate(salary['payment_date'])),
                          _buildPdfRow('Payroll #', salary['id'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Earnings',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Table(
                      border:
                          pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                      columnWidths: {
                        0: pw.FlexColumnWidth(3),
                        1: pw.FlexColumnWidth(2),
                        2: pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              pw.BoxDecoration(color: PdfColors.blue200),
                          children: [
                            pw.Text('Description',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('Current',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('YTD',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        ..._buildEarningsTableRows(salary, numberFormat),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Gross Pay',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                        pw.Text(
                          'KES ${numberFormat.format(double.tryParse(salary['gross_pay']?.toString() ?? '0.0') ?? 0.0)}',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Deductions',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Table(
                      border:
                          pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                      columnWidths: {
                        0: pw.FlexColumnWidth(3),
                        1: pw.FlexColumnWidth(2),
                        2: pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              pw.BoxDecoration(color: PdfColors.blue200),
                          children: [
                            pw.Text('Description',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('Current',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('YTD',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        ..._buildDeductionsTableRows(salary, numberFormat),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Taxable Income',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                        pw.Text(
                          'KES ${numberFormat.format(double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0)}',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Deductions',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                        pw.Text(
                          'KES ${numberFormat.format(_calculateTotalDeductions(salary) ?? 0.0)}',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                  color: PdfColors.blue100,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Net Pay',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green),
                    ),
                    pw.Text(
                      'KES ${numberFormat.format(double.tryParse(salary['net_pay']?.toString() ?? '0.0') ?? 0.0)}',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Signature: ____________________',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
                  ),
                  pw.Text(
                    'Date: ${DateTime.now().toIso8601String().split('T')[0]}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String _getMonthFromPaymentDate(String? paymentDate) {
    if (paymentDate == null || paymentDate.isEmpty) return 'N/A';
    final date = DateTime.tryParse(paymentDate);
    if (date == null) return 'N/A';
    return DateFormat('MMMM yyyy').format(date);
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  List<pw.TableRow> _buildEarningsTableRows(
      Map salary, NumberFormat numberFormat) {
    final staticEarnings = [
      {'description': 'Basic Pay', 'value': salary['basic_pay']},
      {'description': 'House Allowance', 'value': salary['house_allowance']},
      {'description': 'Other Earnings', 'value': salary['other_earnings']},
      {'description': 'Overtime Amount', 'value': salary['overtime_amount']},
      {'description': 'Bonus', 'value': salary['bonus']},
    ];

    final benefits = salary['benefits'] as List<dynamic>? ?? [];
    final benefitRows = benefits.map((benefit) => {
          'description': benefit['description'] ?? 'Unknown Benefit',
          'value': benefit['amount'],
        });

    final totalNonCashBenefits = benefits.fold<double>(
        0.0,
        (sum, benefit) =>
            sum +
            (double.tryParse(benefit['amount']?.toString() ?? '0.0') ?? 0.0));

    return [
      ...staticEarnings.where((earning) =>
          (double.tryParse(earning['value']?.toString() ?? '0.0') ?? 0.0) !=
          0.0),
      ...benefitRows,
      if (totalNonCashBenefits > 0)
        {
          'description': 'Total Non-Cash Benefits',
          'value': totalNonCashBenefits,
        },
    ]
        .map((earning) => _buildEarningsRow(
            earning['description']!, earning['value'], numberFormat))
        .toList();
  }

  pw.TableRow _buildEarningsRow(
      String description, dynamic value, NumberFormat numberFormat) {
    final formattedValue =
        numberFormat.format(double.tryParse(value?.toString() ?? '0.0') ?? 0.0);
    return pw.TableRow(
      children: [
        pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('KES $formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
        pw.Text('KES $formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
      ],
    );
  }

  List<pw.TableRow> _buildDeductionsTableRows(
      Map salary, NumberFormat numberFormat) {
    final deductions = [
      {'description': 'PAYE Tax', 'value': salary['paye_deduction']},
      {'description': 'SHIF Deduction', 'value': salary['nhif_deduction']},
      {'description': 'NSSF Deduction', 'value': salary['nssf_deduction']},
      {
        'description': 'Pension Contributions',
        'value': salary['pension_contributions']
      },
      {'description': 'Loan Repayment', 'value': salary['loan_repayment']},
      {'description': 'Housing Levy', 'value': salary['housing_levy']},
      {
        'description': 'Absenteeism Deduction',
        'value': salary['absenteeism_deduction']
      },
    ];

    final deductionList = salary['deductions_list'] as List<dynamic>? ?? [];
    final deductionRows = deductionList.map((deduction) => {
          'description': deduction['description'] ?? 'Unknown Deduction',
          'value': deduction['amount'],
        });

    return [
      ...deductions.where((deduction) =>
          (double.tryParse(deduction['value']?.toString() ?? '0.0') ?? 0.0) !=
          0.0),
      ...deductionRows,
    ]
        .map((deduction) => _buildDeductionsRow(
            deduction['description']!, deduction['value'], numberFormat))
        .toList();
  }

  pw.TableRow _buildDeductionsRow(
      String description, dynamic value, NumberFormat numberFormat) {
    final formattedValue =
        numberFormat.format(double.tryParse(value?.toString() ?? '0.0') ?? 0.0);
    return pw.TableRow(
      children: [
        pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('- KES $formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('- KES $formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
      ],
    );
  }

  double? _calculateTotalDeductions(Map salary) {
    double total = 0.0;
    final deductions = [
      'paye_deduction',
      'nhif_deduction',
      'nssf_deduction',
      'pension_contributions',
      'loan_repayment',
      'housing_levy',
      'absenteeism_deduction',
    ];

    for (final key in deductions) {
      final value = double.tryParse(salary[key]?.toString() ?? '0.0') ?? 0.0;
      total += value;
    }

    final deductionList = salary['deductions_list'] as List<dynamic>? ?? [];
    for (var deduction in deductionList) {
      total += double.tryParse(deduction['amount']?.toString() ?? '0.0') ?? 0.0;
    }

    return total > 0 ? total : null;
  }

  Future<void> _savePayslipToLocalDisk(Map salary, Uint8List pdfContent) async {
    try {
      // Define the directory path (C:\payslips on Windows)
      String baseDir = Platform.isWindows
          ? r'C:\payslips'
          : (await getApplicationDocumentsDirectory()).path + '/payslips';

      // Create the directory if it doesn't exist
      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Generate filename
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final fullName = (salary['fullname'] ?? 'Unknown')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final filename = 'payslip_${fullName}_$monthYear.pdf';
      final filePath = '$baseDir/$filename';

      // Write the PDF to the file
      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      // Optionally share the PDF (remove this if you only want to save)
      await Printing.sharePdf(bytes: pdfContent, filename: filename);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payslip: $e')),
      );
    }
  }

  Future<void> _printPayslip(Map salary) async {
    final pdfContent = await _generatePdf(salary);
    await _savePayslipToLocalDisk(salary, pdfContent);
  }

  Future<void> _downloadAllPayslips() async {
    if (_salaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payslips available to download')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      for (var salary in _salaries) {
        final pdfContent = await _generatePdf(salary);
        await _savePayslipToLocalDisk(salary, pdfContent);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${_salaries.length} payslips to C:\\payslips'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save all payslips: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslip'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<int>(
                  value: selectedMonth,
                  items: List.generate(12, (index) => index + 1)
                      .map((month) => DropdownMenuItem(
                            value: month,
                            child: Text(DateFormat('MMMM')
                                .format(DateTime(selectedYear, month))),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMonth = value!;
                      _fetchSalaries();
                    });
                  },
                ),
                DropdownButton<int>(
                  value: selectedYear,
                  items:
                      List.generate(10, (index) => DateTime.now().year - index)
                          .map((year) => DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              ))
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedYear = value!;
                      _fetchSalaries();
                    });
                  },
                ),
                DropdownButton<String>(
                  value: selectedCompany ?? 'All Companies',
                  items: companyNames
                      .map((company) => DropdownMenuItem(
                            value: company,
                            child: Text(company),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCompany = value;
                      _fetchSalaries();
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: _fetchSalaries,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _downloadAllPayslips,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Download All'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _salaries.isEmpty
                      ? const Center(
                          child: Text(
                              'No payslips available for selected filters'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Employee ID')),
                                DataColumn(label: Text('Full Name')),
                                DataColumn(label: Text('Company Name')),
                                DataColumn(label: Text('Gross Pay')),
                                DataColumn(label: Text('Basic Pay')),
                                DataColumn(label: Text('Non-Cash Benefits')),
                                DataColumn(label: Text('Other Earnings')),
                                DataColumn(label: Text('Overtime Amount')),
                                DataColumn(
                                    label: Text('Absenteeism Deduction')),
                                DataColumn(label: Text('Taxable Income')),
                                DataColumn(label: Text('SHIF Deduction')),
                                DataColumn(label: Text('PAYE Deduction')),
                                DataColumn(label: Text('NSSF Deduction')),
                                DataColumn(
                                    label: Text('Pension Contributions')),
                                DataColumn(label: Text('Loan Repayment')),
                                DataColumn(label: Text('Deductions')),
                                DataColumn(label: Text('Housing Levy')),
                                DataColumn(label: Text('Housing Levy Relief')),
                                DataColumn(label: Text('Net Pay')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Payment Date')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _salaries.map((salary) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(
                                        salary['id']?.toString() ?? 'N/A')),
                                    DataCell(Text(
                                        salary['employee_id']?.toString() ??
                                            'N/A')),
                                    DataCell(Text(salary['fullname'] ?? 'N/A')),
                                    DataCell(
                                        Text(salary['company_name'] ?? 'N/A')),
                                    DataCell(Text(
                                        'KES ${salary['gross_pay']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['basic_pay']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['non_cash_benefits']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['other_earnings']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['overtime_amount']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['absenteeism_deduction']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['taxable_income']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['nhif_deduction']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['paye_deduction']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['nssf_deduction']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['pension_contributions']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['loan_repayment']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['deductions']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['housing_levy']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['housing_levy_relief']?.toString() ?? '0.00'}')),
                                    DataCell(Text(
                                        'KES ${salary['net_pay']?.toString() ?? '0.00'}')),
                                    DataCell(Text(salary['status'] ?? 'N/A')),
                                    DataCell(
                                        Text(salary['payment_date'] ?? 'N/A')),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.download),
                                          onPressed: () async {
                                            final pdfContent =
                                                await _generatePdf(salary);
                                            await _savePayslipToLocalDisk(
                                                salary, pdfContent);
                                          },
                                          tooltip:
                                              'Download Payslip to C:\\payslips',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.print),
                                          onPressed: () =>
                                              _printPayslip(salary),
                                          tooltip: 'Print Payslip',
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
