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
      _showSnackBar('Failed to load companies: $e');
    }
  }

  Future<void> _fetchPensionRecords() async {
    setState(() {
      _isLoading = true;
      _pensionRecords = [];
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
      if (companyId == null || companyId.toString().isEmpty || int.tryParse(companyId.toString()) == null || int.parse(companyId.toString()) <= 0) {
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
    } catch (e) {
      _showSnackBar('Failed to load pension records: $e');
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
      _showSnackBar('Please fetch pension records first.');
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
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(csvBytes);
        _showSnackBar('CSV file saved to Downloads: ${file.path}');
      }

      _showSnackBar('Pension report exported successfully',
          backgroundColor: Colors.teal[700]);
    } catch (e) {
      _showSnackBar('Failed to export pension report: $e');
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
      _showSnackBar('No employees available for the selected company.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Add Pension Contribution',
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
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: _buildInputDecoration('Employee'),
                    value: selectedEmployeeId,
                    items: filteredEmployees
                        .map((e) => DropdownMenuItem(
                              value: e['employee_id'].toString(),
                              child: Text(
                                '${e['fullname']} (${e['employee_id']})',
                                style: TextStyle(color: Colors.teal[900]),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedEmployeeId = value;
                        final employee = filteredEmployees.firstWhere(
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
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select an employee' : null,
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: _buildInputDecoration('Pension Amount'),
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
                    Text(
                      'Calculated Pension: ${calculatedPension!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.teal[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: _buildInputDecoration('Payment Date').copyWith(
                      suffixIcon: IconButton(
                        icon:
                            Icon(Icons.calendar_today, color: Colors.teal[700]),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                    primary: Colors.teal[700]!),
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
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select a date'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: _buildInputDecoration('Month'),
                    value: dialogMonth,
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          DateFormat('MMMM')
                              .format(DateTime(dialogYear, index + 1)),
                          style: TextStyle(color: Colors.teal[900]),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => dialogMonth = value!);
                    },
                    validator: (value) =>
                        value == null ? 'Please select a month' : null,
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: _buildInputDecoration('Year'),
                    value: dialogYear,
                    items: List.generate(
                      10,
                      (index) => DropdownMenuItem(
                        value: DateTime.now().year - index,
                        child: Text(
                          (DateTime.now().year - index).toString(),
                          style: TextStyle(color: Colors.teal[900]),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => dialogYear = value!);
                    },
                    validator: (value) =>
                        value == null ? 'Please select a year' : null,
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.teal[700])),
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
                  if (companyId == null || companyId.toString().isEmpty) {
                    throw Exception(
                        'Invalid company ID: ${widget.user.companyId}');
                  }
                  await _apiService.savePensionContribution(
                    pensionData,
                    companyId,
                  );
                  Navigator.pop(context);
                  _showSnackBar('Pension contribution added successfully',
                      backgroundColor: Colors.teal[700]);
                  await _fetchPensionRecords();
                } catch (e) {
                  _showSnackBar('Failed to add pension contribution: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmployeePensionDetails(String employeeId) async {
    try {
      final companyId = int.tryParse(widget.user.companyId.toString());
      if (companyId == null) {
        throw Exception('Invalid company ID: ${widget.user.companyId}');
      }

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

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pension Details',
              style: TextStyle(color: Colors.teal[900])),
          content: Text(
            'Total Pension Contribution for $employeeId: ${totalAmount.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.teal[900]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Colors.teal[700])),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to load pension details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Manage Pension Contributions',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () => debugPrint('Notifications tapped'),
        onProfileTap: () => debugPrint('Profile tapped'),
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<int>(
                              value: _selectedMonth,
                              items: List.generate(12, (index) => index + 1),
                              itemBuilder: (month) => DateFormat('MMMM')
                                  .format(DateTime(_selectedYear, month)),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value!;
                                  _pensionRecords = [];
                                  _searchKeyword = '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDropdown<int>(
                              value: _selectedYear,
                              items: List.generate(
                                  10, (index) => DateTime.now().year - index),
                              itemBuilder: (year) => year.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value!;
                                  _pensionRecords = [];
                                  _searchKeyword = '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDropdown<String>(
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _selectedPaymentDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                          primary: Colors.teal[700]!),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedPaymentDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal[50]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedPaymentDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(_selectedPaymentDate!)
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _fetchPensionRecords,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('Fetch Pensions'),
                            ),
                          ),
                        ],
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search by Full Name',
                      prefixIcon: Icon(Icons.search, color: Colors.teal[700]),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() => _searchKeyword = value.toLowerCase());
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[400]))
                    : _pensionRecords.isEmpty
                        ? Center(
                            child: Text(
                              'No pension records available',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 0,
                                dataRowMinHeight: 40.0,
                                headingRowColor: MaterialStateProperty.all(Colors.teal[100]),
                                sortColumnIndex: _getColumnIndex(_sortColumn),
                                columns: _buildTableColumns(),
                                rows: _buildFilteredTableRows(),
                              ),
                            ),
                          ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _exportPensionReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Export Pension Report'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showAddPensionDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add Pension'),
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
            color: Colors.teal[900],
            fontSize: 14,
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

  List<DataRow> _buildFilteredTableRows() {
    final filteredRecords = _pensionRecords.where((record) {
      if (record['fullname'] == 'Totals') return true;
      final fullName = record['fullname']?.toString().toLowerCase() ?? '';
      return fullName.contains(_searchKeyword);
    }).toList();

    return filteredRecords.map((record) {
      final cells = [
        record['employee_id']?.toString() ?? '',
        record['company_name']?.toString() ?? '',
        record['fullname']?.toString() ?? 'Unknown',
        (record['basic_pay'] as num?)?.toStringAsFixed(2) ?? '0.00',
        (record['pension_contribution'] as num?)?.toStringAsFixed(2) ?? '0.00',
        (record['contribution_count'] as int?)?.toString() ?? '0',
        record['payment_date']?.toString() ?? '',
        record['month']?.toString() ?? '',
        (record['year'] as int?)?.toString() ?? '',
      ];

      return DataRow(
        onSelectChanged: record['employee_id'] != null
            ? (selected) =>
                _showEmployeePensionDetails(record['employee_id'] as String)
            : null,
        cells: cells.map((value) {
          return DataCell(
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: record['fullname'] == 'Totals'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      );
    }).toList();
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
    return columns.indexOf(columnKey);
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

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.teal[900]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.teal[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.teal[700]!),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red[700],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
