import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../services/services.dart';

// DeductionsScreen: Allows admins to add and view employee deductions
class DeductionsScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const DeductionsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  int? _companyId;
  String? _companyName;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _filteredDeductions = [];
  bool _isLoadingEmployees = false;
  bool _isLoadingDeductions = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    print(
        'InitState: User role=${widget.user.role}, companyId=${widget.user.companyId}, companyName=${widget.user.companyName}, userId=${widget.user.userId}');
    if (widget.user.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('Access denied: Non-admin user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Access denied: Only admins can manage deductions')),
        );
        Navigator.pop(context);
      });
      return;
    }

    _companyId = widget.user.companyId;
    _companyName = widget.user.companyName ?? 'Unknown';
    print('Initialized: companyId=$_companyId, companyName=$_companyName');

    if (_companyId == null || _companyId! <= 0) {
      setState(() {
        _errorMessage = 'No valid company assigned to this user';
        _isLoadingEmployees = false;
        _isLoadingDeductions = false;
      });
      print('Error: Invalid companyId=$_companyId');
    } else {
      _fetchEmployees();
      _fetchDeductions();
    }

    _searchController.addListener(_filterDeductions);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    print('Disposed controllers');
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId! <= 0) {
      print('FetchEmployees: Invalid companyId=$_companyId, aborting');
      return;
    }
    setState(() => _isLoadingEmployees = true);
    print('Fetching employees for companyId=$_companyId');
    try {
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      print('Fetched employees: ${employees.length} records');
      setState(() {
        _employees = employees;
        _selectedEmployeeId = _employees.isNotEmpty
            ? _employees[0]['employee_id'].toString()
            : null;
        _isLoadingEmployees = false;
        _errorMessage = null;
      });
    } catch (e) {
      print('Error fetching employees: $e');
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoadingEmployees = false;
      });
    }
  }

  Future<void> _fetchDeductions() async {
    if (_companyId == null || _companyId! <= 0) {
      print('FetchDeductions: Invalid companyId=$_companyId, aborting');
      return;
    }
    setState(() => _isLoadingDeductions = true);
    print(
        'Fetching deductions for companyId=$_companyId, month=$_selectedMonth, year=$_selectedYear');
    try {
      final userId = int.tryParse(widget.user.userId?.toString() ?? '0') ?? 0;
      print('Using userId=$userId for fetchDeductions');
      final employeeId = _employees.isNotEmpty
          ? _employees[0]['employee_id'].toString()
          : null;
      if (employeeId == null)
        throw Exception('No employees available to fetch deductions');

      final deductions = await widget.apiService.fetchDeductions(
          _companyId!, _selectedMonth, _selectedYear, employeeId);
      print('Fetched deductions: ${deductions.length} records');
      setState(() {
        _deductions = deductions;
        _filterDeductions();
        _isLoadingDeductions = false;
        _errorMessage = null;
      });
    } catch (e) {
      print('Error fetching deductions: $e');
      setState(() {
        _errorMessage = 'Failed to load deductions: $e';
        _isLoadingDeductions = false;
      });
    }
  }

  void _filterDeductions() {
    final query = _searchController.text.toLowerCase();
    print('Filtering deductions with query="$query"');
    setState(() {
      _filteredDeductions = _deductions.where((deduction) {
        final employee = _employees.firstWhere(
          (emp) =>
              emp['employee_id'].toString() ==
              deduction['employee_id'].toString(),
          orElse: () => {'fullname': 'Unknown Employee'},
        );
        final fullname = (employee['fullname']?.toString() ?? '').toLowerCase();
        final description =
            (deduction['description']?.toString() ?? '').toLowerCase();
        return query.isEmpty ||
            fullname.contains(query) ||
            description.contains(query);
      }).toList();
      print('Filtered deductions count: ${_filteredDeductions.length}');
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    print('Opening date picker, current date=$_selectedDate');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Colors.teal[700]!),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal[700])),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      print('Selected date: $picked');
      setState(() => _selectedDate = picked);
    } else {
      print('Date selection cancelled');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _selectedDate == null) {
      print(
          'Form validation failed: selectedEmployeeId=$_selectedEmployeeId, selectedDate=$_selectedDate');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please complete all required fields and select a date')),
      );
      return;
    }

    final employeeId = _selectedEmployeeId!;
    final description = _descriptionController.text;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final date = _selectedDate!;

    final deductionData = {
      'employee_id': employeeId,
      'company_id': _companyId,
      'description': description,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(date),
    };
    print('Submitting deduction: $deductionData');

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Adding deduction...'),
            backgroundColor: Colors.teal[700]),
      );

      final userId = int.tryParse(widget.user.userId?.toString() ?? '0') ?? 0;
      print('Using userId=$userId for addDeduction');
      await widget.apiService.addDeduction(deductionData, userId);
      print('Deduction added successfully');

      final deductionDate = DateTime.parse(deductionData['date'] as String);
      setState(() {
        _selectedMonth = deductionDate.month;
        _selectedYear = deductionDate.year;
      });
      await _fetchDeductions();

      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == employeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Deduction Added: ${employee['fullname']}, $description, ${currencyFormat.format(amount)}, ${DateFormat.yMMMd().format(date)}'),
          backgroundColor: Colors.teal[700],
        ),
      );

      _descriptionController.clear();
      _amountController.clear();
      setState(() {
        _selectedEmployeeId = _employees.isNotEmpty
            ? _employees[0]['employee_id'].toString()
            : null;
        _selectedDate = null;
      });
    } catch (e) {
      print('Error submitting deduction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add deduction: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Retry', onPressed: _submitForm),
        ),
      );
    }
  }

  Future<void> _exportToCSV() async {
    if (_filteredDeductions.isEmpty) {
      print('No deductions to export');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No deductions available to export')),
      );
      return;
    }
    print('Exporting ${_filteredDeductions.length} deductions to CSV');

    try {
      final headers = [
        'Company',
        'Employee',
        'Description',
        'Amount (KES)',
        'Date'
      ];
      final rows = [
        headers,
        ..._filteredDeductions.map((deduction) {
          final employee = _employees.firstWhere(
            (emp) =>
                emp['employee_id'].toString() ==
                deduction['employee_id'].toString(),
            orElse: () => {'fullname': 'Unknown Employee'},
          );
          final dateStr = deduction['date'] != null
              ? DateFormat.yMMMd().format(DateTime.parse(deduction['date']))
              : 'N/A';
          final amount = deduction['amount'] is String
              ? double.tryParse(deduction['amount']) ?? 0.0
              : (deduction['amount']?.toDouble() ?? 0.0);
          return [
            _companyName ?? 'Unknown',
            employee['fullname'] ?? 'Unknown',
            deduction['description'] ?? 'Unknown',
            currencyFormat.format(amount),
            dateStr,
          ];
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'deductions_${_companyName?.replaceAll(' ', '_') ?? 'unknown'}_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsString(csv);
      print('CSV exported to: $filePath');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Deductions exported to $filePath'),
            backgroundColor: Colors.teal[700]),
      );
    } catch (e) {
      print('Error exporting to CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    }
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    bool isEnabled = true,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.teal[900],
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          decoration: InputDecoration(
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
          value: value,
          items: items
              .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(itemBuilder(item),
                      style: TextStyle(color: Colors.teal[900]))))
              .toList(),
          onChanged: isEnabled ? onChanged : null,
          validator: validator ??
              (value) => value == null ? 'Please select $label' : null,
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.teal[900]),
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
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixText: isNumber ? 'KES ' : null,
        prefixStyle: isNumber ? TextStyle(color: Colors.teal[900]) : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (isNumber) {
          final num = double.tryParse(value);
          if (num == null || num <= 0)
            return 'Please enter a valid positive amount';
          if (num > 1000000) return 'Amount cannot exceed KES 1,000,000';
        } else if (value.length > 100)
          return 'Description cannot exceed 100 characters';
        return null;
      },
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deduction Date',
            style: TextStyle(
                color: Colors.teal[900],
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'No date selected'
                  : 'Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
              style: TextStyle(
                  color: _selectedDate == null
                      ? Colors.grey[600]
                      : Colors.teal[900],
                  fontSize: 16),
            ),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Select Date'),
            ),
          ],
        ),
        if (_selectedDate == null)
          Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Please select a date',
                  style: TextStyle(color: Colors.red[700], fontSize: 12))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building UI: companyName=$_companyName, errorMessage=$_errorMessage, employees=${_employees.length}, deductions=${_deductions.length}');
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Deductions - $_companyName'),
            backgroundColor: Colors.teal[800],
            pinned: true,
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    print('Refresh button pressed');
                    _fetchEmployees();
                    _fetchDeductions();
                  },
                  tooltip: 'Refresh Data'),
              IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () => print('Notifications tapped'),
                  tooltip: 'Notifications'),
              IconButton(
                  icon: const Icon(Icons.person, color: Colors.white),
                  onPressed: () => print('Profile tapped'),
                  tooltip: 'Profile'),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.teal[50]!, Colors.teal[100]!],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
              ),
              child: _errorMessage != null
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!,
                                style: TextStyle(
                                    color: Colors.teal[900], fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                print('Retry button pressed');
                                _fetchEmployees();
                                _fetchDeductions();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: const Text('Retry'),
                            ),
                          ]),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [Colors.white, Colors.teal[50]!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(16.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Company: $_companyName',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal[900])),
                                        const SizedBox(height: 16.0),
                                        _buildDropdown(
                                          label: 'Employee',
                                          value: _selectedEmployeeId,
                                          items: _isLoadingEmployees ||
                                                  _employees.isEmpty
                                              ? []
                                              : _employees
                                                  .map((e) => e['employee_id']
                                                      .toString())
                                                  .toList(),
                                          itemBuilder: (id) {
                                            final employee =
                                                _employees.firstWhere(
                                                    (emp) =>
                                                        emp['employee_id']
                                                            .toString() ==
                                                        id,
                                                    orElse: () => {
                                                          'fullname': 'Unknown'
                                                        });
                                            return '${employee['employee_id']} - ${employee['fullname']}';
                                          },
                                          onChanged: (value) => value != null
                                              ? setState(() =>
                                                  _selectedEmployeeId = value)
                                              : null,
                                          isEnabled: !_isLoadingEmployees &&
                                              _employees.isNotEmpty,
                                        ),
                                        if (_isLoadingEmployees)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: CircularProgressIndicator(
                                                  color: Colors.teal[700])),
                                        if (_employees.isEmpty &&
                                            !_isLoadingEmployees)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Text(
                                                  'No employees available for this company',
                                                  style: TextStyle(
                                                      color: Colors.red[700]))),
                                        const SizedBox(height: 16.0),
                                        _buildTextField(
                                            controller: _descriptionController,
                                            label: 'Description',
                                            hintText:
                                                'e.g., Loan Repayment, Advance Deduction'),
                                        const SizedBox(height: 16.0),
                                        _buildTextField(
                                            controller: _amountController,
                                            label: 'Amount',
                                            isNumber: true,
                                            hintText: 'e.g., 5000.00'),
                                        const SizedBox(height: 16.0),
                                        _buildDatePicker(),
                                        const SizedBox(height: 24.0),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isLoadingEmployees ||
                                                    _isLoadingDeductions ||
                                                    _employees.isEmpty
                                                ? null
                                                : _submitForm,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.teal[700],
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16.0),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8))),
                                            child: const Text('Add Deduction',
                                                style: TextStyle(fontSize: 16)),
                                          ),
                                        ),
                                      ]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _exportToCSV,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                child: const Text('Export to CSV',
                                    style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ]),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                            child: _buildDropdown(
                          label: 'Month',
                          value: _selectedMonth,
                          items: List.generate(12, (index) => index + 1),
                          itemBuilder: (month) => DateFormat('MMMM')
                              .format(DateTime(_selectedYear, month)),
                          onChanged: (value) => value != null
                              ? setState(() {
                                  _selectedMonth = value;
                                  _fetchDeductions();
                                })
                              : null,
                        )),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildDropdown(
                          label: 'Year',
                          value: _selectedYear,
                          items: List.generate(
                              10, (index) => DateTime.now().year - index),
                          itemBuilder: (year) => year.toString(),
                          onChanged: (value) => value != null
                              ? setState(() {
                                  _selectedYear = value;
                                  _fetchDeductions();
                                })
                              : null,
                        )),
                      ]),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search',
                          labelStyle: TextStyle(color: Colors.teal[900]),
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
                          hintText: 'Search by name or description',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          suffixIcon:
                              Icon(Icons.search, color: Colors.teal[700]),
                        ),
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5),
                      child: _isLoadingDeductions
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: Colors.teal[700]))
                          : _filteredDeductions.isEmpty
                              ? Center(
                                  child: Text(
                                      'No deductions for selected filters',
                                      style: TextStyle(
                                          color: Colors.teal[900],
                                          fontSize: 16)))
                              : PaginatedDataTable(
                                  header: Text('Deductions',
                                      style:
                                          TextStyle(color: Colors.teal[900])),
                                  columns: [
                                    DataColumn(
                                        label: Text('Company',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14))),
                                    DataColumn(
                                        label: Text('Employee',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14))),
                                    DataColumn(
                                        label: Text('Description',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14))),
                                    DataColumn(
                                        label: Text('Amount (KES)',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14))),
                                    DataColumn(
                                        label: Text('Date',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14))),
                                  ],
                                  source: DeductionsDataSource(
                                      _filteredDeductions,
                                      _employees,
                                      _companyName ?? 'Unknown'),
                                  rowsPerPage: 5,
                                  columnSpacing: 16,
                                  dataRowHeight: 60,
                                  headingRowColor: MaterialStateProperty.all(
                                      Colors.teal[100]),
                                ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeductionsDataSource extends DataTableSource {
  final List<Map<String, dynamic>> deductions;
  final List<Map<String, dynamic>> employees;
  final String companyName;
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);

  DeductionsDataSource(this.deductions, this.employees, this.companyName);

  @override
  DataRow getRow(int index) {
    final deduction = deductions[index];
    print('Rendering row $index: deduction=$deduction');
    final employee = employees.firstWhere(
      (emp) =>
          emp['employee_id'].toString() == deduction['employee_id'].toString(),
      orElse: () => {'fullname': 'Unknown Employee'},
    );
    final dateStr = deduction['date'] != null
        ? DateFormat.yMMMd().format(DateTime.parse(deduction['date']))
        : 'N/A';
    final amount = deduction['amount'] is String
        ? double.tryParse(deduction['amount']) ?? 0.0
        : (deduction['amount']?.toDouble() ?? 0.0);
    return DataRow(cells: [
      DataCell(Text(companyName, style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(employee['fullname'] ?? 'Unknown',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(deduction['description'] ?? 'Unknown',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(currencyFormat.format(amount),
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(dateStr, style: TextStyle(color: Colors.grey[800]))),
    ]);
  }

  @override
  int get rowCount => deductions.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
