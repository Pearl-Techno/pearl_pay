import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html
    if (kIsWeb) "universal_html.dart";

import '../../models/user.dart';
import '../../services/services.dart';
import '../../widgets/custom_app_bar.dart';

// Constants - Using same colors as PaidSalariesScreen
class PensionConstants {
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
}

class PensionScreen extends StatefulWidget {
  final ApiService apiService;
  final User user;

  const PensionScreen({
    super.key,
    required this.apiService,
    required this.user,
  });

  @override
  State<PensionScreen> createState() => _PensionScreenState();
}

class _PensionScreenState extends State<PensionScreen> {
  late final ApiService _apiService;
  List<Map<String, dynamic>> _pensionRecords = [];
  List<Map<String, dynamic>> _employees = [];
  List<String> _companyNames = ['All Companies'];
  bool _isLoading = false;
  String _searchKeyword = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedCompany;
  DateTime? _selectedPaymentDate;
  String _sortColumn = 'fullname';
  bool _sortAscending = true;

  // Statistics
  double _totalPensionAmount = 0.0;
  int _totalContributions = 0;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService;
    _selectedPaymentDate = DateTime.now();
    _fetchCompanies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    try {
      final fetchedEmployees =
          await _apiService.getEmployeeList(widget.user.companyId);
      setState(() {
        _employees = fetchedEmployees;
        _companyNames = ['All Companies'] +
            fetchedEmployees
                .map((e) => e['company_name'])
                .whereType<String>()
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load companies: $e');
    }
  }

  Future<void> _fetchPensionRecords() async {
    setState(() {
      _isLoading = true;
      _pensionRecords = [];
      _totalPensionAmount = 0.0;
      _totalContributions = 0;
    });

    try {
      final fetchedEmployees = _employees.isEmpty
          ? await _apiService.getEmployeeList(widget.user.companyId)
          : _employees;

      if (fetchedEmployees.isEmpty) {
        throw Exception('No employees found.');
      }

      final filteredEmployees =
          _selectedCompany == null || _selectedCompany == 'All Companies'
              ? fetchedEmployees
              : fetchedEmployees
                  .where((e) => e['company_name'] == _selectedCompany)
                  .toList();

      if (filteredEmployees.isEmpty) {
        throw Exception('No employees found for the selected company.');
      }

      final companyId = widget.user.companyId;
      if (companyId <= 0) {
        throw Exception('Invalid company ID: ${widget.user.companyId}');
      }

      final pensionContributions =
          await _apiService.fetchAllPensionContributions(
        companyId,
        _selectedMonth,
        _selectedYear,
      );

      double totalBasicPay = 0;
      double totalPensionContribution = 0;
      int totalContributionCount = 0;

      final employeeMap = {
        for (var e in filteredEmployees) e['employee_id'].toString(): e
      };

      for (var contribution in pensionContributions) {
        final employeeId = contribution['employee_id']?.toString();
        if (employeeId == null) continue;
        final employee = employeeMap[employeeId];
        if (employee == null) continue;

        final basicPay =
            double.tryParse(employee['basic']?.toString() ?? '0.0') ?? 0.0;
        final companyName = employee['company_name'] as String?;
        final amount =
            double.tryParse(contribution['amount']?.toString() ?? '0.0') ?? 0.0;
        final contributionCount = 1;
        final fullname =
            contribution['fullname'] ?? employee['fullname'] ?? 'Unknown';
        final contributionDate = contribution['contribution_date'] ??
            (_selectedPaymentDate != null
                ? DateFormat('yyyy-MM-dd').format(_selectedPaymentDate!)
                : DateFormat('yyyy-MM-dd').format(DateTime.now()));

        totalBasicPay += basicPay;
        totalPensionContribution += amount;
        totalContributionCount += contributionCount;

        _pensionRecords.add({
          'employee_id': employeeId,
          'fullname': fullname,
          'company_name': companyName,
          'basic_pay': basicPay,
          'pension_contribution': amount,
          'contribution_count': contributionCount,
          'payment_date': contributionDate,
          'month': _selectedMonth,
          'year': _selectedYear,
        });
      }

      // Update statistics
      _totalPensionAmount = totalPensionContribution;
      _totalContributions = totalContributionCount;

      _pensionRecords.add({
        'employee_id': null,
        'fullname': 'Totals',
        'company_name': null,
        'basic_pay': totalBasicPay,
        'pension_contribution': totalPensionContribution,
        'contribution_count': totalContributionCount,
        'payment_date': _selectedPaymentDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedPaymentDate!)
            : DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'month': _selectedMonth,
        'year': _selectedYear,
      });

      _sortRecords();
      _showSuccessSnackBar('Pension records loaded successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to load pension records: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sortRecords() {
    _pensionRecords.sort((a, b) {
      if (a['fullname'] == 'Totals') return 1;
      if (b['fullname'] == 'Totals') return -1;

      final aValue = a[_sortColumn] ?? '';
      final bValue = b[_sortColumn] ?? '';

      if (aValue is num && bValue is num) {
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }
      return _sortAscending
          ? aValue.toString().compareTo(bValue.toString())
          : bValue.toString().compareTo(aValue.toString());
    });
  }

  Future<void> _exportPensionReport() async {
    if (_pensionRecords.isEmpty ||
        _pensionRecords.last['fullname'] != 'Totals') {
      _showErrorSnackBar('Please fetch pension records first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = [
        'Employee ID',
        'Company Name',
        'Full Name',
        'Basic Pay',
        'Pension Contribution',
        'Contribution Count',
        'Payment Date',
        'Month',
        'Year',
      ];

      final csvData = [
        headers,
        ..._pensionRecords.map((record) => [
              record['employee_id']?.toString() ?? '',
              record['company_name']?.toString() ?? '',
              record['fullname']?.toString() ?? '',
              (record['basic_pay'] as num?)?.toStringAsFixed(2) ?? '0.00',
              (record['pension_contribution'] as num?)?.toStringAsFixed(2) ??
                  '0.00',
              record['contribution_count']?.toString() ?? '0',
              record['payment_date']?.toString() ?? '',
              record['month']?.toString() ?? '',
              record['year']?.toString() ?? '',
            ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName =
          'PensionReport_${_selectedPaymentDate != null ? DateFormat('yyyy-MM-dd').format(_selectedPaymentDate!) : DateTime.now().toIso8601String()}.csv';
      final csvBytes = utf8.encode(csvString);

      if (kIsWeb) {
        final blob = html.Blob([csvBytes]);
        html.AnchorElement(href: html.Url.createObjectUrlFromBlob(blob))
          ..setAttribute('download', fileName)
          ..click();
      } else {
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access Downloads directory');
        }
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(csvBytes);
        _showSuccessSnackBar('CSV file saved to Downloads: ${file.path}');
      }

      _showSuccessSnackBar('Pension report exported successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to export pension report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddPensionDialog() async {
    String? selectedEmployeeId;
    double? pensionAmount;
    DateTime paymentDate = DateTime.now();
    int dialogMonth = _selectedMonth;
    int dialogYear = _selectedYear;
    double? calculatedPension;
    String? selectedFullname;

    final amountController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(paymentDate),
    );
    final formKey = GlobalKey<FormState>();

    final filteredEmployees =
        _selectedCompany == null || _selectedCompany == 'All Companies'
            ? _employees
            : _employees
                .where((e) => e['company_name'] == _selectedCompany)
                .toList();

    if (filteredEmployees.isEmpty) {
      _showErrorSnackBar('No employees available for the selected company.');
      return;
    }

    // Remove duplicate employees by employee_id
    final uniqueEmployees = <String, Map<String, dynamic>>{};
    for (final employee in filteredEmployees) {
      final employeeId = employee['employee_id']?.toString();
      if (employeeId != null && !uniqueEmployees.containsKey(employeeId)) {
        uniqueEmployees[employeeId] = employee;
      }
    }
    final uniqueEmployeeList = uniqueEmployees.values.toList();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PensionConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Pension Contribution',
            style: TextStyle(
              color: PensionConstants.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        content: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PensionConstants.cardColor, PensionConstants.backgroundColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Employee Dropdown - Fixed to remove duplicates
                  _buildEmployeeDropdown(
                    value: selectedEmployeeId,
                    employees: uniqueEmployeeList,
                    onChanged: (value) {
                      setState(() {
                        selectedEmployeeId = value;
                        if (value != null) {
                          final employee = uniqueEmployeeList.firstWhere(
                            (e) => e['employee_id'].toString() == value,
                            orElse: () => {},
                          );
                          if (employee.isNotEmpty) {
                            final basicPay = double.tryParse(
                                    employee['basic']?.toString() ?? '0.0') ??
                                0.0;
                            calculatedPension = basicPay * 0.025;
                            pensionAmount = calculatedPension;
                            selectedFullname = employee['fullname'] ?? 'Unknown';
                            amountController.text =
                                calculatedPension?.toStringAsFixed(2) ?? '';
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: amountController,
                    label: 'Pension Amount *',
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      pensionAmount = double.tryParse(value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter pension amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  if (calculatedPension != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PensionConstants.successColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PensionConstants.successColor.withAlpha(77)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calculate, color: PensionConstants.successColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Calculated Pension: ${calculatedPension!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: PensionConstants.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildDatePickerField(
                    controller: dateController,
                    label: 'Payment Date *',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: PensionConstants.primaryColor),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(foregroundColor: PensionConstants.primaryColor),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          paymentDate = picked;
                          dateController.text =
                              DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select a date'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMonthYearDropdown(
            label: 'Month',
                          value: dialogMonth,
                          items: List.generate(12, (index) => index + 1),
                          itemBuilder: (month) => DateFormat('MMMM').format(DateTime(dialogYear, month)),
                          onChanged: (value) {
                            setState(() => dialogMonth = value!);
                          },
                          validator: (value) =>
                              value == null ? 'Please select a month' : null,
                        ),
                      ),
        SizedBox(width: 12),
                      Expanded(
                        child: _buildMonthYearDropdown(
            label: 'Year',
                          value: dialogYear,
                          items: List.generate(10, (index) => DateTime.now().year - index),
                          itemBuilder: (year) => year.toString(),
                          onChanged: (value) {
                            setState(() => dialogYear = value!);
                          },
                          validator: (value) =>
                              value == null ? 'Please select a year' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: PensionConstants.subtitleColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final pensionData = {
                  'employee_id': selectedEmployeeId!,
                  'amount': pensionAmount!,
                  'payment_date': DateFormat('yyyy-MM-dd').format(paymentDate),
                  'month': dialogMonth,
                  'year': dialogYear,
                  'fullname': selectedFullname!,
                };

                try {
                  final companyId = widget.user.companyId;
                  if (companyId <= 0) {
                    throw Exception(
                        'Invalid company ID: ${widget.user.companyId}');
                  }
                  await _apiService.savePensionContribution(
                    pensionData,
                    companyId,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSuccessSnackBar('Pension contribution added successfully');
                  await _fetchPensionRecords();
                } catch (e) {
                  _showErrorSnackBar('Failed to add pension contribution: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PensionConstants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Save Contribution'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmployeePensionDetails(String employeeId) async {
    try {
      final companyId = widget.user.companyId;

      final contributions = await _apiService.fetchPensionContributions(
        employeeId,
        companyId,
        _selectedMonth,
        _selectedYear,
      );

      final totalAmount = (contributions as Iterable).fold<double>(
        0.0,
        (sum, c) =>
            sum + (double.tryParse(c['amount']?.toString() ?? '0.0') ?? 0.0),
      );

      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: PensionConstants.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Pension Details',
              style: TextStyle(
                color: PensionConstants.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              )),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PensionConstants.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet, size: 48, color: PensionConstants.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Employee: $employeeId',
                  style: TextStyle(
                    color: PensionConstants.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Pension Contribution',
                  style: TextStyle(
                    color: PensionConstants.subtitleColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'KES ${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: PensionConstants.successColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'For ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
                  style: TextStyle(
                    color: PensionConstants.subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: PensionConstants.subtitleColor),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to load pension details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PensionConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Pension Management',
        backgroundColor: PensionConstants.primaryColor,
        onNotificationTap: () => debugPrint('Notifications tapped'),
        onProfileTap: () => debugPrint('Profile tapped'),
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildFiltersSection(),
                  const SizedBox(height: 16),
                  _buildStatisticsCards(),
                  const SizedBox(height: 16),
                  _buildContentSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PensionConstants.primaryColor, PensionConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
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
                    Icons.account_balance_wallet,
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
                        'Pension Management',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage employee pension contributions and reports',
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDateFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedMonth,
            items: List.generate(12, (index) => index + 1),
            itemBuilder: (month) => DateFormat('MMMM').format(DateTime(_selectedYear, month)),
            onChanged: (value) {
              setState(() {
                _selectedMonth = value!;
                _pensionRecords = [];
                _searchKeyword = '';
              });
            },
            hint: 'Select Month',
            icon: Icons.calendar_month,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterDropdown(
            value: _selectedYear,
            items: List.generate(5, (index) => DateTime.now().year - index),
            itemBuilder: (year) => year.toString(),
            onChanged: (value) {
              setState(() {
                _selectedYear = value!;
                _pensionRecords = [];
                _searchKeyword = '';
              });
            },
            hint: 'Select Year',
            icon: Icons.event,
          ),
        ),
        const SizedBox(width: 12),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(
                      color: PensionConstants.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(color: PensionConstants.subtitleColor),
          prefixIcon: Icon(icon, color: PensionConstants.primaryColor),
        ),
        icon: Icon(Icons.arrow_drop_down, color: PensionConstants.primaryColor),
        dropdownColor: PensionConstants.cardColor,
        style: TextStyle(
          color: PensionConstants.textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _fetchPensionRecords,
        icon: Icon(Icons.refresh, color: PensionConstants.primaryColor),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildFilterDropdown<String>(
            value: _selectedCompany ?? 'All Companies',
            items: _companyNames,
            itemBuilder: (company) => company,
            onChanged: (value) {
              setState(() {
                _selectedCompany = value;
                _pensionRecords = [];
                _searchKeyword = '';
              });
            },
            hint: 'Select Company',
            icon: Icons.business,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: PensionConstants.cardColor,
              borderRadius: BorderRadius.circular(16),
        boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
            offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchKeyword = value.toLowerCase()),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                hintText: 'Search employees...',
                hintStyle: TextStyle(color: PensionConstants.subtitleColor),
                prefixIcon: Icon(Icons.search, color: PensionConstants.subtitleColor),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: TextStyle(
                color: PensionConstants.textColor,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: PensionConstants.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
            offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: PensionConstants.primaryColor, size: 20),
              title: Text(
                _selectedPaymentDate != null
                    ? DateFormat('MMM dd').format(_selectedPaymentDate!)
                    : 'Select Date',
                style: TextStyle(
                  color: PensionConstants.textColor,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(Icons.arrow_drop_down, color: PensionConstants.primaryColor),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedPaymentDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(primary: PensionConstants.primaryColor),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(foregroundColor: PensionConstants.primaryColor),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedPaymentDate = picked);
                }
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Pension',
            value: 'KES ${_totalPensionAmount.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: PensionConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Contributions',
            value: _totalContributions.toString(),
            icon: Icons.list_alt,
            color: PensionConstants.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            title: 'Export Report',
            icon: Icons.download,
            onTap: _exportPensionReport,
            color: PensionConstants.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            title: 'Add Contribution',
            icon: Icons.add,
            onTap: _showAddPensionDialog,
            color: PensionConstants.successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PensionConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
                  color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: PensionConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: PensionConstants.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PensionConstants.cardColor,
          borderRadius: BorderRadius.circular(16),
              boxShadow: const [
            BoxShadow(
                  color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: PensionConstants.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: PensionConstants.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 16,
            offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_pensionRecords.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildPensionTable()),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: PensionConstants.primaryColor,
            strokeWidth: 2,
          ),
          SizedBox(height: 20),
          Text(
            'Loading Pension Records...',
            style: TextStyle(
              color: PensionConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching data for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: TextStyle(
              color: PensionConstants.subtitleColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: PensionConstants.greyColor.withAlpha(128),
            ),
            const SizedBox(height: 24),
            Text(
              'No Pension Records Found',
              style: TextStyle(
                color: PensionConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No pension records available for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
              style: TextStyle(
                color: PensionConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pension records will appear here once contributions are added',
              style: TextStyle(
                color: PensionConstants.subtitleColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPensionRecords,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PensionConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: PensionConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: PensionConstants.backgroundColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: PensionConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Pension Records',
            style: TextStyle(
              color: PensionConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_pensionRecords.where((r) => r['fullname'] != 'Totals').length} records',
            style: TextStyle(
              color: PensionConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPensionTable() {
    final filteredRecords = _pensionRecords.where((record) {
      if (record['fullname'] == 'Totals') return true;
      final fullName = record['fullname']?.toString().toLowerCase() ?? '';
      return fullName.contains(_searchKeyword);
    }).toList();

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            headingRowHeight: 56,
            horizontalMargin: 24,
            headingTextStyle: TextStyle(
              color: PensionConstants.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            dataTextStyle: TextStyle(
              color: PensionConstants.textColor,
              fontSize: 12,
            ),
            headingRowColor: WidgetStateProperty.all(PensionConstants.backgroundColor),
            sortColumnIndex: _getColumnIndex(_sortColumn),
            sortAscending: _sortAscending,
            onSelectAll: (value) {},
            columns: _buildTableColumns(),
            rows: filteredRecords.map((record) {
              final isTotal = record['fullname'] == 'Totals';
              
              return DataRow(
                onSelectChanged: record['employee_id'] != null
                    ? (selected) => _showEmployeePensionDetails(record['employee_id'] as String)
                    : null,
                color: isTotal
                    ? WidgetStateProperty.all(PensionConstants.successColor.withAlpha(26))
                    : null,
                cells: [
                  _buildDataCell(record['employee_id']?.toString() ?? '', isBold: isTotal),
                  _buildDataCell(record['company_name']?.toString() ?? '', isBold: isTotal),
                  _buildDataCell(record['fullname']?.toString() ?? 'Unknown', isBold: isTotal),
                  _buildCurrencyCell(record['basic_pay'], isHighlighted: isTotal),
                  _buildCurrencyCell(record['pension_contribution'], isHighlighted: isTotal),
                  _buildDataCell(record['contribution_count']?.toString() ?? '0', isBold: isTotal),
                  _buildDataCell(record['payment_date']?.toString() ?? '', isBold: isTotal),
                  _buildDataCell(record['month']?.toString() ?? '', isBold: isTotal),
                  _buildDataCell(record['year']?.toString() ?? '', isBold: isTotal),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    final columns = [
      {'key': 'employee_id', 'label': 'Employee ID'},
      {'key': 'company_name', 'label': 'Company Name'},
      {'key': 'fullname', 'label': 'Full Name'},
      {'key': 'basic_pay', 'label': 'Basic Pay'},
      {'key': 'pension_contribution', 'label': 'Pension Contribution'},
      {'key': 'contribution_count', 'label': 'Contribution Count'},
      {'key': 'payment_date', 'label': 'Payment Date'},
      {'key': 'month', 'label': 'Month'},
      {'key': 'year', 'label': 'Year'},
    ];

    return columns.map((column) {
      return DataColumn(
        label: Text(
          column['label']!,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: PensionConstants.textColor,
            fontSize: 12,
          ),
        ),
        onSort: (index, ascending) {
          setState(() {
            _sortColumn = columns[index]['key']!;
            _sortAscending = ascending;
            _sortRecords();
          });
        },
      );
    }).toList();
  }

  DataCell _buildDataCell(String text, {bool isBold = false}) {
    return DataCell(
      Tooltip(
        message: text,
        child: Text(
          text,
          style: TextStyle(
            color: PensionConstants.textColor,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  DataCell _buildCurrencyCell(dynamic amount, {bool isHighlighted = false}) {
    final value = double.tryParse(amount?.toString() ?? '0.0') ?? 0.0;
    final formattedValue = 'KES ${value.toStringAsFixed(2)}';
    
    return DataCell(
      Tooltip(
        message: formattedValue,
        child: Text(
          formattedValue,
          style: TextStyle(
            color: isHighlighted ? PensionConstants.successColor : PensionConstants.textColor,
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  int? _getColumnIndex(String columnKey) {
    const columns = [
      'employee_id',
      'company_name',
      'fullname',
      'basic_pay',
      'pension_contribution',
      'contribution_count',
      'payment_date',
      'month',
      'year',
    ];
    final index = columns.indexOf(columnKey);
    return index >= 0 ? index : null;
  }

  // Dialog Widgets - Fixed to handle duplicate employee IDs
  Widget _buildEmployeeDropdown({
    required String? value,
    required List<Map<String, dynamic>> employees,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Employee *',
          style: TextStyle(
            color: PensionConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PensionConstants.backgroundColor),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: employees
                .map((employee) => DropdownMenuItem(
                      value: employee['employee_id'].toString(),
                      child: Text(
                        '${employee['fullname']} (${employee['employee_id']})',
                        style: TextStyle(color: PensionConstants.textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: Icon(Icons.arrow_drop_down, color: PensionConstants.primaryColor),
            ),
            validator: (value) => value == null ? 'Please select an employee' : null,
            dropdownColor: PensionConstants.cardColor,
            style: TextStyle(color: PensionConstants.textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthYearDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    required String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: PensionConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PensionConstants.backgroundColor),
          ),
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        itemBuilder(item),
                        style: TextStyle(color: PensionConstants.textColor),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: Icon(Icons.arrow_drop_down, color: PensionConstants.primaryColor),
            ),
            validator: validator,
            dropdownColor: PensionConstants.cardColor,
            style: TextStyle(color: PensionConstants.textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required ValueChanged<String> onChanged,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: PensionConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PensionConstants.backgroundColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PensionConstants.primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: validator,
          style: TextStyle(color: PensionConstants.textColor),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: PensionConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PensionConstants.backgroundColor),
            ),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: PensionConstants.primaryColor),
              title: Text(
                controller.text.isEmpty ? 'Select Date' : controller.text,
                style: TextStyle(
                  color: controller.text.isEmpty ? PensionConstants.subtitleColor : PensionConstants.textColor,
                ),
              ),
              trailing: Icon(Icons.arrow_drop_down, color: PensionConstants.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
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
        backgroundColor: PensionConstants.successColor,
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
        backgroundColor: PensionConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}