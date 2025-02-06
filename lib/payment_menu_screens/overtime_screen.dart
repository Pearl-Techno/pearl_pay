import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services.dart'; // Assuming this is where ApiService is defined

class OvertimeScreen extends StatefulWidget {
  @override
  _OvertimeScreenState createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  String? selectedEmployee;
  DateTime? selectedDate;
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController minutesController = TextEditingController();
  String? selectedRate;
  final TextEditingController filterController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final List<String> rates = ['1.5%', '3%'];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> overtimeRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];

  bool isLoading = false;
  final http.Client _httpClient = http.Client();
  final ApiService apiService = ApiService(client: http.Client());

  int currentPage = 0;
  final int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _fetchOvertimeRecords();
    filterController.addListener(_updateFilteredRecords);
  }

  @override
  void dispose() {
    _httpClient.close();
    filterController.removeListener(_updateFilteredRecords);
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => isLoading = true);
    try {
      employees = await apiService.getEmployeeList();
    } catch (e) {
      _showError('Error fetching employees: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOvertimeRecords() async {
    setState(() => isLoading = true);
    try {
      overtimeRecords = await apiService.getOvertimeList();
      _updateFilteredRecords();
    } catch (e) {
      _showError('Error fetching overtime records: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateFilteredRecords() {
    final filter = filterController.text.toLowerCase();
    setState(() {
      filteredRecords = overtimeRecords.where((record) {
        final employeeId =
            record['employee_id']?.toString().toLowerCase() ?? '';
        final fullname = record['fullname']?.toString().toLowerCase() ?? '';
        final dateOvertime =
            record['date_overtime']?.toString().toLowerCase() ?? '';
        return employeeId.contains(filter) ||
            fullname.contains(filter) ||
            dateOvertime.contains(filter);
      }).toList();
      currentPage = 0;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.teal),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showAddOvertimeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Overtime'),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedEmployee,
                    onChanged: (value) =>
                        setState(() => selectedEmployee = value),
                    items: employees
                        .map((e) => DropdownMenuItem<String>(
                              value: e['id'].toString(),
                              child: Text(
                                  '${e['employee_id']} - ${e['fullname']}'),
                            ))
                        .toList(),
                    decoration: InputDecoration(
                      labelText: 'Select Employee',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Please select an employee' : null,
                  ),
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Select Date',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today, color: Colors.teal),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    validator: (value) =>
                        selectedDate == null ? 'Please select a date' : null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: hoursController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Hours', border: OutlineInputBorder()),
                          validator: (value) =>
                              _validateNumber(value, 'Please enter hours'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Minutes',
                              border: OutlineInputBorder()),
                          validator: (value) =>
                              _validateNumber(value, 'Please enter minutes'),
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedRate,
                    onChanged: (value) => setState(() => selectedRate = value),
                    items: rates
                        .map((rate) =>
                            DropdownMenuItem(value: rate, child: Text(rate)))
                        .toList(),
                    decoration: InputDecoration(
                      labelText: 'Rate (%)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Please select a rate' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (Form.of(context).validate()) {
                  await _addOvertimeRecord();
                  Navigator.pop(context);
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  String? _validateNumber(String? value, String message) {
    if (value == null ||
        value.isEmpty ||
        !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return message;
    }
    return null;
  }

  Future<void> _addOvertimeRecord() async {
    try {
      double totalMinutes = double.parse(hoursController.text) * 60 +
          double.parse(minutesController.text);
      double grossPay = double.tryParse(employees.firstWhere(
                  (e) => e['id'].toString() == selectedEmployee)['gross_pay'] ??
              '0') ??
          0;
      double rate = double.parse(selectedRate!.replaceAll('%', '')) / 100;
      double amount = (grossPay / 60) * totalMinutes * rate;

      Map<String, dynamic> newRecord = {
        'employee_id': selectedEmployee,
        'hours': hoursController.text,
        'minutes': minutesController.text,
        'rate': selectedRate,
        'date_overtime': selectedDate!.toIso8601String(),
        'amount': amount.toStringAsFixed(2),
      };

      await apiService.addOvertime(newRecord);
      _showError('Overtime added successfully');
      _fetchOvertimeRecords();
    } catch (e) {
      _showError('Failed to add overtime: $e');
    }
  }

  Widget _buildOvertimeTable() {
    int start = currentPage * itemsPerPage;
    int end = start + itemsPerPage;
    final currentRecords = filteredRecords.sublist(
        start, end > filteredRecords.length ? filteredRecords.length : end);

    if (filteredRecords.isEmpty) {
      return Center(child: Text('No overtime records available'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Employee ID')),
          DataColumn(label: Text('Full Name')),
          DataColumn(label: Text('Hours')),
          DataColumn(label: Text('Rate')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Amount')),
        ],
        rows: currentRecords
            .map((record) => DataRow(
                  cells: [
                    DataCell(Text(record['id']?.toString() ?? '')),
                    DataCell(Text(record['employee_id']?.toString() ?? '')),
                    DataCell(Text(record['fullname'] ?? '')),
                    DataCell(Text(
                        '${record['hours'] ?? '0'}h ${record['minutes'] ?? '0'}m')),
                    DataCell(Text(record['rate'] ?? '')),
                    DataCell(Text(DateFormat('yyyy-MM-dd')
                        .format(DateTime.parse(record['date_overtime'])))),
                    DataCell(Text(record['amount'] ?? '0')),
                  ],
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Overtime Records', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: filterController,
                    decoration: InputDecoration(
                      labelText: 'Filter by name, date, or keywords',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _showAddOvertimeDialog,
                  backgroundColor: Colors.teal,
                  mini: true,
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _buildOvertimeTable(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentPage > 0
                      ? () => setState(() => currentPage--)
                      : null,
                  child: Text('Previous'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
                Text(
                    'Page ${currentPage + 1} of ${(filteredRecords.length / itemsPerPage).ceil()}'),
                ElevatedButton(
                  onPressed:
                      (currentPage + 1) * itemsPerPage < filteredRecords.length
                          ? () => setState(() => currentPage++)
                          : null,
                  child: Text('Next'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
