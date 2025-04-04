import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html
    if (kIsWeb) "universal_html.dart";

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class PaySalariesScreen extends StatefulWidget {
  const PaySalariesScreen({super.key});

  @override
  _PaySalariesScreenState createState() => _PaySalariesScreenState();
}

class _PaySalariesScreenState extends State<PaySalariesScreen> {
  final ApiService apiService = ApiService(client: http.Client());
  List<Map<String, dynamic>> salaries = [];
  bool isLoading = false;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  String? selectedCompany;
  List<String> companyNames = ['All Companies'];

  Map<String, bool> selectedEmployees = {};
  String searchKeyword = '';

  @override
  void initState() {
    super.initState();
    fetchCompanies();
  }

  Future<void> fetchCompanies() async {
    try {
      final employees = await apiService.getAllEmployees();
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

  Future<void> fetchAndCalculateSalaries() async {
    setState(() {
      isLoading = true;
      salaries.clear();
      selectedEmployees.clear();
    });

    try {
      final employees = await apiService.getAllEmployees();

      if (employees.isEmpty) {
        throw Exception('No employees found in the database.');
      }

      final filteredEmployees =
          selectedCompany == null || selectedCompany == 'All Companies'
              ? employees
              : employees
                  .where((e) => e['company_name'] == selectedCompany)
                  .toList();

      if (filteredEmployees.isEmpty) {
        throw Exception('No employees found for the selected company.');
      }

      double totalGrossPay = 0;
      double totalHouseAllowance = 0;
      double totalNetPay = 0;
      double totalDeductions = 0;
      double totalOvertimeAmount = 0;
      double totalEarnings = 0;
      double totalShifDeduction = 0;
      double totalNssfTierIDeduction = 0;
      double totalNssfTierIIDeduction = 0;
      double totalHousingLevy = 0;
      double totalPensionContributions = 0;
      double totalPayeDeduction = 0;
      double totalLoanRepayment = 0;
      double totalOtherDeductions = 0;

      for (var employee in filteredEmployees) {
        final employeeId = employee['employee_id'].toString();
        final grossPay =
            double.tryParse(employee['gross_pay'].toString()) ?? 0.0;
        final houseAllowance =
            double.tryParse(employee['house_allowance'].toString()) ?? 0.0;
        final companyName = employee['company_name'] as String?;

        if (kDebugMode) {
          print('Processing employee: $employeeId');
        }

        final nonCashBenefits = await apiService.fetchNonCashBenefits(
            employeeId, selectedMonth, selectedYear);
        final overtimeAmount = await apiService.fetchOvertimeAmount(
            employeeId, selectedMonth, selectedYear);
        final earnings = await apiService.fetchEarnings(
            employeeId, selectedMonth, selectedYear);
        final deductions = await apiService.fetchDeductions(
            employeeId, selectedMonth, selectedYear);
        final pensionContributions = await apiService.fetchPensionContributions(
            employeeId, selectedMonth, selectedYear);
        final loanRepayment = await apiService.fetchLoanRepayment(
            employeeId, selectedMonth, selectedYear);
        final insuranceReliefs = await apiService.getInsuranceRelief(
            employeeId: employeeId, month: selectedMonth, year: selectedYear);

        double totalNonCashBenefits = 0.0;
        double nonCashForTaxing = 0.0;

        if (nonCashBenefits != null && nonCashBenefits.isNotEmpty) {
          totalNonCashBenefits = nonCashBenefits.fold(
              0.0,
              (sum, benefit) =>
                  sum + (double.tryParse(benefit['amount'].toString()) ?? 0.0));
          if (totalNonCashBenefits > 3000) {
            nonCashForTaxing = totalNonCashBenefits;
          }
        }

        final originalGrossPay = grossPay;

        final nssfTierIDeduction =
            originalGrossPay > 8000 ? 480 : originalGrossPay * 0.06;
        final nssfTierIIDeduction = (originalGrossPay > 8000)
            ? ((originalGrossPay <= 72000)
                ? (originalGrossPay - 8000) * 0.06
                : (72000 - 8000) * 0.06)
            : 0.0;
        final shifDeduction = originalGrossPay * 0.0275;
        final housingLevy = originalGrossPay * 0.015;

        double insuranceRelief = 0.0;
        if (insuranceReliefs != null && insuranceReliefs.isNotEmpty) {
          insuranceRelief = insuranceReliefs
              .where((relief) => relief['employee_id'] == employeeId)
              .fold<double>(
                  0.0,
                  (sum, relief) =>
                      sum +
                      (double.tryParse(relief['relief_amount'].toString()) ??
                          0.0));
        }

        final taxableIncome = originalGrossPay +
            nonCashForTaxing -
            nssfTierIDeduction -
            nssfTierIIDeduction -
            shifDeduction -
            (pensionContributions ?? 0.0) -
            housingLevy;

        final payeDeductionBeforeRelief = await apiService.calculatePAYE(
          taxableIncome,
          personalRelief: 2400,
          nhifRelief: 0,
          nssfContribution: nssfTierIDeduction + nssfTierIIDeduction,
          housingLevy: housingLevy,
        );

        final payeDeduction =
            insuranceRelief > 0 && payeDeductionBeforeRelief > 0
                ? (payeDeductionBeforeRelief - insuranceRelief > 0
                    ? payeDeductionBeforeRelief - insuranceRelief
                    : 0.0)
                : payeDeductionBeforeRelief;

        final totalEarningsForEmployee = earnings.fold(
                0.0,
                (sum, earning) =>
                    sum +
                    (double.tryParse(earning['amount'].toString()) ?? 0.0)) +
            (overtimeAmount ?? 0.0);

        final totalOtherDeductionsForEmployee = deductions.fold(
            0.0,
            (sum, deduction) =>
                sum + (double.tryParse(deduction['amount'].toString()) ?? 0.0));

        final totalCoreDeductions = payeDeduction +
            shifDeduction +
            nssfTierIDeduction +
            nssfTierIIDeduction +
            (loanRepayment ?? 0.0) +
            housingLevy;

        final netPay = originalGrossPay +
            totalEarningsForEmployee -
            totalCoreDeductions -
            totalOtherDeductionsForEmployee +
            (insuranceRelief > 0 ? insuranceRelief : 0.0);

        totalGrossPay += originalGrossPay;
        totalHouseAllowance += houseAllowance;
        totalNetPay += netPay;
        totalDeductions +=
            totalCoreDeductions + totalOtherDeductionsForEmployee;
        totalOvertimeAmount += (overtimeAmount ?? 0.0);
        totalEarnings += totalEarningsForEmployee;
        totalShifDeduction += shifDeduction;
        totalNssfTierIDeduction += nssfTierIDeduction;
        totalNssfTierIIDeduction += nssfTierIIDeduction;
        totalHousingLevy += housingLevy;
        totalPensionContributions += (pensionContributions ?? 0.0);
        totalPayeDeduction += payeDeduction;
        totalLoanRepayment += (loanRepayment ?? 0.0);
        totalOtherDeductions += totalOtherDeductionsForEmployee;

        final salaryRecord = {
          'employee_id': employeeId,
          'fullname': employee['fullname'] ?? 'Unknown',
          'company_name': companyName,
          'gross_pay': originalGrossPay,
          'house_allowance': houseAllowance,
          'basic_pay': double.tryParse(employee['basic'].toString()) ?? 0.0,
          'non_cash_benefits':
              totalNonCashBenefits > 0 ? totalNonCashBenefits : null,
          'overtime_amount': overtimeAmount > 0 ? overtimeAmount : null,
          'earnings':
              totalEarningsForEmployee > 0 ? totalEarningsForEmployee : null,
          'taxable_income': taxableIncome > 0 ? taxableIncome : null,
          'shif_deduction': shifDeduction > 0 ? shifDeduction : null,
          'nssf_tier_i_deduction':
              nssfTierIDeduction > 0 ? nssfTierIDeduction : null,
          'nssf_tier_ii_deduction':
              nssfTierIIDeduction > 0 ? nssfTierIIDeduction : null,
          'housing_levy': housingLevy > 0 ? housingLevy : null,
          'pension_contributions':
              pensionContributions > 0 ? pensionContributions : null,
          'paye_deduction': payeDeduction > 0 ? payeDeduction : null,
          'loan_repayment': loanRepayment > 0 ? loanRepayment : null,
          'deductions': totalOtherDeductionsForEmployee > 0
              ? totalOtherDeductionsForEmployee
              : null,
          'insurance_relief': insuranceRelief > 0 ? insuranceRelief : null,
          'total_deductions':
              (totalCoreDeductions + totalOtherDeductionsForEmployee) > 0
                  ? (totalCoreDeductions + totalOtherDeductionsForEmployee)
                  : null,
          'net_pay': netPay > 0 ? netPay : null,
          'month': selectedMonth,
          'year': selectedYear,
        };

        setState(() {
          salaries.add(salaryRecord);
          selectedEmployees[employeeId] = false;
        });
      }

      setState(() {
        salaries.add({
          'employee_id': null,
          'fullname': 'Totals',
          'company_name': null,
          'gross_pay': totalGrossPay > 0 ? totalGrossPay : null,
          'house_allowance': totalHouseAllowance > 0 ? totalHouseAllowance : 0,
          'basic_pay': null,
          'non_cash_benefits': null,
          'overtime_amount':
              totalOvertimeAmount > 0 ? totalOvertimeAmount : null,
          'earnings': totalEarnings > 0 ? totalEarnings : null,
          'taxable_income': null,
          'shif_deduction': totalShifDeduction > 0 ? totalShifDeduction : null,
          'nssf_tier_i_deduction':
              totalNssfTierIDeduction > 0 ? totalNssfTierIDeduction : null,
          'nssf_tier_ii_deduction':
              totalNssfTierIIDeduction > 0 ? totalNssfTierIIDeduction : null,
          'housing_levy': totalHousingLevy > 0 ? totalHousingLevy : null,
          'pension_contributions':
              totalPensionContributions > 0 ? totalPensionContributions : null,
          'paye_deduction': totalPayeDeduction > 0 ? totalPayeDeduction : null,
          'loan_repayment': totalLoanRepayment > 0 ? totalLoanRepayment : null,
          'deductions': totalOtherDeductions > 0 ? totalOtherDeductions : null,
          'insurance_relief': null,
          'total_deductions': totalDeductions > 0 ? totalDeductions : null,
          'net_pay': totalNetPay > 0 ? totalNetPay : null,
          'month': selectedMonth,
          'year': selectedYear,
        });
      });

      if (kDebugMode) {
        print(
            'Processing complete. Total employees processed: ${filteredEmployees.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching and calculating salaries: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> exportMasterPayroll() async {
    if (salaries.isEmpty || salaries.last['fullname'] != 'Totals') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fetch salaries first.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Extract clean header text from _buildTableColumns
      final headers = _buildTableColumns()
          .map((col) => (col.label as Text).data!) // Extract the text data
          .toList()
          .where((header) => header != 'Select') // Exclude the "Select" column
          .toList();

      final List<List<String>> csvData = [headers];

      for (var salary in salaries) {
        final row = [
          salary['employee_id']?.toString() ?? '', // Add employee_id
          salary['company_name']?.toString() ?? '',
          salary['fullname']?.toString() ?? '',
          salary['gross_pay']?.toStringAsFixed(2) ?? '0.00',
          salary['house_allowance']?.toStringAsFixed(2) ?? '0.00',
          salary['basic_pay']?.toStringAsFixed(2) ?? '0.00',
          salary['non_cash_benefits']?.toStringAsFixed(2) ?? '',
          salary['overtime_amount']?.toStringAsFixed(2) ?? '',
          salary['earnings']?.toStringAsFixed(2) ?? '',
          salary['taxable_income']?.toStringAsFixed(2) ?? '',
          salary['deductions']?.toStringAsFixed(2) ?? '',
          salary['shif_deduction']?.toStringAsFixed(2) ?? '',
          salary['nssf_tier_i_deduction']?.toStringAsFixed(2) ?? '',
          salary['nssf_tier_ii_deduction']?.toStringAsFixed(2) ?? '',
          salary['housing_levy']?.toStringAsFixed(2) ?? '',
          salary['paye_deduction']?.toStringAsFixed(2) ?? '',
          salary['loan_repayment']?.toStringAsFixed(2) ?? '',
          salary['pension_contributions']?.toStringAsFixed(2) ?? '',
          salary['insurance_relief']?.toStringAsFixed(2) ?? '',
          salary['total_deductions']?.toStringAsFixed(2) ?? '',
          salary['net_pay']?.toStringAsFixed(2) ?? '',
        ];
        csvData.add(row.map((e) => e.toString()).toList());
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName = 'MasterPayroll_${selectedMonth}_${selectedYear}.csv';
      final csvBytes = utf8.encode(csvString);

      if (kIsWeb) {
        final blob = html.Blob([csvBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(csvBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('CSV file saved to Downloads: ${file.path}')),
          );
        } else {
          throw 'Could not access Downloads directory';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Master Payroll exported successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting master payroll: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting master payroll: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showSalarySlip(Map<String, dynamic> salary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Salary Slip for ${salary['fullname']}',
            style: TextStyle(color: Colors.teal[900])),
        content: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.teal[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (salary['employee_id'] != null)
                  _buildSlipText(
                      'Employee ID', salary['employee_id'].toString()),
                if (salary['company_name'] != null)
                  _buildSlipText('Company', salary['company_name']),
                if (salary['gross_pay'] != null)
                  _buildSlipText(
                      'Gross Pay', salary['gross_pay'].toStringAsFixed(2)),
                if (salary['house_allowance'] != null)
                  _buildSlipText('House Allowance',
                      salary['house_allowance'].toStringAsFixed(2)),
                if (salary['basic_pay'] != null)
                  _buildSlipText(
                      'Basic Pay', salary['basic_pay'].toStringAsFixed(2)),
                if (salary['non_cash_benefits'] != null)
                  _buildSlipText('Non-Cash Benefits',
                      salary['non_cash_benefits'].toStringAsFixed(2)),
                if (salary['overtime_amount'] != null)
                  _buildSlipText('Overtime Amount',
                      salary['overtime_amount'].toStringAsFixed(2)),
                if (salary['earnings'] != null)
                  _buildSlipText(
                      'Total Earnings', salary['earnings'].toStringAsFixed(2)),
                if (salary['taxable_income'] != null)
                  _buildSlipText('Taxable Income',
                      salary['taxable_income'].toStringAsFixed(2)),
                if (salary['shif_deduction'] != null)
                  _buildSlipText('SHIF Deduction',
                      salary['shif_deduction'].toStringAsFixed(2)),
                if (salary['nssf_tier_i_deduction'] != null)
                  _buildSlipText('NSSF Tier I Deduction',
                      salary['nssf_tier_i_deduction'].toStringAsFixed(2)),
                if (salary['nssf_tier_ii_deduction'] != null)
                  _buildSlipText('NSSF Tier II Deduction',
                      salary['nssf_tier_ii_deduction'].toStringAsFixed(2)),
                if (salary['housing_levy'] != null)
                  _buildSlipText('Housing Levy',
                      salary['housing_levy'].toStringAsFixed(2)),
                if (salary['paye_deduction'] != null)
                  _buildSlipText('PAYE Deduction',
                      salary['paye_deduction'].toStringAsFixed(2)),
                if (salary['loan_repayment'] != null)
                  _buildSlipText('Loan Repayment',
                      salary['loan_repayment'].toStringAsFixed(2)),
                if (salary['pension_contributions'] != null)
                  _buildSlipText('Pension Contributions',
                      salary['pension_contributions'].toStringAsFixed(2)),
                if (salary['insurance_relief'] != null)
                  _buildSlipText('Insurance Relief',
                      salary['insurance_relief'].toStringAsFixed(2)),
                if (salary['deductions'] != null)
                  _buildSlipText('Other Deductions',
                      salary['deductions'].toStringAsFixed(2)),
                if (salary['total_deductions'] != null)
                  _buildSlipText('Total Deductions',
                      salary['total_deductions'].toStringAsFixed(2)),
                if (salary['net_pay'] != null)
                  _buildSlipText(
                      'Net Pay', salary['net_pay'].toStringAsFixed(2)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.teal[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildSlipText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: Colors.teal[900])),
          Text(value, style: TextStyle(color: Colors.grey[800])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Pay Salaries',
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
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: selectedMonth,
                          items: List.generate(12, (index) => index + 1),
                          itemBuilder: (month) => DateFormat('MMMM')
                              .format(DateTime(selectedYear, month)),
                          onChanged: (value) {
                            setState(() {
                              selectedMonth = value!;
                              salaries.clear();
                              selectedEmployees.clear();
                              searchKeyword = '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildDropdown(
                          value: selectedYear,
                          items: List.generate(
                              10, (index) => DateTime.now().year - index),
                          itemBuilder: (year) => year.toString(),
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value!;
                              salaries.clear();
                              selectedEmployees.clear();
                              searchKeyword = '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildDropdown(
                          value: selectedCompany ?? 'All Companies',
                          items: companyNames,
                          itemBuilder: (company) => company,
                          onChanged: (value) {
                            setState(() {
                              selectedCompany = value;
                              salaries.clear();
                              selectedEmployees.clear();
                              searchKeyword = '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                        onPressed: isLoading ? null : fetchAndCalculateSalaries,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Fetch Salaries'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.teal[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search by Full Name',
                      labelStyle: TextStyle(color: Colors.teal[900]),
                      prefixIcon: Icon(Icons.search, color: Colors.teal[700]),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.teal[200]!)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.teal[200]!)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.teal[700]!)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchKeyword = value.toLowerCase();
                      });
                    },
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ),
              if (salaries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Instructions: Check the box next to an employee to exclude them from bulk payment.',
                    style: TextStyle(fontSize: 12, color: Colors.teal[900]),
                  ),
                ),
              Expanded(
                child: isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]),
                      )
                    : salaries.isEmpty
                        ? Center(
                            child: Text('No salaries available',
                                style: TextStyle(
                                    color: Colors.teal[900], fontSize: 16)),
                          )
                        : Card(
                            elevation: 4,
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
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    dataRowHeight: 60,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.teal[100]),
                                    columns: _buildTableColumns(),
                                    rows: _buildFilteredTableRows(),
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : exportMasterPayroll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Export Master Payroll'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () async {
              if (salaries.isEmpty || salaries.last['fullname'] != 'Totals') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fetch salaries first.')),
                );
                return;
              }

              final selectedEmployeeId = selectedEmployees.entries
                  .singleWhere((entry) => entry.value,
                      orElse: () => const MapEntry('', false))
                  .key;

              if (selectedEmployeeId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('No employee selected for single payment.')),
                );
                return;
              }

              final selectedEmployee = salaries.firstWhere(
                (salary) => salary['employee_id'] == selectedEmployeeId,
                orElse: () => {},
              );

              if (selectedEmployee.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected employee not found.')),
                );
                return;
              }

              setState(() => isLoading = true);

              try {
                await apiService.saveSalary(selectedEmployee);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Single Payment initiated for ${selectedEmployee['fullname']}'),
                    backgroundColor: Colors.teal[700],
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error during single payment: $e')),
                );
              } finally {
                setState(() => isLoading = false);
              }
            },
            backgroundColor: Colors.teal[700],
            heroTag: 'single_payment',
            tooltip: 'Single Payment',
            child: const Icon(Icons.payment, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () async {
              if (salaries.isEmpty || salaries.last['fullname'] != 'Totals') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fetch salaries first.')),
                );
                return;
              }

              final employeesToPay = salaries
                  .where((salary) =>
                      salary['fullname'] != 'Totals' &&
                      !(selectedEmployees[salary['employee_id']] ?? false))
                  .toList();

              if (employeesToPay.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No employees selected for bulk payment.')),
                );
                return;
              }

