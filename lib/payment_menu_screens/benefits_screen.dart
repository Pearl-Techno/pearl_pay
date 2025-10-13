import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pearl_pay/services/services.dart';

import '../models/user.dart';
import '../widgets/custom_app_bar.dart';

// BenefitsScreen: Allows admins to add and view employee benefits
class BenefitsScreen extends StatefulWidget {
  final User user; // User data from HomeScreen
  final ApiService apiService; // ApiService for backend calls

  const BenefitsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  int? _companyId;
  String? _companyName;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _benefits = [];
  bool _isLoadingEmployees = false;
  bool _isLoadingBenefits = false;
  String? _errorMessage;
  String? _selectedBenefitType;
  final List<String> _benefitTypes = ['Cash', 'Non-Cash'];

  int _selectedMonth = DateTime.now().month; // June 2025
  int _selectedYear = DateTime.now().year; // 2025
  String? _filterEmployeeId; // For filtering benefits by employee

  @override
  void initState() {
    super.initState();
    // Restrict access to admins only
    if (widget.user.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Access denied: Only admins can manage benefits')),
        );
        Navigator.pop(context);
      });
      return;
    }

    // Set company details from user
    _companyId = widget.user.companyId;
    _companyName = widget.user.companyName ?? 'Unknown';

    // Fetch employees and benefits for the user's company
    if (_companyId != null && _companyId! > 0) {
      _fetchEmployees();
      _fetchBenefits();
    } else {
      setState(() {
        _errorMessage = 'No company assigned to this user';
        _isLoadingEmployees = false;
        _isLoadingBenefits = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Fetch Employees: Retrieves employees for the user's company
  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId! <= 0) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      setState(() {
        _employees = employees;
        _selectedEmployeeId = _employees.isNotEmpty
            ? _employees[0]['employee_id'].toString()
            : null;
        _filterEmployeeId = null; // Default to no employee filter
        _isLoadingEmployees = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoadingEmployees = false;
      });
    }
  }

  // Fetch Benefits: Retrieves benefits for the user's company, filtered by employee, month, and year
