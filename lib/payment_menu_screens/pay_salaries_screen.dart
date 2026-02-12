import 'dart:async';
import 'dart:convert';
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
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  PaySalariesScreenState createState() => PaySalariesScreenState();
}

class PaySalariesScreenState extends State<PaySalariesScreen> {
  // Data
  List<SalaryRecord> salaries = [];
  bool isLoading = false;

  // Filters
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  DateTime? selectedPaymentDate;
  int? selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};

  // Selection & Search
  Map<String, bool> selectedEmployees = {};
  String searchKeyword = '';
  Timer? _debounce;

  // Benefits & Deductions tracking
  Set<String> cashBenefitDescriptions = {};
  Set<String> nonCashBenefitDescriptions = {};
  Set<String> deductionDescriptions = {};
  bool _includeBonusInHousingLevy = true;

  // Color scheme
  final Color primaryColor = const Color(0xFF2E7D32);
  final Color secondaryColor = const Color(0xFF4CAF50);
  final Color accentColor = const Color(0xFF8BC34A);
  final Color backgroundColor = const Color(0xFFF5F9F5);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2E3A3B);
  final Color subtitleColor = const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    selectedPaymentDate = DateTime.now();
    _initializeData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    setState(() => isLoading = true);
    try {
      final companies = await widget.apiService.getCompanies();
      final isAdmin = widget.user.role == 'admin';

      setState(() {
        if (isAdmin) {
          // Admin sees their assigned company
          final filteredCompanies = companies.where((c) {
            final companyId = _parseCompanyId(c['id']);
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
          // Non-admin sees only their company
          final filteredCompanies = companies.where((c) {
            final companyId = _parseCompanyId(c['id']);
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
      });

      if (selectedCompanyId != null) {
        await fetchAndCalculateSalaries();
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error fetching companies: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  int _parseCompanyId(dynamic id) {
    if (id is String) return int.tryParse(id) ?? 0;
    if (id is int) return id;
    return 0;
  }

  Future<void> fetchAndCalculateSalaries() async {
    if (selectedCompanyId == null) return;

    final isAdmin = widget.user.role == 'admin';
    if (!isAdmin && selectedCompanyId != widget.user.companyId) {
      _showErrorSnackBar('Access denied: You can only view your company\'s salaries.');
      return;
    }

    setState(() {
      isLoading = true;
      salaries.clear();
      selectedEmployees.clear();
      cashBenefitDescriptions.clear();
      nonCashBenefitDescriptions.clear();
      deductionDescriptions.clear();
    });

    try {
      final employees = await _fetchEmployees();
      if (employees.isEmpty) {
        throw Exception('No active employees found for your company.');
      }

      // Fetch all deductions for the company once
      final allDeductions = await widget.apiService.fetchDeductionsList(
        selectedCompanyId!,
        month: selectedMonth,
        year: selectedYear,
      );

      final calculationResults = await _calculateAllSalaries(employees, allDeductions);
      _updateSalariesList(calculationResults);

    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error calculating salaries: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEmployees() async {
    final isAdmin = widget.user.role == 'admin';
    final userEmployeeId = widget.user.employeeId;
    final effectiveCompanyId = selectedCompanyId!;

    List<Map<String, dynamic>> employees = [];
    
    if (isAdmin) {
      employees = await widget.apiService.getEmployeeList(effectiveCompanyId);
    } else if (userEmployeeId != null) {
      employees = (await widget.apiService.getEmployeeList(widget.user.companyId))
          .where((e) => e['employee_id'] == userEmployeeId)
          .toList();
    }

    // Filter out inactive employees
    return employees.where((e) => e['employee_status'] != 'Inactive').toList();
  }

  Future<List<SalaryCalculation>> _calculateAllSalaries(
      List<Map<String, dynamic>> employees,
      List<Map<String, dynamic>> allDeductions) async {
    final effectiveCompanyId = selectedCompanyId!;
    final List<SalaryCalculation> calculations = [];

    for (var employee in employees) {
      final calculation = await _calculateEmployeeSalary(employee, effectiveCompanyId, allDeductions);
      calculations.add(calculation);
    }

    return calculations;
  }

  Future<SalaryCalculation> _calculateEmployeeSalary(
      Map<String, dynamic> employee,
      int companyId,
      List<Map<String, dynamic>> allDeductions) async {
    final employeeId = employee['employee_id'].toString();
    final originalGrossPay = _parseDouble(employee['gross_pay']);
    final houseAllowance = _parseDouble(employee['house_allowance']);
    final basicPay = _parseDouble(employee['basic']);

    // Check if already paid
    final paymentDate = selectedPaymentDate!;
    final month = paymentDate.month;
    final year = paymentDate.year;
    final isPaid = await _checkPaidStatus(employeeId, companyId, month, year);

    // Fetch all necessary data
    final allBenefits = await widget.apiService.fetchBenefits(
      companyId, selectedMonth, selectedYear, employeeId);

    final overtimeAmount = await widget.apiService.fetchOvertimeAmount(
      employeeId, companyId, selectedMonth, selectedYear);

    final earnings = await widget.apiService.fetchEarnings(
      employeeId, companyId, selectedMonth, selectedYear);

    // Filter deductions for this employee and selected month/year from the bulk list
    final deductions = allDeductions.where((d) {
      if (d['date'] == null) return false;
      try {
        final date = DateTime.parse(d['date'].toString());
        return d['employee_id'].toString().trim().toLowerCase() == 
               employeeId.trim().toLowerCase() &&
               date.month == selectedMonth &&
               date.year == selectedYear;
      } catch (e) {
        return false;
      }
    }).toList();

    final pensionContributions = await widget.apiService.fetchPensionContributions(
      employeeId, companyId, selectedMonth, selectedYear);

    final loanRepayment = await widget.apiService.fetchLoanRepayment(
      employeeId, companyId, selectedMonth, selectedYear);

    final insuranceReliefs = await widget.apiService.getInsuranceRelief(
      employeeId: employeeId,
      companyId: companyId,
      month: selectedMonth,
      year: selectedYear);

    // Process benefits (SEPARATE CASH AND NON-CASH BASED ON benefit_type FROM API)
    final benefitResult = _processBenefits(allBenefits);
    
    // Process Deductions into a Map for the UI columns
    Map<String, double> deductionAmounts = {};
    for (var deduction in deductions) {
      final description = deduction['description']?.toString() ?? 'Unknown Deduction';
      final amount = _parseDouble(deduction['amount']);
      
      if (!description.toLowerCase().contains('loan')) {
        deductionAmounts[description] = (deductionAmounts[description] ?? 0.0) + amount;
      }
    }

    // Calculate gross pay (INCLUDING CASH BENEFITS)
    final grossPay = originalGrossPay + overtimeAmount + benefitResult.totalCashBenefits;

    // Calculate statutory deductions
    final nssfTierIDeduction = _calculateNSSFTierI(grossPay);
    final nssfTierIIDeduction = _calculateNSSFTierII(grossPay);
    final shifDeduction = grossPay * 0.0275;

    double housingLevyBase = grossPay;
    if (!_includeBonusInHousingLevy) {
      housingLevyBase -= benefitResult.bonusAmount;
    }
    housingLevyBase -= overtimeAmount;
    final housingLevy = housingLevyBase * 0.015;

    // Calculate other components
    final totalEarnings = _sumEarnings(earnings);
    final insuranceRelief = _sumInsuranceRelief(insuranceReliefs, employeeId);
    final totalOtherDeductions = _calculateOtherDeductions(deductions, loanRepayment);

    // Calculate taxable income (INCLUDING taxable non-cash benefits)
    final taxableIncome = _calculateTaxableIncome(
      grossPay,
      benefitResult.taxableNonCashBenefits,
      totalEarnings,
      nssfTierIDeduction,
      nssfTierIIDeduction,
      shifDeduction,
      pensionContributions,
      housingLevy,
    );

    // Calculate PAYE
    final payeDeduction = await _calculatePAYEWithRelief(
      taxableIncome,
      nssfTierIDeduction + nssfTierIIDeduction,
      housingLevy,
      insuranceRelief,
    );

    // Calculate net pay
    final netPay = _calculateNetPay(
      grossPay,
      totalEarnings,
      payeDeduction,
      shifDeduction,
      nssfTierIDeduction,
      nssfTierIIDeduction,
      housingLevy,
      pensionContributions,
      totalOtherDeductions,
      insuranceRelief,
    );

    // Track descriptions for UI
    _trackBenefitAndDeductionDescriptions(benefitResult, deductions);

    return SalaryCalculation(
      employeeId: employeeId,
      fullname: employee['fullname']?.toString() ?? 'Unknown',
      companyId: companyId,
      companyName: employee['company_name']?.toString(),
      originalGrossPay: originalGrossPay,
      houseAllowance: houseAllowance,
      basicPay: basicPay,
      isPaid: isPaid,
      benefitResult: benefitResult,
      overtimeAmount: overtimeAmount,
      earnings: earnings,
      totalEarnings: totalEarnings,
      deductions: deductions,
      pensionContributions: pensionContributions,
      loanRepayment: loanRepayment,
      insuranceRelief: insuranceRelief,
      grossPay: grossPay,
      nssfTierIDeduction: nssfTierIDeduction,
      nssfTierIIDeduction: nssfTierIIDeduction,
      shifDeduction: shifDeduction,
      housingLevy: housingLevy,
      totalOtherDeductions: totalOtherDeductions,
      taxableIncome: taxableIncome,
      payeDeduction: payeDeduction,
      netPay: netPay,
      cashBenefitAmounts: benefitResult.cashBenefitAmounts,
      nonCashBenefitAmounts: benefitResult.nonCashBenefitAmounts,
      deductionAmounts: deductionAmounts,
      bonusAmount: benefitResult.bonusAmount,
    );
  }

  BenefitResult _processBenefits(List<Map<String, dynamic>> benefits) {
    double totalCashBenefits = 0.0;
    double totalNonCashBenefits = 0.0;
    double taxableNonCashBenefits = 0.0;
    double carBenefitTotal = 0.0;
    double otherNonCashTotal = 0.0;
    Map<String, double> cashBenefitAmounts = {};
    Map<String, double> nonCashBenefitAmounts = {};
    Map<String, double> deductionAmounts = {};
    double bonusAmount = 0.0;

    for (var benefit in benefits) {
      final description = benefit['description']?.toString() ?? 'Unknown Benefit';
      final amount = _parseDouble(benefit['amount']);
      
      // CRITICAL: Read benefit_type from API response - this comes from {"benefit_type":"Cash"}
      final benefitType = (benefit['benefit_type']?.toString() ?? 'Non-Cash').toLowerCase().trim();
      
      if (kDebugMode) {
        print('Processing benefit: $description, Type: $benefitType, Amount: $amount');
      }

      if (benefitType.contains('cash') && !benefitType.contains('non')) {
        // CASH BENEFITS: Always taxable, add to gross pay
        cashBenefitAmounts[description] = amount;
        if (description.toLowerCase().trim() == 'bonus') {
          bonusAmount += amount;
        }
        totalCashBenefits += amount;
        if (kDebugMode) {
          print('✓ CASH benefit: $description - KES $amount (ALWAYS taxable, added to gross pay)');
        }
      } else {
        // NON-CASH BENEFITS: Only taxable if > 5,000
        nonCashBenefitAmounts[description] = amount;
        totalNonCashBenefits += amount;
        
        // Check if it is a Car Benefit
        if (description.toLowerCase().contains('car')) {
          carBenefitTotal += amount;
        } else {
          otherNonCashTotal += amount;
        }
      }
    }

    // Calculate Taxable Non-Cash Benefits
    // Car benefit is always taxable. Other non-cash benefits are taxable only if their sum exceeds 5,000.
    taxableNonCashBenefits = carBenefitTotal;
    
    if (otherNonCashTotal > 5000) {
      taxableNonCashBenefits += otherNonCashTotal;
    }

    if (kDebugMode) {
      print('Benefit Summary:');
      print('  Total Cash Benefits: KES $totalCashBenefits');
      print('  Total Non-Cash Benefits: KES $totalNonCashBenefits');
      print('  Car Benefit: KES $carBenefitTotal');
      print('  Other Non-Cash Total: KES $otherNonCashTotal');
      print('  Taxable Non-Cash Benefits: KES $taxableNonCashBenefits');
    }

    return BenefitResult(
      totalCashBenefits: totalCashBenefits,
      totalNonCashBenefits: totalNonCashBenefits,
      taxableNonCashBenefits: taxableNonCashBenefits,
      cashBenefitAmounts: cashBenefitAmounts,
      nonCashBenefitAmounts: nonCashBenefitAmounts,
      deductionAmounts: deductionAmounts,
      bonusAmount: bonusAmount,
    );
  }

  void _trackBenefitAndDeductionDescriptions(
      BenefitResult benefitResult, List<Map<String, dynamic>> deductions) {
    cashBenefitDescriptions.addAll(benefitResult.cashBenefitAmounts.keys);
    nonCashBenefitDescriptions.addAll(benefitResult.nonCashBenefitAmounts.keys);
    
    for (var deduction in deductions) {
      final description = deduction['description']?.toString() ?? 'Unknown Deduction';
      if (!description.toLowerCase().contains('loan')) {
        deductionDescriptions.add(description);
      }
    }
  }

  double _calculateNSSFTierI(double grossPay) {
    return grossPay > 8000 ? 480 : grossPay * 0.06;
  }

  double _calculateNSSFTierII(double grossPay) {
    if (grossPay <= 8000) return 0.0;
    if (grossPay <= 72000) return (grossPay - 8000) * 0.06;
    return (72000 - 8000) * 0.06;
  }

  double _sumEarnings(List<Map<String, dynamic>> earnings) {
    return earnings.fold(0.0, (sum, earning) => sum + _parseDouble(earning['amount']));
  }

  double _sumInsuranceRelief(List<Map<String, dynamic>> reliefs, String employeeId) {
    return reliefs
        .where((relief) => relief['employee_id'] == employeeId)
        .fold(0.0, (sum, relief) => sum + _parseDouble(relief['relief_amount']));
  }

  double _calculateOtherDeductions(List<Map<String, dynamic>> deductions, double? loanRepayment) {
    double total = 0.0;
    
    if (loanRepayment != null && loanRepayment > 0) {
      total += loanRepayment;
    }
    
    for (var deduction in deductions) {
      final description = deduction['description']?.toString().toLowerCase() ?? '';
      if (!description.contains('loan')) {
        total += _parseDouble(deduction['amount']);
      }
    }
    
    return total;
  }

  double _calculateTaxableIncome(
    double grossPay,
    double taxableNonCashBenefits,
    double totalEarnings,
    double nssfTierI,
    double nssfTierII,
    double shifDeduction,
    double pensionContributions,
    double housingLevy,
  ) {
    // IMPORTANT: Cash benefits are already included in grossPay
    // Only taxable non-cash benefits (>5000) are added separately
    return grossPay 
        + taxableNonCashBenefits  // Only NON-CASH benefits > 5,000 KES
        + totalEarnings
        - nssfTierI
        - nssfTierII
        - shifDeduction
        - pensionContributions
        - housingLevy;
  }

  Future<double> _calculatePAYEWithRelief(
    double taxableIncome,
    double nssfContribution,
    double housingLevy,
    double insuranceRelief,
  ) async {
    final payeBeforeRelief = await widget.apiService.calculatePAYE(
      taxableIncome,
      personalRelief: 2400,
      nhifRelief: 0,
      nssfContribution: nssfContribution,
      housingLevy: housingLevy,
    );

    if (insuranceRelief > 0 && payeBeforeRelief > 0) {
      return payeBeforeRelief - insuranceRelief > 0 
          ? payeBeforeRelief - insuranceRelief 
          : 0.0;
    }
    
    return payeBeforeRelief;
  }

  double _calculateNetPay(
    double grossPay,
    double totalEarnings,
    double payeDeduction,
    double shifDeduction,
    double nssfTierI,
    double nssfTierII,
    double housingLevy,
    double pensionContributions,
    double totalOtherDeductions,
    double insuranceRelief,
  ) {
    final totalCoreDeductions = payeDeduction +
        shifDeduction +
        nssfTierI +
        nssfTierII +
        housingLevy;

    return grossPay +
        totalEarnings -
        totalCoreDeductions -
        totalOtherDeductions +
        (insuranceRelief > 0 ? insuranceRelief : 0.0) -
        pensionContributions;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<bool> _checkPaidStatus(String employeeId, int companyId, int month, int year) async {
    try {
      final response = await widget.apiService.checkPaidStatus(companyId, employeeId, month, year);
      return response == true;
    } catch (e) {
      // Check if error message indicates already paid
      if (e.toString().contains('Salary already paid for employee ID')) {
        return true;
      }
      return false;
    }
  }

  void _updateSalariesList(List<SalaryCalculation> calculations) {
    final isAdmin = widget.user.role == 'admin';
    final now = DateTime.now();
    
    for (var calc in calculations) {
      final salaryRecord = SalaryRecord.fromCalculation(
        calc,
        selectedPaymentDate ?? now,
        isAdmin,
      );
      
      salaries.add(salaryRecord);
      selectedEmployees[calc.employeeId] = false;
    }

    // Add totals row for admin
    if (isAdmin && salaries.isNotEmpty) {
      final totals = _calculateTotals();
      salaries.add(totals);
    }
  }

  SalaryRecord _calculateTotals() {
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
    double totalCashBenefits = 0;
    double totalNonCashBenefits = 0;
    double totalTaxableNonCashBenefits = 0;
    double totalInsuranceRelief = 0;

    for (var salary in salaries) {
      if (salary.employeeId.isNotEmpty) { // Skip if already a totals row
        totalGrossPay += salary.grossPay;
        totalHouseAllowance += salary.houseAllowance;
        totalNetPay += salary.netPay;
        totalDeductions += salary.totalDeductions;
        totalOvertimeAmount += salary.overtimeAmount;
        totalEarnings += salary.earnings;
        totalShifDeduction += salary.shifDeduction;
        totalNssfTierIDeduction += salary.nssfTierIDeduction;
        totalNssfTierIIDeduction += salary.nssfTierIIDeduction;
        totalHousingLevy += salary.housingLevy;
        totalPensionContributions += salary.pensionContributions;
        totalPayeDeduction += salary.payeDeduction;
        totalOtherDeductions += salary.otherDeductions;
        totalCashBenefits += salary.cashBenefits;
        totalNonCashBenefits += salary.nonCashBenefits;
        totalTaxableNonCashBenefits += salary.taxableNonCashBenefits;
        totalInsuranceRelief += salary.insuranceRelief;
      }
    }

    return SalaryRecord.totals(
      totalGrossPay: totalGrossPay,
      totalHouseAllowance: totalHouseAllowance,
      totalNetPay: totalNetPay,
      totalDeductions: totalDeductions,
      totalOvertimeAmount: totalOvertimeAmount,
      totalEarnings: totalEarnings,
      totalShifDeduction: totalShifDeduction,
      totalNssfTierIDeduction: totalNssfTierIDeduction,
      totalNssfTierIIDeduction: totalNssfTierIIDeduction,
      totalHousingLevy: totalHousingLevy,
      totalPensionContributions: totalPensionContributions,
      totalPayeDeduction: totalPayeDeduction,
      totalOtherDeductions: totalOtherDeductions,
      totalCashBenefits: totalCashBenefits,
      totalNonCashBenefits: totalNonCashBenefits,
      totalTaxableNonCashBenefits: totalTaxableNonCashBenefits,
      totalInsuranceRelief: totalInsuranceRelief,
      cashBenefitDescriptions: cashBenefitDescriptions,
      nonCashBenefitDescriptions: nonCashBenefitDescriptions,
      deductionDescriptions: deductionDescriptions,
      salaries: salaries,
      paymentDate: selectedPaymentDate ?? DateTime.now(),
    );
  }

  // UI Components
  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: CustomAppBar(
        title: isAdmin ? 'Pay Salaries' : 'My Salary',
        backgroundColor: primaryColor,
        onNotificationTap: () => _handleNotificationTap(),
        onProfileTap: () => _showProfileBottomSheet(context),
      ),
      body: Column(
        children: [
          // Header Card with Filters
          _buildHeaderCard(isAdmin),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (isAdmin) ...[
                    _buildSearchSection(),
                    const SizedBox(height: 8),
                    if (salaries.isNotEmpty) _buildInstructions(),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLoading
                        ? _buildLoadingState()
                        : salaries.isEmpty
                            ? _buildEmptyState()
                            : _buildSalaryTable(),
                  ),
                ],
              ),
            ),
          ),

          // Footer Actions (Admin only)
          if (isAdmin) _buildFooterActions(),
        ],
      ),
      floatingActionButton: isAdmin ? _buildFloatingActions() : null,
    );
  }

  Widget _buildHeaderCard(bool isAdmin) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, secondaryColor],
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
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAdmin ? Icons.payments : Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdmin ? 'Salary Management' : 'My Salary',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isAdmin 
                            ? 'Process and manage employee salaries'
                            : 'View your salary details and payslips',
                        style:  TextStyle(
                          color: Colors.white.withAlpha(230),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFilterSection(isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isAdmin) {
    return Column(
      children: [
        if (isAdmin) ...[
          Row(
            children: [
              Expanded(child: _buildMonthDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildYearDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildCompanyDropdown()),
            ],
          ),
          const SizedBox(height: 12),
        ] else ...[
          Row(
            children: [
              Expanded(child: _buildMonthDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildYearDropdown()),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Company: ${companyIdToName[widget.user.companyId] ?? 'Unknown'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDatePicker()),
            const SizedBox(width: 12),
            _buildFetchButton(),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          _buildHousingLevyOnBonusCheckbox(),
        ],
      ],
    );
  }

  Widget _buildMonthDropdown() {
    return _buildDropdown<int>(
      value: selectedMonth,
      items: List.generate(12, (index) => index + 1),
      itemBuilder: (month) => DateFormat('MMMM').format(DateTime(selectedYear, month)),
      onChanged: (value) => _updateFilter(month: value),
      hint: 'Select Month',
    );
  }

  Widget _buildYearDropdown() {
    return _buildDropdown<int>(
      value: selectedYear,
      items: List.generate(10, (index) => DateTime.now().year - index),
      itemBuilder: (year) => year.toString(),
      onChanged: (value) => _updateFilter(year: value),
      hint: 'Select Year',
    );
  }

  Widget _buildCompanyDropdown() {
    return _buildDropdown<int?>(
      value: selectedCompanyId,
      items: companyIds,
      itemBuilder: (id) => companyIdToName[id] ?? 'Unknown',
      onChanged: (value) => _updateFilter(companyId: value),
      hint: 'Select Company', 
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item, 
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(color: subtitleColor),
        ),
        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
        dropdownColor: cardColor,
        style: TextStyle(color: textColor, fontSize: 14),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _showDatePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedPaymentDate != null
                  ? DateFormat('EEE, MMM d, yyyy').format(selectedPaymentDate!)
                  : 'Select Payment Date',
              style: TextStyle(
                color: selectedPaymentDate != null ? textColor : subtitleColor,
                fontSize: 14,
              ),
            ),
            Icon(Icons.calendar_today, color: primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFetchButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : fetchAndCalculateSalaries,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: primaryColor,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 16),
                SizedBox(width: 8),
                Text('Fetch Salaries'),
              ],
            ),
    );
  }

  Widget _buildHousingLevyOnBonusCheckbox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        title: Text(
          'Include Bonus in Housing Levy Calculation',
          style: TextStyle(color: textColor, fontSize: 14),
        ),
        value: _includeBonusInHousingLevy,
        onChanged: (bool? value) {
          if (value != null) {
            setState(() {
              _includeBonusInHousingLevy = value;
            });
            if (salaries.isNotEmpty) {
              fetchAndCalculateSalaries();
            }
          }
        },
        activeColor: primaryColor,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: TextField(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            labelText: 'Search employees...',
            labelStyle: TextStyle(color: subtitleColor),
            prefixIcon: Icon(Icons.search, color: subtitleColor),
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.transparent,
          ),
          onChanged: _handleSearch,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Check the box next to an employee to exclude them from bulk payment.',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Calculating salaries...',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payments_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No salaries available',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetch salaries to view payment details',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryTable() {
    final columnLabels = _getTableColumnLabels();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 20,              
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              headingRowHeight: 56,
              horizontalMargin: 20,
              headingTextStyle: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              dataTextStyle: TextStyle(
                color: textColor,
                fontSize: 12,
              ),
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              columns: columnLabels.map((label) => DataColumn(
                label: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              )).toList(),
              rows: _buildTableRows(),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getTableColumnLabels() {
    final isAdmin = widget.user.role == 'admin';
    final keys = <String>[];
    
    if (isAdmin) keys.add('Select');
    
    // Basic employee info
    keys.addAll([
      'Employee ID',
      'Company Name',
      'Full Name',
      'Gross Pay',
      'House Allowance',
      'Basic Pay',
    ]);
    
    // Individual cash benefits
    for (var desc in cashBenefitDescriptions) {
      keys.add('Cash: $desc');
    }
    
    // Individual non-cash benefits
    for (var desc in nonCashBenefitDescriptions) {
      keys.add('Non-Cash: $desc');
    }
    
    // Benefit totals
    keys.addAll([
      'Total Cash Benefits',
      'Total Non-Cash Benefits',
      'Taxable Non-Cash Benefits',
      'Overtime Amount',
      'Total Earnings',
      'Taxable Income',
    ]);
    
    // Individual deductions
    for (var desc in deductionDescriptions) {
      keys.add('Deduction: $desc');
    }
    
    // Deduction totals and statutory
    keys.addAll([
      'Total Other Deductions',
      'SHIF Deduction',
      'NSSF Tier I',
      'NSSF Tier II',
      'Housing Levy',
      'PAYE Deduction',
      'Pension Contributions',
      'Insurance Relief',
      'Total Deductions',
      'Net Pay',
      'Payment Date',
      'Status',
    ]);
    
    return keys.map((key) => key.replaceAll('_', ' ').capitalize()).toList();
  }

  List<DataRow> _buildTableRows() {
    final filteredSalaries = _getFilteredSalaries();
    
    return filteredSalaries.map((salary) {
      final isAdmin = widget.user.role == 'admin';
      final isTotalRow = salary.isTotalsRow;
      
      return DataRow(
        color: isTotalRow
            ? WidgetStateProperty.all(primaryColor.withAlpha(26))
            : null,
        cells: _buildTableCellData(salary, isAdmin, isTotalRow),
      );
    }).toList();
  }

  List<SalaryRecord> _getFilteredSalaries() {
    return salaries.where((salary) {
      if (salary.isTotalsRow) return true;
      final fullName = salary.fullname.toLowerCase();
      return fullName.contains(searchKeyword.toLowerCase());
    }).toList();
  }

  List<DataCell> _buildTableCellData(SalaryRecord salary, bool isAdmin, bool isTotalRow) {
    final cells = <DataCell>[];
    
    if (isAdmin) {
      cells.add(DataCell(
        Checkbox(
          value: !isTotalRow ? selectedEmployees[salary.employeeId] ?? false : null,
          tristate: true,
          onChanged: !isTotalRow ? (value) {
            setState(() {
              selectedEmployees[salary.employeeId] = value!;
            });
          } : null,
          activeColor: primaryColor,
        ),
      ));
    }
    
    // Add all data cells in the correct order
    cells.addAll([
      _buildTextCell(salary.employeeId, isTotalRow),
      _buildTextCell(salary.companyName, isTotalRow),
      _buildTextCell(salary.fullname, isTotalRow, isName: true),
      _buildCurrencyCell(salary.grossPay, isTotalRow),
      _buildCurrencyCell(salary.houseAllowance, isTotalRow),
      _buildCurrencyCell(salary.basicPay, isTotalRow),
    ]);

    // Add individual cash benefits
    for (var desc in cashBenefitDescriptions) {
      final key = 'cash_benefit_$desc';
      final value = salary.additionalFields[key];
      cells.add(_buildCurrencyCell(value is double ? value : 0.0, isTotalRow));
    }

    // Add individual non-cash benefits
    for (var desc in nonCashBenefitDescriptions) {
      final key = 'non_cash_benefit_$desc';
      final value = salary.additionalFields[key];
      cells.add(_buildCurrencyCell(value is double ? value : 0.0, isTotalRow));
    }

    // Add remaining fields
    cells.addAll([
      _buildCurrencyCell(salary.cashBenefits, isTotalRow),
      _buildCurrencyCell(salary.nonCashBenefits, isTotalRow),
      _buildCurrencyCell(salary.taxableNonCashBenefits, isTotalRow),
      _buildCurrencyCell(salary.overtimeAmount, isTotalRow),
      _buildCurrencyCell(salary.earnings, isTotalRow),
      _buildCurrencyCell(salary.taxableIncome, isTotalRow),
    ]);

    // Add individual deductions
    for (var desc in deductionDescriptions) {
      final key = 'deduction_$desc';
      final value = salary.additionalFields[key];
      cells.add(_buildCurrencyCell(value is double ? value : 0.0, isTotalRow));
    }

    // Add remaining deduction fields
    cells.addAll([
      _buildCurrencyCell(salary.otherDeductions, isTotalRow),
      _buildCurrencyCell(salary.shifDeduction, isTotalRow),
      _buildCurrencyCell(salary.nssfTierIDeduction, isTotalRow),
      _buildCurrencyCell(salary.nssfTierIIDeduction, isTotalRow),
      _buildCurrencyCell(salary.housingLevy, isTotalRow),
      _buildCurrencyCell(salary.payeDeduction, isTotalRow),
      _buildCurrencyCell(salary.pensionContributions, isTotalRow),
      _buildCurrencyCell(salary.insuranceRelief, isTotalRow),
      _buildCurrencyCell(salary.totalDeductions, isTotalRow),
      _buildCurrencyCell(salary.netPay, isTotalRow, isNetPay: true),
      _buildTextCell(salary.formattedPaymentDate, isTotalRow),
      _buildStatusCell(salary.status, isTotalRow),
    ]);
    
    return cells;
  }

  DataCell _buildTextCell(String? value, bool isTotalRow, {bool isName = false}) {
    final displayValue = value ?? '';
    return DataCell(
      Tooltip(
        message: displayValue,
        child: Text(
          displayValue,
          style: TextStyle(
            color: isTotalRow ? primaryColor : textColor,
            fontWeight: isTotalRow ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      onTap: !isTotalRow && isName ? () => _showSalarySlip(_findSalaryById(value ?? '')) : null,
    );
  }

  DataCell _buildCurrencyCell(double? value, bool isTotalRow, {bool isNetPay = false}) {
    final displayValue = _formatCurrency(value ?? 0);
    return DataCell(
      Tooltip(
        message: displayValue,
        child: Text(
          displayValue,
          style: TextStyle(
            color: isTotalRow 
                ? primaryColor 
                : isNetPay 
                    ? primaryColor 
                    : textColor,
            fontWeight: isTotalRow || isNetPay ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  DataCell _buildStatusCell(String status, bool isTotalRow) {
    return DataCell(
      Tooltip(
        message: status,
        child: Text(
          status,
          style: TextStyle(
            color: status == 'Already Paid' ? Colors.red : 
                   isTotalRow ? primaryColor : textColor,
            fontWeight: isTotalRow ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : exportMasterPayroll,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: 18),
                        const SizedBox(width: 8),
                        Text('Export Master Payroll'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: _handleBulkPayment,
          backgroundColor: primaryColor,
          heroTag: 'bulk_payment',
          tooltip: 'Bulk Payment',
          child: const Icon(Icons.payments, color: Colors.white),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: _handleSinglePayment,
          backgroundColor: secondaryColor,
          heroTag: 'single_payment',
          tooltip: 'Single Payment',
          child: const Icon(Icons.payment, color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedPaymentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedPaymentDate) {
      setState(() {
        selectedPaymentDate = picked;
        salaries.clear();
        selectedEmployees.clear();
        searchKeyword = '';
      });
    }
  }

  void _handleSearch(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchKeyword = value.toLowerCase();
      });
    });
  }

  void _updateFilter({int? month, int? year, int? companyId}) {
    setState(() {
      if (month != null) selectedMonth = month;
      if (year != null) selectedYear = year;
      if (companyId != null) selectedCompanyId = companyId;
      salaries.clear();
      selectedEmployees.clear();
      searchKeyword = '';
    });
  }

  // Actions
  Future<void> exportMasterPayroll() async {
    if (salaries.isEmpty) {
      _showErrorSnackBar('Please fetch salaries first.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final headers = _getTableColumnLabels()
          .where((header) => header != 'Select')
          .toList();

      final List<List<String>> csvData = [headers];

      for (var salary in salaries) {
        final row = _buildCsvRow(salary);
        csvData.add(row);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName = _generateFileName();
      
      await _saveCsvFile(csvString, fileName);
      if (!mounted) return;
      _showSuccessSnackBar('Master Payroll exported successfully');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error exporting master payroll: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<String> _buildCsvRow(SalaryRecord salary) {
    final row = <String>[
      salary.employeeId,
      salary.companyName ?? '', // Ensure non-nullable string
      salary.fullname,
      _formatNumber(salary.grossPay),
      _formatNumber(salary.houseAllowance),
      _formatNumber(salary.basicPay),
    ];

    // Add individual cash benefits
    for (var desc in cashBenefitDescriptions) {
      final key = 'cash_benefit_$desc';
      final value = salary.additionalFields[key];
      row.add(_formatNumber(value is double ? value : 0.0));
    }

    // Add individual non-cash benefits
    for (var desc in nonCashBenefitDescriptions) {
      final key = 'non_cash_benefit_$desc';
      final value = salary.additionalFields[key];
      row.add(_formatNumber(value is double ? value : 0.0));
    }

    // Add benefit totals
    row.addAll([
      _formatNumber(salary.cashBenefits),
      _formatNumber(salary.nonCashBenefits),
      _formatNumber(salary.taxableNonCashBenefits),
      _formatNumber(salary.overtimeAmount),
      _formatNumber(salary.earnings),
      _formatNumber(salary.taxableIncome),
    ]);

    // Add individual deductions
    for (var desc in deductionDescriptions) {
      final key = 'deduction_$desc';
      final value = salary.additionalFields[key];
      row.add(_formatNumber(value is double ? value : 0.0));
    }

    // Add remaining fields
    row.addAll([
      _formatNumber(salary.otherDeductions),
      _formatNumber(salary.shifDeduction),
      _formatNumber(salary.nssfTierIDeduction),
      _formatNumber(salary.nssfTierIIDeduction),
      _formatNumber(salary.housingLevy),
      _formatNumber(salary.payeDeduction),
      _formatNumber(salary.pensionContributions),
      _formatNumber(salary.insuranceRelief),
      _formatNumber(salary.totalDeductions),
      _formatNumber(salary.netPay),
      salary.formattedPaymentDate,
      salary.status,
    ]);

    return row.map((e) => e.replaceAll(',', '')).toList();
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  String _generateFileName() {
    final companyName = companyIdToName[selectedCompanyId]!;
    final dateStr = selectedPaymentDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedPaymentDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    return 'MasterPayroll_${dateStr}_${companyName.replaceAll(' ', '_')}.csv';
  }

  Future<void> _saveCsvFile(String csvString, String fileName) async {
    final csvBytes = utf8.encode(csvString);

    if (kIsWeb) {
      final blob = html.Blob([csvBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      String filePath;
      if (Platform.isWindows) {
        final directory = Directory(r'C:\payroll_exports');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        filePath = '${directory.path}\\$fileName';
      } else {
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access Downloads directory');
        }
        filePath = '${directory.path}/$fileName';
      }
      final file = File(filePath);
      await file.writeAsBytes(csvBytes);
      if (!mounted) return;
      _showSuccessSnackBar('CSV file saved to: $filePath');
    }
  }

  Future<void> _handleSinglePayment() async {
    final selectedEmployeeId = _getSelectedEmployeeId();
    if (selectedEmployeeId.isEmpty) {
      _showErrorSnackBar('No employee selected for single payment.');
      return;
    }

    final selectedEmployee = _findSalaryById(selectedEmployeeId);
    if (selectedEmployee == null) {
      _showErrorSnackBar('Selected employee not found.');
      return;
    }

    if (selectedEmployee.status == 'Already Paid') {
      _showErrorSnackBar('Salary already paid for this month.');
      return;
    }

    final confirm = await _showConfirmationDialog(
      'Confirm Single Payment',
      'Initiate payment for ${selectedEmployee.fullname}?\nNet Pay: ${_formatCurrency(selectedEmployee.netPay)}',
    );

    if (confirm != true) return;

    await _processPayment([selectedEmployee], 'single');
  }

  Future<void> _handleBulkPayment() async {
    final employeesToPay = _getEmployeesToPay();
    if (employeesToPay.isEmpty) {
      _showErrorSnackBar('No employees selected for bulk payment.');
      return;
    }

    final alreadyPaid = employeesToPay.where((s) => s.status == 'Already Paid').toList();
    if (alreadyPaid.isNotEmpty) {
      _showErrorSnackBar('${alreadyPaid.length} employee(s) already paid for this month.');
      return;
    }

    final totalNetPay = employeesToPay.fold<double>(0.0, (sum, emp) => sum + emp.netPay);
    
    final confirm = await _showConfirmationDialog(
      'Confirm Bulk Payment',
      'Initiate payment for ${employeesToPay.length} employees?\nTotal Net Pay: ${_formatCurrency(totalNetPay)}',
    );

    if (confirm != true) return;

    await _processPayment(employeesToPay, 'bulk');
  }

  String _getSelectedEmployeeId() {
    return selectedEmployees.entries
        .singleWhere((entry) => entry.value, orElse: () => MapEntry('', false))
        .key;
  }

  SalaryRecord? _findSalaryById(String employeeId) {
    try {
      return salaries.firstWhere(
        (salary) => salary.employeeId == employeeId,
      );
    } catch (e) {
      return null;
    }
  }

  List<SalaryRecord> _getEmployeesToPay() {
    return salaries.where((salary) {
      return !salary.isTotalsRow && 
             salary.employeeId.isNotEmpty &&
             !(selectedEmployees[salary.employeeId] ?? false);
    }).toList();
  }

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payment,
                size: 48,
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: subtitleColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(List<SalaryRecord> employees, String type) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      for (var employee in employees) {
        final salaryData = employee.toApiMap();
        await widget.apiService.saveSalary(salaryData, selectedCompanyId!);
      }
      if (!mounted) return;
      _showSuccessSnackBar(
        '${type.capitalize()} payment initiated for ${employees.length} employee${employees.length > 1 ? 's' : ''}'
      );
      
      await fetchAndCalculateSalaries();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error during $type payment: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSalarySlip(SalaryRecord? salary) {
    if (salary == null || salary.isTotalsRow) return;
    
    showDialog(
      context: context,
      builder: (context) => SalarySlipDialog(
        salary: salary,
        primaryColor: primaryColor,
        cardColor: cardColor,
        textColor: textColor,
        subtitleColor: subtitleColor,
        formatCurrency: _formatCurrency,
        cashBenefitDescriptions: cashBenefitDescriptions,
        nonCashBenefitDescriptions: nonCashBenefitDescriptions,
        deductionDescriptions: deductionDescriptions,
      ),
    );
  }

  // Helper methods
  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_KE', symbol: 'KES ').format(amount);
  }

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
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleNotificationTap() {
    if (kDebugMode) print('Notifications tapped');
  }

  void _showProfileBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProfileSheet(),
    );
  }

  Widget _buildProfileSheet() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: primaryColor),
            ),
            title: Text(
              widget.user.username ?? 'User',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              widget.user.role,
              style: TextStyle(color: subtitleColor),
            ),
          ),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.red),
            ),
            title: Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: subtitleColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
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
}

// Supporting Classes

class SalaryCalculation {
  final String employeeId;
  final String fullname;
  final int companyId;
  final String? companyName;
  final double originalGrossPay;
  final double houseAllowance;
  final double basicPay;
  final bool isPaid;
  final BenefitResult benefitResult;
  final double overtimeAmount;
  final List<Map<String, dynamic>> earnings;
  final double totalEarnings;
  final List<Map<String, dynamic>> deductions;
  final double pensionContributions;
  final double loanRepayment;
  final double insuranceRelief;
  final double grossPay;
  final double nssfTierIDeduction;
  final double nssfTierIIDeduction;
  final double shifDeduction;
  final double housingLevy;
  final double totalOtherDeductions;
  final double taxableIncome;
  final double payeDeduction;
  final double netPay;
  final Map<String, double> cashBenefitAmounts;
  final Map<String, double> nonCashBenefitAmounts;
  final Map<String, double> deductionAmounts;
  final double bonusAmount;

  SalaryCalculation({
    required this.employeeId,
    required this.fullname,
    required this.companyId,
    required this.companyName,
    required this.originalGrossPay,
    required this.houseAllowance,
    required this.basicPay,
    required this.isPaid,
    required this.benefitResult,
    required this.overtimeAmount,
    required this.earnings,
    required this.totalEarnings,
    required this.deductions,
    required this.pensionContributions,
    required this.loanRepayment,
    required this.insuranceRelief,
    required this.grossPay,
    required this.nssfTierIDeduction,
    required this.nssfTierIIDeduction,
    required this.shifDeduction,
    required this.housingLevy,
    required this.totalOtherDeductions,
    required this.taxableIncome,
    required this.payeDeduction,
    required this.netPay,
    required this.cashBenefitAmounts,
    required this.nonCashBenefitAmounts,
    required this.deductionAmounts,
    required this.bonusAmount,
  });
}

class BenefitResult {
  final double totalCashBenefits;
  final double totalNonCashBenefits;
  final double taxableNonCashBenefits;
  final Map<String, double> cashBenefitAmounts;
  final Map<String, double> nonCashBenefitAmounts;
  final Map<String, double> deductionAmounts;
  final double bonusAmount;

  BenefitResult({
    required this.totalCashBenefits,
    required this.totalNonCashBenefits,
    required this.taxableNonCashBenefits,
    required this.cashBenefitAmounts,
    required this.nonCashBenefitAmounts,
    required this.deductionAmounts,
    this.bonusAmount = 0.0,
  });
}

class SalaryRecord {
  final String employeeId;
  final String fullname;
  final int companyId;
  final String? companyName;
  final double grossPay;
  final double houseAllowance;
  final double basicPay;
  final double cashBenefits;
  final double nonCashBenefits;
  final double taxableNonCashBenefits;
  final double overtimeAmount;
  final double earnings;
  final double taxableIncome;
  final double shifDeduction;
  final double nssfTierIDeduction;
  final double nssfTierIIDeduction;
  final double housingLevy;
  final double pensionContributions;
  final double payeDeduction;
  final double otherDeductions;
  final double insuranceRelief;
  final double totalDeductions;
  final double netPay;
  final DateTime paymentDate;
  final String status;
  final bool isTotalsRow;
  final Map<String, dynamic> additionalFields;

  SalaryRecord({
    required this.employeeId,
    required this.fullname,
    required this.companyId,
    required this.companyName,
    required this.grossPay,
    required this.houseAllowance,
    required this.basicPay,
    required this.cashBenefits,
    required this.nonCashBenefits,
    required this.taxableNonCashBenefits,
    required this.overtimeAmount,
    required this.earnings,
    required this.taxableIncome,
    required this.shifDeduction,
    required this.nssfTierIDeduction,
    required this.nssfTierIIDeduction,
    required this.housingLevy,
    required this.pensionContributions,
    required this.payeDeduction,
    required this.otherDeductions,
    required this.insuranceRelief,
    required this.totalDeductions,
    required this.netPay,
    required this.paymentDate,
    required this.status,
    this.isTotalsRow = false,
    this.additionalFields = const {},
  });

  factory SalaryRecord.fromCalculation(
    SalaryCalculation calc,
    DateTime paymentDate,
    bool isAdmin,
  ) {
    return SalaryRecord(
      employeeId: calc.employeeId,
      fullname: calc.fullname,
      companyId: calc.companyId,
      companyName: calc.companyName,
      grossPay: calc.grossPay,
      houseAllowance: calc.houseAllowance,
      basicPay: calc.basicPay,
      cashBenefits: calc.benefitResult.totalCashBenefits,
      nonCashBenefits: calc.benefitResult.totalNonCashBenefits,
      taxableNonCashBenefits: calc.benefitResult.taxableNonCashBenefits,
      overtimeAmount: calc.overtimeAmount,
      earnings: calc.totalEarnings,
      taxableIncome: calc.taxableIncome,
      shifDeduction: calc.shifDeduction,
      nssfTierIDeduction: calc.nssfTierIDeduction,
      nssfTierIIDeduction: calc.nssfTierIIDeduction,
      housingLevy: calc.housingLevy,
      pensionContributions: calc.pensionContributions,
      payeDeduction: calc.payeDeduction,
      otherDeductions: calc.totalOtherDeductions,
      insuranceRelief: calc.insuranceRelief,
      totalDeductions: calc.payeDeduction +
          calc.shifDeduction +
          calc.nssfTierIDeduction +
          calc.nssfTierIIDeduction +
          calc.housingLevy +
          calc.totalOtherDeductions +
          calc.pensionContributions,
      netPay: calc.netPay,
      paymentDate: paymentDate,
      status: calc.isPaid ? 'Already Paid' : 'Pending',
      additionalFields: {
        ...calc.cashBenefitAmounts.map((key, value) => MapEntry('cash_benefit_$key', value)),
        ...calc.nonCashBenefitAmounts.map((key, value) => MapEntry('non_cash_benefit_$key', value)),
        ...calc.deductionAmounts.map((key, value) => MapEntry('deduction_$key', value)),
      },
    );
  }

  factory SalaryRecord.totals({
    required double totalGrossPay,
    required double totalHouseAllowance,
    required double totalNetPay,
    required double totalDeductions,
    required double totalOvertimeAmount,
    required double totalEarnings,
    required double totalShifDeduction,
    required double totalNssfTierIDeduction,
    required double totalNssfTierIIDeduction,
    required double totalHousingLevy,
    required double totalPensionContributions,
    required double totalPayeDeduction,
    required double totalOtherDeductions,
    required double totalCashBenefits,
    required double totalNonCashBenefits,
    required double totalTaxableNonCashBenefits,
    required double totalInsuranceRelief,
    required Set<String> cashBenefitDescriptions,
    required Set<String> nonCashBenefitDescriptions,
    required Set<String> deductionDescriptions,
    required List<SalaryRecord> salaries,
    required DateTime paymentDate,
  }) {
    final additionalFields = <String, dynamic>{};
    
    // Calculate totals for cash benefits
    for (var desc in cashBenefitDescriptions) {
      final total = salaries.fold<double>(0.0, (sum, record) {
        if (record.employeeId.isEmpty) return sum; // Skip totals row
        final value = record.additionalFields['cash_benefit_$desc'];
        return sum + (value is double ? value : 0.0);
      });
      additionalFields['cash_benefit_$desc'] = total;
    }
    
    // Calculate totals for non-cash benefits
    for (var desc in nonCashBenefitDescriptions) {
      final total = salaries.fold<double>(0.0, (sum, record) {
        if (record.employeeId.isEmpty) return sum; // Skip totals row
        final value = record.additionalFields['non_cash_benefit_$desc'];
        return sum + (value is double ? value : 0.0);
      });
      additionalFields['non_cash_benefit_$desc'] = total;
    }
    
    // Calculate totals for deductions
    for (var desc in deductionDescriptions) {
      final total = salaries.fold<double>(0.0, (sum, record) {
        if (record.employeeId.isEmpty) return sum; // Skip totals row
        final value = record.additionalFields['deduction_$desc'];
        return sum + (value is double ? value : 0.0);
      });
      additionalFields['deduction_$desc'] = total;
    }
    
    return SalaryRecord(
      employeeId: '',
      fullname: 'Totals',
      companyId: 0,
      companyName: null,
      grossPay: totalGrossPay,
      houseAllowance: totalHouseAllowance,
      basicPay: 0,
      cashBenefits: totalCashBenefits,
      nonCashBenefits: totalNonCashBenefits,
      taxableNonCashBenefits: totalTaxableNonCashBenefits,
      overtimeAmount: totalOvertimeAmount,
      earnings: totalEarnings,
      taxableIncome: 0,
      shifDeduction: totalShifDeduction,
      nssfTierIDeduction: totalNssfTierIDeduction,
      nssfTierIIDeduction: totalNssfTierIIDeduction,
      housingLevy: totalHousingLevy,
      pensionContributions: totalPensionContributions,
      payeDeduction: totalPayeDeduction,
      otherDeductions: totalOtherDeductions,
      insuranceRelief: totalInsuranceRelief,
      totalDeductions: totalDeductions,
      netPay: totalNetPay,
      paymentDate: paymentDate,
      status: 'Totals',
      isTotalsRow: true,
      additionalFields: additionalFields,
    );
  }

  factory SalaryRecord.empty() {
    return SalaryRecord(
      employeeId: '',
      fullname: '',
      companyId: 0,
      companyName: null,
      grossPay: 0,
      houseAllowance: 0,
      basicPay: 0,
      cashBenefits: 0,
      nonCashBenefits: 0,
      taxableNonCashBenefits: 0,
      overtimeAmount: 0,
      earnings: 0,
      taxableIncome: 0,
      shifDeduction: 0,
      nssfTierIDeduction: 0,
      nssfTierIIDeduction: 0,
      housingLevy: 0,
      pensionContributions: 0,
      payeDeduction: 0,
      otherDeductions: 0,
      insuranceRelief: 0,
      totalDeductions: 0,
      netPay: 0,
      paymentDate: DateTime.now(),
      status: '',
    );
  }

  String get formattedPaymentDate {
    return DateFormat('yyyy-MM-dd').format(paymentDate);
  }

  Map<String, dynamic> toApiMap() {
    return {
      'employee_id': employeeId,
      'company_id': companyId,
      'gross_pay': grossPay,
      'house_allowance': houseAllowance,
      'basic_pay': basicPay,
      'cash_benefits': cashBenefits,
      'non_cash_benefits': nonCashBenefits,
      'taxable_non_cash_benefits': taxableNonCashBenefits,
      'overtime_amount': overtimeAmount,
      'earnings': earnings,
      'taxable_income': taxableIncome,
      'shif_deduction': shifDeduction,
      'nssf_tier_i_deduction': nssfTierIDeduction,
      'nssf_tier_ii_deduction': nssfTierIIDeduction,
      'housing_levy': housingLevy,
      'pension_contributions': pensionContributions,
      'paye_deduction': payeDeduction,
      'deductions': otherDeductions,
      'insurance_relief': insuranceRelief,
      'total_deductions': totalDeductions,
      'net_pay': netPay,
      'payment_date': formattedPaymentDate,
      'status': status,
      ...additionalFields,
    };
  }
}

class SalarySlipDialog extends StatelessWidget {
  final SalaryRecord salary;
  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;
  final String Function(double) formatCurrency;
  final Set<String> cashBenefitDescriptions;
  final Set<String> nonCashBenefitDescriptions;
  final Set<String> deductionDescriptions;

  const SalarySlipDialog({
    super.key,
    required this.salary,
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    required this.formatCurrency,
    required this.cashBenefitDescriptions,
    required this.nonCashBenefitDescriptions,
    required this.deductionDescriptions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Salary Slip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    salary.fullname,
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSlipSection('Employee Information', [
                      _buildSlipRow('Employee ID', salary.employeeId),
                      _buildSlipRow('Company', salary.companyName ?? 'N/A'),
                      _buildSlipRow('Payment Date', salary.formattedPaymentDate),
                      _buildSlipRow('Status', salary.status,
                          isHighlighted: salary.status == 'Already Paid'),
                    ]),
                    
                    _buildSlipSection('Earnings', [
                      _buildSlipRow('Gross Pay', formatCurrency(salary.grossPay)),
                      _buildSlipRow('House Allowance', formatCurrency(salary.houseAllowance)),
                      _buildSlipRow('Basic Pay', formatCurrency(salary.basicPay)),
                      
                      // Individual cash benefits
                      ..._buildIndividualBenefits('Cash Benefits', cashBenefitDescriptions, 'cash_benefit_'),
                      
                      // Individual non-cash benefits
                      ..._buildIndividualBenefits('Non-Cash Benefits', nonCashBenefitDescriptions, 'non_cash_benefit_'),
                      
                      if (salary.taxableNonCashBenefits > 0)
                        _buildSlipRow('Taxable Non-Cash Benefits', formatCurrency(salary.taxableNonCashBenefits)),
                      
                      if (salary.overtimeAmount > 0)
                        _buildSlipRow('Overtime', formatCurrency(salary.overtimeAmount)),
                      
                      if (salary.earnings > 0)
                        _buildSlipRow('Other Earnings', formatCurrency(salary.earnings)),
                    ]),
                    
                    _buildSlipSection('Deductions', [
                      // Individual deductions
                      ..._buildIndividualBenefits('Deductions', deductionDescriptions, 'deduction_'),
                      
                      _buildSlipRow('SHIF', formatCurrency(salary.shifDeduction)),
                      _buildSlipRow('NSSF Tier I', formatCurrency(salary.nssfTierIDeduction)),
                      _buildSlipRow('NSSF Tier II', formatCurrency(salary.nssfTierIIDeduction)),
                      _buildSlipRow('Housing Levy', formatCurrency(salary.housingLevy)),
                      _buildSlipRow('PAYE', formatCurrency(salary.payeDeduction)),
                      
                      if (salary.pensionContributions > 0)
                        _buildSlipRow('Pension', formatCurrency(salary.pensionContributions)),
                      
                      if (salary.insuranceRelief > 0)
                        _buildSlipRow('Insurance Relief', formatCurrency(salary.insuranceRelief)),
                      
                      if (salary.otherDeductions > 0)
                        _buildSlipRow('Other Deductions', formatCurrency(salary.otherDeductions)),
                    ]),
                    
                    _buildSlipSection('Summary', [
                      _buildSlipRow('Taxable Income', formatCurrency(salary.taxableIncome)),
                      _buildSlipRow('Total Deductions', formatCurrency(salary.totalDeductions)),
                      _buildSlipRow('Net Pay', formatCurrency(salary.netPay), isTotal: true),
                    ]),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(color: subtitleColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _printSalarySlip(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Print',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 8),
        Divider(color: Colors.grey[300]),
      ],
    );
  }

  Widget _buildSlipRow(String label, String value, {bool isHighlighted = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlighted ? Colors.red : textColor,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlighted ? Colors.red : (isTotal ? primaryColor : textColor),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIndividualBenefits(String category, Set<String> descriptions, String prefix) {
    final List<Widget> rows = [];
    
    for (var desc in descriptions) {
      final key = '$prefix$desc';
      final value = salary.additionalFields[key];
      if (value is double && value > 0) {
        rows.add(_buildSlipRow('$category: $desc', formatCurrency(value)));
      }
    }
    
    return rows;
  }

  Future<void> _printSalarySlip(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => _generatePdf(format),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Salary Slip',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(salary.companyName ?? '',
                        style: const pw.TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee Name: ${salary.fullname}'),
                      pw.Text('Employee ID: ${salary.employeeId}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${salary.formattedPaymentDate}'),
                      pw.Text('Status: ${salary.status}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              pw.Text('Earnings',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              _buildPdfRow('Gross Pay', salary.grossPay),
              _buildPdfRow('Basic Pay', salary.basicPay),
              _buildPdfRow('House Allowance', salary.houseAllowance),
              if (salary.overtimeAmount > 0)
                _buildPdfRow('Overtime', salary.overtimeAmount),
              if (salary.earnings > 0)
                _buildPdfRow('Other Earnings', salary.earnings),
              if (salary.cashBenefits > 0)
                _buildPdfRow('Cash Benefits', salary.cashBenefits),
              if (salary.nonCashBenefits > 0)
                _buildPdfRow('Non-Cash Benefits', salary.nonCashBenefits),
              pw.SizedBox(height: 10),
              pw.Text('Deductions',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              _buildPdfRow('PAYE', salary.payeDeduction),
              _buildPdfRow('SHIF', salary.shifDeduction),
              _buildPdfRow('NSSF',
                  salary.nssfTierIDeduction + salary.nssfTierIIDeduction),
              _buildPdfRow('Housing Levy', salary.housingLevy),
              if (salary.pensionContributions > 0)
                _buildPdfRow('Pension', salary.pensionContributions),
              if (salary.otherDeductions > 0)
                _buildPdfRow('Other Deductions', salary.otherDeductions),
              pw.Divider(),
              _buildPdfRow('Total Deductions', salary.totalDeductions,
                  isBold: true),
              pw.SizedBox(height: 10),
              _buildPdfRow('Net Pay', salary.netPay,
                  isBold: true, fontSize: 16),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildPdfRow(String label, double value,
      {bool isBold = false, double fontSize = 12}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(formatCurrency(value),
            style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}