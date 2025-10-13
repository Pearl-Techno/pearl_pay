import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class PayslipScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const PayslipScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PayslipScreenState createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  List _salaries = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;

  int? selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  // Logout function to clear SharedPreferences and navigate to LoginScreen
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
    try {
      final companies = await widget.apiService.getCompanies();
      if (kDebugMode) {
        print('Fetched companies: $companies');
      }

      // Convert user['company_id'] to int, handling String or int
      final userCompanyId = widget.user['company_id'] != null
          ? int.tryParse(widget.user['company_id'].toString())
          : null;
      final userCompanyName = widget.user['company_name']?.toString() ?? 'Unknown';

      if (userCompanyId == null) {
        if (kDebugMode) {
          print('No company ID found for user');
        }
        setState(() {
          companyIds = [];
          companyIdToName = {};
          selectedCompanyId = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No company assigned to user')),
        );
        return;
      }

      // Find the user's company in the fetched companies
      final userCompany = companies.firstWhere(
        (c) => int.tryParse(c['id']?.toString() ?? '') == userCompanyId,
        orElse: () => {
          'id': userCompanyId.toString(),
          'company_name': userCompanyName,
        },
      );

      setState(() {
        _companies = [userCompany];
        companyIds = [userCompanyId];
        companyIdToName = {userCompanyId: userCompany['company_name']?.toString() ?? userCompanyName};
        selectedCompanyId = userCompanyId;
      });

      if (kDebugMode) {
        print('companyIds: $companyIds');
        print('companyIdToName: $companyIdToName');
        print('selectedCompanyId: $selectedCompanyId');
      }

      await _fetchSalaries();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() {
        companyIds = [];
        companyIdToName = {};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load companies: $e')),
      );
    }
  }

  Future<void> _fetchSalaries() async {
    if (selectedCompanyId == null) {
      setState(() {
        _salaries = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> salaries = [];
      List<Map<String, dynamic>> employees = [];
      final isAdmin = widget.user['role'] == 'admin';
      final employeeId = widget.user['employee_id']?.toString();

      // Fetch salaries and employees for the selected company
      salaries = await widget.apiService.getSalaries(selectedCompanyId!);
      employees = await widget.apiService.getEmployeeList(selectedCompanyId!);

      // Filter employees by Active status
      _employees = employees.where((e) => e['employee_status'] == 'Active').toList();

      // Filter salaries for the selected company, month, year, and user role
      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        if (paymentDate == null) return false;

        // Verify company_id matches selectedCompanyId
        final salaryCompanyId = salary['company_id'] != null
            ? int.tryParse(salary['company_id'].toString())
            : selectedCompanyId;
        if (salaryCompanyId != selectedCompanyId) return false;

        // Verify company_name matches
        final salaryCompanyName = salary['company_name']?.toString();
        final expectedCompanyName = companyIdToName[selectedCompanyId];
        if (salaryCompanyName != null && salaryCompanyName != expectedCompanyName) {
          if (kDebugMode) {
            print('Salary company_name mismatch: $salaryCompanyName != $expectedCompanyName');
          }
          return false;
        }

        final matchesMonth = paymentDate.month == selectedMonth;
        final matchesYear = paymentDate.year == selectedYear;
        final matchesEmployee = isAdmin || salary['employee_id'].toString() == employeeId;

        // Ensure employee is Active
        final employee = _employees.firstWhere(
          (e) => e['employee_id'].toString() == salary['employee_id'].toString(),
          orElse: () => {},
        );
        final isActive = employee['employee_status'] == 'Active';

        return matchesMonth && matchesYear && matchesEmployee && isActive;
      }).toList();

      for (var salary in filteredSalaries) {
        final employeeId = salary['employee_id'].toString();
        final companyId = selectedCompanyId!; // Use selectedCompanyId directly
 final benefits = await widget.apiService.fetchBenefits(
          companyId, // int companyId
          selectedMonth, // int month
          selectedYear, // int year
          employeeId, // String employeeId
        );
        final deductions = await widget.apiService.fetchDeductions(
                    companyId, // int companyId
          selectedMonth, // int month
          selectedYear, // int year
          employeeId, // String employeeId
          );
        salary['benefits'] = benefits;
        salary['deductions_list'] = deductions;

        // Find employee by employee_id only (no company_id in employee_salaries)
        final employee = _employees.firstWhere(
          (e) => e['employee_id'].toString() == employeeId,
          orElse: () => {},
        );
        salary['kra_pin'] = employee['kra_pin'] ?? salary['kra_pin'];
        salary['position'] = employee['position_name'] ?? employee['position'] ?? salary['position'];
        salary['house_allowance'] = employee['house_allowance'] ?? salary['house_allowance'];

        // Use company details from _companies
        final company = _companies.firstWhere(
          (c) => int.tryParse(c['id'].toString()) == companyId,
          orElse: () => {
            'id': companyId.toString(),
            'company_name': companyIdToName[companyId] ?? 'N/A',
            'physical_address': 'N/A',
            'kra_pin': 'N/A',
          },
        );
        salary['company_details'] = {
          'company_id': company['id'] ?? companyId.toString(),
          'company_name': company['company_name']?.toString() ?? 'N/A',
          'physical_address': company['physical_address']?.toString() ?? 'N/A',
          'kra_pin': company['kra_pin']?.toString() ?? 'N/A',
        };

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
          'house_allowance',
        ];

        for (var key in numericalKeys) {
          if (salary[key] != null) {
            final value = double.tryParse(salary[key].toString()) ?? 0.0;
            salary[key] = value.round();
          } else {
            salary[key] = 0;
          }
        }

        for (var benefit in salary['benefits'] ?? []) {
          final amount =
              double.tryParse(benefit['amount']?.toString() ?? '0.0') ?? 0.0;
          benefit['amount'] = amount.round();
        }
        for (var deduction in salary['deductions_list'] ?? []) {
          final amount =
              double.tryParse(deduction['amount']?.toString() ?? '0.0') ?? 0.0;
          deduction['amount'] = amount.round();
        }
      }

      setState(() {
        _salaries = filteredSalaries;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching salaries: $e');
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load salaries: $e')),
      );
    }
  }

  pw.Widget buildPayslipContent(Map salary, NumberFormat numberFormat) {
    final companyDetails = salary['company_details'] as Map<String, dynamic>? ??
        {
          'company_name': salary['company_name']?.toString() ?? 'N/A',
          'physical_address': 'N/A',
          'kra_pin': 'N/A',
        };

    return pw.Container(
      width: PdfPageFormat.a4.width / 2 - 48,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                companyDetails['company_name'],
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                companyDetails['physical_address'],
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.black,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'KRA PIN: ${companyDetails['kra_pin']}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.black,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Payslip',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(1),
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
                pw.SizedBox(height: 1),
                _buildPdfRow(
                    'Full Name', salary['fullname']?.toString() ?? 'N/A'),
                _buildPdfRow('Company', companyDetails['company_name']),
                _buildPdfRow(
                    'Emp ID', salary['employee_id']?.toString() ?? 'N/A'),
                _buildPdfRow('KRA Pin', salary['kra_pin']?.toString() ?? 'N/A'),
                _buildPdfRow(
                    'Position', salary['position']?.toString() ?? 'N/A'),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(1),
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
                pw.SizedBox(height: 1),
                _buildPdfRow(
                    'Pay Date', salary['payment_date']?.toString() ?? 'N/A'),
                _buildPdfRow('Pay Type', 'Monthly'),
                _buildPdfRow(
                    'Period', _getMonthFromPaymentDate(salary['payment_date'])),
                _buildPdfRow('Payroll #', salary['id']?.toString() ?? 'N/A'),
                _buildPdfRow('Currency', 'KES'),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(1),
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
                pw.SizedBox(height: 1),
                pw.Table(
                  border: null,
                  columnWidths: {
                    0: pw.FlexColumnWidth(1.5),
                    1: pw.FlexColumnWidth(1),
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
                pw.SizedBox(height: 1),
                _buildSummaryRow(
                  'Gross Pay',
                  'KES ${numberFormat.format(salary['gross_pay'] ?? 0)}',
                  color: PdfColors.black,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(1),
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
                pw.SizedBox(height: 1),
                pw.Table(
                  border: null,
                  columnWidths: {
                    0: pw.FlexColumnWidth(1.5),
                    1: pw.FlexColumnWidth(1),
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
                pw.SizedBox(height: 1),
                _buildSummaryRow(
                  'Taxable Income',
                  'KES ${numberFormat.format(salary['taxable_income'] ?? 0)}',
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 1),
                _buildSummaryRow(
                  'Total Deductions',
                  'KES ${numberFormat.format(_calculateTotalDeductions(salary) ?? 0)}',
                  color: PdfColors.red800,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(1),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
              borderRadius: pw.BorderRadius.circular(2),
              color: PdfColors.grey100,
            ),
            child: _buildSummaryRow(
              'Net Pay',
              'KES ${numberFormat.format(salary['net_pay'] ?? 0)}',
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 28),
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

  Future<Uint8List> _generatePdf(Map salary) async {
    final pdf = pw.Document();
    final numberFormat = NumberFormat('#,##0', 'en_US');

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPayslipContent(salary, numberFormat),
              pw.SizedBox(width: 14),
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
                        color: index % 2 == 0
                            ? PdfColors.grey800
                            : PdfColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              buildPayslipContent(salary, numberFormat),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _exportToCsv() async {
    if (_salaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payslips available to export')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final numberFormat = NumberFormat('#,##0', 'en_US');
      final csvData = <List<dynamic>>[
        [
          'ID',
          'Employee ID',
          'Full Name',
          'Company',
          'KRA PIN',
          'Position',
          'Pay Date',
          'Gross Pay',
          'Basic Pay',
          'House Allowance',
          'Non-Cash Benefits',
          'Other Earnings',
          'Overtime',
          'Bonus',
          'Taxable Income',
          'PAYE Deduction',
          'SHIF Deduction',
          'NSSF Deduction',
          'Pension Contributions',
          'Loan Repayment',
          'Housing Levy',
          'Absenteeism Deduction',
          'Total Deductions',
          'Net Pay',
          'Status',
          'Benefits',
          'Deductions List'
        ],
        ..._salaries.map((salary) {
          final benefits = (salary['benefits'] as List<dynamic>? ?? [])
              .map((b) =>
                  '${b['description']}: KES ${numberFormat.format(b['amount'] ?? 0)}')
              .join('; ');
          final deductions = (salary['deductions_list'] as List<dynamic>? ?? [])
              .map((d) =>
                  '${d['description']}: KES ${numberFormat.format(d['amount'] ?? 0)}')
              .join('; ');
          return [
            salary['id']?.toString() ?? 'N/A',
            salary['employee_id']?.toString() ?? 'N/A',
            salary['fullname']?.toString() ?? 'N/A',
            (salary['company_details']?['company_name'] ??
                    salary['company_name']?.toString()) ??
                'N/A',
            salary['kra_pin']?.toString() ?? 'N/A',
            salary['position']?.toString() ?? 'N/A',
            salary['payment_date']?.toString() ?? 'N/A',
            numberFormat.format(salary['gross_pay'] ?? 0),
            numberFormat.format(salary['basic_pay'] ?? 0),
            numberFormat.format(salary['house_allowance'] ?? 0),
            numberFormat.format(salary['non_cash_benefits'] ?? 0),
            numberFormat.format(salary['other_earnings'] ?? 0),
            numberFormat.format(salary['overtime_amount'] ?? 0),
            numberFormat.format(salary['bonus'] ?? 0),
            numberFormat.format(salary['taxable_income'] ?? 0),
            numberFormat.format(salary['paye_deduction'] ?? 0),
            numberFormat.format(salary['nhif_deduction'] ?? 0),
            numberFormat.format(salary['nssf_deduction'] ?? 0),
            numberFormat.format(salary['pension_contributions'] ?? 0),
            numberFormat.format(salary['loan_repayment'] ?? 0),
            numberFormat.format(salary['housing_levy'] ?? 0),
            numberFormat.format(salary['absenteeism_deduction'] ?? 0),
            numberFormat.format(_calculateTotalDeductions(salary) ?? 0),
            numberFormat.format(salary['net_pay'] ?? 0),
            salary['status']?.toString() ?? 'N/A',
            benefits,
            deductions,
          ];
        }).toList(),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);

      String baseDir = Platform.isWindows
          ? r'C:\payslips'
          : '${(await getApplicationDocumentsDirectory()).path}/payslips';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));
      final filename = 'payslips_$monthYear.csv';
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
      {
        'description': 'Basic Pay',
        'value': salary['basic_pay'] ?? 0,
      },
      {
        'description': 'House Allow.',
        'value': salary['house_allowance'] ?? 0,
      },
      {
        'description': 'Other Earn.',
        'value': salary['other_earnings'] ?? 0,
      },
      {
        'description': 'Overtime',
        'value': salary['overtime_amount'] ?? 0,
      },
      {
        'description': 'Bonus',
        'value': salary['bonus'] ?? 0,
      },
    ];

    final benefits = salary['benefits'] as List<dynamic>? ?? [];
    final benefitRows = benefits.map((benefit) => {
          'description':
              benefit['description']?.toString() ?? 'Unknown Benefit',
          'value': benefit['amount'] ?? 0,
        });

    final totalNonCashBenefits = benefits.fold<int>(
        0, (sum, benefit) => sum + (benefit['amount'] as int? ?? 0));

    final allRows = [
      ...staticEarnings.where((earning) {
        final value = earning['value'] as int;
        return value != 0;
      }),
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
      return _buildEarningsRow(earning['description']!, earning['value'] as int,
          numberFormat, index);
    }).toList();
  }

  pw.TableRow _buildEarningsRow(
      String description, int value, NumberFormat numberFormat, int index) {
    final formattedValue = numberFormat.format(value);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
      ),
      children: [
        pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(formattedValue,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
            textAlign: pw.TextAlign.right),
      ],
    );
  }

  List<pw.TableRow> _buildDeductionsTableRows(
      Map salary, NumberFormat numberFormat) {
    final deductions = [
      {
        'description': 'PAYE Tax',
        'value': salary['paye_deduction'] ?? 0,
      },
      {
        'description': 'SHIF Ded.',
        'value': salary['nhif_deduction'] ?? 0,
      },
      {
        'description': 'NSSF Ded.',
        'value': salary['nssf_deduction'] ?? 0,
      },
      {
        'description': 'Pension',
        'value': salary['pension_contributions'] ?? 0,
      },
      {
        'description': 'Loan Repay',
        'value': salary['loan_repayment'] ?? 0,
      },
      {
        'description': 'Housing Levy',
        'value': salary['housing_levy'] ?? 0,
      },
      {
        'description': 'Absenteeism',
        'value': salary['absenteeism_deduction'] ?? 0,
      },
    ];

    final deductionList = salary['deductions_list'] as List<dynamic>? ?? [];
    final deductionRows = deductionList.map((deduction) => {
          'description':
              deduction['description']?.toString() ?? 'Unknown Deduction',
          'value': deduction['amount'] ?? 0,
        });

    final allRows = [
      ...deductions.where((deduction) {
        final value = deduction['value'] as int;
        return value != 0;
      }),
      ...deductionRows,
    ];

    return allRows.asMap().entries.map((entry) {
      final index = entry.key;
      final deduction = entry.value;
      return _buildDeductionsRow(deduction['description']!,
          deduction['value'] as int, numberFormat, index);
    }).toList();
  }

  pw.TableRow _buildDeductionsRow(
      String description, int value, NumberFormat numberFormat, int index) {
    final formattedValue = numberFormat.format(value);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
      ),
      children: [
        pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('-$formattedValue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red800),
            textAlign: pw.TextAlign.right),
      ],
    );
  }

  int? _calculateTotalDeductions(Map salary) {
    int total = 0;
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
      final value = salary[key] as int? ?? 0;
      total += value;
    }

    final deductionList = salary['deductions_list'] as List<dynamic>? ?? [];
    for (var deduction in deductionList) {
      total += deduction['amount'] as int? ?? 0;
    }

    return total > 0 ? total : null;
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
      final fullName = (salary['fullname']?.toString() ?? 'Unknown')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final filename = 'payslip_${fullName}_$monthYear.pdf';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      await Printing.sharePdf(bytes: pdfContent, filename: filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payslip saved to $filePath'),
          backgroundColor: Colors.teal,
        ),
      );
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
      final numberFormat = NumberFormat('#,##0', 'en_US');

      for (var salary in _salaries) {
        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildPayslipContent(salary, numberFormat),
                  pw.SizedBox(width: 14),
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
                            color: index % 2 == 0
                                ? PdfColors.grey800
                                : PdfColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  buildPayslipContent(salary, numberFormat),
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
    final numberFormat = NumberFormat('#,##0', 'en_US');
    final userCompanyName = widget.user['company_name']?.toString() ?? 'Unknown';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Payslips',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) {
            print('Notifications tapped');
          }
        },
        onProfileTap: () {
          // Show profile options, including logout
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
                      Navigator.pop(context); // Close bottom sheet
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
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal[200]!),
                          ),
                          child: Text(
                            userCompanyName,
                            style: TextStyle(
                              color: Colors.teal[900],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _downloadAllPayslips,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Download All Payslips'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _exportToCsv,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Export to CSV'),
                  ),
                ],
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
                                              salary['fullname']?.toString() ??
                                                  'N/A'),
                                          _buildDataCell(
                                              (salary['company_details']
                                                          ?['company_name'] ??
                                                      salary['company_name']
                                                          ?.toString()) ??
                                                  'N/A'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['gross_pay'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['basic_pay'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['non_cash_benefits'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['other_earnings'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['overtime_amount'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['absenteeism_deduction'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['taxable_income'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['nhif_deduction'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['paye_deduction'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['nssf_deduction'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['pension_contributions'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['loan_repayment'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['deductions'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['housing_levy'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['housing_levy_relief'] ?? 0)}'),
                                          _buildDataCell(
                                              'KES ${numberFormat.format(salary['net_pay'] ?? 0)}'),
                                          _buildDataCell(
                                              salary['status']?.toString() ??
                                                  'N/A'),
                                          _buildDataCell(salary['payment_date']
                                                  ?.toString() ??
                                              'N/A'),
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