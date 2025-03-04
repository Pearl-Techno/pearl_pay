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

import '../services.dart';

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
          // Only apply insurance relief if this employee's ID matches the relief record
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

        // Apply insurance relief only if it exists for this employee
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

        // Add insurance relief to net pay only if it exists for this employee
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
          'insurance_relief': null, // No total for insurance relief
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
      final headers = _buildTableColumns()
          .map((col) => col.label
              .toString()
              .replaceFirst('Text(', '')
              .replaceFirst(')', ''))
          .toList()
          .where((header) => header != 'Select')
          .toList();

      final List<List<String>> csvData = [headers];

      for (var salary in salaries) {
        final row = [
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
        const SnackBar(
          content: Text('Master Payroll exported successfully'),
          backgroundColor: Colors.teal,
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
        title: Text('Salary Slip for ${salary['fullname']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (salary['company_name'] != null)
                Text('Company: ${salary['company_name']}'),
              if (salary['gross_pay'] != null)
                Text('Gross Pay: ${salary['gross_pay'].toStringAsFixed(2)}'),
              if (salary['house_allowance'] != null)
                Text(
                    'House Allowance: ${salary['house_allowance'].toStringAsFixed(2)}'),
              if (salary['basic_pay'] != null)
                Text('Basic Pay: ${salary['basic_pay'].toStringAsFixed(2)}'),
              if (salary['non_cash_benefits'] != null)
                Text(
                    'Non-Cash Benefits: ${salary['non_cash_benefits'].toStringAsFixed(2)}'),
              if (salary['overtime_amount'] != null)
                Text(
                    'Overtime Amount: ${salary['overtime_amount'].toStringAsFixed(2)}'),
              if (salary['earnings'] != null)
                Text(
                    'Total Earnings: ${salary['earnings'].toStringAsFixed(2)}'),
              if (salary['taxable_income'] != null)
                Text(
                    'Taxable Income: ${salary['taxable_income'].toStringAsFixed(2)}'),
              if (salary['shif_deduction'] != null)
                Text(
                    'SHIF Deduction: ${salary['shif_deduction'].toStringAsFixed(2)}'),
              if (salary['nssf_tier_i_deduction'] != null)
                Text(
                    'NSSF Tier I Deduction: ${salary['nssf_tier_i_deduction'].toStringAsFixed(2)}'),
              if (salary['nssf_tier_ii_deduction'] != null)
                Text(
                    'NSSF Tier II Deduction: ${salary['nssf_tier_ii_deduction'].toStringAsFixed(2)}'),
              if (salary['housing_levy'] != null)
                Text(
                    'Housing Levy: ${salary['housing_levy'].toStringAsFixed(2)}'),
              if (salary['paye_deduction'] != null)
                Text(
                    'PAYE Deduction: ${salary['paye_deduction'].toStringAsFixed(2)}'),
              if (salary['loan_repayment'] != null)
                Text(
                    'Loan Repayment: ${salary['loan_repayment'].toStringAsFixed(2)}'),
              if (salary['pension_contributions'] != null)
                Text(
                    'Pension Contributions: ${salary['pension_contributions'].toStringAsFixed(2)}'),
              if (salary['insurance_relief'] != null)
                Text(
                    'Insurance Relief: ${salary['insurance_relief'].toStringAsFixed(2)}'),
              if (salary['deductions'] != null)
                Text(
                    'Other Deductions: ${salary['deductions'].toStringAsFixed(2)}'),
              if (salary['total_deductions'] != null)
                Text(
                    'Total Deductions: ${salary['total_deductions'].toStringAsFixed(2)}'),
              if (salary['net_pay'] != null)
                Text('Net Pay: ${salary['net_pay'].toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Salaries'),
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
                      salaries.clear();
                      selectedEmployees.clear();
                      searchKeyword = '';
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
                      salaries.clear();
                      selectedEmployees.clear();
                      searchKeyword = '';
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
                      salaries.clear();
                      selectedEmployees.clear();
                      searchKeyword = '';
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : fetchAndCalculateSalaries,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Fetch Salaries'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by Full Name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    searchKeyword = value.toLowerCase();
                  });
                },
              ),
            ),
            if (salaries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Instructions: Check the box next to an employee to exclude them from bulk payment.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            Expanded(
              child: salaries.isEmpty
                  ? const Center(child: Text('No salaries available'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columns: _buildTableColumns(),
                          rows: _buildFilteredTableRows(),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : exportMasterPayroll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Export Master Payroll'),
            ),
          ],
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
            backgroundColor: Colors.teal,
            heroTag: 'single_payment',
            tooltip: 'Single Payment',
            child: const Icon(Icons.payment),
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
            backgroundColor: Colors.teal,
            heroTag: 'bulk_payment',
            tooltip: 'Bulk Payment',
            child: const Icon(Icons.payments),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    final keys = [
      'Select',
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
        label: Text(key.replaceAll('_', ' ').capitalize()),
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
            ));
          } else {
            final value = salary[key] ??
                (key == 'fullname'
                    ? 'Unknown'
                    : key == 'company_name'
                        ? ''
                        : key == 'house_allowance'
                            ? 0.0
                            : 0.0);

            if (value is num) {
              if (salary['fullname'] == 'Totals') {
                return DataCell(Text(value.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold)));
              }
              return DataCell(Text(value.toStringAsFixed(2)));
            } else {
              return DataCell(Text(value.toString()));
            }
          }
        }).toList(),
      );
    }).toList();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
