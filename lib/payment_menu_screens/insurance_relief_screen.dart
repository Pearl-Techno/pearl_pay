import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';

// InsuranceReliefScreen: Allows admins to add and view insurance relief records
class InsuranceReliefScreen extends StatefulWidget {
  final User user; // User data from HomeScreen
  final ApiService apiService; // ApiService for backend calls

  const InsuranceReliefScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<InsuranceReliefScreen> createState() => _InsuranceReliefScreenState();
}

class _InsuranceReliefScreenState extends State<InsuranceReliefScreen> {
  final _formKey = GlobalKey<FormState>();
  final _premiumController = TextEditingController();
  final _percentageController = TextEditingController();
  final _reliefController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  int? _companyId;
  String? _companyName;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _reliefRecords = [];
  List<Map<String, dynamic>> _filteredReliefRecords = [];
  bool _isLoadingEmployees = false;
  bool _isLoadingReliefs = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    // Restrict access to admins only
    if (widget.user.role.toLowerCase() != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Access denied: Only admins can manage insurance reliefs')),
        );
        Navigator.pop(context);
      });
      return;
    }

    // Set company details from user
    _companyId = widget.user.companyId;
    _companyName = widget.user.companyName ?? 'Unknown';

    // Fetch employees and relief records for the user's company
    if (_companyId != 0) {
      _fetchEmployees();
      _fetchReliefRecords();
    } else {
      setState(() {
        _errorMessage = 'No company assigned to this user';
        _isLoadingEmployees = false;
        _isLoadingReliefs = false;
      });
    }

    // Add listeners for relief calculation
    _premiumController.addListener(_calculateRelief);
    _percentageController.addListener(_calculateRelief);
    _searchController.addListener(_filterReliefRecords);
  }

  @override
  void dispose() {
    _premiumController.removeListener(_calculateRelief);
    _percentageController.removeListener(_calculateRelief);
    _searchController.removeListener(_filterReliefRecords);
    _premiumController.dispose();
    _percentageController.dispose();
    _reliefController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Fetch Employees: Retrieves employees for the user's company
  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId == 0) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      setState(() {
        _employees = employees;
        _selectedEmployeeId = null;
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

  // Fetch Relief Records: Retrieves relief records for the user's company, filtered by month and year
  Future<void> _fetchReliefRecords() async {
    if (_companyId == null || _companyId == 0) return;
    setState(() => _isLoadingReliefs = true);
    try {
      final reliefRecords = await widget.apiService.getInsuranceRelief(
        companyId: _companyId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() {
        _reliefRecords = reliefRecords;
        _filterReliefRecords();
        _isLoadingReliefs = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load relief records: $e';
        _isLoadingReliefs = false;
      });
    }
  }

  // Filter Relief Records: Filters relief records by search query
  void _filterReliefRecords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReliefRecords = _reliefRecords.where((record) {
        final employee = _employees.firstWhere(
          (emp) =>
              emp['employee_id'].toString() == record['employee_id'].toString(),
          orElse: () => {'fullname': 'Unknown Employee'},
        );
        final fullname = (employee['fullname']?.toString() ?? '').toLowerCase();
        return query.isEmpty || fullname.contains(query);
      }).toList();
    });
  }

  // Calculate Relief: Updates relief amount based on premium and percentage
  void _calculateRelief() {
    final premium = double.tryParse(_premiumController.text) ?? 0.0;
    final percentage = double.tryParse(_percentageController.text) ?? 0.0;
    final relief = premium * (percentage / 100);
    _reliefController.text = relief.toStringAsFixed(2);
  }

  // Select Date: Shows a date picker for relief date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
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

  // Submit Form: Adds a new insurance relief to the backend
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() ||
        _selectedEmployeeId == null ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please complete all required fields and select a date')),
      );
      return;
    }

    final employeeId = _selectedEmployeeId!;
    final premium = double.parse(_premiumController.text);
    final percentage = double.parse(_percentageController.text);
    final relief = double.parse(_reliefController.text);

    if (relief > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relief amount cannot exceed KES 5,000')),
      );
      return;
    }

    final reliefData = {
      'employee_id': employeeId,
      'company_id': _companyId,
      'premium_amount': premium,
      'relief_percentage': percentage,
      'relief_amount': relief,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
    };

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saving insurance relief...'),
          backgroundColor: Colors.teal[700],
        ),
      );

      await widget.apiService.addInsuranceRelief(reliefData, _companyId!);

      final reliefDate = DateTime.parse(reliefData['date'] as String);
      setState(() {
        _selectedMonth = reliefDate.month;
        _selectedYear = reliefDate.year;
      });
      await _fetchReliefRecords();

      final employee = _employees.firstWhere(
        (emp) => emp['employee_id'].toString() == employeeId,
        orElse: () => {'fullname': 'Unknown'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insurance Relief Saved: ${employee['fullname']}, Premium: ${currencyFormat.format(premium)}, Relief: ${currencyFormat.format(relief)}, ${DateFormat.yMMMd().format(_selectedDate!)}',
          ),
          backgroundColor: Colors.teal[700],
        ),
      );

      _premiumController.clear();
      _percentageController.clear();
      _reliefController.clear();
      setState(() {
        _selectedEmployeeId = null;
        _selectedDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save relief: $e'),
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
              .map((item) => DropdownMenuItem<T>(
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
    bool readOnly = false,
    String? hintText,
    String? prefixText,
    String? suffixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
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
        prefixText: prefixText,
        prefixStyle:
            prefixText != null ? TextStyle(color: Colors.teal[900]) : null,
        suffixText: suffixText,
        suffixStyle:
            suffixText != null ? TextStyle(color: Colors.teal[900]) : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (isNumber && !readOnly) {
          final num = double.tryParse(value);
          if (num == null || num <= 0)
            return 'Please enter a valid positive amount';
          if (label.contains('Premium') && num > 100000) {
            return 'Premium cannot exceed KES 100,000';
          }
          if (label.contains('Percentage') && (num < 0 || num > 100)) {
            return 'Percentage must be between 0 and 100';
          }
        }
        return null;
      },
      style: TextStyle(color: Colors.grey[800]),
    );
  }

  // Build Date Picker: Creates a date picker for relief date
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relief Date',
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Insurance Relief - $_companyName'),
            backgroundColor: Colors.teal[800],
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  _fetchEmployees();
                  _fetchReliefRecords();
                },
                tooltip: 'Refresh Data',
              ),
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => print('Notifications tapped'),
                tooltip: 'Notifications',
              ),
              IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () => print('Profile tapped'),
                tooltip: 'Profile',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
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
                            style: TextStyle(
                                color: Colors.teal[900], fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _fetchEmployees();
                              _fetchReliefRecords();
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
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Relief Form
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
                                    _buildDropdown<String>(
                                      label: 'Employee',
                                      value: _selectedEmployeeId,
                                      items: _isLoadingEmployees ||
                                              _employees.isEmpty
                                          ? []
                                          : _employees
                                              .map((e) =>
                                                  e['employee_id'].toString())
                                              .toList(),
                                      itemBuilder: (id) {
                                        final employee = _employees.firstWhere(
                                          (emp) =>
                                              emp['employee_id'].toString() ==
                                              id,
                                          orElse: () => {'fullname': 'Unknown'},
                                        );
                                        return '${employee['employee_id']} - ${employee['fullname']}';
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedEmployeeId = value;
                                        });
                                      },
                                      isEnabled: !_isLoadingEmployees &&
                                          _employees.isNotEmpty,
                                    ),
                                    if (_isLoadingEmployees)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: CircularProgressIndicator(
                                            color: Colors.teal[700]),
                                      ),
                                    if (_employees.isEmpty &&
                                        !_isLoadingEmployees)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'No employees available for this company',
                                          style:
                                              TextStyle(color: Colors.red[700]),
                                        ),
                                      ),
                                    const SizedBox(height: 16.0),
                                    // Premium Field
                                    _buildTextField(
                                      controller: _premiumController,
                                      label: 'Premium Amount',
                                      isNumber: true,
                                      hintText: 'e.g., 10000.00',
                                      prefixText: 'KES ',
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Percentage Field
                                    _buildTextField(
                                      controller: _percentageController,
                                      label: 'Relief Percentage',
                                      isNumber: true,
                                      hintText: 'e.g., 15',
                                      suffixText: '%',
                                    ),
                                    const SizedBox(height: 16.0),
                                    // Relief Field
                                    _buildTextField(
                                      controller: _reliefController,
                                      label: 'Calculated Relief',
                                      readOnly: true,
                                      prefixText: 'KES ',
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
                                                _isLoadingReliefs ||
                                                _employees.isEmpty
                                            ? null
                                            : _submitForm,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16.0),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Save Relief',
                                          style: TextStyle(fontSize: 16),
                                        ),
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
          ),
          // Filters and Relief Records Table
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
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<int>(
                              label: 'Month',
                              value: _selectedMonth,
                              items: List.generate(12, (index) => index + 1),
                              itemBuilder: (month) => DateFormat('MMMM')
                                  .format(DateTime(_selectedYear, month)),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value!;
                                  _fetchReliefRecords();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<int>(
                              label: 'Year',
                              value: _selectedYear,
                              items: List.generate(
                                  10, (index) => DateTime.now().year - index),
                              itemBuilder: (year) => year.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value!;
                                  _fetchReliefRecords();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by Employee Name',
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
                          hintText: 'Search by employee name',
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
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isLoadingReliefs
                      ? Center(
                          child: CircularProgressIndicator(
                              color: Colors.teal[700]))
                      : _filteredReliefRecords.isEmpty
                          ? Center(
                              child: Text(
                                'No relief records for selected filters',
                                style: TextStyle(
                                    color: Colors.teal[900], fontSize: 16),
                              ),
                            )
                          : PaginatedDataTable(
                              header: Text('Insurance Relief Records',
                                  style: TextStyle(color: Colors.teal[900])),
                              columns: [
                                DataColumn(
                                  label: Text('Company',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal[900],
                                          fontSize: 14)),
                                ),
                                DataColumn(
                                  label: Text('Employee',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal[900],
                                          fontSize: 14)),
                                ),
                                DataColumn(
                                  label: Text('Premium (KES)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal[900],
                                          fontSize: 14)),
                                ),
                                DataColumn(
                                  label: Text('Percentage (%)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal[900],
                                          fontSize: 14)),
                                ),
                                DataColumn(
                                  label: Text('Relief (KES)',
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
                              source: ReliefRecordsDataSource(
                                  _filteredReliefRecords,
                                  _employees,
                                  _companyName ?? 'Unknown'),
                              rowsPerPage: 5,
                              columnSpacing: 16,
                              dataRowHeight: 60,
                              headingRowColor:
                                  MaterialStateProperty.all(Colors.teal[100]),
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

// ReliefRecordsDataSource: Data source for PaginatedDataTable
class ReliefRecordsDataSource extends DataTableSource {
  final List<Map<String, dynamic>> reliefRecords;
  final List<Map<String, dynamic>> employees;
  final String companyName;
  final NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: 'KES ', decimalDigits: 2);

  ReliefRecordsDataSource(this.reliefRecords, this.employees, this.companyName);

  @override
  DataRow getRow(int index) {
    final record = reliefRecords[index];
    final employee = employees.firstWhere(
      (emp) =>
          emp['employee_id'].toString() == record['employee_id'].toString(),
      orElse: () => {'fullname': 'Unknown Employee'},
    );
    final dateStr = record['date'] != null
        ? DateFormat.yMMMd().format(DateTime.parse(record['date']))
        : 'N/A';
    return DataRow(cells: [
      DataCell(Text(companyName, style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(employee['fullname'] ?? 'Unknown',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(
          currencyFormat.format(record['premium_amount']?.toDouble() ?? 0.0),
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(
          '${record['relief_percentage']?.toStringAsFixed(2) ?? 'N/A'}%',
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(
          currencyFormat.format(record['relief_amount']?.toDouble() ?? 0.0),
          style: TextStyle(color: Colors.grey[800]))),
      DataCell(Text(dateStr, style: TextStyle(color: Colors.grey[800]))),
    ]);
  }

  @override
  int get rowCount => reliefRecords.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
