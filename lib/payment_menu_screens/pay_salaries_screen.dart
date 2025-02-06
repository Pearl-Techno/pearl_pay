import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

  // Track selected employees for single payment
  Map<String, bool> selectedEmployees = {};

  // Search keyword for filtering employees
  String searchKeyword = '';

  Future<void> fetchAndCalculateSalaries() async {
    setState(() => isLoading = true);

    try {
      if (kDebugMode) {
        print('Fetching employees...');
      }
      final employees = await apiService.getAllEmployees();

      if (employees.isEmpty) {
        throw Exception('No employees found in the database.');
      }

      if (kDebugMode) {
        print('Processing ${employees.length} employees...');
      }
      double totalGrossPay = 0;
      double totalNetPay = 0;
      double totalDeductions = 0;
      double totalOvertimeAmount = 0;
      double totalEarnings = 0;
      double totalNhifDeduction = 0;
      double totalNssfDeduction = 0;
      double totalHousingLevy = 0;
      double totalSaccoContribution = 0;
      double totalPayeDeduction = 0;
      double totalLoanRepayment = 0;
      double totalPensionContributions = 0;

      for (var employee in employees) {
        final employeeId = employee['employee_id'].toString();
        final grossPay =
            double.tryParse(employee['gross_pay'].toString()) ?? 0.0;

        if (kDebugMode) {
          print('Processing employee: $employeeId');
        }

        // Fetch additional data
        final absenteeismDeduction = await apiService.fetchAbsenteeismDeduction(
                employeeId, selectedMonth, selectedYear);
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

        // Calculate deductions
        final nhifDeduction = await apiService.calculateNHIF(grossPay);
        final nssfDeduction = await apiService.calculateNSSF(grossPay);
        final totalNonCashBenefits = nonCashBenefits.fold(
            0.0,
            (sum, benefit) =>
                sum + double.tryParse(benefit['estimated_value'].toString())!);
        final payeDeduction = await apiService.calculatePAYE(
              grossPay + totalNonCashBenefits,
              personalRelief: 2400,
              nhifRelief: 0,
              nssfContribution: nssfDeduction,
              housingLevy: 0.015 * grossPay,
            );

        // Calculate net pay
        final totalEarningsForEmployee = earnings.fold(
                0.0,
                (sum, earning) =>
                    sum +
                    (double.tryParse(earning['amount'].toString()) ?? 0.0)) +
            overtimeAmount; // Include overtime in total earnings
        final taxableIncome =
            grossPay - nssfDeduction - pensionContributions - nhifDeduction;
        final housingLevy = 0.015 * grossPay;
        final saccoContribution =
            0.1 * grossPay; // Example SACCO contribution (10% of gross pay)
        final totalDeductionsForEmployee = payeDeduction +
            nhifDeduction +
            nssfDeduction +
            loanRepayment +
            absenteeismDeduction +
            saccoContribution +
            housingLevy +
            deductions.fold(
                0.0,
                (sum, deduction) =>
                    sum +
                    (double.tryParse(deduction['amount'].toString()) ?? 0.0));
        final netPay =
            grossPay + totalEarningsForEmployee - totalDeductionsForEmployee;

        // Update totals
        totalGrossPay += grossPay;
        totalNetPay += netPay;
        totalDeductions += totalDeductionsForEmployee;
        totalOvertimeAmount += overtimeAmount;
        totalEarnings += totalEarningsForEmployee;
        totalNhifDeduction += nhifDeduction;
        totalNssfDeduction += nssfDeduction;
        totalHousingLevy += housingLevy;
        totalSaccoContribution += saccoContribution;
        totalPayeDeduction += payeDeduction;
        totalLoanRepayment += loanRepayment;
        totalPensionContributions += pensionContributions;

        // Add to salaries list with default values for missing fields
        final salaryRecord = {
          'employee_id': employeeId,
          'fullname': employee['fullname'] ?? 'Unknown',
          'gross_pay': grossPay,
          'basic_pay': double.tryParse(employee['basic'].toString()) ?? 0.0,
          'absenteeism_deduction': absenteeismDeduction,
          'non_cash_benefits': nonCashBenefits,
          'overtime_amount': overtimeAmount,
          'earnings': totalEarningsForEmployee,
          'taxable_income': taxableIncome,
          'nhif_deduction': nhifDeduction,
          'nssf_deduction': nssfDeduction,
          'housing_levy': housingLevy,
          'sacco_contribution': saccoContribution,
          'paye_deduction': payeDeduction,
          'loan_repayment': loanRepayment,
          'pension_contributions': pensionContributions,
          'total_deductions': totalDeductionsForEmployee,
          'net_pay': netPay,
        };

        // Add the current employee's record to the list
        setState(() {
          salaries.add(salaryRecord);
        });

        if (kDebugMode) {
          print(
            'Processed employee: $employeeId | Gross Pay: $grossPay | Net Pay: $netPay');
        }
      }

      // Add totals to the salaries list after processing all employees
      setState(() {
        salaries.add({
          'fullname': 'Totals',
          'gross_pay': totalGrossPay,
          'basic_pay': null,
          'absenteeism_deduction': null,
          'non_cash_benefits': null,
          'overtime_amount': totalOvertimeAmount,
          'earnings': totalEarnings,
          'taxable_income': null,
          'nhif_deduction': totalNhifDeduction,
          'nssf_deduction': totalNssfDeduction,
          'housing_levy': totalHousingLevy,
          'sacco_contribution': totalSaccoContribution,
          'paye_deduction': totalPayeDeduction,
          'loan_repayment': totalLoanRepayment,
          'pension_contributions': totalPensionContributions,
          'total_deductions': totalDeductions,
          'net_pay': totalNetPay,
        });
      });

      if (kDebugMode) {
        print(
          'Processing complete. Total employees processed: ${employees.length}');
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

  void showSalarySlip(Map<String, dynamic> salary) {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Salary Slip for ${salary['fullname']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gross Pay: ${salary['gross_pay'] ?? 0.0}'),
                Text('Basic Pay: ${salary['basic_pay'] ?? 0.0}'),
                Text('Overtime Amount: ${salary['overtime_amount'] ?? 0.0}'),
                Text('Total Earnings: ${salary['earnings'] ?? 0.0}'),
                Text('Taxable Income: ${salary['taxable_income'] ?? 0.0}'),
                Text('NHIF Deduction: ${salary['nhif_deduction'] ?? 0.0}'),
                Text('NSSF Deduction: ${salary['nssf_deduction'] ?? 0.0}'),
                Text('Housing Levy: ${salary['housing_levy'] ?? 0.0}'),
                Text(
                    'SACCO Contribution: ${salary['sacco_contribution'] ?? 0.0}'),
                Text('PAYE Deduction: ${salary['paye_deduction'] ?? 0.0}'),
                Text('Loan Repayment: ${salary['loan_repayment'] ?? 0.0}'),
                Text(
                    'Pension Contributions: ${salary['pension_contributions'] ?? 0.0}'),
                Text('Total Deductions: ${salary['total_deductions'] ?? 0.0}'),
                Text('Net Pay: ${salary['net_pay'] ?? 0.0}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing salary slip: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to display salary slip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pay Salaries'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Month Dropdown
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
                      salaries.clear(); // Clear salaries when month changes
                      selectedEmployees.clear(); // Reset selections
                      searchKeyword = ''; // Reset search keyword
                    });
                    if (kDebugMode) {
                      print('Selected month changed to: $selectedMonth');
                    }
                  },
                ),

                // Year Dropdown
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
                      salaries.clear(); // Clear salaries when year changes
                      selectedEmployees.clear(); // Reset selections
                      searchKeyword = ''; // Reset search keyword
                    });
                    if (kDebugMode) {
                      print('Selected year changed to: $selectedYear');
                    }
                  },
                ),

                // Fetch Salaries Button
                ElevatedButton(
                  onPressed: isLoading ? null : fetchAndCalculateSalaries,
                  child: isLoading
                      ? CircularProgressIndicator()
                      : Text('Fetch Salaries'),
                ),
              ],
            ),

            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
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

            // Instructions
            if (salaries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Instructions: Check the box next to an employee to exclude them from bulk payment.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),

            // Salary Table
            Expanded(
              child: salaries.isEmpty
                  ? Center(child: Text('No salaries available'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: _buildTableColumns(),
                        rows: _buildFilteredTableRows(),
                      ),
                    ),
            ),
          ],
        ),
      ),

      // Floating Action Buttons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              if (salaries.isEmpty || salaries.last['fullname'] != 'Totals') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fetch salaries first.')),
                );
                return;
              }

              final selectedEmployeeId = selectedEmployees.entries
                  .singleWhere((entry) => entry.value,
                      orElse: () => MapEntry('', false))
                  .key;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Single Payment initiated for $selectedEmployeeId')),
              );
            },
            backgroundColor: Colors.teal,
            heroTag: 'single_payment',
            tooltip: 'Single Payment',
            child: Icon(Icons.payment),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              if (salaries.isEmpty || salaries.last['fullname'] != 'Totals') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fetch salaries first.')),
                );
                return;
              }

              final employeesToPay = salaries
                  .where((salary) =>
                      salary['fullname'] != 'Totals' &&
                      !(selectedEmployees[salary['employee_id']] ?? false))
                  .map((salary) => salary['employee_id'])
                  .toList();

              if (employeesToPay.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('No employees selected for bulk payment.')),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Bulk Payment initiated for ${employeesToPay.length} employees')),
              );
            },
            backgroundColor: Colors.teal,
            heroTag: 'bulk_payment',
            tooltip: 'Bulk Payment',
            child: Icon(Icons.payments),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    final keys = [
      'Select', // Checkbox column
      'Full Name',
      'Gross Pay',
      'Basic Pay',
      'Overtime Amount',
      'Total Earnings',
      'Taxable Income',
      'Absenteeism Deduction',
      'NHIF Deduction',
      'NSSF Deduction',
      'Housing Levy',
      'SACCO Contribution',
      'PAYE Deduction',
      'Loan Repayment',
      'Pension Contributions',
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
    // Filter salaries based on search keyword
    final filteredSalaries = salaries.where((salary) {
      if (salary['fullname'] == 'Totals') {
        return true; // Always include "Totals" row
      }
      final fullName = salary['fullname']?.toString().toLowerCase() ?? '';
      return fullName.contains(searchKeyword);
    }).toList();

    return filteredSalaries.map((salary) {
      final keys = [
        'Select', // Checkbox column
        'fullname',
        'gross_pay',
        'basic_pay',
        'overtime_amount',
        'earnings',
        'taxable_income',
        'absenteeism_deduction',
        'nhif_deduction',
        'nssf_deduction',
        'housing_levy',
        'sacco_contribution',
        'paye_deduction',
        'loan_repayment',
        'pension_contributions',
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
              tristate: true, // Allow null for "Totals" row
              onChanged: salary['fullname'] != 'Totals'
                  ? (value) {
                      setState(() {
                        selectedEmployees[salary['employee_id']] = value!;
                      });
                    }
                  : null,
            ));
          } else {
            final value = salary[key] ?? (key == 'fullname' ? 'Unknown' : 0.0);

            if (value is num) {
              if (salary['fullname'] == 'Totals') {
                return DataCell(Text(value.toStringAsFixed(2),
                    style: TextStyle(fontWeight: FontWeight.bold)));
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

  void _initSelectedEmployees() {
    selectedEmployees = { for (var e in salaries.where((s) => s['fullname'] != 'Totals')) e['employee_id'] : false };
  }

  @override
  void initState() {
    super.initState();
    _initSelectedEmployees();
  }

  @override
  void didUpdateWidget(PaySalariesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initSelectedEmployees();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
