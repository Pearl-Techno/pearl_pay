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
class P10Constants {
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

class P10Screen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;
  const P10Screen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  P10ScreenState createState() => P10ScreenState();
}

class P10ScreenState extends State<P10Screen> {
  late final ApiService _apiService;
  List<Map<String, dynamic>> _p10Data = [];
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

  // Enhanced logout function with consistent styling
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: P10Constants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(
          color: P10Constants.textColor,
          fontWeight: FontWeight.w600,
        )),
        content: Text('Are you sure you want to log out?', style: TextStyle(
          color: P10Constants.subtitleColor,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(
              color: P10Constants.subtitleColor,
            )),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: P10Constants.errorColor,
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
        backgroundColor: P10Constants.successColor,
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
        backgroundColor: P10Constants.errorColor,
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
        backgroundColor: P10Constants.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

Future<void> _fetchCompanies() async {
  try {
    final companies = await _apiService.getCompanies();
    
    // Handle user company ID - it might be string or int
    final userCompanyIdRaw = widget.user['company_id'];
    int? userCompanyId;
    
    if (userCompanyIdRaw is int) {
      userCompanyId = userCompanyIdRaw;
    } else if (userCompanyIdRaw is String) {
      userCompanyId = int.tryParse(userCompanyIdRaw);
    }
    
    final isAdmin = widget.user['role'] == 'admin';

    setState(() {
      _companies = companies;
      
      // Process company IDs safely
      final processedCompanies = companies.map((c) {
        final idRaw = c['id'];
        int? id;
        String? companyName = c['company_name']?.toString() ?? 'Unknown';
        
        if (idRaw is int) {
          id = idRaw;
        } else if (idRaw is String) {
          id = int.tryParse(idRaw);
        }
        
        return {
          'id': id,
          'company_name': companyName,
          'raw_data': c,
        };
      }).where((c) => c['id'] != null).toList();

      if (isAdmin) {
        // For admin users, show all companies
        companyIds = processedCompanies
            .map((c) => c['id'] as int)
            .toSet()
            .toList();
        
        companyIdToName = {
          for (var c in processedCompanies)
            c['id'] as int: c['company_name'] as String
        };
        
        companyIds.insert(0, 0); // 0 for 'All Companies'
        companyIdToName[0] = 'All Companies';
      } else if (userCompanyId != null) {
        // For non-admin users, only show their company
        final userCompany = processedCompanies.firstWhere(
          (c) => c['id'] == userCompanyId,
          orElse: () => {
            'id': userCompanyId,
            'company_name': widget.user['company_name']?.toString() ?? 'Unknown'
          },
        );
        
        companyIds = [userCompanyId];
        companyIdToName = {
          userCompanyId: userCompany['company_name'] as String
        };
      } else {
        // No company assigned
        companyIds = [];
        companyIdToName = {};
      }
      
      selectedCompanyId = companyIds.isNotEmpty ? companyIds[0] : null;
    });

    if (selectedCompanyId != null) {
      _fetchP10Data();
    } else {
      setState(() => _isLoading = false);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching companies: $e');
    }
    setState(() {
      _isLoading = false;
    });
    _showErrorSnackBar('Failed to load companies: $e');
  }
}

Future<void> _fetchP10Data() async {
  if (selectedCompanyId == null) {
    setState(() {
      _p10Data = [];
      _isLoading = false;
    });
    return;
  }

  setState(() => _isLoading = true);
  try {
    List<Map<String, dynamic>> employees = [];
    List<Map<String, dynamic>> p10Data = [];

    if (selectedCompanyId == 0) {
      // Admins: Fetch all companies (excluding the "All Companies" option)
      for (var companyId in companyIds.where((id) => id != 0)) {
        try {
          final companyEmployees = await _apiService.getEmployeeList(companyId);
          employees.addAll(companyEmployees);
          
          for (var employee in companyEmployees) {
            try {
              final p9Data = await _apiService.fetchP9Data(
                employeeId: employee['employee_id'].toString(),
                companyId: companyId,
                year: selectedYear,
              );
              if (p9Data.isNotEmpty) {
                p10Data.add(_aggregateP9Data(employee, p9Data, companyId));
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error fetching P9 data for employee ${employee['employee_id']}: $e');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching employees for company $companyId: $e');
          }
        }
      }
    } else {
      // Single company
      try {
        employees = await _apiService.getEmployeeList(selectedCompanyId!);
        for (var employee in employees) {
          try {
            final p9Data = await _apiService.fetchP9Data(
              employeeId: employee['employee_id'].toString(),
              companyId: selectedCompanyId!,
              year: selectedYear,
            );
            if (p9Data.isNotEmpty) {
              p10Data.add(_aggregateP9Data(employee, p9Data, selectedCompanyId!));
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching P9 data for employee ${employee['employee_id']}: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching employees for company $selectedCompanyId: $e');
        }
      }
    }

    setState(() {
      _p10Data = p10Data;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    _showErrorSnackBar('Failed to load P10 data: $e');
  }
}

 Map<String, dynamic> _aggregateP9Data(
    Map<String, dynamic> employee, 
    List<Map<String, dynamic>> p9Data,
    int companyId) {
  
  return {
    'employee_id': employee['employee_id'].toString(),
    'fullname': employee['fullname']?.toString() ?? 'Unknown',
    'kra_pin': employee['kra_pin']?.toString() ?? 'N/A',
    'company_id': companyId,
    'company_name': companyIdToName[companyId] ?? 'Unknown',
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

  // Keep all PDF generation methods exactly as they were
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

              // Table (keep all table structure exactly as it was)
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
                  }),

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
      _showWarningSnackBar('No P10 data available to download');
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

      _showSuccessSnackBar('P10 Form saved as $filename to $baseDir');
    } catch (e) {
      _showErrorSnackBar('Failed to save P10 form: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin';

    return Scaffold(
      backgroundColor: P10Constants.backgroundColor,
      appBar: CustomAppBar(
        title: 'P10 Forms Dashboard',
        backgroundColor: P10Constants.primaryColor,
        onNotificationTap: () {
          // Handle notifications
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: P10Constants.cardColor,
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
                      color: P10Constants.greyColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: P10Constants.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: P10Constants.primaryColor),
                    ),
                    title: Text('Profile: ${widget.user['username']}',
                        style: TextStyle(
                          color: P10Constants.textColor,
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('Role: ${widget.user['role']}',
                        style: TextStyle(color: P10Constants.subtitleColor)),
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
                        backgroundColor: P10Constants.errorColor,
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
                    P10Constants.primaryColor,
                    P10Constants.secondaryColor
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: P10Constants.primaryColor.withValues(alpha: 0.3),
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
                      Icons.assignment_ind,
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
                          'P10 Forms Dashboard',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate and download P10 annual tax summaries',
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
                  color: P10Constants.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (isAdmin) ...[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Company',
                                  style: TextStyle(
                                    color: P10Constants.textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDropdown(
                                  value: selectedCompanyId,
                                  items: companyIds.toSet().toList(), // Ensure unique values
                                  itemBuilder: (id) => companyIdToName[id] ?? 'Unknown',
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCompanyId = value;
                                      _fetchP10Data();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Year',
                                style: TextStyle(
                                  color: P10Constants.textColor,
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
                                    _fetchP10Data();
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
                            onPressed: _fetchP10Data,
                            icon: Icon(Icons.refresh, size: 20),
                            label: const Text('Generate P10 Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: P10Constants.primaryColor,
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
                            onPressed: _isLoading ? null : _downloadP10,
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
                            label: Text(_isLoading ? 'Downloading...' : 'Download P10 Form'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: P10Constants.accentColor,
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
              'P10 Summary (${_p10Data.length} employees)',
              style: TextStyle(
                color: P10Constants.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: P10Constants.primaryColor,
                      ),
                    )
                  : _p10Data.isEmpty
                      ? Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: P10Constants.cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_ind_outlined,
                                  size: 80,
                                  color: P10Constants.greyColor.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No P10 Data Available',
                                  style: TextStyle(
                                    color: P10Constants.textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generate P10 data using the controls above',
                                  style: TextStyle(
                                    color: P10Constants.subtitleColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildP10DataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildP10DataTable() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: P10Constants.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            headingRowColor: WidgetStateProperty.all(P10Constants.primaryColor.withValues(alpha: 0.1)),
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
              final numberFormat = NumberFormat('#,##0.00', 'en_US');
              return DataRow(
                cells: [
                  _buildDataCell(data['fullname']),
                  _buildDataCell(data['kra_pin']),
                  _buildDataCell(numberFormat.format(data['basic_salary'])),
                  _buildDataCell(numberFormat.format(data['gross_pay'])),
                  _buildDataCell(numberFormat.format(data['taxable_income'])),
                  _buildDataCell(numberFormat.format(data['paye_deduction'])),
                  _buildDataCell(numberFormat.format(data['paye_tax'])),
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
          color: P10Constants.textColor,
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
          color: P10Constants.textColor,
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
    // Remove duplicate values to prevent DropdownButton assertion error
    final uniqueItems = items.toSet().toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: P10Constants.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P10Constants.primaryColor.withValues(alpha: 0.3)),
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
                      color: P10Constants.textColor,
                      fontSize: 14,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: P10Constants.cardColor,
        icon: Icon(Icons.arrow_drop_down, color: P10Constants.primaryColor),
        isExpanded: true,
      ),
    );
  }
}