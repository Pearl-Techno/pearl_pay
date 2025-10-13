import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// PAYEExport: Component for displaying and exporting PAYE data
class PAYEExport {
  final String title = 'PAYE Export';
  final IconData icon = Icons.account_balance;
  final Map<String, dynamic> user;
  final ApiService apiService;
  final int? companyId; // Explicit company ID for restriction

  PAYEExport({
    required this.user,
    required this.apiService,
    this.companyId,
  });

  // Build Card: Creates a clickable card for the ExportsScreen
  Widget buildCard(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal[700]),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.teal[900],
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.file_download, color: Colors.teal[700]),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => buildDetailsPage(context)),
          );
        },
      ),
    );
  }

  // Build Details Page: Creates the PAYE export details page
  Widget buildDetailsPage(BuildContext context) {
    return _PAYEExportDetailsPage(
      apiService: apiService,
      user: user,
      companyId: companyId,
    );
  }

  // Export: Generates a full PAYE CSV for the current month/year
  Future<String> export() async {
    if (companyId == null) {
      throw Exception('No company ID provided for export');
    }
    final companyName = user['company_name']?.toString() ?? 'Unknown';
    final month = DateTime.now().month;
    final year = DateTime.now().year;
    final employees = await _fetchPAYEDataForExport(
      apiService: apiService,
      companyId: companyId!,
      month: month,
      year: year,
      companyName: companyName,
    );
    return await _exportPAYEToCSV(
      employees: employees,
      exportType: 'full',
      companyName: companyName,
      year: year,
      month: month,
      apiService: apiService,
      companyId: companyId!,
    );
  }

  // Fetch PAYE Data for Export: Retrieves and filters employee and salary data
  static Future<List<Map<String, dynamic>>> _fetchPAYEDataForExport({
    required ApiService apiService,
    required int companyId,
    required int month,
    required int year,
    required String companyName,
  }) async {
    try {
      final employees = await apiService.getEmployeeList(companyId);
      final salaries = await apiService.getSalaries(companyId);

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == month &&
            paymentDate.year == year;
        final hasPAYE =
            (double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && hasPAYE;
      }).toList();

      final payeEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        return payeEmployeeIds.contains(employee['employee_id'].toString());
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        return {
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'fullname': employee['fullname'] ?? 'N/A',
          'company_id': employee['company_id'] ?? companyId,
          'company_name': employee['company_name']?.toString() ?? companyName,
          'resident_status': 'RESIDENT',
          'type_of_employee': 'PRIMARY EMPLOYEE',
          'basic_salary': salary['basic_pay']?.toString() ?? '0.0',
          'house_allowance': employee['house_allowance']?.toString() ?? '0.0',
          'transport_allowance': salary['transport']?.toString() ?? '0.0',
          'leave_pay': '0',
          'overtime_allowance': salary['overtime_amount']?.toString() ?? '0.0',
          'directors_fee': '0',
          'lumpsum_payment': '0',
          'any_other_allowance': salary['other_earnings']?.toString() ?? '0.0',
          'total_cash_pay': _calculateTotalCashPay(salary, employee),
          'value_of_car_benefit': '0',
          'other_non_cash_benefits':
              salary['non_cash_benefits']?.toString() ?? '0.0',
          'total_non_cash_benefits':
              salary['non_cash_benefits']?.toString() ?? '0.0',
          'value_of_meals': '0',
          'type_of_housing': 'BENEFIT NOT GIVEN',
          'rent_of_house': '0',
          'computed_rent_of_house': '0',
          'rent_recovered_from_employee': '0',
          'net_value_of_the_house': '0',
          'total_gross_pay': salary['gross_pay']?.toString() ?? '0.0',
          'shif': salary['nhif_deduction']?.toString() ?? '0.0',
          'nssf': salary['nssf_deduction']?.toString() ?? '0.0',
          'post_retirement_medication_fund': '0',
          'mortgage_interest': '0',
          'housing_levy': salary['housing_levy']?.toString() ?? '0.0',
          'actual_benefits': _calculateActualBenefits(salary),
          'taxable_pay': salary['taxable_income']?.toString() ?? '0.0',
          'tax_payable_before_reliefs': _calculateTaxBeforeReliefs(salary),
          'monthly_personal_relief': '2400.00',
          'insurance_relief': '0',
          'leave_blank': '',
          'paye': salary['paye_deduction']?.toString() ?? '0.0',
        };
      }).toList();

      if (kDebugMode) {
        print('Fetched PAYE data for export: $companyName ($companyId)');
        print('Filtered employees: ${filteredEmployees.length}');
      }

      return filteredEmployees;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching PAYE data for export: $e');
      }
      throw Exception('Failed to load PAYE data: $e');
    }
  }

  // Export PAYE to CSV: Generates CSV for PAYE data
  static Future<String> _exportPAYEToCSV({
    required List<Map<String, dynamic>> employees,
    required String exportType,
    required String companyName,
    required int year,
    required int month,
    required ApiService apiService,
    required int companyId,
  }) async {
    if (employees.isEmpty) {
      throw Exception('No data available to export');
    }

    try {
      List<List<dynamic>> rows;
      String fileName;

      final numberFormat = NumberFormat('#,##0.00', 'en_US');
      final monthYear = DateFormat('MMM_yyyy').format(DateTime(year, month));
      final sanitizedCompanyName = companyName.replaceAll(' ', '_');

      if (exportType == 'summary') {
        final totalPAYE = employees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(employee['paye']?.toString() ?? '0.0') ??
                    0.0));
        final totalGrossPay = employees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(
                        employee['total_gross_pay']?.toString() ?? '0.0') ??
                    0.0));
        final totalTaxablePay = employees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(
                        employee['taxable_pay']?.toString() ?? '0.0') ??
                    0.0));

        rows = [
          [
            'Total Employees',
            'Total Gross Pay',
            'Total Taxable Pay',
            'Total PAYE'
          ],
          [
            employees.length,
            numberFormat.format(totalGrossPay),
            numberFormat.format(totalTaxablePay),
            numberFormat.format(totalPAYE),
          ],
        ];
        fileName = 'paye_summary_${sanitizedCompanyName}_$monthYear.csv';
      } else if (exportType == 'annual') {
        final allSalaries = await apiService.getSalaries(companyId);
        final annualSalaries = allSalaries.where((salary) {
          final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
          final matchesYear = paymentDate != null && paymentDate.year == year;
          final hasPAYE =
              (double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ??
                      0.0) >
                  0;
          return matchesYear && hasPAYE;
        }).toList();

        final annualEmployeeIds = annualSalaries
            .map((salary) => salary['employee_id'].toString())
            .toSet();

        final annualEmployees = employees.where((employee) {
          return annualEmployeeIds.contains(employee['employee_id'].toString());
        }).map((employee) {
          final employeeSalaries = annualSalaries
              .where((s) =>
                  s['employee_id'].toString() ==
                  employee['employee_id'].toString())
              .toList();
          final totalBasic = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['basic_pay']?.toString() ?? '0.0') ??
                      0.0));
          final totalTransport = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['transport']?.toString() ?? '0.0') ??
                      0.0));
          final totalOvertime = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['overtime_amount']?.toString() ?? '0.0') ??
                      0.0));
          final totalOther = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['other_earnings']?.toString() ?? '0.0') ??
                      0.0));
          final totalGross = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['gross_pay']?.toString() ?? '0.0') ??
                      0.0));
          final totalNHIF = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['nhif_deduction']?.toString() ?? '0.0') ??
                      0.0));
          final totalNSSF = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['nssf_deduction']?.toString() ?? '0.0') ??
                      0.0));
          final totalHousingLevy = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['housing_levy']?.toString() ?? '0.0') ??
                      0.0));
          final totalTaxable = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['taxable_income']?.toString() ?? '0.0') ??
                      0.0));
          final totalPAYE = employeeSalaries.fold<double>(
              0.0,
              (sum, s) =>
                  sum +
                  (double.tryParse(s['paye_deduction']?.toString() ?? '0.0') ??
                      0.0));

          return {
            'kra_pin': employee['kra_pin'] ?? 'N/A',
            'fullname': employee['fullname'] ?? 'N/A',
            'resident_status': 'RESIDENT',
            'type_of_employee': 'PRIMARY EMPLOYEE',
            'basic_salary': totalBasic.toStringAsFixed(2),
            'house_allowance': employee['house_allowance']?.toString() ?? '0.0',
            'transport_allowance': totalTransport.toStringAsFixed(2),
            'leave_pay': '0',
            'overtime_allowance': totalOvertime.toStringAsFixed(2),
            'directors_fee': '0',
            'lumpsum_payment': '0',
            'any_other_allowance': totalOther.toStringAsFixed(2),
            'total_cash_pay':
                (totalBasic + totalTransport + totalOvertime + totalOther)
                    .toStringAsFixed(2),
            'value_of_car_benefit': '0',
            'other_non_cash_benefits': '0',
            'total_non_cash_benefits': '0',
            'value_of_meals': '0',
            'type_of_housing': 'BENEFIT NOT GIVEN',
            'rent_of_house': '0',
            'computed_rent_of_house': '0',
            'rent_recovered_from_employee': '0',
            'net_value_of_the_house': '0',
            'total_gross_pay': totalGross.toStringAsFixed(2),
            'shif': totalNHIF.toStringAsFixed(2),
            'nssf': totalNSSF.toStringAsFixed(2),
            'post_retirement_medication_fund': '0',
            'mortgage_interest': '0',
            'housing_levy': totalHousingLevy.toStringAsFixed(2),
            'actual_benefits': totalHousingLevy.toStringAsFixed(2),
            'taxable_pay': totalTaxable.toStringAsFixed(2),
            'tax_payable_before_reliefs':
                (totalPAYE + 2400.00 * 12).toStringAsFixed(2),
            'monthly_personal_relief': (2400.00 * 12).toStringAsFixed(2),
            'insurance_relief': '0',
            'leave_blank': '',
            'paye': totalPAYE.toStringAsFixed(2),
            'company_name': employee['company_name']?.toString() ?? companyName,
          };
        }).toList();

        rows = [
          [
            'KRA PIN',
            'Fullname',
            'Resident Status',
            'Type of employee',
            'Basic salary',
            'House Allowance',
            'Transport Allowance',
            'Leave Pay',
            'Overtime Allowance',
            'Directors fee',
            'Lumpsum payment if any',
            'Any other allowance',
            'Total Cash pay',
            'Value of car benefit',
            'Other non cash benefits',
            'Total non cash benefits',
            'Value of meals',
            'Type of housing',
            'Rent of house',
            'Computed rent of house',
            'Rent recovered from employee',
            'Net value of the house',
            'Total gross pay',
            'Shif',
            'NSSF',
            'Post Retirement medication fund',
            'Mortgage Interest',
            'Housing levy',
            'Actual benefits',
            'Taxable pay',
            'Tax payable before reliefs',
            'Monthly personal relief',
            'Insurance relief',
            'Leave blank',
            'PAYE',
            'Company Name'
          ],
          ...annualEmployees.map((employee) {
            return [
              employee['kra_pin'],
              employee['fullname'],
              employee['resident_status'],
              employee['type_of_employee'],
              numberFormat.format(
                  double.tryParse(employee['basic_salary'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['house_allowance'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['transport_allowance'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['leave_pay'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['overtime_allowance'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['directors_fee'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['lumpsum_payment'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['any_other_allowance'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['total_cash_pay'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['value_of_car_benefit'] ?? '0.0') ??
                      0.0),
              numberFormat.format(double.tryParse(
                      employee['other_non_cash_benefits'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['total_non_cash_benefits'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['value_of_meals'] ?? '0.0') ?? 0.0),
              employee['type_of_housing'],
              numberFormat.format(
                  double.tryParse(employee['rent_of_house'] ?? '0.0') ?? 0.0),
              numberFormat.format(double.tryParse(
                      employee['computed_rent_of_house'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['rent_recovered_from_employee'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['net_value_of_the_house'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['total_gross_pay'] ?? '0.0') ?? 0.0),
              numberFormat
                  .format(double.tryParse(employee['shif'] ?? '0.0') ?? 0.0),
              numberFormat
                  .format(double.tryParse(employee['nssf'] ?? '0.0') ?? 0.0),
              numberFormat.format(double.tryParse(
                      employee['post_retirement_medication_fund'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['mortgage_interest'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['housing_levy'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['actual_benefits'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['taxable_pay'] ?? '0.0') ?? 0.0),
              numberFormat.format(double.tryParse(
                      employee['tax_payable_before_reliefs'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['monthly_personal_relief'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['insurance_relief'] ?? '0.0') ??
                      0.0),
              employee['leave_blank'],
              numberFormat
                  .format(double.tryParse(employee['paye'] ?? '0.0') ?? 0.0),
              employee['company_name'],
            ];
          }),
        ];
        fileName = 'paye_annual_${sanitizedCompanyName}_$year.csv';
      } else {
        rows = [
          [
            'KRA PIN',
            'Fullname',
            'Resident Status',
            'Type of employee',
            'Basic salary',
            'House Allowance',
            'Transport Allowance',
            'Leave Pay',
            'Overtime Allowance',
            'Directors fee',
            'Lumpsum payment if any',
            'Any other allowance',
            'Total Cash pay',
            'Value of car benefit',
            'Other non cash benefits',
            'Total non cash benefits',
            'Value of meals',
            'Type of housing',
            'Rent of house',
            'Computed rent of house',
            'Rent recovered from employee',
            'Net value of the house',
            'Total gross pay',
            'Shif',
            'NSSF',
            'Post Retirement medication fund',
            'Mortgage Interest',
            'Housing levy',
            'Actual benefits',
            'Taxable pay',
            'Tax payable before reliefs',
            'Monthly personal relief',
            'Insurance relief',
            'Leave blank',
            'PAYE',
            'Company Name'
          ],
          ...employees.map((employee) {
            return [
              employee['kra_pin'],
              employee['fullname'],
              employee['resident_status'],
              employee['type_of_employee'],
              numberFormat.format(
                  double.tryParse(employee['basic_salary'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['house_allowance'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['transport_allowance'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['leave_pay'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['overtime_allowance'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['directors_fee'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['lumpsum_payment'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['any_other_allowance'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['total_cash_pay'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['value_of_car_benefit'] ?? '0.0') ??
                      0.0),
              numberFormat.format(double.tryParse(
                      employee['other_non_cash_benefits'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['total_non_cash_benefits'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['value_of_meals'] ?? '0.0') ?? 0.0),
              employee['type_of_housing'],
              numberFormat.format(
                  double.tryParse(employee['rent_of_house'] ?? '0.0') ?? 0.0),
              numberFormat.format(double.tryParse(
                      employee['computed_rent_of_house'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['rent_recovered_from_employee'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['net_value_of_the_house'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['total_gross_pay'] ?? '0.0') ?? 0.0),
              numberFormat
                  .format(double.tryParse(employee['shif'] ?? '0.0') ?? 0.0),
              numberFormat
                  .format(double.tryParse(employee['nssf'] ?? '0.0') ?? 0.0),
              numberFormat.format(double.tryParse(
                      employee['post_retirement_medication_fund'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['mortgage_interest'] ?? '0.0') ??
                      0.0),
              numberFormat.format(
                  double.tryParse(employee['housing_levy'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['actual_benefits'] ?? '0.0') ?? 0.0),
              numberFormat.format(
                  double.tryParse(employee['taxable_pay'] ?? '0.0') ?? 0.0),
              numberFormat.format(double.tryParse(
                      employee['tax_payable_before_reliefs'] ?? '0.0') ??
                  0.0),
              numberFormat.format(double.tryParse(
                      employee['monthly_personal_relief'] ?? '0.0') ??
                  0.0),
              numberFormat.format(
                  double.tryParse(employee['insurance_relief'] ?? '0.0') ??
                      0.0),
              employee['leave_blank'],
              numberFormat
                  .format(double.tryParse(employee['paye'] ?? '0.0') ?? 0.0),
              employee['company_name'],
            ];
          }),
        ];
        fileName = 'paye_export_${sanitizedCompanyName}_$monthYear.csv';
      }

      final csv = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export: $e');
    }
  }

  // Calculate Total Cash Pay
  static String _calculateTotalCashPay(
      Map<String, dynamic> salary, Map<String, dynamic> employee) {
    final basic =
        double.tryParse(salary['basic_pay']?.toString() ?? '0.0') ?? 0.0;
    final house =
        double.tryParse(employee['house_allowance']?.toString() ?? '0.0') ??
            0.0;
    final transport =
        double.tryParse(salary['transport']?.toString() ?? '0.0') ?? 0.0;
    final overtime =
        double.tryParse(salary['overtime_amount']?.toString() ?? '0.0') ?? 0.0;
    final other =
        double.tryParse(salary['other_earnings']?.toString() ?? '0.0') ?? 0.0;
    return (basic + house + transport + overtime + other).toStringAsFixed(2);
  }

  // Calculate Actual Benefits
  static String _calculateActualBenefits(Map<String, dynamic> salary) {
    final housingLevy =
        double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ?? 0.0;
    final nonCashBenefits =
        double.tryParse(salary['non_cash_benefits']?.toString() ?? '0.0') ??
            0.0;
    return (housingLevy + nonCashBenefits).toStringAsFixed(2);
  }

  // Calculate Tax Before Reliefs
  static String _calculateTaxBeforeReliefs(Map<String, dynamic> salary) {
    final taxablePay =
        double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0;
    final paye =
        double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ?? 0.0;
    const relief = 2400.00; // Monthly personal relief (Kenya, as of 2023)
    return (paye + relief).toStringAsFixed(2);
  }
}

class _PAYEExportDetailsPage extends StatefulWidget {
  final ApiService apiService;
  final Map<String, dynamic> user;
  final int? companyId;

  const _PAYEExportDetailsPage({
    required this.apiService,
    required this.user,
    this.companyId,
  });

  @override
  _PAYEExportDetailsPageState createState() => _PAYEExportDetailsPageState();
}

class _PAYEExportDetailsPageState extends State<_PAYEExportDetailsPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  String searchKeyword = '';
  late int effectiveCompanyId;
  late String companyName;

  @override
  void initState() {
    super.initState();
    // Validate company ID
    effectiveCompanyId = widget.companyId ??
        (widget.user['company_id'] != null
            ? int.tryParse(widget.user['company_id'].toString()) ?? 0
            : 0);
    companyName = widget.user['company_name']?.toString() ?? 'Unknown';
    if (effectiveCompanyId == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: No valid company ID')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _fetchPAYEData();
  }

  // Fetch PAYE Data: Retrieves and filters employee and salary data
  Future<void> _fetchPAYEData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employees =
          await widget.apiService.getEmployeeList(effectiveCompanyId);
      final salaries = await widget.apiService.getSalaries(effectiveCompanyId);

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == selectedMonth &&
            paymentDate.year == selectedYear;
        final hasPAYE =
            (double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && hasPAYE;
      }).toList();

      final payeEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        final matchesSearch = searchKeyword.isEmpty ||
            (employee['fullname'] ?? '').toLowerCase().contains(searchKeyword);
        return payeEmployeeIds.contains(employee['employee_id'].toString()) &&
            matchesSearch;
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        return {
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'fullname': employee['fullname'] ?? 'N/A',
          'company_id': employee['company_id'] ?? effectiveCompanyId,
          'company_name': employee['company_name']?.toString() ?? companyName,
          'resident_status': 'RESIDENT',
          'type_of_employee': 'PRIMARY EMPLOYEE',
          'basic_salary': salary['basic_pay']?.toString() ?? '0.0',
          'house_allowance': employee['house_allowance']?.toString() ?? '0.0',
          'transport_allowance': salary['transport']?.toString() ?? '0.0',
          'leave_pay': '0',
          'overtime_allowance': salary['overtime_amount']?.toString() ?? '0.0',
          'directors_fee': '0',
          'lumpsum_payment': '0',
          'any_other_allowance': salary['other_earnings']?.toString() ?? '0.0',
          'total_cash_pay': PAYEExport._calculateTotalCashPay(salary, employee),
          'value_of_car_benefit': '0',
          'other_non_cash_benefits':
              salary['non_cash_benefits']?.toString() ?? '0.0',
          'total_non_cash_benefits':
              salary['non_cash_benefits']?.toString() ?? '0.0',
          'value_of_meals': '0',
          'type_of_housing': 'BENEFIT NOT GIVEN',
          'rent_of_house': '0',
          'computed_rent_of_house': '0',
          'rent_recovered_from_employee': '0',
          'net_value_of_the_house': '0',
          'total_gross_pay': salary['gross_pay']?.toString() ?? '0.0',
          'shif': salary['nhif_deduction']?.toString() ?? '0.0',
          'nssf': salary['nssf_deduction']?.toString() ?? '0.0',
          'post_retirement_medication_fund': '0',
          'mortgage_interest': '0',
          'housing_levy': salary['housing_levy']?.toString() ?? '0.0',
          'actual_benefits': PAYEExport._calculateActualBenefits(salary),
          'taxable_pay': salary['taxable_income']?.toString() ?? '0.0',
          'tax_payable_before_reliefs':
              PAYEExport._calculateTaxBeforeReliefs(salary),
          'monthly_personal_relief': '2400.00',
          'insurance_relief': '0',
          'leave_blank': '',
          'paye': salary['paye_deduction']?.toString() ?? '0.0',
        };
      }).toList();

      setState(() {
        _employees = employees;
        _filteredEmployees = filteredEmployees;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
            'Fetched PAYE data for company: $companyName ($effectiveCompanyId)');
        print('Filtered employees: ${filteredEmployees.length}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load PAYE data: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching PAYE data: $e');
      }
    }
  }

  // Export to CSV: Exports PAYE data with customizable fields
  Future<String> _exportToCSV(String exportType) async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return '';
    }

    setState(() => _isExporting = true);

    try {
      final filePath = await PAYEExport._exportPAYEToCSV(
        employees: _filteredEmployees,
        exportType: exportType,
        companyName: companyName,
        year: selectedYear,
        month: selectedMonth,
        apiService: widget.apiService,
        companyId: effectiveCompanyId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
      return filePath;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _exportToCSV(exportType),
          ),
        ),
      );
      return '';
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // Filter Employees by Search Keyword
  void _filterEmployees(String keyword) {
    setState(() {
      searchKeyword = keyword.toLowerCase();
      _filteredEmployees = _employees.where((employee) {
        return (employee['fullname'] ?? '')
            .toLowerCase()
            .contains(searchKeyword);
      }).toList();
    });
  }

  // Build Dropdown: Creates a styled dropdown widget
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
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: CustomAppBar(
        title: 'PAYE Export',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) {
            print('Notifications tapped');
          }
        },
        onProfileTap: () {
          if (kDebugMode) {
            print('Profile tapped');
          }
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
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style:
                              TextStyle(color: Colors.teal[900], fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchPAYEData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
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
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.teal[200]!),
                                          ),
                                          child: Text(
                                            companyName,
                                            style: TextStyle(
                                              color: Colors.teal[900],
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDropdown(
                                          value: selectedMonth,
                                          items: List.generate(
                                              12, (index) => index + 1),
                                          itemBuilder: (month) =>
                                              DateFormat('MMMM').format(
                                                  DateTime(
                                                      selectedYear, month)),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedMonth = value!;
                                              _fetchPAYEData();
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDropdown(
                                          value: selectedYear,
                                          items: List.generate(
                                              10,
                                              (index) =>
                                                  DateTime.now().year - index),
                                          itemBuilder: (year) =>
                                              year.toString(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedYear = value!;
                                              _fetchPAYEData();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search by Employee Name',
                                      prefixIcon: Icon(Icons.search,
                                          color: Colors.teal[700]),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.teal[200]!)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.teal[200]!)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.teal[700]!)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: _filterEmployees,
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.teal[50]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _filteredEmployees.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          'No PAYE data available for selected filters',
                                          style: TextStyle(
                                              color: Colors.teal[900],
                                              fontSize: 16),
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: DataTable(
                                          columnSpacing: 12,
                                          dataRowHeight: 60,
                                          headingRowColor:
                                              MaterialStateProperty.all(
                                                  Colors.teal[100]),
                                          columns: const [
                                            DataColumn(
                                                label: Text('KRA PIN',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Fullname',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Resident Status',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Type of Employee',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Basic Salary',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('House Allowance',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Transport Allowance',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Leave Pay',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Overtime Allowance',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Directors Fee',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Lumpsum Payment',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Any Other Allowance',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Total Cash Pay',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Value of Car Benefit',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Other Non-Cash Benefits',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Total Non-Cash Benefits',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Value of Meals',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Type of Housing',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Rent of House',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Computed Rent of House',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Rent Recovered from Employee',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Net Value of the House',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Total Gross Pay',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('SHIF',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('NSSF',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Post Retirement Medication Fund',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Mortgage Interest',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Housing Levy',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Actual Benefits',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Taxable Pay',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Tax Payable Before Reliefs',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text(
                                                    'Monthly Personal Relief',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Insurance Relief',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Leave Blank',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('PAYE',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Company Name',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                          ],
                                          rows: _filteredEmployees
                                              .map((employee) {
                                            return DataRow(
                                              cells: [
                                                DataCell(Text(
                                                    employee['kra_pin'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['fullname'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['resident_status'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee[
                                                        'type_of_employee'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['basic_salary'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['house_allowance'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['transport_allowance'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['leave_pay'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['overtime_allowance'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['directors_fee'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['lumpsum_payment'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['any_other_allowance'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['total_cash_pay'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['value_of_car_benefit'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['other_non_cash_benefits'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['total_non_cash_benefits'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['value_of_meals'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['type_of_housing'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['rent_of_house'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['computed_rent_of_house'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['rent_recovered_from_employee'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['net_value_of_the_house'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['total_gross_pay'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['shif'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['nssf'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['post_retirement_medication_fund'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['mortgage_interest'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['housing_levy'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['actual_benefits'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['taxable_pay'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['tax_payable_before_reliefs'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['monthly_personal_relief'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['insurance_relief'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['leave_blank'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['paye'] ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['company_name'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_filteredEmployees.isNotEmpty)
                            Card(
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
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isExporting
                                            ? null
                                            : () => _exportToCSV('monthly'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: _isExporting
                                            ? const CircularProgressIndicator(
                                                color: Colors.white)
                                            : const Text('Export Monthly PAYE'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isExporting
                                            ? null
                                            : () => _exportToCSV('annual'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: _isExporting
                                            ? const CircularProgressIndicator(
                                                color: Colors.white)
                                            : const Text('Export Annual PAYE'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isExporting
                                            ? null
                                            : () => _exportToCSV('summary'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: _isExporting
                                            ? const CircularProgressIndicator(
                                                color: Colors.white)
                                            : const Text('Export Summary'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
