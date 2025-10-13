import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html
    if (kIsWeb) "universal_html.dart";

import '../models/user.dart';
import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class PaySalariesScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const PaySalariesScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PaySalariesScreenState createState() => _PaySalariesScreenState();
}

class _PaySalariesScreenState extends State<PaySalariesScreen> {
  List<Map<String, dynamic>> salaries = [];
  bool isLoading = false;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  DateTime? selectedPaymentDate;
  int? selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};

  Map<String, bool> selectedEmployees = {};
  String searchKeyword = '';
  Timer? _debounce;

  Set<String> benefitDescriptions = {};
  Set<String> deductionDescriptions = {};

  @override
  void initState() {
    super.initState();
    selectedPaymentDate = DateTime.now();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
    setState(() => isLoading = true);
    try {
      final companies = await widget.apiService.getCompanies();
      if (kDebugMode) {
        print('API companies response: $companies');
      }
      final isAdmin = widget.user.role == 'admin';

      setState(() {
        if (isAdmin) {
          final filteredCompanies = companies.where((c) {
            final companyId =
                c['id'] is String ? int.tryParse(c['id']) : c['id'] as int?;
            return companyId == widget.user.companyId;
          }).toList();

          final userCompany = filteredCompanies.isNotEmpty
              ? filteredCompanies.first
              : {
                  'id': widget.user.companyId,
                  'company_name': 'Unknown',
                };

          companyIds = [widget.user.companyId];
          companyIdToName = {
            widget.user.companyId:
                userCompany['company_name']?.toString() ?? 'Unknown',
          };
          selectedCompanyId = widget.user.companyId;
        } else {
          final filteredCompanies = companies.where((c) {
            final companyId =
                c['id'] is String ? int.tryParse(c['id']) : c['id'] as int?;
            return companyId == widget.user.companyId;
          }).toList();

          final userCompany = filteredCompanies.isNotEmpty
              ? filteredCompanies.first
              : {
                  'id': widget.user.companyId,
                  'company_name': 'Unknown',
                };

          companyIds = [widget.user.companyId];
          companyIdToName = {
            widget.user.companyId:
                userCompany['company_name']?.toString() ?? 'Unknown',
          };
          selectedCompanyId = widget.user.companyId;
        }
        if (kDebugMode) {
          print('companyIds: $companyIds');
          print('selectedCompanyId: $selectedCompanyId');
        }
      });

      if (selectedCompanyId != null) {
        await fetchAndCalculateSalaries();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching companies: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchAndCalculateSalaries() async {
    if (selectedCompanyId == null) {
      setState(() {
        salaries.clear();
        selectedEmployees.clear();
        isLoading = false;
      });
      return;
    }

    final isAdmin = widget.user.role == 'admin';
    if (!isAdmin && selectedCompanyId != widget.user.companyId) {
      if (kDebugMode) {
        print(
            'Invalid selectedCompanyId ($selectedCompanyId) for non-admin user. Resetting to user.companyId (${widget.user.companyId})');
      }
      setState(() {
        selectedCompanyId = widget.user.companyId;
        salaries.clear();
        selectedEmployees.clear();
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Access denied: You can only view your company’s salaries.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      salaries.clear();
      selectedEmployees.clear();
      benefitDescriptions.clear();
      deductionDescriptions.clear();
    });

    try {
      final userEmployeeId = widget.user.employeeId;
      final effectiveCompanyId = selectedCompanyId!;

      if (kDebugMode) {
        print('Fetching employees for companyId: $effectiveCompanyId');
      }

      List<Map<String, dynamic>> employees = [];
      if (isAdmin) {
        employees = await widget.apiService.getEmployeeList(effectiveCompanyId);
      } else if (userEmployeeId != null) {
        employees =
            (await widget.apiService.getEmployeeList(widget.user.companyId))
                .where((e) => e['employee_id'] == userEmployeeId)
                .toList();
      }

      employees =
          employees.where((e) => e['employee_status'] != 'Inactive').toList();

      if (employees.isEmpty) {
        throw Exception('No active employees found for your company.');
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
      double totalOtherDeductions = 0;
      double totalNonCashBenefitsOverall = 0;
      double totalInsuranceRelief = 0;

      for (var employee in employees) {
        final employeeId = employee['employee_id'].toString();
        final originalGrossPay =
            double.tryParse(employee['gross_pay']?.toString() ?? '0') ?? 0.0;
        final houseAllowance =
            double.tryParse(employee['house_allowance']?.toString() ?? '0') ??
                0.0;
        final companyName = employee['company_name']?.toString();

        if (kDebugMode) {
          print(
              'Processing employee: $employeeId, status: ${employee['employee_status']}');
        }

        // Check if salary is already paid for this month and year
        final paymentDate = selectedPaymentDate ?? DateTime.now();
        final month = paymentDate.month;
        final year = paymentDate.year;
        final checkResult =
            await _checkPaidStatus(employeeId, effectiveCompanyId, month, year);
        final isPaid = checkResult['isPaid'] as bool;
        final errorMessage = checkResult['message'] as String?;

        final nonCashBenefits = await widget.apiService.fetchBenefits(
          effectiveCompanyId,
          selectedMonth,
          selectedYear,
          employeeId,
        );
        final overtimeAmount = await widget.apiService.fetchOvertimeAmount(
            employeeId, effectiveCompanyId, selectedMonth, selectedYear);
        final earnings = await widget.apiService.fetchEarnings(
            employeeId, effectiveCompanyId, selectedMonth, selectedYear);
        final deductions = await widget.apiService.fetchDeductions(
          effectiveCompanyId,
          selectedMonth,
          selectedYear,
          employeeId,
        );
        final pensionContributions = await widget.apiService
            .fetchPensionContributions(
                employeeId, effectiveCompanyId, selectedMonth, selectedYear);
        final loanRepayment = await widget.apiService.fetchLoanRepayment(
            employeeId, effectiveCompanyId, selectedMonth, selectedYear);
        final insuranceReliefs = await widget.apiService.getInsuranceRelief(
            employeeId: employeeId,
            companyId: effectiveCompanyId,
            month: selectedMonth,
            year: selectedYear);

        double totalNonCashBenefits = 0.0;
        double nonCashForTaxing = 0.0;
        Map<String, double> benefitAmounts = {};
        Map<String, double> deductionAmounts = {};

        if (nonCashBenefits.isNotEmpty) {
          for (var benefit in nonCashBenefits) {
            final description =
                benefit['description']?.toString() ?? 'Unknown Benefit';
            final amount =
                double.tryParse(benefit['amount']?.toString() ?? '0') ?? 0.0;
            benefitDescriptions.add(description);
            benefitAmounts[description] = amount;
            totalNonCashBenefits += amount;
          }
          if (totalNonCashBenefits > 3000) {
            nonCashForTaxing = totalNonCashBenefits;
          }
        }

        double totalOtherDeductionsForEmployee = 0.0;
        if (loanRepayment != null && loanRepayment > 0) {
          const loanDeductionDesc = 'Loan Deduction';
          deductionDescriptions.add(loanDeductionDesc);
          deductionAmounts[loanDeductionDesc] = loanRepayment;
          totalOtherDeductionsForEmployee += loanRepayment;
          if (kDebugMode) {
            print(
                'Added Loan Deduction: $loanRepayment for employee $employeeId');
          }
        }

        if (deductions.isNotEmpty) {
          for (var deduction in deductions) {
            final description =
                deduction['description']?.toString() ?? 'Unknown Deduction';
            if (description.toLowerCase().contains('loan')) {
              if (kDebugMode) {
                print('Skipping loan-related deduction: $description');
              }
              continue;
            }
            final amount =
                double.tryParse(deduction['amount']?.toString() ?? '0') ?? 0.0;
            deductionDescriptions.add(description);
            deductionAmounts[description] = amount;
            totalOtherDeductionsForEmployee += amount;
          }
        }

        final grossPay = originalGrossPay + (overtimeAmount ?? 0.0);
        final nssfTierIDeduction = grossPay > 8000 ? 480 : grossPay * 0.06;
        final nssfTierIIDeduction = (grossPay > 8000)
            ? ((grossPay <= 72000)
                ? (grossPay - 8000) * 0.06
                : (72000 - 8000) * 0.06)
            : 0.0;
        final shifDeduction = grossPay * 0.0275;
        final housingLevy = originalGrossPay * 0.015;

        double insuranceRelief = 0.0;
        if (insuranceReliefs.isNotEmpty) {
          insuranceRelief = insuranceReliefs
              .where((relief) => relief['employee_id'] == employeeId)
              .fold<double>(
                  0.0,
                  (sum, relief) =>
                      sum +
                      (double.tryParse(
                              relief['relief_amount']?.toString() ?? '0') ??
                          0.0));
        }

        final taxableIncome = grossPay +
            nonCashForTaxing -
            nssfTierIDeduction -
            nssfTierIIDeduction -
            shifDeduction -
            (pensionContributions ?? 0.0) -
            housingLevy;

        final payeDeductionBeforeRelief = await widget.apiService.calculatePAYE(
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
                (double.tryParse(earning['amount']?.toString() ?? '0') ?? 0.0));

        final totalCoreDeductions = payeDeduction +
            shifDeduction +
            nssfTierIDeduction +
            nssfTierIIDeduction +
            housingLevy;

        final netPay = grossPay +
            totalEarningsForEmployee -
            totalCoreDeductions -
            totalOtherDeductionsForEmployee +
            (insuranceRelief > 0 ? insuranceRelief : 0.0) -
            (pensionContributions ?? 0.0);

        totalGrossPay += grossPay;
        totalHouseAllowance += houseAllowance;
        totalNetPay += netPay;
        totalDeductions += totalCoreDeductions +
            totalOtherDeductionsForEmployee +
            (pensionContributions ?? 0.0);
        totalOvertimeAmount += (overtimeAmount ?? 0.0);
        totalEarnings += totalEarningsForEmployee;
        totalShifDeduction += shifDeduction;
        totalNssfTierIDeduction += nssfTierIDeduction;
        totalNssfTierIIDeduction += nssfTierIIDeduction;
        totalHousingLevy += housingLevy;
        totalPensionContributions += (pensionContributions ?? 0.0);
        totalPayeDeduction += payeDeduction;
        totalOtherDeductions += totalOtherDeductionsForEmployee;
        totalNonCashBenefitsOverall += totalNonCashBenefits;
        totalInsuranceRelief += insuranceRelief;

        final salaryRecord = {
          'employee_id': employeeId,
          'fullname': employee['fullname'] ?? 'Unknown',
          'company_id': employee['company_id'] ?? effectiveCompanyId,
          'company_name': companyName,
          'gross_pay': grossPay,
          'house_allowance': houseAllowance,
          'basic_pay':
              double.tryParse(employee['basic']?.toString() ?? '0') ?? 0.0,
          'non_cash_benefits':
              totalNonCashBenefits > 0 ? totalNonCashBenefits : null,
          'overtime_amount': overtimeAmount != null && overtimeAmount > 0
              ? overtimeAmount
              : null,
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
              pensionContributions != null && pensionContributions > 0
                  ? pensionContributions
                  : null,
          'paye_deduction': payeDeduction > 0 ? payeDeduction : null,
          'deductions': totalOtherDeductionsForEmployee > 0
              ? totalOtherDeductionsForEmployee
              : null,
          'insurance_relief': insuranceRelief > 0 ? insuranceRelief : null,
          'total_deductions': (totalCoreDeductions +
                      totalOtherDeductionsForEmployee +
                      (pensionContributions ?? 0.0)) >
                  0
              ? (totalCoreDeductions +
                  totalOtherDeductionsForEmployee +
                  (pensionContributions ?? 0.0))
              : null,
          'net_pay': netPay > 0 ? netPay : null,
          'payment_date': selectedPaymentDate != null
              ? DateFormat('yyyy-MM-dd').format(selectedPaymentDate!)
              : DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'status': isPaid ? 'Already Paid' : 'Pending',
          ...benefitAmounts
              .map((key, value) => MapEntry('benefit_$key', value)),
          ...deductionAmounts
              .map((key, value) => MapEntry('deduction_$key', value)),
        };

        setState(() {
          salaries.add(salaryRecord);
          selectedEmployees[employeeId] = false;
        });
      }

      if (isAdmin && salaries.isNotEmpty) {
        setState(() {
          salaries.add({
            'employee_id': null,
            'fullname': 'Totals',
            'company_id': null,
            'company_name': null,
            'gross_pay': totalGrossPay > 0 ? totalGrossPay : null,
            'house_allowance':
                totalHouseAllowance > 0 ? totalHouseAllowance : 0,
            'basic_pay': null,
            'non_cash_benefits': totalNonCashBenefitsOverall > 0
                ? totalNonCashBenefitsOverall
                : null,
            'overtime_amount':
                totalOvertimeAmount > 0 ? totalOvertimeAmount : null,
            'earnings': totalEarnings > 0 ? totalEarnings : null,
            'taxable_income': null,
            'shif_deduction':
                totalShifDeduction > 0 ? totalShifDeduction : null,
            'nssf_tier_i_deduction':
                totalNssfTierIDeduction > 0 ? totalNssfTierIDeduction : null,
            'nssf_tier_ii_deduction':
                totalNssfTierIIDeduction > 0 ? totalNssfTierIIDeduction : null,
            'housing_levy': totalHousingLevy > 0 ? totalHousingLevy : null,
            'pension_contributions': totalPensionContributions > 0
                ? totalPensionContributions
                : null,
            'paye_deduction':
                totalPayeDeduction > 0 ? totalPayeDeduction : null,
            'deductions':
                totalOtherDeductions > 0 ? totalOtherDeductions : null,
            'insurance_relief':
                totalInsuranceRelief > 0 ? totalInsuranceRelief : null,
            'total_deductions': totalDeductions > 0 ? totalDeductions : null,
            'net_pay': totalNetPay > 0 ? totalNetPay : null,
            'payment_date': selectedPaymentDate != null
                ? DateFormat('yyyy-MM-dd').format(selectedPaymentDate!)
                : DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'status': 'Totals',
            ...benefitDescriptions.fold<Map<String, dynamic>>(
                {},
                (map, desc) => map
                  ..['benefit_$desc'] = salaries.fold<double>(0.0,
                      (sum, record) => sum + (record['benefit_$desc'] ?? 0.0))),
            ...deductionDescriptions.fold<Map<String, dynamic>>(
                {},
                (map, desc) => map
                  ..['deduction_$desc'] = salaries.fold<double>(
                      0.0,
                      (sum, record) =>
                          sum + (record['deduction_$desc'] ?? 0.0))),
          });
        });
      }

      if (kDebugMode) {
        print(
            'Processing complete. Total active employees processed: ${employees.length}');
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

Future<Map<String, dynamic>> _checkPaidStatus(
      String employeeId, int companyId, int month, int year) async {
    try {
      final response = await widget.apiService
          .checkPaidStatus(companyId, employeeId, month, year);
      return {'isPaid': response == true, 'message': null};
    } catch (e) {
      if (e is Exception) {
        // Attempt to parse the error as JSON if it's a string
        if (e.toString().contains('{') && e.toString().contains('}')) {
          try {
            final errorData = jsonDecode(e.toString());
            if (errorData['status'] == 'error' &&
                errorData['errors'] is List &&
                (errorData['errors'] as List).any((error) => error
                    .toString()
                    .contains(
                        'Salary already paid for employee ID $employeeId'))) {
              return {
                'isPaid': true,
                'message':
                    'Salary already processed for employee ID $employeeId in ${month.toString().padLeft(2, '0')}/$year'
              };
            }
          } catch (jsonError) {
            if (kDebugMode) {
              print('Failed to parse JSON error: $jsonError');
            }
          }
        }
        if (kDebugMode) {
          print('Error checking paid status for $employeeId: $e');
        }
        return {'isPaid': false, 'message': e.toString()};
      }
      return {'isPaid': false, 'message': e.toString()};
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
                if (salary['payment_date'] != null)
                  _buildSlipText('Payment Date', salary['payment_date']),
                if (salary['status'] != null)
                  _buildSlipText('Status', salary['status']),
                if (salary['gross_pay'] != null)
                  _buildSlipText('Gross Pay (incl. Overtime)',
                      salary['gross_pay'].toStringAsFixed(2)),
                if (salary['house_allowance'] != null)
                  _buildSlipText('House Allowance',
                      salary['house_allowance'].toStringAsFixed(2)),
                if (salary['basic_pay'] != null)
                  _buildSlipText(
                      'Basic Pay', salary['basic_pay'].toStringAsFixed(2)),
                ...benefitDescriptions.map((desc) {
                  final key = 'benefit_$desc';
                  return salary[key] != null
                      ? _buildSlipText(desc, salary[key].toStringAsFixed(2))
                      : Container();
                }),
                if (salary['non_cash_benefits'] != null)
                  _buildSlipText('Total Non-Cash Benefits',
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
                if (salary['pension_contributions'] != null)
                  _buildSlipText('Pension Contributions',
                      salary['pension_contributions'].toStringAsFixed(2)),
                if (salary['insurance_relief'] != null)
                  _buildSlipText('Insurance Relief',
                      salary['insurance_relief'].toStringAsFixed(2)),
                ...deductionDescriptions.map((desc) {
                  final key = 'deduction_$desc';
                  return salary[key] != null
                      ? _buildSlipText(desc, salary[key].toStringAsFixed(2))
                      : Container();
                }),
                if (salary['deductions'] != null)
                  _buildSlipText('Total Other Deductions',
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

  Future<void> exportMasterPayroll() async {
    if (salaries.isEmpty ||
        (widget.user.role == 'admin' &&
            salaries.last['fullname'] != 'Totals')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fetch salaries first.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final headers = _buildTableColumns()
          .map((col) => (col.label as Text).data!)
          .toList()
          .where((header) => header != 'Select')
          .toList();

      final List<List<String>> csvData = [headers];

      for (var salary in salaries) {
        final row = [
          salary['employee_id']?.toString() ?? '',
          salary['company_name']?.toString() ?? '',
          salary['fullname']?.toString() ?? '',
          salary['gross_pay']?.toStringAsFixed(2) ?? '0.00',
          salary['house_allowance']?.toStringAsFixed(2) ?? '0.00',
          salary['basic_pay']?.toStringAsFixed(2) ?? '0.00',
          ...benefitDescriptions
              .map((desc) => salary['benefit_$desc']?.toStringAsFixed(2) ?? ''),
          salary['non_cash_benefits']?.toStringAsFixed(2) ?? '',
          salary['overtime_amount']?.toStringAsFixed(2) ?? '',
          salary['earnings']?.toStringAsFixed(2) ?? '',
          salary['taxable_income']?.toStringAsFixed(2) ?? '',
          ...deductionDescriptions.map(
              (desc) => salary['deduction_$desc']?.toStringAsFixed(2) ?? ''),
          salary['deductions']?.toStringAsFixed(2) ?? '',
          salary['shif_deduction']?.toStringAsFixed(2) ?? '',
          salary['nssf_tier_i_deduction']?.toStringAsFixed(2) ?? '',
          salary['nssf_tier_ii_deduction']?.toStringAsFixed(2) ?? '',
          salary['housing_levy']?.toStringAsFixed(2) ?? '',
          salary['paye_deduction']?.toStringAsFixed(2) ?? '',
          salary['pension_contributions']?.toStringAsFixed(2) ?? '',
          salary['insurance_relief']?.toStringAsFixed(2) ?? '',
          salary['total_deductions']?.toStringAsFixed(2) ?? '',
          salary['net_pay']?.toStringAsFixed(2) ?? '',
          salary['payment_date']?.toString() ?? '',
          salary['status']?.toString() ?? '',
        ];
        csvData.add(row.map((e) => (e as String).replaceAll(',', '')).toList());
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName =
          'MasterPayroll_${selectedPaymentDate != null ? DateFormat('yyyy-MM-dd').format(selectedPaymentDate!) : DateTime.now().toString()}_${companyIdToName[selectedCompanyId] ?? 'Unknown'}.csv';
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
        if (directory == null) {
          throw Exception('Could not access Downloads directory');
        }
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(csvBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV file saved to: $filePath')),
        );
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';

    return Scaffold(
      appBar: CustomAppBar(
        title: isAdmin ? 'Pay Salaries' : 'My Salary',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.teal[700]),
                    title: Text('Profile: ${widget.user.username}'),
                    subtitle: Text('Role: ${widget.user.role}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
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
                      if (isAdmin) ...[
                        Row(
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
                                value: selectedCompanyId,
                                items: companyIds,
                                itemBuilder: (id) =>
                                    companyIdToName[id] ?? 'Unknown',
                                onChanged: (value) {
                                  setState(() {
                                    selectedCompanyId = value;
                                    salaries.clear();
                                    selectedEmployees.clear();
                                    searchKeyword = '';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
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
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Company: ${companyIdToName[widget.user.companyId] ?? 'Unknown'}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[900]),
                        ),
                      ],
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      selectedPaymentDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.teal[700]!,
                                          onPrimary: Colors.white,
                                          surface: Colors.teal[50]!,
                                          onSurface: Colors.teal[900]!,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null &&
                                    picked != selectedPaymentDate) {
                                  setState(() {
                                    selectedPaymentDate = picked;
                                    salaries.clear();
                                    selectedEmployees.clear();
                                    searchKeyword = '';
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedPaymentDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(selectedPaymentDate!)
                                          : 'Select Payment Date',
                                      style: TextStyle(color: Colors.teal[900]),
                                    ),
                                    Icon(Icons.calendar_today,
                                        color: Colors.teal[700]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton(
                            onPressed:
                                isLoading ? null : fetchAndCalculateSalaries,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isAdmin)
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
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 300), () {
                          setState(() {
                            searchKeyword = value.toLowerCase();
                          });
                        });
                      },
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ),
                ),
              if (isAdmin && salaries.isNotEmpty)
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
                            child: Text('No active salaries available',
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
              if (isAdmin) const SizedBox(height: 16),
              if (isAdmin)
                ElevatedButton(
                  onPressed: isLoading ? null : exportMasterPayroll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
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
      floatingActionButton: isAdmin
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: () async {
                    if (salaries.isEmpty ||
                        salaries.last['fullname'] != 'Totals') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fetch salaries first.')),
                      );
                      return;
                    }

                    if (selectedCompanyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No company selected.')),
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
                            content: Text(
                                'No employee selected for single payment.')),
                      );
                      return;
                    }

                    final selectedEmployee = salaries.firstWhere(
                      (salary) => salary['employee_id'] == selectedEmployeeId,
                      orElse: () => {},
                    );

                    if (selectedEmployee.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Selected employee not found.')),
                      );
                      return;
                    }

                    if (selectedEmployee['status'] == 'Already Paid') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Salary already paid for this month.')),
                      );
                      return;
                    }

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Single Payment'),
                        content: Text(
                            'Initiate payment for ${selectedEmployee['fullname']} (Net Pay: ${selectedEmployee['net_pay'].toStringAsFixed(2)})?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    setState(() => isLoading = true);

                    try {
                      final response = await widget.apiService
                          .saveSalary(selectedEmployee, selectedCompanyId!);
                      // If saveSalary returns void, just show a success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Single Payment initiated for ${selectedEmployee['fullname']}'),
                          backgroundColor: Colors.teal[700],
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error during single payment: $e')),
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
                    if (salaries.isEmpty ||
                        salaries.last['fullname'] != 'Totals') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fetch salaries first.')),
                      );
                      return;
                    }

                    if (selectedCompanyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No company selected.')),
                      );
                      return;
                    }

                    final employeesToPay = salaries
                        .where((salary) =>
                            salary['fullname'] != 'Totals' &&
                            !(selectedEmployees[salary['employee_id']] ??
                                false))
                        .toList();

                    if (employeesToPay.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'No employees selected for bulk payment.')),
                      );
                      return;
                    }

                    final employeesAlreadyPaid = employeesToPay
                        .where((salary) => salary['status'] == 'Already Paid')
                        .toList();
                    if (employeesAlreadyPaid.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${employeesAlreadyPaid.length} employee(s) already paid for this month.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Bulk Payment'),
                        content: Text(
                            'Initiate payment for ${employeesToPay.length} employees?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    setState(() => isLoading = true);

                    try {
                      for (var employee in employeesToPay) {
                        await widget.apiService.saveSalary(employee, selectedCompanyId!);
                        // If you want to update the status after saving, you may need to re-fetch salaries or handle status update differently.
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
                        SnackBar(
                            content: Text('Error during bulk payment: $e')),
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
            )
          : null,
    );
  }

  List<DataColumn> _buildTableColumns() {
    final isAdmin = widget.user.role == 'admin';
    final keys = [
      if (isAdmin) 'Select',
      'Employee ID',
      'Company Name',
      'Full Name',
      'Gross Pay',
      'House Allowance',
      'Basic Pay',
      ...benefitDescriptions.map((desc) => desc),
      'Total Non-Cash Benefits',
      'Overtime Amount',
      'Total Earnings',
      'Taxable Income',
      ...deductionDescriptions.map((desc) => desc),
      'Total Other Deductions',
      'SHIF Deduction',
      'NSSF Tier I Deduction',
      'NSSF Tier II Deduction',
      'Housing Levy',
      'PAYE Deduction',
      'Pension Contributions',
      'Insurance Relief',
      'Total Deductions',
      'Net Pay',
      'Payment Date',
      'Status',
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
      if (widget.user.role == 'admin' && salary['fullname'] == 'Totals') {
        return true;
      }
      final fullName = salary['fullname']?.toString().toLowerCase() ?? '';
      return fullName.contains(searchKeyword);
    }).toList();

    return filteredSalaries.map((salary) {
      final isAdmin = widget.user.role == 'admin';
      final keys = [
        if (isAdmin) 'Select',
        'employee_id',
        'company_name',
        'fullname',
        'gross_pay',
        'house_allowance',
        'basic_pay',
        ...benefitDescriptions.map((desc) => 'benefit_$desc'),
        'non_cash_benefits',
        'overtime_amount',
        'earnings',
        'taxable_income',
        ...deductionDescriptions.map((desc) => 'deduction_$desc'),
        'deductions',
        'shif_deduction',
        'nssf_tier_i_deduction',
        'nssf_tier_ii_deduction',
        'housing_levy',
        'paye_deduction',
        'pension_contributions',
        'insurance_relief',
        'total_deductions',
        'net_pay',
        'payment_date',
        'status',
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
                            ? ''
                            : key == 'house_allowance'
                                ? 0.0
                                : key == 'payment_date'
                                    ? ''
                                    : key == 'status'
                                        ? 'Pending'
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
                    style: TextStyle(
                        color: value == 'Already Paid'
                            ? Colors.red[700]
                            : Colors.grey[800])),
                onTap: () => showSalarySlip(salary),
              );
            }
          }
        }).toList(),
      );
    }).toList();
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
