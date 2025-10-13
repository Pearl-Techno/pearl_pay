import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// Custom AppBar for consistent styling
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.backgroundColor,
    this.titleStyle,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ??
            GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
      ),
      backgroundColor: backgroundColor ?? Colors.teal.shade700,
      actions: actions,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 4,
      shadowColor: Colors.teal.withOpacity(0.3),
    );
  }
}

// Theme configuration for consistent UI
class AppTheme {
  static final ThemeData theme = ThemeData(
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.teal,
      backgroundColor: Colors.teal.shade50,
    ).copyWith(
      surface: Colors.teal.shade50,
      onSurface: Colors.teal.shade900,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.teal.shade700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: Colors.teal.shade700,
        textStyle: GoogleFonts.roboto(fontSize: 16),
      ),
    ),
    textTheme: TextTheme(
      bodyMedium: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade900),
      titleLarge: GoogleFonts.roboto(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
      labelLarge: GoogleFonts.roboto(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
    ),
    cardTheme: CardTheme(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
  );
}

// Provider for managing appraisal state
class AppraisalDetailProvider with ChangeNotifier {
  bool isUpdating = false;
  bool isExporting = false;
  String? errorMessage;

  Future<void> updateStatus({
    required BuildContext context,
    required ApiService apiService,
    required String appraisalId,
    required String status,
    required int companyId,
  }) async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();
    try {
      await apiService.updateAppraisalStatus(
        appraisalId: appraisalId,
        status: status,
        companyId: companyId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $status', style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      errorMessage = 'Failed to update status: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!, style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> exportToPdf({
    required BuildContext context,
    required Map<String, dynamic> appraisal,
    required String employeeName,
    required String employeePosition,
  }) async {
    isExporting = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }
      final pdf = pw.Document();
      final personalAttributes = appraisal['personal_attributes'] as Map<String, dynamic>? ?? {};
      final operationalSkills = appraisal['operational_skills'] as Map<String, dynamic>? ?? {};
      final improvementPlan = (appraisal['improvement_plan'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final appraisalId = _safeToString(appraisal['appraisal_id']);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Appraisal Details',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal),
              ),
            ),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Personal Details', [
              ['Employee Name', _safeToString(employeeName)],
              ['Position', _safeToString(employeePosition)],
              ['Employee ID', _safeToString(appraisal['employee_id'])],
              ['Company ID', _safeToString(appraisal['company_id'])],
              ['Period', _safeToString(appraisal['period'])],
              ['Status', _safeToString(appraisal['status'])],
              ['Designation', _safeToString(appraisal['designation'])],
              ['Period Under Review', _safeToString(appraisal['period_under_review'])],
              ['Last Appraisal Date', _safeToString(appraisal['last_appraisal_date'])],
              ['Date of Joining', _safeToString(appraisal['date_of_joining'])],
              ['Date of Appointment', _safeToString(appraisal['date_of_appointment'])],
              ['Appraiser Name', _safeToString(appraisal['appraiser_name'])],
              ['Appraiser Position', _safeToString(appraisal['appraiser_position'])],
            ]),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Performance Indicators', [
              ['Awards', _safeToString(appraisal['awards'])],
              ['Recommendations', _safeToString(appraisal['recommendations'])],
              ['Training Attended', _safeToString(appraisal['training_attended'])],
              ['Valid Warnings', _safeToString(appraisal['number_valid_warnings'])],
              ['Absentee Days', _safeToString(appraisal['absentee_days'])],
              ['Sick Days', _safeToString(appraisal['sick_offs'])],
            ]),
            pw.SizedBox(height: 16),
            _buildPdfTableSection(
                'Personal Attributes',
                personalAttributes.entries
                    .map((e) => [
                          e.key.replaceAll('_', ' ').toTitleCase(),
                          _safeToString(e.value['self_rating']),
                          _safeToString(e.value['appraiser_rating']),
                          _safeToString(e.value['comments']),
                        ])
                    .toList(),
                headers: ['Attribute', 'Self Rating', 'Appraiser Rating', 'Comments']),
            pw.SizedBox(height: 16),
            _buildPdfTableSection(
                'Operational Skills',
                operationalSkills.entries
                    .map((e) => [
                          e.key.replaceAll('_', ' ').toTitleCase(),
                          _safeToString(e.value['self_rating']),
                          _safeToString(e.value['appraiser_rating']),
                          _safeToString(e.value['description'] ?? 'N/A'),
                          _safeToString(e.value['comments'] ?? 'N/A'),
                        ])
                    .toList(),
                headers: ['Skill', 'Self Rating', 'Appraiser Rating', 'Description', 'Comments']),
            pw.SizedBox(height: 16),
            _buildPdfTableSection(
                'Compliance Questions',
                [
                  ['Compliance Training', appraisal['compliance_training'] == '1' ? 'Yes' : 'No'],
                  ['Safeguards Company Assets', appraisal['internal_controls'] == '1' ? 'Yes' : 'No'],
                ],
                headers: ['Question', 'Answer']),
            pw.SizedBox(height: 16),
            _buildPdfTableSection(
                'Improvement Plan',
                improvementPlan
                    .map((entry) => [
                          _safeToString(entry['area']),
                          _safeToString(entry['action']),
                          _safeToString(entry['goal']),
                          _safeToString(entry['timing']),
                        ])
                    .toList(),
                headers: ['Area', 'Action', 'Goal', 'Timing']),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Career Development', [
              ['Career Objectives', _safeToString(appraisal['career_objectives'])],
              ['Long-Term Objectives', _safeToString(appraisal['long_term_objectives'])],
              ['Job Targets', _safeToString(appraisal['job_targets'])],
              ['Development Needs', _safeToString(appraisal['development_needs'])],
              ['Work Exposure', _safeToString(appraisal['work_exposure'])],
              ['Training Required', _safeToString(appraisal['training_required'])],
              ['Promotion Possibilities', _safeToString(appraisal['promotion_possibilities'])],
              ['Additional Responsibilities', _safeToString(appraisal['additional_responsibilities'])],
            ]),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Summary', [
              ['Overall Self Rating', _safeToString(appraisal['overall_rating_self'])],
              ['Overall Appraiser Rating', _safeToString(appraisal['overall_rating_appraiser'])],
              ['Appraisee Comments', _safeToString(appraisal['appraisee_comments'])],
              ['Appraiser Comments', _safeToString(appraisal['appraiser_comments'])],
              ['General Manager Comments', _safeToString(appraisal['general_manager_comments'])],
              ['Appraisee Signature', _safeToString(appraisal['appraisee_signature'])],
              ['Appraiser Signature', _safeToString(appraisal['appraiser_signature'])],
              ['General Manager Signature', _safeToString(appraisal['general_manager_signature'])],
            ]),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/appraisal_$appraisalId.pdf');
      await file.writeAsBytes(await pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported to ${file.path}', style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      errorMessage = 'Failed to export PDF: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!, style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<void> exportToCsv({
    required BuildContext context,
    required Map<String, dynamic> appraisal,
    required String employeeName,
    required String employeePosition,
  }) async {
    isExporting = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }
      final personalAttributes = appraisal['personal_attributes'] as Map<String, dynamic>? ?? {};
      final operationalSkills = appraisal['operational_skills'] as Map<String, dynamic>? ?? {};
      final improvementPlan = (appraisal['improvement_plan'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final appraisalId = _safeToString(appraisal['appraisal_id']);

      final List<List<dynamic>> csvData = [
        ['Section', 'Field', 'Value'],
        ..._buildCsvRows('Personal Details', [
          ['Employee Name', _safeToString(employeeName)],
          ['Position', _safeToString(employeePosition)],
          ['Employee ID', _safeToString(appraisal['employee_id'])],
          ['Company ID', _safeToString(appraisal['company_id'])],
          ['Period', _safeToString(appraisal['period'])],
          ['Status', _safeToString(appraisal['status'])],
          ['Designation', _safeToString(appraisal['designation'])],
          ['Period Under Review', _safeToString(appraisal['period_under_review'])],
          ['Last Appraisal Date', _safeToString(appraisal['last_appraisal_date'])],
          ['Date of Joining', _safeToString(appraisal['date_of_joining'])],
          ['Date of Appointment', _safeToString(appraisal['date_of_appointment'])],
          ['Appraiser Name', _safeToString(appraisal['appraiser_name'])],
          ['Appraiser Position', _safeToString(appraisal['appraiser_position'])],
        ]),
        ..._buildCsvRows('Performance Indicators', [
          ['Awards', _safeToString(appraisal['awards'])],
          ['Recommendations', _safeToString(appraisal['recommendations'])],
          ['Training Attended', _safeToString(appraisal['training_attended'])],
          ['Valid Warnings', _safeToString(appraisal['number_valid_warnings'])],
          ['Absentee Days', _safeToString(appraisal['absentee_days'])],
          ['Sick Days', _safeToString(appraisal['sick_offs'])],
        ]),
        ...personalAttributes.entries.expand((e) => [
              ['Personal Attributes', '${e.key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeToString(e.value['self_rating'])],
              ['Personal Attributes', '${e.key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeToString(e.value['appraiser_rating'])],
              ['Personal Attributes', '${e.key.replaceAll('_', ' ').toTitleCase()} Comments', _safeToString(e.value['comments'])],
            ]),
        ...operationalSkills.entries.expand((e) => [
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeToString(e.value['self_rating'])],
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeToString(e.value['appraiser_rating'])],
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} Description', _safeToString(e.value['description'] ?? 'N/A')],
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} Comments', _safeToString(e.value['comments'] ?? 'N/A')],
            ]),
        ..._buildCsvRows('Compliance Questions', [
          ['Compliance Training', appraisal['compliance_training'] == '1' ? 'Yes' : 'No'],
          ['Safeguards Company Assets', appraisal['internal_controls'] == '1' ? 'Yes' : 'No'],
        ]),
        ...improvementPlan.asMap().entries.expand((entry) => [
              ['Improvement Plan', 'Entry ${entry.key + 1}: Area', _safeToString(entry.value['area'])],
              ['Improvement Plan', 'Entry ${entry.key + 1}: Action', _safeToString(entry.value['action'])],
              ['Improvement Plan', 'Entry ${entry.key + 1}: Goal', _safeToString(entry.value['goal'])],
              ['Improvement Plan', 'Entry ${entry.key + 1}: Timing', _safeToString(entry.value['timing'])],
            ]),
        ..._buildCsvRows('Career Development', [
          ['Career Objectives', _safeToString(appraisal['career_objectives'])],
          ['Long-Term Objectives', _safeToString(appraisal['long_term_objectives'])],
          ['Job Targets', _safeToString(appraisal['job_targets'])],
          ['Development Needs', _safeToString(appraisal['development_needs'])],
          ['Work Exposure', _safeToString(appraisal['work_exposure'])],
          ['Training Required', _safeToString(appraisal['training_required'])],
          ['Promotion Possibilities', _safeToString(appraisal['promotion_possibilities'])],
          ['Additional Responsibilities', _safeToString(appraisal['additional_responsibilities'])],
        ]),
        ..._buildCsvRows('Summary', [
          ['Overall Self Rating', _safeToString(appraisal['overall_rating_self'])],
          ['Overall Appraiser Rating', _safeToString(appraisal['overall_rating_appraiser'])],
          ['Appraisee Comments', _safeToString(appraisal['appraisee_comments'])],
          ['Appraiser Comments', _safeToString(appraisal['appraiser_comments'])],
          ['General Manager Comments', _safeToString(appraisal['general_manager_comments'])],
          ['Appraisee Signature', _safeToString(appraisal['appraisee_signature'])],
          ['Appraiser Signature', _safeToString(appraisal['appraiser_signature'])],
          ['General Manager Signature', _safeToString(appraisal['general_manager_signature'])],
        ]),
      ];

      final String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/appraisal_$appraisalId.csv');
      await file.writeAsString(csv);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported to ${file.path}', style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      errorMessage = 'Failed to export CSV: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!, style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<void> exportToExcel({
    required BuildContext context,
    required Map<String, dynamic> appraisal,
    required String employeeName,
    required String employeePosition,
  }) async {
    isExporting = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }
      final personalAttributes = appraisal['personal_attributes'] as Map<String, dynamic>? ?? {};
      final operationalSkills = appraisal['operational_skills'] as Map<String, dynamic>? ?? {};
      final improvementPlan = (appraisal['improvement_plan'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final appraisalId = _safeToString(appraisal['appraisal_id']);

      final excel = Excel.createExcel();
      final sheet = excel['Appraisal'];
      sheet.appendRow([
        TextCellValue('Section'),
        TextCellValue('Field'),
        TextCellValue('Value')
      ]);

      void addRow(String section, String field, String value) {
        sheet.appendRow([
          TextCellValue(section),
          TextCellValue(field),
          TextCellValue(value)
        ]);
      }

      addRow('Personal Details', 'Employee Name', _safeToString(employeeName));
      addRow('Personal Details', 'Position', _safeToString(employeePosition));
      addRow('Personal Details', 'Employee ID', _safeToString(appraisal['employee_id']));
      addRow('Personal Details', 'Company ID', _safeToString(appraisal['company_id']));
      addRow('Personal Details', 'Period', _safeToString(appraisal['period']));
      addRow('Personal Details', 'Status', _safeToString(appraisal['status']));
      addRow('Personal Details', 'Designation', _safeToString(appraisal['designation']));
      addRow('Personal Details', 'Period Under Review', _safeToString(appraisal['period_under_review']));
      addRow('Personal Details', 'Last Appraisal Date', _safeToString(appraisal['last_appraisal_date']));
      addRow('Personal Details', 'Date of Joining', _safeToString(appraisal['date_of_joining']));
      addRow('Personal Details', 'Date of Appointment', _safeToString(appraisal['date_of_appointment']));
      addRow('Personal Details', 'Appraiser Name', _safeToString(appraisal['appraiser_name']));
      addRow('Personal Details', 'Appraiser Position', _safeToString(appraisal['appraiser_position']));
      addRow('Performance Indicators', 'Awards', _safeToString(appraisal['awards']));
      addRow('Performance Indicators', 'Recommendations', _safeToString(appraisal['recommendations']));
      addRow('Performance Indicators', 'Training Attended', _safeToString(appraisal['training_attended']));
      addRow('Performance Indicators', 'Valid Warnings', _safeToString(appraisal['number_valid_warnings']));
      addRow('Performance Indicators', 'Absentee Days', _safeToString(appraisal['absentee_days']));
      addRow('Performance Indicators', 'Sick Days', _safeToString(appraisal['sick_offs']));
      personalAttributes.forEach((key, value) {
        addRow('Personal Attributes', '${key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeToString(value['self_rating']));
        addRow('Personal Attributes', '${key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeToString(value['appraiser_rating']));
        addRow('Personal Attributes', '${key.replaceAll('_', ' ').toTitleCase()} Comments', _safeToString(value['comments']));
      });
      operationalSkills.forEach((key, value) {
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeToString(value['self_rating']));
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeToString(value['appraiser_rating']));
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} Description', _safeToString(value['description'] ?? 'N/A'));
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} Comments', _safeToString(value['comments'] ?? 'N/A'));
      });
      addRow('Compliance Questions', 'Compliance Training', appraisal['compliance_training'] == '1' ? 'Yes' : 'No');
      addRow('Compliance Questions', 'Safeguards Company Assets', appraisal['internal_controls'] == '1' ? 'Yes' : 'No');
      improvementPlan.asMap().forEach((index, entry) {
        addRow('Improvement Plan', 'Entry ${index + 1}: Area', _safeToString(entry['area']));
        addRow('Improvement Plan', 'Entry ${index + 1}: Action', _safeToString(entry['action']));
        addRow('Improvement Plan', 'Entry ${index + 1}: Goal', _safeToString(entry['goal']));
        addRow('Improvement Plan', 'Entry ${index + 1}: Timing', _safeToString(entry['timing']));
      });
      addRow('Career Development', 'Career Objectives', _safeToString(appraisal['career_objectives']));
      addRow('Career Development', 'Long-Term Objectives', _safeToString(appraisal['long_term_objectives']));
      addRow('Career Development', 'Job Targets', _safeToString(appraisal['job_targets']));
      addRow('Career Development', 'Development Needs', _safeToString(appraisal['development_needs']));
      addRow('Career Development', 'Work Exposure', _safeToString(appraisal['work_exposure']));
      addRow('Career Development', 'Training Required', _safeToString(appraisal['training_required']));
      addRow('Career Development', 'Promotion Possibilities', _safeToString(appraisal['promotion_possibilities']));
      addRow('Career Development', 'Additional Responsibilities', _safeToString(appraisal['additional_responsibilities']));
      addRow('Summary', 'Overall Self Rating', _safeToString(appraisal['overall_rating_self']));
      addRow('Summary', 'Overall Appraiser Rating', _safeToString(appraisal['overall_rating_appraiser']));
      addRow('Summary', 'Appraisee Comments', _safeToString(appraisal['appraisee_comments']));
      addRow('Summary', 'Appraiser Comments', _safeToString(appraisal['appraiser_comments']));
      addRow('Summary', 'General Manager Comments', _safeToString(appraisal['general_manager_comments']));
      addRow('Summary', 'Appraisee Signature', _safeToString(appraisal['appraisee_signature']));
      addRow('Summary', 'Appraiser Signature', _safeToString(appraisal['appraiser_signature']));
      addRow('Summary', 'General Manager Signature', _safeToString(appraisal['general_manager_signature']));

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/appraisal_$appraisalId.xlsx');
      await file.writeAsBytes(excel.encode()!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel exported to ${file.path}', style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      errorMessage = 'Failed to export Excel: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!, style: GoogleFonts.roboto(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  pw.Widget _buildPdfTableSection(String title, List<List<String>> data, {List<String>? headers}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: headers ?? ['Field', 'Value'],
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          border: pw.TableBorder.all(color: PdfColors.teal),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
      ],
    );
  }

  List<List<String>> _buildCsvRows(String section, List<List<String>> data) {
    return data.map((row) => [section, row[0], row[1]]).toList();
  }

  String _safeToString(dynamic value) {
    return value?.toString() ?? 'N/A';
  }
}

