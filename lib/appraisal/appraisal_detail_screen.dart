import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// Constants - Using same colors as other screens
class AppraisalDetailConstants {
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

// Provider for managing appraisal state
class AppraisalDetailProvider with ChangeNotifier {
  bool isUpdating = false;
  bool isExporting = false;
  String? errorMessage;

  // Helper method to safely parse strings
  String? _safeParseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

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
      if (!context.mounted) return;
      _showSuccessSnackBar(context, 'Appraisal status updated to $status');
      Navigator.pop(context);
    } catch (e) {
      errorMessage = 'Failed to update status: $e';
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage!);
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
      final appraisalId = _safeParseString(appraisal['appraisal_id']) ?? 'unknown';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Appraisal Details',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue),
              ),
            ),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Personal Details', [
              ['Employee Name', _safeParseString(employeeName) ?? 'N/A'],
              ['Position', _safeParseString(employeePosition) ?? 'N/A'],
              ['Employee ID', _safeParseString(appraisal['employee_id']) ?? 'N/A'],
              ['Company ID', _safeParseString(appraisal['company_id']) ?? 'N/A'],
              ['Period', _safeParseString(appraisal['period']) ?? 'N/A'],
              ['Status', _safeParseString(appraisal['status']) ?? 'N/A'],
              ['Designation', _safeParseString(appraisal['designation']) ?? 'N/A'],
              ['Period Under Review', _safeParseString(appraisal['period_under_review']) ?? 'N/A'],
              ['Last Appraisal Date', _safeParseString(appraisal['last_appraisal_date']) ?? 'N/A'],
              ['Date of Joining', _safeParseString(appraisal['date_of_joining']) ?? 'N/A'],
              ['Date of Appointment', _safeParseString(appraisal['date_of_appointment']) ?? 'N/A'],
              ['Appraiser Name', _safeParseString(appraisal['appraiser_name']) ?? 'N/A'],
              ['Appraiser Position', _safeParseString(appraisal['appraiser_position']) ?? 'N/A'],
            ]),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Performance Indicators', [
              ['Awards', _safeParseString(appraisal['awards']) ?? 'N/A'],
              ['Recommendations', _safeParseString(appraisal['recommendations']) ?? 'N/A'],
              ['Training Attended', _safeParseString(appraisal['training_attended']) ?? 'N/A'],
              ['Valid Warnings', _safeParseString(appraisal['number_valid_warnings']) ?? 'N/A'],
              ['Absentee Days', _safeParseString(appraisal['absentee_days']) ?? 'N/A'],
              ['Sick Days', _safeParseString(appraisal['sick_offs']) ?? 'N/A'],
            ]),
            pw.SizedBox(height: 16),
            _buildPdfTableSection(
                'Personal Attributes',
                personalAttributes.entries
                    .map((e) => [
                          e.key.replaceAll('_', ' ').toTitleCase(),
                          _safeParseString(e.value['self_rating']) ?? 'N/A',
                          _safeParseString(e.value['appraiser_rating']) ?? 'N/A',
                          _safeParseString(e.value['comments']) ?? 'N/A',
                        ])
                    .toList(),
                headers: ['Attribute', 'Self Rating', 'Appraiser Rating', 'Comments']),
            pw.SizedBox(height: 16),
            _buildPdfTableSection(
                'Operational Skills',
                operationalSkills.entries
                    .map((e) => [
                          e.key.replaceAll('_', ' ').toTitleCase(),
                          _safeParseString(e.value['self_rating']) ?? 'N/A',
                          _safeParseString(e.value['appraiser_rating']) ?? 'N/A',
                          _safeParseString(e.value['description']) ?? 'N/A',
                          _safeParseString(e.value['comments']) ?? 'N/A',
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
                          _safeParseString(entry['area']) ?? 'N/A',
                          _safeParseString(entry['action']) ?? 'N/A',
                          _safeParseString(entry['goal']) ?? 'N/A',
                          _safeParseString(entry['timing']) ?? 'N/A',
                        ])
                    .toList(),
                headers: ['Area', 'Action', 'Goal', 'Timing']),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Career Development', [
              ['Career Objectives', _safeParseString(appraisal['career_objectives']) ?? 'N/A'],
              ['Long-Term Objectives', _safeParseString(appraisal['long_term_objectives']) ?? 'N/A'],
              ['Job Targets', _safeParseString(appraisal['job_targets']) ?? 'N/A'],
              ['Development Needs', _safeParseString(appraisal['development_needs']) ?? 'N/A'],
              ['Work Exposure', _safeParseString(appraisal['work_exposure']) ?? 'N/A'],
              ['Training Required', _safeParseString(appraisal['training_required']) ?? 'N/A'],
              ['Promotion Possibilities', _safeParseString(appraisal['promotion_possibilities']) ?? 'N/A'],
              ['Additional Responsibilities', _safeParseString(appraisal['additional_responsibilities']) ?? 'N/A'],
            ]),
            pw.SizedBox(height: 16),
            _buildPdfTableSection('Summary', [
              ['Overall Self Rating', _safeParseString(appraisal['overall_rating_self']) ?? 'N/A'],
              ['Overall Appraiser Rating', _safeParseString(appraisal['overall_rating_appraiser']) ?? 'N/A'],
              ['Appraisee Comments', _safeParseString(appraisal['appraisee_comments']) ?? 'N/A'],
              ['Appraiser Comments', _safeParseString(appraisal['appraiser_comments']) ?? 'N/A'],
              ['General Manager Comments', _safeParseString(appraisal['general_manager_comments']) ?? 'N/A'],
              ['Appraisee Signature', _safeParseString(appraisal['appraisee_signature']) ?? 'N/A'],
              ['Appraiser Signature', _safeParseString(appraisal['appraiser_signature']) ?? 'N/A'],
              ['General Manager Signature', _safeParseString(appraisal['general_manager_signature']) ?? 'N/A'],
            ]),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/appraisal_$appraisalId.pdf');
      await file.writeAsBytes(await pdf.save());
      if (!context.mounted) return;
      _showSuccessSnackBar(context, 'PDF exported to ${file.path}');
    } catch (e) {
      errorMessage = 'Failed to export PDF: $e';
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage!);
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
      final appraisalId = _safeParseString(appraisal['appraisal_id']) ?? 'unknown';

      final List<List<dynamic>> csvData = [
        ['Section', 'Field', 'Value'],
        ..._buildCsvRows('Personal Details', [
          ['Employee Name', _safeParseString(employeeName) ?? 'N/A'],
          ['Position', _safeParseString(employeePosition) ?? 'N/A'],
          ['Employee ID', _safeParseString(appraisal['employee_id']) ?? 'N/A'],
          ['Company ID', _safeParseString(appraisal['company_id']) ?? 'N/A'],
          ['Period', _safeParseString(appraisal['period']) ?? 'N/A'],
          ['Status', _safeParseString(appraisal['status']) ?? 'N/A'],
          ['Designation', _safeParseString(appraisal['designation']) ?? 'N/A'],
          ['Period Under Review', _safeParseString(appraisal['period_under_review']) ?? 'N/A'],
          ['Last Appraisal Date', _safeParseString(appraisal['last_appraisal_date']) ?? 'N/A'],
          ['Date of Joining', _safeParseString(appraisal['date_of_joining']) ?? 'N/A'],
          ['Date of Appointment', _safeParseString(appraisal['date_of_appointment']) ?? 'N/A'],
          ['Appraiser Name', _safeParseString(appraisal['appraiser_name']) ?? 'N/A'],
          ['Appraiser Position', _safeParseString(appraisal['appraiser_position']) ?? 'N/A'],
        ]),
        ..._buildCsvRows('Performance Indicators', [
          ['Awards', _safeParseString(appraisal['awards']) ?? 'N/A'],
          ['Recommendations', _safeParseString(appraisal['recommendations']) ?? 'N/A'],
          ['Training Attended', _safeParseString(appraisal['training_attended']) ?? 'N/A'],
          ['Valid Warnings', _safeParseString(appraisal['number_valid_warnings']) ?? 'N/A'],
          ['Absentee Days', _safeParseString(appraisal['absentee_days']) ?? 'N/A'],
          ['Sick Days', _safeParseString(appraisal['sick_offs']) ?? 'N/A'],
        ]),
        ...personalAttributes.entries.expand((e) => [
              ['Personal Attributes', '${e.key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeParseString(e.value['self_rating']) ?? 'N/A'],
              ['Personal Attributes', '${e.key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeParseString(e.value['appraiser_rating']) ?? 'N/A'],
              ['Personal Attributes', '${e.key.replaceAll('_', ' ').toTitleCase()} Comments', _safeParseString(e.value['comments']) ?? 'N/A'],
            ]),
        ...operationalSkills.entries.expand((e) => [
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeParseString(e.value['self_rating']) ?? 'N/A'],
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeParseString(e.value['appraiser_rating']) ?? 'N/A'],
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} Description', _safeParseString(e.value['description']) ?? 'N/A'],
              ['Operational Skills', '${e.key.replaceAll('_', ' ').toTitleCase()} Comments', _safeParseString(e.value['comments']) ?? 'N/A'],
            ]),
        ..._buildCsvRows('Compliance Questions', [
          ['Compliance Training', appraisal['compliance_training'] == '1' ? 'Yes' : 'No'],
          ['Safeguards Company Assets', appraisal['internal_controls'] == '1' ? 'Yes' : 'No'],
        ]),
        ...improvementPlan.asMap().entries.expand((entry) => [
              ['Improvement Plan', 'Entry ${entry.key + 1}: Area', _safeParseString(entry.value['area']) ?? 'N/A'],
              ['Improvement Plan', 'Entry ${entry.key + 1}: Action', _safeParseString(entry.value['action']) ?? 'N/A'],
              ['Improvement Plan', 'Entry ${entry.key + 1}: Goal', _safeParseString(entry.value['goal']) ?? 'N/A'],
              ['Improvement Plan', 'Entry ${entry.key + 1}: Timing', _safeParseString(entry.value['timing']) ?? 'N/A'],
            ]),
        ..._buildCsvRows('Career Development', [
          ['Career Objectives', _safeParseString(appraisal['career_objectives']) ?? 'N/A'],
          ['Long-Term Objectives', _safeParseString(appraisal['long_term_objectives']) ?? 'N/A'],
          ['Job Targets', _safeParseString(appraisal['job_targets']) ?? 'N/A'],
          ['Development Needs', _safeParseString(appraisal['development_needs']) ?? 'N/A'],
          ['Work Exposure', _safeParseString(appraisal['work_exposure']) ?? 'N/A'],
          ['Training Required', _safeParseString(appraisal['training_required']) ?? 'N/A'],
          ['Promotion Possibilities', _safeParseString(appraisal['promotion_possibilities']) ?? 'N/A'],
          ['Additional Responsibilities', _safeParseString(appraisal['additional_responsibilities']) ?? 'N/A'],
        ]),
        ..._buildCsvRows('Summary', [
          ['Overall Self Rating', _safeParseString(appraisal['overall_rating_self']) ?? 'N/A'],
          ['Overall Appraiser Rating', _safeParseString(appraisal['overall_rating_appraiser']) ?? 'N/A'],
          ['Appraisee Comments', _safeParseString(appraisal['appraisee_comments']) ?? 'N/A'],
          ['Appraiser Comments', _safeParseString(appraisal['appraiser_comments']) ?? 'N/A'],
          ['General Manager Comments', _safeParseString(appraisal['general_manager_comments']) ?? 'N/A'],
          ['Appraisee Signature', _safeParseString(appraisal['appraisee_signature']) ?? 'N/A'],
          ['Appraiser Signature', _safeParseString(appraisal['appraiser_signature']) ?? 'N/A'],
          ['General Manager Signature', _safeParseString(appraisal['general_manager_signature']) ?? 'N/A'],
        ]),
      ];

      final String csv = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/appraisal_$appraisalId.csv');
      await file.writeAsString(csv);
      if (!context.mounted) return;
      _showSuccessSnackBar(context, 'CSV exported to ${file.path}');
    } catch (e) {
      errorMessage = 'Failed to export CSV: $e';
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage!);
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
      final appraisalId = _safeParseString(appraisal['appraisal_id']) ?? 'unknown';

      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Appraisal'];
      sheet.appendRow([
        excel.TextCellValue('Section'),
        excel.TextCellValue('Field'),
        excel.TextCellValue('Value')
      ]);

      void addRow(String section, String field, String value) {
        sheet.appendRow([
          excel.TextCellValue(section),
          excel.TextCellValue(field),
          excel.TextCellValue(value)
        ]);
      }

      addRow('Personal Details', 'Employee Name', _safeParseString(employeeName) ?? 'N/A');
      addRow('Personal Details', 'Position', _safeParseString(employeePosition) ?? 'N/A');
      addRow('Personal Details', 'Employee ID', _safeParseString(appraisal['employee_id']) ?? 'N/A');
      addRow('Personal Details', 'Company ID', _safeParseString(appraisal['company_id']) ?? 'N/A');
      addRow('Personal Details', 'Period', _safeParseString(appraisal['period']) ?? 'N/A');
      addRow('Personal Details', 'Status', _safeParseString(appraisal['status']) ?? 'N/A');
      addRow('Personal Details', 'Designation', _safeParseString(appraisal['designation']) ?? 'N/A');
      addRow('Personal Details', 'Period Under Review', _safeParseString(appraisal['period_under_review']) ?? 'N/A');
      addRow('Personal Details', 'Last Appraisal Date', _safeParseString(appraisal['last_appraisal_date']) ?? 'N/A');
      addRow('Personal Details', 'Date of Joining', _safeParseString(appraisal['date_of_joining']) ?? 'N/A');
      addRow('Personal Details', 'Date of Appointment', _safeParseString(appraisal['date_of_appointment']) ?? 'N/A');
      addRow('Personal Details', 'Appraiser Name', _safeParseString(appraisal['appraiser_name']) ?? 'N/A');
      addRow('Personal Details', 'Appraiser Position', _safeParseString(appraisal['appraiser_position']) ?? 'N/A');
      addRow('Performance Indicators', 'Awards', _safeParseString(appraisal['awards']) ?? 'N/A');
      addRow('Performance Indicators', 'Recommendations', _safeParseString(appraisal['recommendations']) ?? 'N/A');
      addRow('Performance Indicators', 'Training Attended', _safeParseString(appraisal['training_attended']) ?? 'N/A');
      addRow('Performance Indicators', 'Valid Warnings', _safeParseString(appraisal['number_valid_warnings']) ?? 'N/A');
      addRow('Performance Indicators', 'Absentee Days', _safeParseString(appraisal['absentee_days']) ?? 'N/A');
      addRow('Performance Indicators', 'Sick Days', _safeParseString(appraisal['sick_offs']) ?? 'N/A');
      personalAttributes.forEach((key, value) {
        addRow('Personal Attributes', '${key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeParseString(value['self_rating']) ?? 'N/A');
        addRow('Personal Attributes', '${key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeParseString(value['appraiser_rating']) ?? 'N/A');
        addRow('Personal Attributes', '${key.replaceAll('_', ' ').toTitleCase()} Comments', _safeParseString(value['comments']) ?? 'N/A');
      });
      operationalSkills.forEach((key, value) {
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} (Self Rating)', _safeParseString(value['self_rating']) ?? 'N/A');
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} (Appraiser Rating)', _safeParseString(value['appraiser_rating']) ?? 'N/A');
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} Description', _safeParseString(value['description']) ?? 'N/A');
        addRow('Operational Skills', '${key.replaceAll('_', ' ').toTitleCase()} Comments', _safeParseString(value['comments']) ?? 'N/A');
      });
      addRow('Compliance Questions', 'Compliance Training', appraisal['compliance_training'] == '1' ? 'Yes' : 'No');
      addRow('Compliance Questions', 'Safeguards Company Assets', appraisal['internal_controls'] == '1' ? 'Yes' : 'No');
      improvementPlan.asMap().forEach((index, entry) {
        addRow('Improvement Plan', 'Entry ${index + 1}: Area', _safeParseString(entry['area']) ?? 'N/A');
        addRow('Improvement Plan', 'Entry ${index + 1}: Action', _safeParseString(entry['action']) ?? 'N/A');
        addRow('Improvement Plan', 'Entry ${index + 1}: Goal', _safeParseString(entry['goal']) ?? 'N/A');
        addRow('Improvement Plan', 'Entry ${index + 1}: Timing', _safeParseString(entry['timing']) ?? 'N/A');
      });
      addRow('Career Development', 'Career Objectives', _safeParseString(appraisal['career_objectives']) ?? 'N/A');
      addRow('Career Development', 'Long-Term Objectives', _safeParseString(appraisal['long_term_objectives']) ?? 'N/A');
      addRow('Career Development', 'Job Targets', _safeParseString(appraisal['job_targets']) ?? 'N/A');
      addRow('Career Development', 'Development Needs', _safeParseString(appraisal['development_needs']) ?? 'N/A');
      addRow('Career Development', 'Work Exposure', _safeParseString(appraisal['work_exposure']) ?? 'N/A');
      addRow('Career Development', 'Training Required', _safeParseString(appraisal['training_required']) ?? 'N/A');
      addRow('Career Development', 'Promotion Possibilities', _safeParseString(appraisal['promotion_possibilities']) ?? 'N/A');
      addRow('Career Development', 'Additional Responsibilities', _safeParseString(appraisal['additional_responsibilities']) ?? 'N/A');
      addRow('Summary', 'Overall Self Rating', _safeParseString(appraisal['overall_rating_self']) ?? 'N/A');
      addRow('Summary', 'Overall Appraiser Rating', _safeParseString(appraisal['overall_rating_appraiser']) ?? 'N/A');
      addRow('Summary', 'Appraisee Comments', _safeParseString(appraisal['appraisee_comments']) ?? 'N/A');
      addRow('Summary', 'Appraiser Comments', _safeParseString(appraisal['appraiser_comments']) ?? 'N/A');
      addRow('Summary', 'General Manager Comments', _safeParseString(appraisal['general_manager_comments']) ?? 'N/A');
      addRow('Summary', 'Appraisee Signature', _safeParseString(appraisal['appraisee_signature']) ?? 'N/A');
      addRow('Summary', 'Appraiser Signature', _safeParseString(appraisal['appraiser_signature']) ?? 'N/A');
      addRow('Summary', 'General Manager Signature', _safeParseString(appraisal['general_manager_signature']) ?? 'N/A');

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/appraisal_$appraisalId.xlsx');
      await file.writeAsBytes(workbook.encode()!);
      if (!context.mounted) return;
      _showSuccessSnackBar(context, 'Excel exported to ${file.path}');
    } catch (e) {
      errorMessage = 'Failed to export Excel: $e';
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage!);
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
        pw.TableHelper.fromTextArray(
          headers: headers ?? ['Field', 'Value'],
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 12),
          border: pw.TableBorder.all(color: PdfColors.blue),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
      ],
    );
  }

  List<List<String>> _buildCsvRows(String section, List<List<String>> data) {
    return data.map((row) => [section, row[0], row[1]]).toList();
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppraisalDetailConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppraisalDetailConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

class _AppraisalDetailViewState extends State<_AppraisalDetailView> {
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

  // Helper method to safely parse strings
  String? _safeParseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
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
    final isManagerOrAbove = ['manager', 'operator', 'director'].contains(widget.user.role);
    final isPending = _safeParseString(widget.appraisal['status'])?.toLowerCase() == 'pending';

    return Scaffold(
      backgroundColor: AppraisalDetailConstants.backgroundColor,
      appBar: _buildAppBar(context, provider),
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeaderSection(),
                  const SizedBox(height: 16),
                  
                  // Appraisal Sections
                  _buildSection(
                    title: 'Personal Details',
                    sectionKey: 'personal',
                    icon: Icons.person,
                    children: [
                      _buildInfoRow('Employee ID', _safeParseString(widget.appraisal['employee_id']) ?? 'N/A'),
                      _buildInfoRow('Company ID', _safeParseString(widget.appraisal['company_id']) ?? 'N/A'),
                      _buildInfoRow('Period', _safeParseString(widget.appraisal['period']) ?? 'N/A'),
                      _buildInfoRow('Status', _safeParseString(widget.appraisal['status']) ?? 'N/A', isStatus: true),
                      _buildInfoRow('Designation', _safeParseString(widget.appraisal['designation']) ?? 'N/A'),
                      _buildInfoRow('Period Under Review', _safeParseString(widget.appraisal['period_under_review']) ?? 'N/A'),
                      _buildInfoRow('Last Appraisal Date', _safeParseString(widget.appraisal['last_appraisal_date']) ?? 'N/A'),
                      _buildInfoRow('Date of Joining', _safeParseString(widget.appraisal['date_of_joining']) ?? 'N/A'),
                      _buildInfoRow('Date of Appointment', _safeParseString(widget.appraisal['date_of_appointment']) ?? 'N/A'),
                      _buildInfoRow('Appraiser Name', _safeParseString(widget.appraisal['appraiser_name']) ?? 'N/A'),
                      _buildInfoRow('Appraiser Position', _safeParseString(widget.appraisal['appraiser_position']) ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSection(
                    title: 'Performance Indicators',
                    sectionKey: 'performance',
                    icon: Icons.assessment,
                    children: [
                      _buildInfoRow('Awards', _safeParseString(widget.appraisal['awards']) ?? 'N/A'),
                      _buildInfoRow('Recommendations', _safeParseString(widget.appraisal['recommendations']) ?? 'N/A'),
                      _buildInfoRow('Training Attended', _safeParseString(widget.appraisal['training_attended']) ?? 'N/A'),
                      _buildInfoRow('Valid Warnings', _safeParseString(widget.appraisal['number_valid_warnings']) ?? 'N/A'),
                      _buildInfoRow('Absentee Days', _safeParseString(widget.appraisal['absentee_days']) ?? 'N/A'),
                      _buildInfoRow('Sick Days', _safeParseString(widget.appraisal['sick_offs']) ?? 'N/A'),
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
                                  _safeParseString(e.value['self_rating']) ?? 'N/A',
                                  _safeParseString(e.value['appraiser_rating']) ?? 'N/A',
                                  _safeParseString(e.value['comments']) ?? 'N/A',
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
                                  _safeParseString(e.value['self_rating']) ?? 'N/A',
                                  _safeParseString(e.value['appraiser_rating']) ?? 'N/A',
                                  _safeParseString(e.value['description']) ?? 'N/A',
                                  _safeParseString(e.value['comments']) ?? 'N/A',
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
                                  _safeParseString(entry['area']) ?? 'N/A',
                                  _safeParseString(entry['action']) ?? 'N/A',
                                  _safeParseString(entry['goal']) ?? 'N/A',
                                  _safeParseString(entry['timing']) ?? 'N/A',
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
                      _buildInfoRow('Career Objectives', _safeParseString(widget.appraisal['career_objectives']) ?? 'N/A'),
                      _buildInfoRow('Long-Term Objectives', _safeParseString(widget.appraisal['long_term_objectives']) ?? 'N/A'),
                      _buildInfoRow('Job Targets', _safeParseString(widget.appraisal['job_targets']) ?? 'N/A'),
                      _buildInfoRow('Development Needs', _safeParseString(widget.appraisal['development_needs']) ?? 'N/A'),
                      _buildInfoRow('Work Exposure', _safeParseString(widget.appraisal['work_exposure']) ?? 'N/A'),
                      _buildInfoRow('Training Required', _safeParseString(widget.appraisal['training_required']) ?? 'N/A'),
                      _buildInfoRow('Promotion Possibilities', _safeParseString(widget.appraisal['promotion_possibilities']) ?? 'N/A'),
                      _buildInfoRow('Additional Responsibilities', _safeParseString(widget.appraisal['additional_responsibilities']) ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSection(
                    title: 'Summary',
                    sectionKey: 'summary',
                    icon: Icons.summarize,
                    children: [
                      _buildInfoRow('Overall Self Rating', _safeParseString(widget.appraisal['overall_rating_self']) ?? 'N/A'),
                      _buildInfoRow('Overall Appraiser Rating', _safeParseString(widget.appraisal['overall_rating_appraiser']) ?? 'N/A'),
                      _buildInfoRow('Appraisee Comments', _safeParseString(widget.appraisal['appraisee_comments']) ?? 'N/A'),
                      _buildInfoRow('Appraiser Comments', _safeParseString(widget.appraisal['appraiser_comments']) ?? 'N/A'),
                      _buildInfoRow('General Manager Comments', _safeParseString(widget.appraisal['general_manager_comments']) ?? 'N/A'),
                      _buildInfoRow('Appraisee Signature', _safeParseString(widget.appraisal['appraisee_signature']) ?? 'N/A'),
                      _buildInfoRow('Appraiser Signature', _safeParseString(widget.appraisal['appraiser_signature']) ?? 'N/A'),
                      _buildInfoRow('General Manager Signature', _safeParseString(widget.appraisal['general_manager_signature']) ?? 'N/A'),
                    ],
                  ),
                  
                  // Action Buttons for Managers/Admins
                  if (isManagerOrAbove && isPending) ...[
                    const SizedBox(height: 24),
                    _buildActionButtons(context, provider),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Loading Overlay
          if (provider.isExporting || provider.isUpdating)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppraisalDetailConstants.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      provider.isExporting ? 'Exporting...' : 'Updating...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppraisalDetailProvider provider) {
    return AppBar(
      title: Text(
        'Appraisal Details',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppraisalDetailConstants.primaryColor,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download, color: Colors.white, size: 24),
          tooltip: 'Export Appraisal',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'PDF',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: AppraisalDetailConstants.primaryColor),
                  const SizedBox(width: 8),
                  Text('Export as PDF', style: TextStyle(color: AppraisalDetailConstants.textColor)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'CSV',
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: AppraisalDetailConstants.primaryColor),
                  const SizedBox(width: 8),
                  Text('Export as CSV', style: TextStyle(color: AppraisalDetailConstants.textColor)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'Excel',
              child: Row(
                children: [
                  Icon(Icons.table_view, color: AppraisalDetailConstants.primaryColor),
                  const SizedBox(width: 8),
                  Text('Export as Excel', style: TextStyle(color: AppraisalDetailConstants.textColor)),
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
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppraisalDetailConstants.primaryColor, AppraisalDetailConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assessment,
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
                      widget.employeeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.employeePosition,
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
          const SizedBox(height: 12),
          _buildStatusBadge(_safeParseString(widget.appraisal['status']) ?? 'Unknown'),
        ],
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: AppraisalDetailConstants.primaryColor, size: 24),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppraisalDetailConstants.textColor,
          ),
        ),
        iconColor: AppraisalDetailConstants.primaryColor,
        collapsedIconColor: AppraisalDetailConstants.primaryColor,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppraisalDetailConstants.textColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: isStatus
                ? _buildStatusBadge(value)
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppraisalDetailConstants.subtitleColor,
                    ),
                    softWrap: true,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDataTable({
    required List<String> headers,
    required List<List<String>> data,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 48,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 56,
        headingRowColor: WidgetStateProperty.all(AppraisalDetailConstants.backgroundColor),
        headingTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppraisalDetailConstants.textColor,
        ),
        dataTextStyle: TextStyle(
          fontSize: 12,
          color: AppraisalDetailConstants.subtitleColor,
        ),
        columns: headers
            .map(
              (header) => DataColumn(
                label: Text(
                  header,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        rows: data
            .map(
              (row) => DataRow(
                cells: row
                    .map(
                      (cell) => DataCell(
                        Text(
                          cell,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppraisalDetailProvider provider) {
    return Row(
      children: [
        Expanded(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalDetailConstants.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: provider.isUpdating
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 20),
                      const SizedBox(width: 8),
                      Text('Approve', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalDetailConstants.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: provider.isUpdating
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, size: 20),
                      const SizedBox(width: 8),
                      Text('Reject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
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
        backgroundColor: AppraisalDetailConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppraisalDetailConstants.textColor,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: AppraisalDetailConstants.subtitleColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppraisalDetailConstants.subtitleColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'Approved' ? AppraisalDetailConstants.successColor : AppraisalDetailConstants.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              provider.updateStatus(
                context: context,
                apiService: widget.apiService,
                appraisalId: _safeParseString(widget.appraisal['appraisal_id']) ?? '',
                status: status,
                companyId: widget.user.companyId,
              );
              Navigator.pop(context);
            },
            child: Text(
              status,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppraisalDetailConstants.successColor;
      case 'pending':
        return AppraisalDetailConstants.warningColor;
      case 'rejected':
        return AppraisalDetailConstants.errorColor;
      default:
        return AppraisalDetailConstants.greyColor;
    }
  }
}

// String extension for title case
extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }
}