              setState(() => isLoading = true);

              try {
                for (var employee in employeesToPay) {
                  await apiService.saveSalary(employee);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Bulk Payment initiated for ${employeesToPay.length} employees'),
                    backgroundColor: Colors.teal[700],
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error during bulk payment: $e')),
                );
              } finally {
                setState(() => isLoading = false);
              }
            },
            backgroundColor: Colors.teal[700],
            heroTag: 'bulk_payment',
            tooltip: 'Bulk Payment',
            child: const Icon(Icons.payments, color: Colors.white),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    final keys = [
      'Select',
      'Employee ID', // Added Employee ID
      'Company Name',
      'Full Name',
      'Gross Pay',
      'House Allowance',
      'Basic Pay',
      'Non-Cash Benefits',
      'Overtime Amount',
      'Total Earnings',
      'Taxable Income',
      'Deductions',
      'SHIF Deduction',
      'NSSF Tier I Deduction',
      'NSSF Tier II Deduction',
      'Housing Levy',
      'PAYE Deduction',
      'Loan Repayment',
      'Pension Contributions',
      'Insurance Relief',
      'Total Deductions',
      'Net Pay',
    ];

    return keys.map((key) {
      return DataColumn(
        label: Text(
          key.replaceAll('_', ' ').capitalize(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.teal[900],
            fontSize: 14,
          ),
        ),
      );
    }).toList();
  }

  List<DataRow> _buildFilteredTableRows() {
    final filteredSalaries = salaries.where((salary) {
      if (salary['fullname'] == 'Totals') {
        return true;
      }
      final fullName = salary['fullname']?.toString().toLowerCase() ?? '';
      return fullName.contains(searchKeyword);
    }).toList();

    return filteredSalaries.map((salary) {
      final keys = [
        'Select',
        'employee_id', // Added employee_id
        'company_name',
        'fullname',
        'gross_pay',
        'house_allowance',
        'basic_pay',
        'non_cash_benefits',
        'overtime_amount',
        'earnings',
        'taxable_income',
        'deductions',
        'shif_deduction',
        'nssf_tier_i_deduction',
        'nssf_tier_ii_deduction',
        'housing_levy',
        'paye_deduction',
        'loan_repayment',
        'pension_contributions',
        'insurance_relief',
        'total_deductions',
        'net_pay',
      ];

      return DataRow(
        cells: keys.map((key) {
          if (key == 'Select') {
            return DataCell(Checkbox(
              value: salary['fullname'] != 'Totals'
                  ? selectedEmployees[salary['employee_id']] ?? false
                  : null,
              tristate: true,
              onChanged: salary['fullname'] != 'Totals'
                  ? (value) {
                      setState(() {
                        selectedEmployees[salary['employee_id']] = value!;
                      });
                    }
                  : null,
              activeColor: Colors.teal[700],
            ));
          } else {
            final value = salary[key] ??
                (key == 'fullname'
                    ? 'Unknown'
                    : key == 'company_name'
                        ? ''
                        : key == 'employee_id'
                            ? '' // Default for employee_id
                            : key == 'house_allowance'
                                ? 0.0
                                : 0.0);

            if (value is num) {
              if (salary['fullname'] == 'Totals') {
                return DataCell(Text(
                  value.toStringAsFixed(2),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal[900]),
                ));
              }
              return DataCell(
                Text(
                  value.toStringAsFixed(2),
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () => showSalarySlip(salary),
              );
            } else {
              return DataCell(
                Text(value.toString(),
                    style: TextStyle(color: Colors.grey[800])),
                onTap: () => showSalarySlip(salary),
              );
            }
          }
        }).toList(),
      );
    }).toList();
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
