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

class P9Screen extends StatefulWidget {
  @override
  _P9ScreenState createState() => _P9ScreenState();
}

class _P9ScreenState extends State<P9Screen> {
  final ApiService _apiService = ApiService(client: http.Client());
  List _salaries = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _p9Data = [];
  bool _isLoading = true;

  String? selectedCompany;
  String? selectedEmployeeId;
  int selectedYear = DateTime.now().year;
  List<String> companyNames = ['Select Company'];
  List<String> employeeNames = ['Select Employee'];

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    try {
      final employees = await _apiService.getAllEmployees();
      setState(() {
        _employees = employees;
        companyNames = ['Select Company'] +
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

  void _updateEmployeeList() {
    if (selectedCompany == null || selectedCompany == 'Select Company') {
      setState(() {
        _filteredEmployees = [];
        employeeNames = ['Select Employee'];
        selectedEmployeeId = null;
      });
      return;
    }

    final filtered =
        _employees.where((e) => e['company_name'] == selectedCompany).toList();
    setState(() {
      _filteredEmployees = filtered;
      employeeNames = ['Select Employee'] +
          filtered.map((e) => e['fullname'] as String? ?? 'Unknown').toList();
      selectedEmployeeId = null;
    });
  }

  Future<void> _fetchP9Data() async {
    if (selectedCompany == null ||
        selectedCompany == 'Select Company' ||
        selectedEmployeeId == null ||
        selectedEmployeeId == 'Select Employee') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a company and employee')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final salaries = await _apiService.getSalaries();
      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        if (paymentDate == null) return false;
        final matchesYear = paymentDate.year == selectedYear;
        final matchesCompany = salary['company_name'] == selectedCompany;
        final matchesEmployee =
            salary['employee_id'].toString() == selectedEmployeeId;
        return matchesYear && matchesCompany && matchesEmployee;
      }).toList();

      for (var salary in filteredSalaries) {
        final employeeId = salary['employee_id'].toString();
        final benefits =
            await _apiService.fetchBenefits(employeeId, 1, selectedYear);
        final deductions =
            await _apiService.fetchDeductions(employeeId, 1, selectedYear);
        salary['benefits'] = benefits;
        salary['deductions_list'] = deductions;

        final employee = _employees.firstWhere(
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

      // Prepare P9 data
      List<Map<String, dynamic>> p9Data = [];
      for (int month = 1; month <= 12; month++) {
        final salaryForMonth = filteredSalaries.firstWhere(
          (salary) =>
              DateTime.tryParse(salary['payment_date'] ?? '')?.month == month,
          orElse: () => {},
        );

        // Check if there is data for this month
        final hasData = salaryForMonth.isNotEmpty;

        final basicSalary =
            hasData ? (salaryForMonth['basic_pay']?.toDouble() ?? 0.0) : 0.0;
        final e1 = hasData ? (basicSalary * 0.3) : 0.0; // 30% of basic salary
        final e2 = hasData
            ? (salaryForMonth['pension_contributions']?.toDouble() ?? 0.0)
            : 0.0;
        const e3 = 20000.00; // Fixed value as in the image
        const ownerOccupiedInterest = 200.00; // Fixed value as in the image
        final g = hasData
            ? ([e1, e2, e3].reduce((a, b) => a < b ? a : b) +
                ownerOccupiedInterest)
            : 0.0;

        p9Data.add({
          'month': DateFormat('MMMM').format(DateTime(selectedYear, month)),
          'hasData': hasData,
          'basic_salary': basicSalary,
          'benefits': hasData
              ? (salaryForMonth['non_cash_benefits']?.toDouble() ?? 0.0)
              : 0.0,
          'quarters': 0.0, // Not available in payslip data
          'gross_pay':
              hasData ? (salaryForMonth['gross_pay']?.toDouble() ?? 0.0) : 0.0,
          'e1': e1,
          'e2': e2,
          'e3': hasData ? e3 : 0.0,
          'owner_interest': hasData ? ownerOccupiedInterest : 0.0,
          'retirement_added': g,
          'chargeable_pay': hasData
              ? (salaryForMonth['taxable_income']?.toDouble() ?? 0.0)
              : 0.0,
          'tax_charged': hasData
              ? (salaryForMonth['paye_deduction']?.toDouble() ?? 0.0)
              : 0.0,
          'personal_relief':
              hasData ? 2400.00 : 0.0, // Fixed value as in the image
          'insurance_relief':
              hasData ? 142.50 : 0.0, // Fixed value as in the image
          'paye_tax': hasData
              ? ((salaryForMonth['paye_deduction']?.toDouble() ?? 0.0) -
                  2400.00 -
                  142.50)
              : 0.0,
        });
      }

      setState(() {
        _salaries = filteredSalaries;
        _p9Data = p9Data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load P9 data: $e')),
      );
    }
  }

  Future<Uint8List> _generateP9Pdf() async {
    final pdf = pw.Document();
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    final employee = _employees.firstWhere(
      (e) => e['employee_id'].toString() == selectedEmployeeId,
      orElse: () => {},
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, // Ensure landscape orientation
        margin: const pw.EdgeInsets.all(20), // Add margins to reduce congestion
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'KENYA REVENUE AUTHORITY\nINCOME TAX DEDUCTION CARD YEAR $selectedYear',
                  style:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'Employer\'s Name: ${employee['company_name'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          'Employee\'s Main Name: ${employee['fullname']?.split(' ').first ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          'Employee\'s Other Names: ${employee['fullname']?.split(' ').skip(1).join(' ') ?? ''}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employer\'s P.I.N: N/A',
                          style: const pw.TextStyle(
                              fontSize: 8)), // Not available in payslip data
                      pw.Text(
                          'Employee\'s P.I.N: ${employee['kra_pin'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FixedColumnWidth(70), // MONTH
                  1: pw.FixedColumnWidth(60), // A
                  2: pw.FixedColumnWidth(60), // B
                  3: pw.FixedColumnWidth(60), // C
                  4: pw.FixedColumnWidth(60), // D
                  5: pw.FixedColumnWidth(80), // E1, E2, E3
                  6: pw.FixedColumnWidth(60), // F
                  7: pw.FixedColumnWidth(80), // G
                  8: pw.FixedColumnWidth(60), // H
                  9: pw.FixedColumnWidth(60), // J
                  10: pw.FixedColumnWidth(60), // K
                  11: pw.FixedColumnWidth(60), // L
                  12: pw.FixedColumnWidth(60), // M
                },
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('MONTH',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Basic Salary\nKshs.\nA',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Benefits\nNon-Cash\nKshs.\nB',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Value of\nQuarters\nKshs.\nC',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Total\nGross Pay\nKshs.\nD',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            'Defined Contribution\nRetirement Scheme\nKshs.\nE1 30% of A\nE2 Actual\nE3 Fixed',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Owner\nOccupied\nInterest\nKshs.\nF',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            'Retirement\nContribution &\nOwner Occupied\nInterest\nKshs.\nG',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Chargeable\nPay\nKshs.\nH',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Tax\nCharged\nKshs.\nJ',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Monthly\nPersonal\nRelief\nKshs.\nK',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Insurance\nRelief\nKshs.\nL',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('P.A.Y.E\nTax\nKshs.\nM',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),

                  // Monthly Rows
                  ..._p9Data.map((data) {
                    final hasData = data['hasData'] as bool;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(data['month'],
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['basic_salary'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['benefits'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['quarters'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['gross_pay'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? '${numberFormat.format(data['e1'])}\n${numberFormat.format(data['e2'])}\n${numberFormat.format(data['e3'])}'
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['owner_interest'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat
                                      .format(data['retirement_added'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['chargeable_pay'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['tax_charged'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['personal_relief'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat
                                      .format(data['insurance_relief'])
                                  : '',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              hasData
                                  ? numberFormat.format(data['paye_tax'])
                                  : '',
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
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['basic_salary']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['benefits']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['quarters']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['gross_pay']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['owner_interest']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['retirement_added']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['chargeable_pay']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['tax_charged']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['personal_relief']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['insurance_relief']
                                        : 0.0))),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            numberFormat.format(_p9Data.fold(
                                0.0,
                                (sum, item) =>
                                    sum +
                                    (item['hasData']
                                        ? item['paye_tax']
                                        : 0.0))),
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('To be completed by Employer at end of year',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                      'TOTAL TAX (COL M) Kshs. ${numberFormat.format(_p9Data.fold(0.0, (sum, item) => sum + (item['hasData'] ? item['paye_tax'] : 0.0)))}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Text(
                  'TOTAL CHARGEABLE PAY (COL H) Kshs. ${numberFormat.format(_p9Data.fold(0.0, (sum, item) => sum + (item['hasData'] ? item['chargeable_pay'] : 0.0)))}',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
              pw.Text('IMPORTANT',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  '1. Use P9A (a) For all liable employees and where director/employee received benefits in addition to cash emoluments.\n   (b) Where an employee is eligible to deduction on owner occupied interest.',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                  '2. (a) Deductible interest in respect of any month must not exceed Kshs. 12,500/-',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          '(b) Attach\n   (i) Photostat copy of interest certificate and statement of account from the financial institution.\n   (ii) The DECLARATION duly signed by the employee to form P9A.',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          'NAME OF FINANCIAL INSTITUTION ADVANCING MORTGAGE LOAN',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          '_________________________________________________',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('I.R. NO. OF OWNER OCCUPIED PROPERTY',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          '_________________________________________________',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('DATE OF OCCUPATION OF HOUSE',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          '_________________________________________________',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Text(
                      'P9A\n(See back of this card for further information required by the Department)\nAPPROV. CIT/037/2/98/20',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _downloadP9() async {
    if (_p9Data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No P9 data available to download')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdfContent = await _generateP9Pdf();

      // Save to local disk
      String baseDir = Platform.isWindows
          ? r'C:\p9_forms'
          : '${(await getApplicationDocumentsDirectory()).path}/p9_forms';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final employee = _employees.firstWhere(
        (e) => e['employee_id'].toString() == selectedEmployeeId,
        orElse: () => {},
      );
      final filename =
          'p9_${employee['fullname']?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'unknown'}_$selectedYear.pdf';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      await Printing.sharePdf(bytes: pdfContent, filename: filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('P9 Form saved as $filename to $baseDir'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save P9 form: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'P9 Screen',
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
                        value: selectedCompany ?? 'Select Company',
                        items: companyNames,
                        itemBuilder: (company) => company,
                        onChanged: (value) {
                          setState(() {
                            selectedCompany = value;
                            _updateEmployeeList();
                          });
                        },
                      ),
                      _buildDropdown(
                        value: selectedEmployeeId == null
                            ? 'Select Employee'
                            : _filteredEmployees.firstWhere((e) =>
                                e['employee_id'].toString() ==
                                selectedEmployeeId)['fullname'],
                        items: employeeNames,
                        itemBuilder: (employee) => employee,
                        onChanged: (value) {
                          if (value == 'Select Employee') {
                            setState(() {
                              selectedEmployeeId = null;
                            });
                            return;
                          }
                          final selectedEmployee = _filteredEmployees
                              .firstWhere((e) => e['fullname'] == value);
                          setState(() {
                            selectedEmployeeId =
                                selectedEmployee['employee_id'].toString();
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
                          });
                        },
                      ),
                      ElevatedButton(
                        onPressed: _fetchP9Data,
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
                onPressed: _isLoading ? null : _downloadP9,
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
                    : const Text('Download P9 Form'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Colors.teal[700],
                        ),
                      )
                    : _p9Data.isEmpty
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
                                    _buildDataColumn('Month'),
                                    _buildDataColumn('Basic Salary (A)'),
                                    _buildDataColumn('Benefits (B)'),
                                    _buildDataColumn('Quarters (C)'),
                                    _buildDataColumn('Gross Pay (D)'),
                                    _buildDataColumn('Retirement Scheme (E)'),
                                    _buildDataColumn('Owner Interest (F)'),
                                    _buildDataColumn(
                                        'Retirement + Interest (G)'),
                                    _buildDataColumn('Chargeable Pay (H)'),
                                    _buildDataColumn('Tax Charged (J)'),
                                    _buildDataColumn('Personal Relief (K)'),
                                    _buildDataColumn('Insurance Relief (L)'),
                                    _buildDataColumn('P.A.Y.E Tax (M)'),
                                  ],
                                  rows: _p9Data.map((data) {
                                    final hasData = data['hasData'] as bool;
                                    final numberFormat =
                                        NumberFormat('#,##0.00', 'en_US');
                                    return DataRow(
                                      cells: [
                                        _buildDataCell(data['month']),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['basic_salary'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['benefits'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['quarters'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['gross_pay'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? '${numberFormat.format(data['e1'])}\n${numberFormat.format(data['e2'])}\n${numberFormat.format(data['e3'])}'
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['owner_interest'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat.format(
                                                data['retirement_added'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['chargeable_pay'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['tax_charged'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['personal_relief'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat.format(
                                                data['insurance_relief'])
                                            : ''),
                                        _buildDataCell(hasData
                                            ? numberFormat
                                                .format(data['paye_tax'])
                                            : ''),
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