// Fetch Benefits: Retrieves benefits for the user's company, filtered by employee, month, and year
  Future<void> _fetchBenefits() async {
    if (_companyId == null || _companyId! <= 0) return;
    setState(() => _isLoadingBenefits = true);
    try {
      if (kDebugMode) {
        print(
            'Fetching benefits with companyId: $_companyId, employeeId: $_filterEmployeeId, month: $_selectedMonth, year: $_selectedYear, userId: ${widget.user.userId}');
      }
      final benefits = await widget.apiService.fetchBenefits(
        _companyId!, // companyId (int)
        _selectedMonth, // month (int)
        _selectedYear, // year (int)
        _filterEmployeeId ?? '', // employeeId (String, empty if no filter)
      );
      setState(() {
        _benefits = benefits;
        _isLoadingBenefits = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load benefits: $e';
        _isLoadingBenefits = false;
      });
    }
  }

  // Select Date: Shows a date picker for benefit date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
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
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Submit Form: Adds a new benefit to the backend
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _selectedBenefitType == null ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please complete all required fields and select a date')),
      );
      return;
    }

    final employeeId = _selectedEmployeeId!;
    final benefitType = _selectedBenefitType!;
    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final date = _selectedDate!;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    final benefitData = {
      'employee_id': employeeId,
      'benefit_type': benefitType,
      'description': description.isEmpty ? 'No description' : description,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'company_id': _companyId,
    };

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adding benefit...'),
          backgroundColor: Colors.teal[700],
        ),
      );

      await widget.apiService.addBenefit(benefitData, _companyId!);

      final benefitDate = DateTime.parse(benefitData['date'] as String);
      setState(() {
        _selectedMonth = benefitDate.month;
        _selectedYear = benefitDate.year;
        _filterEmployeeId = employeeId; // Filter benefits by the added employee
      });
      await _fetchBenefits();

      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == employeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Benefit Added: ${employee['fullname']}, $benefitType, $description, KES $amount, ${DateFormat.yMMMd().format(date)}',
          ),
          backgroundColor: Colors.teal[700],
        ),
      );

      _descriptionController.clear();
      _amountController.clear();
      setState(() {
        _selectedEmployeeId = _employees.isNotEmpty
            ? _employees[0]['employee_id'].toString()
            : null;
        _selectedBenefitType = null;
        _selectedDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add benefit: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _submitForm,
          ),
        ),
      );
    }
  }

  // Build Dropdown: Creates a styled dropdown widget
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
        Text(
          label,
          style: TextStyle(
            color: Colors.teal[900],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.teal[200]!),
            ),
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
          ),
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

  // Build Text Field: Creates a styled text input field
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
          borderSide: BorderSide(color: Colors.teal[200]!),
        ),
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
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixText: isNumber ? 'KES ' : null,
        prefixStyle: isNumber ? TextStyle(color: Colors.teal[900]) : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (isNumber &&
            (double.tryParse(value) == null || double.parse(value) <= 0)) {
          return 'Please enter a valid positive amount';
        }
        return null;
      },
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  // Build Date Picker: Creates a date picker for benefit date
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benefit Date',
          style: TextStyle(
            color: Colors.teal[900],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'No date selected'
                  : 'Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
              style: TextStyle(
                color:
                    _selectedDate == null ? Colors.grey[600] : Colors.teal[900],
                fontSize: 16,
              ),
            ),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Select Date'),
            ),
          ],
        ),
        if (_selectedDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please select a date',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Benefits - $_companyName',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          print('Profile tapped');
        },
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _fetchEmployees();
              _fetchBenefits();
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.teal[900], fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _fetchEmployees();
                        _fetchBenefits();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filters (Employee, Month, Year)
                    Card(
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
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildDropdown(
                                    label: 'Month',
                                    value: _selectedMonth,
                                    items:
                                        List.generate(12, (index) => index + 1),
                                    itemBuilder: (month) => DateFormat('MMMM')
                                        .format(DateTime(_selectedYear, month)),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedMonth = value;
                                          _fetchBenefits();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDropdown(
                                    label: 'Year',
                                    value: _selectedYear,
                                    items: List.generate(
                                        10,
                                        (index) =>
                                            DateTime.now().year - index),
                                    itemBuilder: (year) => year.toString(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedYear = value;
                                          _fetchBenefits();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDropdown(
                              label: 'Employee Filter',
                              value: _filterEmployeeId,
                              items: [
                                null,
                                ..._employees
                                    .map((e) => e['employee_id'].toString())
                              ],
                              itemBuilder: (id) => id == null
                                  ? 'All Employees'
                                  : _employees.firstWhere(
                                      (emp) =>
                                          emp['employee_id'].toString() == id,
                                      orElse: () => {'fullname': 'Unknown'},
                                    )['fullname'] as String,
                              onChanged: (value) {
                                setState(() {
                                  _filterEmployeeId = value;
                                  _fetchBenefits();
                                });
                              },
                              validator: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    // Benefits Form
                    Card(
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
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Company: $_companyName',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[900],
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              // Employee Dropdown
                              _buildDropdown(
                                label: 'Employee',
                                value: _selectedEmployeeId,
                                items: _isLoadingEmployees || _employees.isEmpty
                                    ? []
                                    : _employees
                                        .map((e) => e['employee_id'].toString())
                                        .toList(),
                                itemBuilder: (id) {
                                  final employee = _employees.firstWhere(
                                    (emp) =>
                                        emp['employee_id'].toString() == id,
                                    orElse: () => {'fullname': 'Unknown'},
                                  );
                                  return '${employee['employee_id']} - ${employee['fullname']}';
                                },
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedEmployeeId = value;
                                    });
                                  }
                                },
                                isEnabled: !_isLoadingEmployees &&
                                    _employees.isNotEmpty,
                              ),
                              if (_isLoadingEmployees)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: CircularProgressIndicator(
                                      color: Colors.teal[700]),
                                ),
                              if (_employees.isEmpty && !_isLoadingEmployees)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'No employees available for this company',
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              const SizedBox(height: 16.0),
                              // Benefit Type Dropdown
                              _buildDropdown(
                                label: 'Benefit Type',
                                value: _selectedBenefitType,
                                items: _benefitTypes,
                                itemBuilder: (type) => type,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedBenefitType = value;
                                    });
                                  }
                                },
                                validator: (value) => value == null
                                    ? 'Please select a benefit type'
                                    : null,
                              ),
                              const SizedBox(height: 16.0),
                              // Description Field
                              _buildTextField(
                                controller: _descriptionController,
                                label: 'Description',
                                hintText:
                                    'e.g., Performance Bonus, Company Car',
                              ),
                              const SizedBox(height: 16.0),
                              // Amount Field
                              _buildTextField(
                                controller: _amountController,
                                label: 'Amount',
                                isNumber: true,
                                hintText: 'e.g., 10000.00',
                              ),
                              const SizedBox(height: 16.0),
                              // Date Picker
                              _buildDatePicker(),
                              const SizedBox(height: 24.0),
                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoadingEmployees ||
                                          _isLoadingBenefits ||
                                          _employees.isEmpty
                                      ? null
                                      : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add Benefit',
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
                    // Benefits Table
                    _isLoadingBenefits
                        ? Center(
                            child: CircularProgressIndicator(
                                color: Colors.teal[700]))
                        : _benefits.isEmpty
                            ? Center(
                                child: Text(
                                  'No benefits recorded for this period',
                                  style: TextStyle(
                                      color: Colors.teal[900], fontSize: 16),
                                ),
                              )
                            : Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.white, Colors.teal[50]!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: PaginatedDataTable(
                                    header: Text('Benefits',
                                        style:
                                            TextStyle(color: Colors.teal[900])),
                                    columns: [
                                      DataColumn(
                                        label: Text('Employee',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14)),
                                      ),
                                      DataColumn(
                                        label: Text('Type',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14)),
                                      ),
                                      DataColumn(
                                        label: Text('Description',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14)),
                                      ),
                                      DataColumn(
                                        label: Text('Amount (KES)',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14)),
                                      ),
                                      DataColumn(
                                        label: Text('Date',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[900],
                                                fontSize: 14)),
                                      ),
                                    ],
                                    source: BenefitsDataSource(
                                        _benefits, _employees),
                                    rowsPerPage: 5,
                                    columnSpacing: 16,
                                    dataRowHeight: 60,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.teal[100]),
                                  ),
                                ),
                              ),
                  ],
                ),
              ),
      ),
    );
  }
}

// BenefitsDataSource: Data source for PaginatedDataTable
class BenefitsDataSource extends DataTableSource {
  final List<Map<String, dynamic>> benefits;
  final List<Map<String, dynamic>> employees;
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);

  BenefitsDataSource(this.benefits, this.employees);

  @override
  DataRow getRow(int index) {
    final benefit = benefits[index];
    final employee = employees.firstWhere(
      (emp) =>
          emp['employee_id'].toString() == benefit['employee_id'].toString(),
      orElse: () => {'fullname': 'Unknown Employee'},
    );
    final amount =
        double.tryParse(benefit['amount']?.toString() ?? '0.0') ?? 0.0;
    return DataRow(cells: [
      DataCell(Text(employee['fullname'] ?? 'Unknown',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(benefit['benefit_type'] ?? 'Unknown',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(benefit['description'] ?? 'Unknown',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(currencyFormat.format(amount),
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(
          benefit['date'] != null
              ? DateFormat.yMMMd().format(DateTime.parse(benefit['date']))
              : 'N/A',
          style: TextStyle(color: Colors.grey[800]))),
    ]);
  }

  @override
  int get rowCount => benefits.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}