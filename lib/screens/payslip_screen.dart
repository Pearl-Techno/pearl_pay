import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

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

        final numericalKeys = [
          'gross_pay',
          'basic_pay',
          'non_cash_benefits',
          'other_earnings',
          'overtime_amount',
          'bonus',
          'taxable_income',
          'paye_deduction',
          'nhif_deduction',
          'nssf_deduction',
          'pension_contributions',
          'loan_repayment',
          'housing_levy',
          'housing_levy_relief',
          'absenteeism_deduction',
          'net_pay',
          'deductions',
        ];

        for (var key in numericalKeys) {
          if (salary[key] != null) {
            final value = double.tryParse(salary[key].toString()) ?? 0.0;
            salary[key] = value.round().toDouble();
          }
        }

        for (var benefit in salary['benefits'] ?? []) {
          final amount =
              double.tryParse(benefit['amount']?.toString() ?? '0.0') ?? 0.0;
          benefit['amount'] = amount.round().toDouble();
        }
        for (var deduction in salary['deductions_list'] ?? []) {
          final amount =
              double.tryParse(deduction['amount']?.toString() ?? '0.0') ?? 0.0;
          deduction['amount'] = amount.round().toDouble();
        }
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

    pw.Widget buildPayslipContent() {
      return pw.Container(
        width: PdfPageFormat.a4.width / 2 - 48, // Adjusted width for spacing
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              salary['company_name'] ?? 'N/A',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 1), // Minimal spacing
            pw.Text(
              'Payslip',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 28), // 1 cm spacing between sections
            pw.Container(
              padding: const pw.EdgeInsets.all(1), // Reduced padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Employee Info',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 1), // Reduced spacing
                  _buildPdfRow('Full Name', salary['fullname'] ?? 'N/A'),
                  _buildPdfRow('Company', salary['company_name'] ?? 'N/A'),
                  _buildPdfRow('Emp ID', salary['employee_id'] ?? 'N/A'),
                  _buildPdfRow('KRA Pin', salary['kra_pin'] ?? 'N/A'),
                  _buildPdfRow('Position', salary['position'] ?? 'N/A'),
                ],
              ),
            ),
            pw.SizedBox(height: 28), // 1 cm spacing between sections
            pw.Container(
              padding: const pw.EdgeInsets.all(1), // Reduced padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Pay Info',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 1), // Reduced spacing
                  _buildPdfRow('Pay Date', salary['payment_date'] ?? 'N/A'),
                  _buildPdfRow('Pay Type', 'Monthly'),
                  _buildPdfRow('Period',
                      _getMonthFromPaymentDate(salary['payment_date'])),
                  _buildPdfRow('Payroll #', salary['id'] ?? 'N/A'),
                ],
              ),
            ),
            pw.SizedBox(height: 28), // 1 cm spacing between sections
            pw.Container(
              padding: const pw.EdgeInsets.all(1), // Reduced padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
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
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 1), // Reduced spacing
                  pw.Table(
                    border: null, // Remove table borders
                    columnWidths: {
                      0: pw.FlexColumnWidth(1.5), // Reduced width
                      1: pw.FlexColumnWidth(1), // Reduced width
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Text('Description',
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Current',
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right),
                        ],
                      ),
                      ..._buildEarningsTableRows(salary, numberFormat),
                    ],
                  ),
                  pw.SizedBox(height: 1), // Reduced spacing
                  _buildSummaryRow('Gross Pay',
                      'KES ${numberFormat.format(double.tryParse(salary['gross_pay']?.toString() ?? '0.0') ?? 0.0)}',
                      color: PdfColors.black),
                ],
              ),
            ),
            pw.SizedBox(height: 28), // 1 cm spacing between sections
            pw.Container(
              padding: const pw.EdgeInsets.all(1), // Reduced padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
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
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 1), // Reduced spacing
                  pw.Table(
                    border: null, // Remove table borders
                    columnWidths: {
                      0: pw.FlexColumnWidth(1.5), // Reduced width
                      1: pw.FlexColumnWidth(1), // Reduced width
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Text('Description',
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Current',
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right),
                        ],
                      ),
                      ..._buildDeductionsTableRows(salary, numberFormat),
                    ],
                  ),
                  pw.SizedBox(height: 1), // Reduced spacing
                  _buildSummaryRow('Taxable Income',
                      'KES ${numberFormat.format(double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0)}',
                      color: PdfColors.black),
                  pw.SizedBox(height: 1), // Reduced spacing
                  _buildSummaryRow('Total Deductions',
                      'KES ${numberFormat.format(_calculateTotalDeductions(salary) ?? 0.0)}',
                      color: PdfColors.red800),
                ],
              ),
            ),
            pw.SizedBox(height: 28), // 1 cm spacing between sections
            pw.Container(
              padding: const pw.EdgeInsets.all(1), // Reduced padding
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
                color: PdfColors.grey100,
              ),
              child: _buildSummaryRow('Net Pay',
                  'KES ${numberFormat.format(double.tryParse(salary['net_pay']?.toString() ?? '0.0') ?? 0.0)}',
                  color: PdfColors.green800),
            ),
            pw.SizedBox(height: 28), // 1 cm spacing between sections
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sign: ________________',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
                ),
                pw.Text(
                  'Date: ${DateTime.now().toIso8601String().split('T')[0]}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
                ),
              ],
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPayslipContent(), // Left payslip (original)
              pw.SizedBox(width: 14), // 0.5 cm (14 points) spacing
              pw.Container(
                height: PdfPageFormat.a4.height,
                child: pw.Container(
                  width: 0.5,
                  height: PdfPageFormat.a4.height,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      (PdfPageFormat.a4.height / 8).floor(),
                      (index) => pw.Container(
                        height: 4,
                        color: index % 2 == 0 ? PdfColors.grey800 : PdfColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 14), // 0.5 cm (14 points) spacing
              buildPayslipContent(), // Right payslip (duplicate)
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
        pw.SizedBox(width: 5),
        pw.Text(value,
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.right),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String label, String value,
      {required PdfColor color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }

  List<pw.TableRow> _buildEarningsTableRows(
      Map salary, NumberFormat numberFormat) {
    final staticEarnings = [
      {'description': 'Basic Pay', 'value': salary['basic_pay']},
      {'description': 'House Allow.', 'value': salary['house_allowance']},
      {'description': 'Other Earn.', 'value': salary['other_earnings']},
      {'description': 'Overtime', 'value': salary['overtime_amount']},
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

    final allRows = [
      ...staticEarnings.where((earning) =>
          (double.tryParse(earning['value']?.toString() ?? '0.0') ?? 0.0) !=
          0.0),
      ...benefitRows,
      if (totalNonCashBenefits > 0)
        {
          'description': 'Non-Cash Benefits',
          'value': totalNonCashBenefits,
        },
    ];

    return allRows.asMap().entries.map((entry) {
      final index = entry.key;
      final earning = entry.value;
      return _buildEarningsRow(
          earning['description']!, earning['value'], numberFormat, index);
    }).toList();
  }

  pw.TableRow _buildEarningsRow(
      String description, dynamic value, NumberFormat numberFormat, int index) {
    final formattedValue =
        numberFormat.format(double.tryParse(value?.toString() ?? '0.0') ?? 0.0);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
      ),
      children: [
        pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('KES $formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
            textAlign: pw.TextAlign.right),
      ],
    );
  }

  List<pw.TableRow> _buildDeductionsTableRows(
      Map salary, NumberFormat numberFormat) {
    final deductions = [
      {'description': 'PAYE Tax', 'value': salary['paye_deduction']},
      {'description': 'SHIF Ded.', 'value': salary['nhif_deduction']},
      {'description': 'NSSF Ded.', 'value': salary['nssf_deduction']},
      {'description': 'Pension', 'value': salary['pension_contributions']},
      {'description': 'Loan Repay', 'value': salary['loan_repayment']},
      {'description': 'Housing Levy', 'value': salary['housing_levy']},
      {'description': 'Absenteeism', 'value': salary['absenteeism_deduction']},
    ];

    final deductionList = salary['deductions_list'] as List<dynamic>? ?? [];
    final deductionRows = deductionList.map((deduction) => {
          'description': deduction['description'] ?? 'Unknown Deduction',
          'value': deduction['amount'],
        });

    final allRows = [
      ...deductions.where((deduction) =>
          (double.tryParse(deduction['value']?.toString() ?? '0.0') ?? 0.0) !=
          0.0),
      ...deductionRows,
    ];

    return allRows.asMap().entries.map((entry) {
      final index = entry.key;
      final deduction = entry.value;
      return _buildDeductionsRow(
          deduction['description']!, deduction['value'], numberFormat, index);
    }).toList();
  }

  pw.TableRow _buildDeductionsRow(
      String description, dynamic value, NumberFormat numberFormat, int index) {
    final formattedValue =
        numberFormat.format(double.tryParse(value?.toString() ?? '0.0') ?? 0.0);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
      ),
      children: [
        pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('- KES $formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red800),
            textAlign: pw.TextAlign.right),
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

    return total > 0 ? total.round().toDouble() : null;
  }

  Future<void> _savePayslipToLocalDisk(Map salary, Uint8List pdfContent) async {
    try {
      String baseDir = Platform.isWindows
          ? r'C:\payslips'
          : '${(await getApplicationDocumentsDirectory()).path}/payslips';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final fullName = (salary['fullname'] ?? 'Unknown')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final filename = 'payslip_${fullName}_$monthYear.pdf';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

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
      final pdf = pw.Document();
      final numberFormat = NumberFormat('#,##0.00', 'en_US');

      pw.Widget buildPayslipContent(Map salary) {
        return pw.Container(
          width: PdfPageFormat.a4.width / 2 - 48, // Adjusted width for spacing
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                salary['company_name'] ?? 'N/A',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 1), // Minimal spacing
              pw.Text(
                'Payslip',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 28), // 1 cm spacing between sections
              pw.Container(
                padding: const pw.EdgeInsets.all(1), // Reduced padding
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Employee Info',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 1), // Reduced spacing
                    _buildPdfRow('Full Name', salary['fullname'] ?? 'N/A'),
                    _buildPdfRow('Company', salary['company_name'] ?? 'N/A'),
                    _buildPdfRow('Emp ID', salary['employee_id'] ?? 'N/A'),
                    _buildPdfRow('KRA Pin', salary['kra_pin'] ?? 'N/A'),
                    _buildPdfRow('Position', salary['position'] ?? 'N/A'),
                  ],
                ),
              ),
              pw.SizedBox(height: 28), // 1 cm spacing between sections
              pw.Container(
                padding: const pw.EdgeInsets.all(1), // Reduced padding
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Pay Info',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 1), // Reduced spacing
                    _buildPdfRow('Pay Date', salary['payment_date'] ?? 'N/A'),
                    _buildPdfRow('Pay Type', 'Monthly'),
                    _buildPdfRow('Period',
                        _getMonthFromPaymentDate(salary['payment_date'])),
                    _buildPdfRow('Payroll #', salary['id'] ?? 'N/A'),
                  ],
                ),
              ),
              pw.SizedBox(height: 28), // 1 cm spacing between sections
              pw.Container(
                padding: const pw.EdgeInsets.all(1), // Reduced padding
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2),
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
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 1), // Reduced spacing
                    pw.Table(
                      border: null, // Remove table borders
                      columnWidths: {
                        0: pw.FlexColumnWidth(1.5), // Reduced width
                        1: pw.FlexColumnWidth(1), // Reduced width
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Text('Description',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('Current',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right),
                          ],
                        ),
                        ..._buildEarningsTableRows(salary, numberFormat),
                      ],
                    ),
                    pw.SizedBox(height: 1), // Reduced spacing
                    _buildSummaryRow('Gross Pay',
                        'KES ${numberFormat.format(double.tryParse(salary['gross_pay']?.toString() ?? '0.0') ?? 0.0)}',
                        color: PdfColors.black),
                  ],
                ),
              ),
              pw.SizedBox(height: 28), // 1 cm spacing between sections
              pw.Container(
                padding: const pw.EdgeInsets.all(1), // Reduced padding
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2),
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
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 1), // Reduced spacing
                    pw.Table(
                      border: null, // Remove table borders
                      columnWidths: {
                        0: pw.FlexColumnWidth(1.5), // Reduced width
                        1: pw.FlexColumnWidth(1), // Reduced width
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Text('Description',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('Current',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right),
                          ],
                        ),
                        ..._buildDeductionsTableRows(salary, numberFormat),
                      ],
                    ),
                    pw.SizedBox(height: 1), // Reduced spacing
                    _buildSummaryRow('Taxable Income',
                        'KES ${numberFormat.format(double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0)}',
                        color: PdfColors.black),
                    pw.SizedBox(height: 1), // Reduced spacing
                    _buildSummaryRow('Total Deductions',
                        'KES ${numberFormat.format(_calculateTotalDeductions(salary) ?? 0.0)}',
                        color: PdfColors.red800),
                  ],
                ),
              ),
              pw.SizedBox(height: 28), // 1 cm spacing between sections
              pw.Container(
                padding: const pw.EdgeInsets.all(1), // Reduced padding
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2),
                  color: PdfColors.grey100,
                ),
                child: _buildSummaryRow('Net Pay',
                    'KES ${numberFormat.format(double.tryParse(salary['net_pay']?.toString() ?? '0.0') ?? 0.0)}',
                    color: PdfColors.green800),
              ),
              pw.SizedBox(height: 28), // 1 cm spacing between sections
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Sign: ________________',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
                  ),
                  pw.Text(
                    'Date: ${DateTime.now().toIso8601String().split('T')[0]}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      for (var salary in _salaries) {
        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildPayslipContent(salary), // Left payslip (original)
                  pw.SizedBox(width: 14), // 0.5 cm (14 points) spacing
                  pw.Container(
                    height: PdfPageFormat.a4.height,
                    child: pw.Container(
                      width: 0.5,
                      height: PdfPageFormat.a4.height,
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          (PdfPageFormat.a4.height / 8).floor(),
                          (index) => pw.Container(
                            height: 4,
                            color: index % 2 == 0 ? PdfColors.grey800 : PdfColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14), // 0.5 cm (14 points) spacing
                  buildPayslipContent(salary), // Right payslip (duplicate)
                ],
              );
            },
          ),
        );
      }

      final pdfContent = await pdf.save();

      String baseDir = Platform.isWindows
          ? r'C:\payslips'
          : '${(await getApplicationDocumentsDirectory()).path}/payslips';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filename = 'payslips_$monthYear.pdf';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      await Printing.sharePdf(bytes: pdfContent, filename: filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Saved ${_salaries.length} payslips as $filename to $baseDir'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save merged payslips: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Payslips',
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
                      _buildDropdown(
                        value: selectedMonth,
                        items: List.generate(12, (index) => index + 1),
                        itemBuilder: (month) => DateFormat('MMMM')
                            .format(DateTime(selectedYear, month)),
                        onChanged: (value) {
                          setState(() {
                            selectedMonth = value!;
                            _fetchSalaries();
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
                            _fetchSalaries();
                          });
                        },
                      ),
                      _buildDropdown(
                        value: selectedCompany ?? 'All Companies',
                        items: companyNames,
                        itemBuilder: (company) => company,
                        onChanged: (value) {
                          setState(() {
                            selectedCompany = value;
                            _fetchSalaries();
                          });
                        },
                      ),
                      ElevatedButton(
                        onPressed: _fetchSalaries,
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
                onPressed: _isLoading ? null : _downloadAllPayslips,
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
                    : const Text('Download All Payslips'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Colors.teal[700],
                        ),
                      )
                    : _salaries.isEmpty
                        ? Center(
                            child: Text(
                              'No payslips available for selected filters',
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
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    dataRowHeight: 60,
                                    headingRowColor: WidgetStateProperty.all(
                                        Colors.teal[100]),
                                    columns: [
                                      _buildDataColumn('ID'),
                                      _buildDataColumn('Employee ID'),
                                      _buildDataColumn('Full Name'),
                                      _buildDataColumn('Company'),
                                      _buildDataColumn('Gross Pay'),
                                      _buildDataColumn('Basic Pay'),
                                      _buildDataColumn('Non-Cash Benefits'),
                                      _buildDataColumn('Other Earnings'),
                                      _buildDataColumn('Overtime'),
                                      _buildDataColumn('Absenteeism'),
                                      _buildDataColumn('Taxable Income'),
                                      _buildDataColumn('SHIF'),
                                      _buildDataColumn('PAYE'),
                                      _buildDataColumn('NSSF'),
                                      _buildDataColumn('Pension'),
                                      _buildDataColumn('Loan'),
                                      _buildDataColumn('Deductions'),
                                      _buildDataColumn('Housing Levy'),
                                      _buildDataColumn('Levy Relief'),
                                      _buildDataColumn('Net Pay'),
                                      _buildDataColumn('Status'),
                                      _buildDataColumn('Pay Date'),
                                      _buildDataColumn('Actions'),
                                    ],
                                    rows: _salaries.map((salary) {
                                      return DataRow(
                                        cells: [
                                          _buildDataCell(
                                              salary['id']?.toString() ??
                                                  'N/A'),
                                          _buildDataCell(salary['employee_id']
                                                  ?.toString() ??
                                              'N/A'),
                                          _buildDataCell(
                                              salary['fullname'] ?? 'N/A'),
                                          _buildDataCell(
                                              salary['company_name'] ?? 'N/A'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['gross_pay']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['basic_pay']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['non_cash_benefits']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['other_earnings']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['overtime_amount']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['absenteeism_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['nhif_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['nssf_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['pension_contributions']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['loan_repayment']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['deductions']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['housing_levy_relief']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['net_pay']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              salary['status'] ?? 'N/A'),
                                          _buildDataCell(
                                              salary['payment_date'] ?? 'N/A'),
                                          DataCell(Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.download,
                                                    color: Colors.teal[700]),
                                                onPressed: () async {
                                                  final pdfContent =
                                                      await _generatePdf(
                                                          salary);
                                                  await _savePayslipToLocalDisk(
                                                      salary, pdfContent);
                                                },
                                                tooltip: 'Download Payslip',
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.print,
                                                    color: Colors.teal[700]),
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
}
