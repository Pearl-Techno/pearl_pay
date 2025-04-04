import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class DeductionsScreen extends StatefulWidget {
  const DeductionsScreen({super.key});

  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedEmployeeId;
  String? _selectedCompany; // For form
  String? _selectedFilterCompany; // For filter
  DateTime? _selectedDate;
  late ApiService _apiService;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _filteredDeductions = [];
  List<String> _companyNames = ['All Companies'];
  bool _isLoadingEmployees = true;
  bool _isLoadingDeductions = true;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(client: http.Client());
    _fetchEmployees();
    _fetchDeductions();
    _searchController.addListener(_filterDeductions);
  }

  Future<void> _fetchEmployees() async {
    try {
      final employees = await _apiService.fetchEmployees();
      setState(() {
        _employees = employees;
        _companyNames = ['All Companies'] +
            employees
                .map((e) => e['company_name'] as String?)
                .where((name) => name != null && name.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
        _isLoadingEmployees = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoadingEmployees = false;
      });
    }
  }

  Future<void> _fetchDeductions() async {
    try {
      final deductions = await _apiService.fetchDeductionsList();
      setState(() {
        _deductions = deductions;
        _filterDeductions();
        _isLoadingDeductions = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load deductions: $e';
        _isLoadingDeductions = false;
      });
    }
  }

  void _filterDeductions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDeductions = _deductions.where((deduction) {
        final date = DateTime.tryParse(deduction['date'] ?? '');
        final matchesDate = date != null &&
            date.month == _selectedMonth &&
            date.year == _selectedYear;
        final employee = _employees.firstWhere(
          (emp) =>
              emp['employee_id'].toString() ==
              deduction['employee_id'].toString(),
          orElse: () =>
              {'fullname': 'Unknown Employee', 'company_name': 'Unknown'},
        );
        final matchesCompany = _selectedFilterCompany == null ||
            _selectedFilterCompany == 'All Companies' ||
            employee['company_name'] == _selectedFilterCompany;
        final matchesSearch = query.isEmpty ||
            employee['fullname'].toString().toLowerCase().contains(query) ||
            deduction['description'].toString().toLowerCase().contains(query);
        return matchesDate && matchesCompany && matchesSearch;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.teal[700]!),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal[700]),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final employeeId = _selectedEmployeeId!;
      final description = _descriptionController.text;
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final date = _selectedDate ?? DateTime.now();

      final deductionData = {
        'employee_id': employeeId,
        'description': description,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(date),
      };

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Adding deduction...'),
              backgroundColor: Colors.teal[700]),
        );

        await _apiService.addDeduction(deductionData);
        await _fetchDeductions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deduction Added: ${_employees.firstWhere((emp) => emp['employee_id'].toString() == employeeId)['fullname']}, $description, KSh $amount, ${DateFormat.yMMMd().format(date)}',
            ),
            backgroundColor: Colors.teal[700],
          ),
        );

        _descriptionController.clear();
        _amountController.clear();
        setState(() {
          _selectedEmployeeId = null;
          _selectedCompany = null;
          _selectedDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add deduction: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (_filteredDeductions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    try {
      final List<List<dynamic>> rows = [
        ['Company', 'Employee', 'Description', 'Amount (KSh)', 'Date'],
        ..._filteredDeductions.map((deduction) {
          final employee = _employees.firstWhere(
            (emp) =>
                emp['employee_id'].toString() ==
                deduction['employee_id'].toString(),
            orElse: () =>
                {'fullname': 'Unknown Employee', 'company_name': 'Unknown'},
          );
          return [
            employee['company_name'] ?? 'Unknown',
            employee['fullname'] ?? 'Unknown',
            deduction['description'] ?? 'Unknown',
            'KSh ${deduction['amount'].toString()}',
            DateFormat.yMMMd().format(DateTime.parse(deduction['date'] ?? '')),
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/deductions_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deductions exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export to CSV: $e')),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDropdown<T>({
    T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
    String? label,
    String? Function(T?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(itemBuilder(item),
                      style: TextStyle(color: Colors.teal[900])),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal[900]),
          border: InputBorder.none,
        ),
        validator: validator,
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Deductions',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () => print('Notifications tapped'),
        onProfileTap: () => print('Profile tapped'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoadingEmployees || _isLoadingDeductions
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]))
                    : _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Colors.teal[900], fontSize: 16),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  padding: const EdgeInsets.all(16.0),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildDropdown<String>(
                                          value: _selectedCompany,
                                          items: _companyNames,
                                          itemBuilder: (company) => company,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedCompany = value;
                                              _selectedEmployeeId = null;
                                            });
                                          },
                                          label: 'Select Company',
                                          validator: (value) => value == null
                                              ? 'Please select a company'
                                              : null,
                                        ),
                                        const SizedBox(height: 16.0),
                                        _buildDropdown<String>(
                                          value: _selectedEmployeeId,
                                          items: _employees
                                              .where((employee) =>
                                                  _selectedCompany == null ||
                                                  _selectedCompany ==
                                                      'All Companies' ||
                                                  employee['company_name'] ==
                                                      _selectedCompany)
                                              .map((e) =>
                                                  e['employee_id'].toString())
                                              .toList(),
                                          itemBuilder: (id) =>
                                              _employees.firstWhere((e) =>
                                                  e['employee_id'].toString() ==
                                                  id)['fullname'] ??
                                              'Unknown',
                                          onChanged: (value) => setState(() =>
                                              _selectedEmployeeId = value),
                                          label: 'Select Employee',
                                          validator: (value) => value == null
                                              ? 'Please select an employee'
                                              : null,
                                        ),
                                        const SizedBox(height: 16.0),
                                        TextFormField(
                                          controller: _descriptionController,
                                          decoration: InputDecoration(
                                            labelText: 'Description',
                                            labelStyle: TextStyle(
                                                color: Colors.teal[900]),
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
                                            hintText:
                                                'e.g., Advance Deduction, Loan Repayment',
                                            hintStyle: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                                  ? 'Please enter a description'
                                                  : null,
                                          style: TextStyle(
                                              color: Colors.grey[800]),
                                        ),
                                        const SizedBox(height: 16.0),
                                        TextFormField(
                                          controller: _amountController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Amount (KSh)',
                                            labelStyle: TextStyle(
                                                color: Colors.teal[900]),
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
                                            hintText: 'e.g., 5000.00',
                                            hintStyle: TextStyle(
                                                color: Colors.grey[600]),
                                            prefixText: 'KSh ',
                                            prefixStyle: TextStyle(
                                                color: Colors.teal[900]),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty)
                                              return 'Please enter an amount';
                                            if (double.tryParse(value) ==
                                                    null ||
                                                double.parse(value) <= 0) {
                                              return 'Please enter a valid positive amount';
                                            }
                                            return null;
                                          },
                                          style: TextStyle(
                                              color: Colors.grey[800]),
                                        ),
                                        const SizedBox(height: 16.0),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _selectedDate == null
                                                  ? 'No date selected'
                                                  : 'Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
                                              style: TextStyle(
                                                color: _selectedDate == null
                                                    ? Colors.grey[600]
                                                    : Colors.teal[900],
                                                fontSize: 16,
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _selectDate(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.teal[700],
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              child: const Text('Select Date'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24.0),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _submitForm,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal[700],
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16.0),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Add Deduction',
                                                style: TextStyle(fontSize: 16)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
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
                          children: [
                            Expanded(
                              child: _buildDropdown<String>(
                                value: _selectedFilterCompany,
                                items: _companyNames,
                                itemBuilder: (company) => company,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFilterCompany = value;
                                    _filterDeductions();
                                  });
                                },
                                label: 'Company',
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: _buildDropdown<int>(
                                value: _selectedMonth,
                                items: List.generate(12, (index) => index + 1),
                                itemBuilder: (month) => DateFormat('MMMM')
                                    .format(DateTime(_selectedYear, month)),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMonth = value!;
                                    _filterDeductions();
                                  });
                                },
                                label: 'Month',
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: _buildDropdown<int>(
                                value: _selectedYear,
                                items: List.generate(
                                    10, (index) => DateTime.now().year - index),
                                itemBuilder: (year) => year.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value!;
                                    _filterDeductions();
                                  });
                                },
                                label: 'Year',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search',
                            labelStyle: TextStyle(color: Colors.teal[900]),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[200]!)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[200]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.teal[700]!)),
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
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _filteredDeductions.isEmpty
                        ? Center(
                            child: Text(
                              'No deductions for selected filters',
                              style: TextStyle(
                                  color: Colors.teal[900], fontSize: 16),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                columnSpacing: 16,
                                dataRowHeight: 60,
                                headingRowColor:
                                    MaterialStateProperty.all(Colors.teal[100]),
                                columns: const [
                                  DataColumn(
                                      label: Text('Company',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal))),
                                  DataColumn(
                                      label: Text('Employee',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal))),
                                  DataColumn(
                                      label: Text('Description',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal))),
                                  DataColumn(
                                      label: Text('Amount (KSh)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal))),
                                  DataColumn(
                                      label: Text('Date',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal))),
                                ],
                                rows: _filteredDeductions.map((deduction) {
                                  final employee = _employees.firstWhere(
                                    (emp) =>
                                        emp['employee_id'].toString() ==
                                        deduction['employee_id'].toString(),
                                    orElse: () => {
                                      'fullname': 'Unknown Employee',
                                      'company_name': 'Unknown'
                                    },
                                  );
                                  return DataRow(cells: [
                                    DataCell(Text(
                                        employee['company_name'] ?? 'Unknown',
                                        style: TextStyle(
                                            color: Colors.grey[800]))),
                                    DataCell(Text(
                                        employee['fullname'] ?? 'Unknown',
                                        style: TextStyle(
                                            color: Colors.grey[800]))),
                                    DataCell(Text(
                                        deduction['description'] ?? 'Unknown',
                                        style: TextStyle(
                                            color: Colors.grey[800]))),
                                    DataCell(Text(
                                        'KSh ${deduction['amount'].toString()}',
                                        style: TextStyle(
                                            color: Colors.grey[800]))),
                                    DataCell(Text(
                                        DateFormat.yMMMd().format(
                                            DateTime.parse(
                                                deduction['date'] ?? '')),
                                        style: TextStyle(
                                            color: Colors.grey[800]))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _exportToCSV,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Export to CSV'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
