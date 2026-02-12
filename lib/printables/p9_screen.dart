import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// Constants - Using same colors as other screens
class P9Constants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
  static const Color greyColor = Color(0xFF9E9E9E);
  static const Color errorColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFFF9800);
}

class P9Screen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;
  const P9Screen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  P9ScreenState createState() => P9ScreenState();
}

class P9ScreenState extends State<P9Screen> {
  late final ApiService _apiService;
  List<Map<String, dynamic>> _p9Data = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;

  int? selectedCompanyId;
  String? selectedEmployeeId;
  int selectedYear = DateTime.now().year;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};

  @override
  void initState() {
    super.initState();
    final user = User.fromMap(widget.user); // Convert Map to User
    _apiService = ApiService(client: http.Client(), user: user);
    _fetchCompanies();
  }

  // Enhanced logout function with consistent styling
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: P9Constants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(
          color: P9Constants.textColor,
          fontWeight: FontWeight.w600,
        )),
        content: Text('Are you sure you want to log out?', style: TextStyle(
          color: P9Constants.subtitleColor,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(
              color: P9Constants.subtitleColor,
            )),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: P9Constants.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // Snackbar helper methods
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: P9Constants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: P9Constants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: P9Constants.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _fetchCompanies() async {
    try {
      final companies = await _apiService.getCompanies();
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
        _showErrorSnackBar('No company assigned to user');
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

      await _fetchEmployees();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() {
        companyIds = [];
        companyIdToName = {};
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load companies: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    if (selectedCompanyId == null) {
      setState(() {
        _employees = [];
        selectedEmployeeId = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final employees = await _apiService.getEmployeeList(selectedCompanyId!);
      setState(() {
        _employees = employees;
        selectedEmployeeId = null;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching employees: $e');
      }
      _showErrorSnackBar('Failed to load employees: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchP9Data() async {
    if (selectedCompanyId == null || selectedEmployeeId == null) {
      _showWarningSnackBar('Please select a company and employee');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final p9Data = await _apiService.fetchP9Data(
        employeeId: selectedEmployeeId!,
        companyId: selectedCompanyId!,
        year: selectedYear,
      );

      // Ensure all 12 months are represented
      final formattedP9Data = <Map<String, dynamic>>[];
      for (int month = 1; month <= 12; month++) {
        final dataForMonth = p9Data.firstWhere(
          (data) =>
              DateFormat('MMMM').format(DateTime(selectedYear, month)) ==
              data['month'],
          orElse: () => {},
        );

        final hasData = dataForMonth.isNotEmpty;
        final basicSalary =
            hasData ? (dataForMonth['basic_salary']?.toDouble() ?? 0.0) : 0.0;
        final e1 = hasData ? (basicSalary * 0.3) : 0.0; // 30% of basic salary
        final e2 = hasData
            ? (dataForMonth['pension_contributions']?.toDouble() ?? 0.0)
            : 0.0;
        const e3 = 20000.00; // Fixed value
        const ownerOccupiedInterest = 200.00; // Fixed value
        final g = hasData
            ? ([e1, e2, e3].reduce((a, b) => a < b ? a : b) +
                ownerOccupiedInterest)
            : 0.0;

        formattedP9Data.add({
          'month': DateFormat('MMMM').format(DateTime(selectedYear, month)),
          'hasData': hasData,
          'basic_salary': basicSalary,
          'benefits':
              hasData ? (dataForMonth['benefits']?.toDouble() ?? 0.0) : 0.0,
          'quarters':
              hasData ? (dataForMonth['quarters']?.toDouble() ?? 0.0) : 0.0,
          'gross_pay':
              hasData ? (dataForMonth['gross_pay']?.toDouble() ?? 0.0) : 0.0,
          'e1': e1,
          'e2': e2,
          'e3': hasData ? e3 : 0.0,
          'owner_interest': hasData ? ownerOccupiedInterest : 0.0,
          'retirement_added': g,
          'chargeable_pay': hasData
              ? (dataForMonth['taxable_income']?.toDouble() ?? 0.0)
              : 0.0,
          'tax_charged': hasData
              ? (dataForMonth['paye_deduction']?.toDouble() ?? 0.0)
              : 0.0,
          'personal_relief': hasData
              ? (dataForMonth['personal_relief']?.toDouble() ?? 2400.00)
              : 0.0,
          'insurance_relief': hasData
              ? (dataForMonth['insurance_relief']?.toDouble() ?? 142.50)
              : 0.0,
          'paye_tax': hasData
              ? ((dataForMonth['paye_deduction']?.toDouble() ?? 0.0) -
                  (dataForMonth['personal_relief']?.toDouble() ?? 2400.00) -
                  (dataForMonth['insurance_relief']?.toDouble() ?? 142.50))
              : 0.0,
        });
      }

      setState(() {
        _p9Data = formattedP9Data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load P9 data: $e');
    }
  }

  // Keep all the PDF generation methods exactly as they were
  Future<Uint8List> _generateP9Pdf() async {
    final pdf = pw.Document();
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    final employee = _employees.firstWhere(
      (e) => e['employee_id'].toString() == selectedEmployeeId,
      orElse: () => {},
    );

    final company = _companies.firstWhere(
      (c) => c['id'] == (employee['company_id'] ?? selectedCompanyId),
      orElse: () => {'company_name': 'N/A', 'kra_pin': 'N/A'},
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
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
                          'Employer\'s Name: ${company['company_name'] ?? 'N/A'}',
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
                      pw.Text(
                          'Employer\'s P.I.N: ${company['kra_pin'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                          'Employee\'s P.I.N: ${employee['kra_pin'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Table (keep the entire table structure exactly as it was)
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
                      // ... (keep all the table header cells exactly as they were)
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

                  // Monthly Rows (keep all data rows exactly as they were)
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
                        // ... (keep all other table cells exactly as they were)
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
                  }),

                  // Totals Row (keep totals exactly as they were)
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
                      // ... (keep all other total cells exactly as they were)
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

              // Footer (keep footer exactly as it was)
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
      _showWarningSnackBar('No P9 data available to download');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdfContent = await _generateP9Pdf();

      String baseDir = Platform.isWindows
          ? r'C:\p9_forms'
          : '${(await getApplicationDocumentsDirectory()).path}/p9_forms';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final employee = _employees.firstWhere(
        (e) => e['employee_id'].toString() == selectedEmployeeId,
        orElse: () => {'fullname': 'unknown'},
      );
      final filename =
          'p9_${employee['fullname']?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'unknown'}_$selectedYear.pdf';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      await Printing.sharePdf(bytes: pdfContent, filename: filename);

      _showSuccessSnackBar('P9 Form saved as $filename to $baseDir');
    } catch (e) {
      _showErrorSnackBar('Failed to save P9 form: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCompanyName = widget.user['company_name']?.toString() ?? 'Unknown';

    return Scaffold(
      backgroundColor: P9Constants.backgroundColor,
      appBar: CustomAppBar(
        title: 'P9 Forms Dashboard',
        backgroundColor: P9Constants.primaryColor,
        onNotificationTap: () {
          // Handle notifications
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: P9Constants.cardColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: P9Constants.greyColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: P9Constants.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: P9Constants.primaryColor),
                    ),
                    title: Text('Profile: ${widget.user['username']}',
                        style: TextStyle(
                          color: P9Constants.textColor,
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('Role: ${widget.user['role']}',
                        style: TextStyle(color: P9Constants.subtitleColor)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      icon: Icon(Icons.logout, size: 20),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: P9Constants.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    P9Constants.primaryColor,
                    P9Constants.secondaryColor
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: P9Constants.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'P9 Forms Dashboard',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate and download P9 tax forms for employees',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Controls Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: P9Constants.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Company',
                                style: TextStyle(
                                  color: P9Constants.textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: P9Constants.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: P9Constants.primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  userCompanyName,
                                  style: TextStyle(
                                    color: P9Constants.textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Employee',
                                style: TextStyle(
                                  color: P9Constants.textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: selectedEmployeeId,
                                items: [
                                  null,
                                  ..._employees.map((e) => e['employee_id'].toString()),
                                ],
                                itemBuilder: (id) => id == null
                                    ? 'Select Employee'
                                    : _employees
                                        .firstWhere(
                                            (e) => e['employee_id'].toString() == id,
                                            orElse: () =>
                                                {'fullname': 'Unknown'})['fullname']
                                        .toString(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedEmployeeId = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Year',
                                style: TextStyle(
                                  color: P9Constants.textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _fetchP9Data,
                            icon: Icon(Icons.refresh, size: 20),
                            label: const Text('Generate P9 Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: P9Constants.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _downloadP9,
                            icon: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.download, size: 20),
                            label: Text(_isLoading ? 'Downloading...' : 'Download P9 Form'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: P9Constants.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Results Section
            Text(
              'P9 Data (${_p9Data.length} months)',
              style: TextStyle(
                color: P9Constants.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: P9Constants.primaryColor,
                      ),
                    )
                  : _p9Data.isEmpty
                      ? Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: P9Constants.cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 80,
                                  color: P9Constants.greyColor.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No P9 Data Available',
                                  style: TextStyle(
                                    color: P9Constants.textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generate P9 data using the controls above',
                                  style: TextStyle(
                                    color: P9Constants.subtitleColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildP9DataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildP9DataTable() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: P9Constants.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            headingRowColor: WidgetStateProperty.all(P9Constants.primaryColor.withValues(alpha: 0.1)),
            columns: [
              _buildDataColumn('Month'),
              _buildDataColumn('Basic Salary (A)'),
              _buildDataColumn('Benefits (B)'),
              _buildDataColumn('Quarters (C)'),
              _buildDataColumn('Gross Pay (D)'),
              _buildDataColumn('Retirement Scheme (E)'),
              _buildDataColumn('Owner Interest (F)'),
              _buildDataColumn('Retirement + Interest (G)'),
              _buildDataColumn('Chargeable Pay (H)'),
              _buildDataColumn('Tax Charged (J)'),
              _buildDataColumn('Personal Relief (K)'),
              _buildDataColumn('Insurance Relief (L)'),
              _buildDataColumn('P.A.Y.E Tax (M)'),
            ],
            rows: _p9Data.map((data) {
              final hasData = data['hasData'] as bool;
              final numberFormat = NumberFormat('#,##0.00', 'en_US');
              return DataRow(
                cells: [
                  _buildDataCell(data['month']),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['basic_salary'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['benefits'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['quarters'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['gross_pay'])
                      : ''),
                  _buildDataCell(hasData
                      ? '${numberFormat.format(data['e1'])}\n${numberFormat.format(data['e2'])}\n${numberFormat.format(data['e3'])}'
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['owner_interest'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['retirement_added'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['chargeable_pay'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['tax_charged'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['personal_relief'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['insurance_relief'])
                      : ''),
                  _buildDataCell(hasData
                      ? numberFormat.format(data['paye_tax'])
                      : ''),
                ],
              );
            }).toList(),
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
          color: P9Constants.textColor,
          fontSize: 12,
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Text(
        text,
        style: TextStyle(
          color: P9Constants.textColor,
          fontSize: 12,
        ),
      ),
    );
  }

 Widget _buildDropdown<T>({
  required T? value,
  required List<T?> items,
  required String Function(T?) itemBuilder,
  required ValueChanged<T?> onChanged,
}) {
  // Remove duplicate values to fix the DropdownButton assertion error
  final uniqueItems = items.toSet().toList();
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: P9Constants.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: P9Constants.primaryColor.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: DropdownButton<T>(
      value: value,
      items: uniqueItems
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  itemBuilder(item),
                  style: TextStyle(
                    color: P9Constants.textColor,
                    fontSize: 14,
                  ),
                ),
              ))
          .toList(),
      onChanged: onChanged,
      underline: const SizedBox(),
      dropdownColor: P9Constants.cardColor,
      icon: Icon(Icons.arrow_drop_down, color: P9Constants.primaryColor),
      isExpanded: true,
    ),
  );
}
}