// Main screen widget
class AppraisalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> appraisal;
  final User user;
  final ApiService apiService;
  final String employeeName;
  final String employeePosition;

  const AppraisalDetailScreen({
    super.key,
    required this.appraisal,
    required this.user,
    required this.apiService,
    required this.employeeName,
    required this.employeePosition,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppraisalDetailProvider(),
      child: _AppraisalDetailView(
        appraisal: appraisal,
        user: user,
        apiService: apiService,
        employeeName: employeeName,
        employeePosition: employeePosition,
      ),
    );
  }
}

// Stateful widget for the appraisal detail view
class _AppraisalDetailView extends StatefulWidget {
  final Map<String, dynamic> appraisal;
  final User user;
  final ApiService apiService;
  final String employeeName;
  final String employeePosition;

  const _AppraisalDetailView({
    required this.appraisal,
    required this.user,
    required this.apiService,
    required this.employeeName,
    required this.employeePosition,
  });

  @override
  _AppraisalDetailViewState createState() => _AppraisalDetailViewState();
}

class _AppraisalDetailViewState extends State<_AppraisalDetailView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final Map<String, bool> _sectionExpanded = {
    'personal': true,
    'performance': true,
    'attributes': true,
    'skills': true,
    'compliance': true,
    'improvement': true,
    'career': true,
    'summary': true,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSection(String section) {
    setState(() {
      _sectionExpanded[section] = !_sectionExpanded[section]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppraisalDetailProvider>(context);
    final personalAttributes = widget.appraisal['personal_attributes'] as Map<String, dynamic>? ?? {};
    final operationalSkills = widget.appraisal['operational_skills'] as Map<String, dynamic>? ?? {};
    final improvementPlan = (widget.appraisal['improvement_plan'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final isManagerOrAbove = ['manager', 'operator', 'director'].contains(widget.user.role ?? '');
    final isPending = _safeToString(widget.appraisal['status']).toLowerCase() == 'pending';

    return Theme(
      data: AppTheme.theme,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Appraisal Details for ${widget.employeeName}',
          backgroundColor: Colors.teal.shade700,
          titleStyle: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download, color: Colors.white, size: 28),
              tooltip: 'Export Appraisal',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              offset: const Offset(0, 40),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'PDF',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Text('Export as PDF', style: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade900)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'CSV',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Text('Export as CSV', style: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade900)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_view, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Text('Export as Excel', style: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade900)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'PDF':
                    provider.exportToPdf(
                      context: context,
                      appraisal: widget.appraisal,
                      employeeName: widget.employeeName,
                      employeePosition: widget.employeePosition,
                    );
                    break;
                  case 'CSV':
                    provider.exportToCsv(
                      context: context,
                      appraisal: widget.appraisal,
                      employeeName: widget.employeeName,
                      employeePosition: widget.employeePosition,
                    );
                    break;
                  case 'Excel':
                    provider.exportToExcel(
                      context: context,
                      appraisal: widget.appraisal,
                      employeeName: widget.employeeName,
                      employeePosition: widget.employeePosition,
                    );
                    break;
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade50, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Employee: ${widget.employeeName}',
                            style: GoogleFonts.roboto(fontSize: 18, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Position: ${widget.employeePosition}',
                            style: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade700),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Personal Details',
                            sectionKey: 'personal',
                            icon: Icons.person,
                            children: [
                              _buildInfoRow('Employee ID', _safeToString(widget.appraisal['employee_id'])),
                              _buildInfoRow('Company ID', _safeToString(widget.appraisal['company_id'])),
                              _buildInfoRow('Period', _safeToString(widget.appraisal['period'])),
                              _buildInfoRow('Status', _safeToString(widget.appraisal['status']), isStatus: true),
                              _buildInfoRow('Designation', _safeToString(widget.appraisal['designation'])),
                              _buildInfoRow('Period Under Review', _safeToString(widget.appraisal['period_under_review'])),
                              _buildInfoRow('Last Appraisal Date', _safeToString(widget.appraisal['last_appraisal_date'])),
                              _buildInfoRow('Date of Joining', _safeToString(widget.appraisal['date_of_joining'])),
                              _buildInfoRow('Date of Appointment', _safeToString(widget.appraisal['date_of_appointment'])),
                              _buildInfoRow('Appraiser Name', _safeToString(widget.appraisal['appraiser_name'])),
                              _buildInfoRow('Appraiser Position', _safeToString(widget.appraisal['appraiser_position'])),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Performance Indicators',
                            sectionKey: 'performance',
                            icon: Icons.assessment,
                            children: [
                              _buildInfoRow('Awards', _safeToString(widget.appraisal['awards'])),
                              _buildInfoRow('Recommendations', _safeToString(widget.appraisal['recommendations'])),
                              _buildInfoRow('Training Attended', _safeToString(widget.appraisal['training_attended'])),
                              _buildInfoRow('Valid Warnings', _safeToString(widget.appraisal['number_valid_warnings'])),
                              _buildInfoRow('Absentee Days', _safeToString(widget.appraisal['absentee_days'])),
                              _buildInfoRow('Sick Days', _safeToString(widget.appraisal['sick_offs'])),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Personal Attributes',
                            sectionKey: 'attributes',
                            icon: Icons.person_outline,
                            children: [
                              _buildDataTable(
                                headers: ['Attribute', 'Self Rating', 'Appraiser Rating', 'Comments'],
                                data: personalAttributes.entries
                                    .map((e) => [
                                          e.key.replaceAll('_', ' ').toTitleCase(),
                                          _safeToString(e.value['self_rating']),
                                          _safeToString(e.value['appraiser_rating']),
                                          _safeToString(e.value['comments']),
                                        ])
                                    .toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Operational Skills',
                            sectionKey: 'skills',
                            icon: Icons.work,
                            children: [
                              _buildDataTable(
                                headers: ['Skill', 'Self Rating', 'Appraiser Rating', 'Description', 'Comments'],
                                data: operationalSkills.entries
                                    .map((e) => [
                                          e.key.replaceAll('_', ' ').toTitleCase(),
                                          _safeToString(e.value['self_rating']),
                                          _safeToString(e.value['appraiser_rating']),
                                          _safeToString(e.value['description'] ?? 'N/A'),
                                          _safeToString(e.value['comments'] ?? 'N/A'),
                                        ])
                                    .toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Compliance Questions',
                            sectionKey: 'compliance',
                            icon: Icons.verified,
                            children: [
                              _buildDataTable(
                                headers: ['Question', 'Answer'],
                                data: [
                                  ['Compliance Training', widget.appraisal['compliance_training'] == '1' ? 'Yes' : 'No'],
                                  ['Safeguards Company Assets', widget.appraisal['internal_controls'] == '1' ? 'Yes' : 'No'],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Improvement Plan',
                            sectionKey: 'improvement',
                            icon: Icons.trending_up,
                            children: [
                              _buildDataTable(
                                headers: ['Area', 'Action', 'Goal', 'Timing'],
                                data: improvementPlan
                                    .map((entry) => [
                                          _safeToString(entry['area']),
                                          _safeToString(entry['action']),
                                          _safeToString(entry['goal']),
                                          _safeToString(entry['timing']),
                                        ])
                                    .toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Career Development',
                            sectionKey: 'career',
                            icon: Icons.school,
                            children: [
                              _buildInfoRow('Career Objectives', _safeToString(widget.appraisal['career_objectives'])),
                              _buildInfoRow('Long-Term Objectives', _safeToString(widget.appraisal['long_term_objectives'])),
                              _buildInfoRow('Job Targets', _safeToString(widget.appraisal['job_targets'])),
                              _buildInfoRow('Development Needs', _safeToString(widget.appraisal['development_needs'])),
                              _buildInfoRow('Work Exposure', _safeToString(widget.appraisal['work_exposure'])),
                              _buildInfoRow('Training Required', _safeToString(widget.appraisal['training_required'])),
                              _buildInfoRow('Promotion Possibilities', _safeToString(widget.appraisal['promotion_possibilities'])),
                              _buildInfoRow('Additional Responsibilities', _safeToString(widget.appraisal['additional_responsibilities'])),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'Summary',
                            sectionKey: 'summary',
                            icon: Icons.summarize,
                            children: [
                              _buildInfoRow('Overall Self Rating', _safeToString(widget.appraisal['overall_rating_self'])),
                              _buildInfoRow('Overall Appraiser Rating', _safeToString(widget.appraisal['overall_rating_appraiser'])),
                              _buildInfoRow('Appraisee Comments', _safeToString(widget.appraisal['appraisee_comments'])),
                              _buildInfoRow('Appraiser Comments', _safeToString(widget.appraisal['appraiser_comments'])),
                              _buildInfoRow('General Manager Comments', _safeToString(widget.appraisal['general_manager_comments'])),
                              _buildInfoRow('Appraisee Signature', _safeToString(widget.appraisal['appraisee_signature'])),
                              _buildInfoRow('Appraiser Signature', _safeToString(widget.appraisal['appraiser_signature'])),
                              _buildInfoRow('General Manager Signature', _safeToString(widget.appraisal['general_manager_signature'])),
                            ],
                          ),
                          if (isManagerOrAbove && isPending) ...[
                            const SizedBox(height: 24),
                            _buildActionButtons(context, provider),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (provider.isExporting || provider.isUpdating)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.teal.shade700),
                      const SizedBox(height: 16),
                      Text(
                        provider.isExporting ? 'Exporting...' : 'Updating...',
                        style: GoogleFonts.roboto(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
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

  Widget _buildSection({
    required String title,
    required String sectionKey,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.teal.shade700, size: 28),
        title: Text(
          title,
          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
        ),
        iconColor: Colors.teal.shade700,
        collapsedIconColor: Colors.teal.shade400,
        childrenPadding: const EdgeInsets.all(16),
        initiallyExpanded: _sectionExpanded[sectionKey]!,
        onExpansionChanged: (expanded) => _toggleSection(sectionKey),
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
            ),
          ),
          Expanded(
            flex: 3,
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(value),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      value,
                      style: GoogleFonts.roboto(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  )
                : Text(
                    value,
                    style: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade800),
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable({
    required List<String> headers,
    required List<List<String>> data,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: maxWidth),
            child: Card(
              elevation: 0,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade200),
              ),
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 48,
                dataRowHeight: 56,
                headingRowColor: WidgetStateProperty.all(Colors.teal.shade100),
                headingTextStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
                dataTextStyle: GoogleFonts.roboto(fontSize: 14, color: Colors.teal.shade800),
                border: TableBorder.all(color: Colors.teal.shade200, borderRadius: BorderRadius.circular(12)),
                columns: headers
                    .asMap()
                    .entries
                    .map(
                      (entry) => DataColumn(
                        label: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: 80,
                            maxWidth: maxWidth / headers.length,
                          ),
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                rows: data
                    .map(
                      (row) => DataRow(
                        cells: row
                            .asMap()
                            .entries
                            .map(
                              (cell) => DataCell(
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: 80,
                                    maxWidth: maxWidth / headers.length,
                                  ),
                                  child: Text(
                                    cell.value,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, AppraisalDetailProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ScaleTransitionButton(
            onPressed: provider.isUpdating
                ? null
                : () => _showConfirmationDialog(
                      context: context,
                      provider: provider,
                      status: 'Approved',
                      title: 'Approve Appraisal',
                      message: 'Are you sure you want to approve this appraisal?',
                    ),
            child: ElevatedButton(
              onPressed: provider.isUpdating
                  ? null
                  : () => _showConfirmationDialog(
                        context: context,
                        provider: provider,
                        status: 'Approved',
                        title: 'Approve Appraisal',
                        message: 'Are you sure you want to approve this appraisal?',
                      ),
              child: provider.isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Approve', style: GoogleFonts.roboto(fontSize: 16, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ScaleTransitionButton(
            onPressed: provider.isUpdating
                ? null
                : () => _showConfirmationDialog(
                      context: context,
                      provider: provider,
                      status: 'Rejected',
                      title: 'Reject Appraisal',
                      message: 'Are you sure you want to reject this appraisal?',
                      ),
            child: ElevatedButton(
              onPressed: provider.isUpdating
                  ? null
                  : () => _showConfirmationDialog(
                        context: context,
                        provider: provider,
                        status: 'Rejected',
                        title: 'Reject Appraisal',
                        message: 'Are you sure you want to reject this appraisal?',
                      ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: provider.isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Reject', style: GoogleFonts.roboto(fontSize: 16, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required AppraisalDetailProvider provider,
    required String status,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Text(title, style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.teal.shade900)),
        content: Text(message, style: GoogleFonts.roboto(fontSize: 16, color: Colors.teal.shade800)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'Approved' ? Colors.teal.shade700 : Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              provider.updateStatus(
                context: context,
                apiService: widget.apiService,
                appraisalId: _safeToString(widget.appraisal['appraisal_id']),
                status: status,
                companyId: widget.user.companyId,
              );
              Navigator.pop(context);
            },
            child: Text(status, style: GoogleFonts.roboto(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

  String _safeToString(dynamic value) {
    return value?.toString() ?? 'N/A';
  }
}

// Button with scale animation
class ScaleTransitionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const ScaleTransitionButton({super.key, required this.onPressed, required this.child});

  @override
  _ScaleTransitionButtonState createState() => _ScaleTransitionButtonState();
}

class _ScaleTransitionButtonState extends State<ScaleTransitionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.onPressed != null) widget.onPressed!();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// String extension for title case
extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }
}