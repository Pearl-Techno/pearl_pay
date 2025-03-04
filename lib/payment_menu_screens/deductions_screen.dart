import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services.dart';

class DeductionsScreen extends StatefulWidget {
  const DeductionsScreen({super.key});

  @override
  State<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends State<DeductionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedEmployeeId;
  String? _selectedCompany; // New variable for selected company
  DateTime? _selectedDate;
  late ApiService _apiService;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _deductions = [];
  List<String> _companyNames = [
    'All Companies'
  ]; // List of unique company names
  bool _isLoadingEmployees = true;
  bool _isLoadingDeductions = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(client: http.Client());
    _fetchEmployees();
    _fetchDeductions();
  }

  Future<void> _fetchEmployees() async {
    try {
      final employees = await _apiService.fetchEmployees();
      setState(() {
        _employees = employees;
        // Extract unique company names
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
        _isLoadingDeductions = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load deductions: $e';
        _isLoadingDeductions = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
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
          const SnackBar(content: Text('Adding deduction...')),
        );

        await _apiService.addDeduction(deductionData);

        await _fetchDeductions();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deduction Added: ${_employees.firstWhere((emp) => emp['employee_id'].toString() == employeeId)['fullname']}, $description, KSh $amount, ${DateFormat.yMMMd().format(date)}',
            ),
            backgroundColor: Colors.teal,
          ),
        );

        _descriptionController.clear();
        _amountController.clear();
        setState(() {
          _selectedEmployeeId = null;
          _selectedDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add deduction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deductions'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingEmployees || _isLoadingDeductions
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Company Dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedCompany,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Company',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _companyNames.map((company) {
                                    return DropdownMenuItem(
                                      value: company,
                                      child: Text(company),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCompany = value;
                                      _selectedEmployeeId =
                                          null; // Reset employee selection
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a company';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),

                                // Employee Dropdown (filtered by company)
                                DropdownButtonFormField<String>(
                                  value: _selectedEmployeeId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Employee',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _employees
                                      .where((employee) =>
                                          _selectedCompany == null ||
                                          _selectedCompany == 'All Companies' ||
                                          employee['company_name'] ==
                                              _selectedCompany)
                                      .map((employee) {
                                    return DropdownMenuItem(
                                      value: employee['employee_id'].toString(),
                                      child: Text(
                                          employee['fullname'] ?? 'Unknown'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedEmployeeId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select an employee';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),

                                // Description Field
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(),
                                    hintText:
                                        'e.g., Advance Deduction, Loan Repayment, etc.',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a description';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),

                                // Amount Field (in Kenyan Shillings)
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (KSh)',
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g., 5000.00',
                                    prefixText: 'KSh ',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an amount';
                                    }
                                    if (double.tryParse(value) == null ||
                                        double.parse(value) <= 0) {
                                      return 'Please enter a valid positive amount';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),

                                // Date Picker
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
                                            ? Colors.grey
                                            : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _selectDate(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                      ),
                                      child: const Text('Select Date'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24.0),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                    ),
                                    child: const Text(
                                      'Add Deduction',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      // Deductions Table
                      Expanded(
                        child: _deductions.isEmpty
                            ? const Center(
                                child: Text('No deductions recorded yet'))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Employee')),
                                    DataColumn(label: Text('Description')),
                                    DataColumn(label: Text('Amount (KSh)')),
                                    DataColumn(label: Text('Date')),
                                  ],
                                  rows: _deductions.map((deduction) {
                                    final employee = _employees.firstWhere(
                                        (emp) =>
                                            emp['employee_id'].toString() ==
                                            deduction['employee_id'].toString(),
                                        orElse: () =>
                                            {'fullname': 'Unknown Employee'});
                                    return DataRow(cells: [
                                      DataCell(Text(
                                          employee['fullname'] ?? 'Unknown')),
                                      DataCell(Text(deduction['description'] ??
                                          'Unknown')),
                                      DataCell(Text(
                                          'KSh ${deduction['amount'].toString()}')),
                                      DataCell(Text(DateFormat.yMMMd().format(
                                          DateTime.parse(
                                              deduction['date'] ?? '')))),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
