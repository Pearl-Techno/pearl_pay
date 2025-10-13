import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class OvertimeScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;
  const OvertimeScreen({
    Key? key,
    required this.apiService,
    required this.user,
  }) : super(key: key);

  @override
  _OvertimeScreenState createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  String? selectedEmployee;
  String? selectedCompany;
  String? filterCompany;
  DateTime? selectedDate;
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController monthlyHoursController = TextEditingController(text: '208');
  final TextEditingController filterController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  int? _selectedMonth; // Nullable for "Show All"
  int? _selectedYear; // Nullable for "Show All"
  List<Map<String, dynamic>> employees = [];
  List<String> companyNames = [];
  List<Map<String, dynamic>> overtimeRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];
  bool isLoading = false;
  int currentPage = 0;
  final int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    selectedCompany = widget.user.companyName;
    filterCompany = widget.user.companyName;
    companyNames = [widget.user.companyName ?? 'Unknown'];
    _selectedMonth = null;
    _selectedYear = null;
    _fetchEmployees();
    _fetchOvertimeRecords();
    filterController.addListener(_updateFilteredRecords);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Managing overtime for ${widget.user.companyName ?? 'Company'}, ${widget.user.username ?? 'User'}!'),
          backgroundColor: Colors.teal[700],
        ),
      );
    });
  }

  @override
  void dispose() {
    filterController.removeListener(_updateFilteredRecords);
    filterController.dispose();
    hoursController.dispose();
    minutesController.dispose();
    monthlyHoursController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => isLoading = true);
    try {
      employees = await widget.apiService.getEmployeeList(widget.user.companyId);
      setState(() {
        companyNames = [widget.user.companyName ?? 'Unknown'];
      });
    } catch (e) {
      _showError('Error fetching employees: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchOvertimeRecords() async {
    setState(() => isLoading = true);
    try {
      overtimeRecords = await widget.apiService.getOvertimeList(
        widget.user.companyId.toString(),
        month: _selectedMonth,
        year: _selectedYear,
      );
      print('Fetched Overtime Records: $overtimeRecords');
      for (var record in overtimeRecords) {
        final employee = employees.firstWhere(
          (e) => e['employee_id'].toString() == record['employee_id'].toString(),
          orElse: () => {'company_name': widget.user.companyName, 'fullname': 'Unknown'},
        );
        record['company_name'] = employee['company_name'] ?? widget.user.companyName;
        record['fullname'] = employee['fullname'] ?? record['fullname'] ?? 'Unknown';
        if (record['date_overtime'] != null && DateTime.tryParse(record['date_overtime']) == null) {
          print('Invalid date_overtime format: ${record['date_overtime']}');
          record['date_overtime'] = null;
        }
      }
      _updateFilteredRecords();
      if (filteredRecords.isEmpty && overtimeRecords.isNotEmpty) {
        _showError(
            'Records fetched but filtered out. API may be returning incorrect data for selected month. Try "Show All" or select May.');
      }
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
        final dateOvertime = record['date_overtime'] != null ? DateTime.tryParse(record['date_overtime']) : null;
        final employeeId = record['employee_id']?.toString().toLowerCase() ?? '';
        final fullname = record['fullname']?.toString().toLowerCase() ?? '';
        final companyName = record['company_name']?.toString().toLowerCase() ?? '';
        final matchesMonth = _selectedMonth == null || (dateOvertime != null && dateOvertime.month == _selectedMonth);
        final matchesYear = _selectedYear == null || (dateOvertime != null && dateOvertime.year == _selectedYear);
        final matchesKeyword = employeeId.contains(filter) ||
            fullname.contains(filter) ||
            (record['date_overtime']?.toLowerCase() ?? '').contains(filter) ||
            companyName.contains(filter);
        print('Record: $record, MatchesMonth: $matchesMonth, MatchesYear: $matchesYear, MatchesKeyword: $matchesKeyword');
        return matchesMonth && matchesYear && matchesKeyword;
      }).toList();
      print('Filtered Records: $filteredRecords');
      currentPage = 0;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('successfully') ? Colors.teal[700] : Colors.red,
      ),
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
            colorScheme: ColorScheme.light(primary: Colors.teal[700]!),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal[700]),
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
    final _formKey = GlobalKey<FormState>();
    double? calculatedAmount;
    double? selectedRateMultiplier;
    String? employeeId;

    showDialog(
      context: context,
      builder: (context) {
        String? dialogSelectedCompany = selectedCompany;
        String? dialogSelectedEmployee = selectedEmployee;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredEmployees = employees
                .where((e) => e['company_name'] == dialogSelectedCompany)
                .toList();

            void calculateOvertime() {
              if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final hoursText = hoursController.text;
              final minutesText = minutesController.text;
              final monthlyHoursText = monthlyHoursController.text;

              final hours = double.tryParse(hoursText) ?? 0.0;
              final minutes = double.tryParse(minutesText) ?? 0.0;
              final monthlyHours = double.tryParse(monthlyHoursText) ?? 208.0;

              if (hours <= 0 || minutes < 0 || minutes >= 60 || monthlyHours <= 0) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final empId = dialogSelectedEmployee;
              if (empId == null) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final employee = employees.firstWhere(
                (e) => e['id'].toString() == empId,
                orElse: () => {'basic': 0},
              );

              double basicPay = 0.0;
              if (employee['basic'] is num) {
                basicPay = (employee['basic'] as num).toDouble();
              } else if (employee['basic'] is String) {
                basicPay = double.tryParse(employee['basic']) ?? 0.0;
              }

              if (basicPay <= 0 || selectedRateMultiplier == null) {
                setDialogState(() => calculatedAmount = null);
                return;
              }

              final hourlyRate = basicPay / monthlyHours;
              final totalHours = hours + (minutes / 60);
              final amount = hourlyRate * selectedRateMultiplier! * totalHours;

              setDialogState(() {
                calculatedAmount = amount;
              });
            }

            hoursController.addListener(calculateOvertime);
            minutesController.addListener(calculateOvertime);
            monthlyHoursController.addListener(calculateOvertime);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Add New Overtime', style: TextStyle(color: Colors.teal[900])),
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
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          readOnly: true,
                          initialValue: widget.user.companyName ?? 'Unknown',
                          decoration: InputDecoration(
                            labelText: 'Company',
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
                          ),
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: dialogSelectedEmployee,
                          onChanged: dialogSelectedCompany == null
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    dialogSelectedEmployee = value;
                                    employeeId = employees
                                        .firstWhere(
                                            (e) => e['id'].toString() == value,
                                            orElse: () => {'employee_id': null})['employee_id']
                                        ?.toString();
                                  });
                                  setState(() {
                                    selectedEmployee = value;
                                  });
                                  calculateOvertime();
                                },
                          items: filteredEmployees.isEmpty
                              ? [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('No employees available',
                                        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                    enabled: false,
                                  )
                                ]
                              : filteredEmployees
                                  .map((e) => DropdownMenuItem<String>(
                                        value: e['id'].toString(),
                                        child: Text('${e['employee_id']} - ${e['fullname']}',
                                            style: TextStyle(color: Colors.teal[900])),
                                      ))
                                  .toList(),
                          decoration: InputDecoration(
                            labelText: 'Select Employee',
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
                          ),
                          validator: (value) => value == null ? 'Please select an employee' : null,
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Select Date',
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
                            suffixIcon: IconButton(
                              icon: Icon(Icons.calendar_today, color: Colors.teal[700]),
                              onPressed: () => _selectDate(context),
                            ),
                          ),
                          validator: (value) => selectedDate == null ? 'Please select a date' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: monthlyHoursController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Total Monthly Hours to be Worked',
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
                          ),
                          validator: (value) => _validateNumber(value, 'Please enter total monthly hours'),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: hoursController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Hours',
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
                                ),
                                validator: (value) => _validateNumber(value, 'Please enter overtime hours'),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: minutesController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Minutes',
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
                                ),
                                validator: (value) => _validateNumber(
                                    value, 'Please enter overtime minutes'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<double>(
                          value: selectedRateMultiplier,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedRateMultiplier = value;
                            });
                            calculateOvertime();
                          },
                          items: [
                            DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                            DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                            DropdownMenuItem(value: 3.0, child: Text('3.0x')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Select Rate Multiplier',
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
                          ),
                          validator: (value) => value == null ? 'Please select a rate' : null,
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
                        ),
                        SizedBox(height: 16),
                        if (calculatedAmount != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calculated Overtime Amount: KES ${calculatedAmount!.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: Colors.teal[600],
                                    fontWeight: FontWeight.bold),
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
                  onPressed: () {
                    hoursController.removeListener(calculateOvertime);
                    minutesController.removeListener(calculateOvertime);
                    monthlyHoursController.removeListener(calculateOvertime);
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: TextStyle(color: Colors.teal[700])),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate() &&
                        calculatedAmount != null &&
                        selectedRateMultiplier != null) {
                      setState(() {
                        selectedCompany = dialogSelectedCompany;
                        selectedEmployee = dialogSelectedEmployee;
                      });

                      double hours = double.tryParse(hoursController.text) ?? 0.0;
                      double minutes = double.tryParse(minutesController.text) ?? 0.0;
                      double totalHours = hours + (minutes / 60);

                      await _addOvertimeRecord(
                        employeeId!,
                        totalHours.toStringAsFixed(2),
                        selectedRateMultiplier!,
                        calculatedAmount!,
                      );

                      hoursController.removeListener(calculateOvertime);
                      minutesController.removeListener(calculateOvertime);
                      monthlyHoursController.removeListener(calculateOvertime);
                      Navigator.pop(context);
                    } else {
                      _showError('Please ensure all fields are valid and amount is calculated.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _validateNumber(String? value, String message) {
    if (value == null || value.isEmpty) {
      return message;
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return 'Please enter a valid number';
    }
    if (message.contains('minutes') && number >= 60) {
      return 'Minutes must be less than 60';
    }
    return null;
  }

  Future<void> _addOvertimeRecord(
    String employeeId,
    String totalHours,
    double rateMultiplier,
    double calculatedAmount,
  ) async {
    try {
      Map<String, dynamic> newRecord = {
        'employee_id': employeeId,
        'company_name': selectedCompany,
        'hours': totalHours,
        'rate': rateMultiplier.toString(),
        'date_overtime': selectedDate!.toIso8601String(),
        'amount': calculatedAmount.toStringAsFixed(2),
      };

      await widget.apiService.addOvertime(newRecord, widget.user.companyId);
      _showError('Overtime added successfully');
      _fetchOvertimeRecords();

      setState(() {
        selectedEmployee = null;
        selectedCompany = widget.user.companyName;
        selectedDate = null;
        hoursController.clear();
        minutesController.clear();
        monthlyHoursController.text = '208';
        _dateController.clear();
      });
    } catch (e) {
      _showError('Failed to add overtime: $e');
    }
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

  Widget _buildOvertimeTable() {
    int start = currentPage * itemsPerPage;
    int end = start + itemsPerPage;
    final currentRecords = filteredRecords.sublist(
        start, end > filteredRecords.length ? filteredRecords.length : end);
    if (filteredRecords.isEmpty) {
      return Center(
        child: Text(
          overtimeRecords.isEmpty
              ? 'No overtime records available'
              : 'No records match the selected filters. Try "Show All" or a different month.',
          style: TextStyle(color: Colors.teal[900], fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          dataRowHeight: 60,
          headingRowColor: MaterialStateProperty.all(Colors.teal[100]),
          columns: [
            DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Company Name', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Hours', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
            DataColumn(label: Text('Amount (KES)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14))),
          ],
          rows: currentRecords.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            return DataRow(
              color: MaterialStateProperty.all(index % 2 == 0 ? Colors.white : Colors.teal[50]),
              cells: [
                DataCell(Text(record['id']?.toString() ?? '', style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(record['employee_id']?.toString() ?? '', style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(record['fullname'] ?? 'Unknown', style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(record['company_name'] ?? 'N/A', style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(
                    '${record['hours'] != null ? (record['hours'] is num ? (record['hours'] as num).toStringAsFixed(2) : record['hours'].toString()) : '0'}h',
                    style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(
                    '${record['rate'] != null ? (record['rate'] is num ? (record['rate'] as num).toStringAsFixed(1) : record['rate'].toString()) : '0'}x',
                    style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(
                    record['date_overtime'] != null
                        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(record['date_overtime']))
                        : 'N/A',
                    style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                DataCell(Text(
                    'KES ${record['amount'] != null ? (record['amount'] is num ? (record['amount'] as num).toStringAsFixed(2) : record['amount'].toString()) : '0'}',
                    style: TextStyle(color: Colors.green[800], fontSize: 14))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String labelText,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text('All $labelText', style: TextStyle(color: Colors.grey[600])),
          ),
          ...items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(itemBuilder(item), style: TextStyle(color: Colors.teal[900])),
              )),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.teal[900], fontSize: 14),
          border: InputBorder.none,
        ),
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Overtime - ${widget.user.username ?? 'User'} (${widget.user.companyName ?? 'Company'})',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
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
                    title: Text('Profile: ${widget.user.username ?? 'User'}'),
                    subtitle: Text('Role: ${widget.user.role} | Company: ${widget.user.companyName ?? 'Company'}'),
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
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                shadowColor: Colors.grey.withOpacity(0.3),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal[50]!, Colors.teal[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business, size: 32, color: Colors.teal[700]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Managing Overtime for ${widget.user.companyName ?? 'Company'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[900],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: 1,
                            child: _buildDropdown(
                              value: _selectedMonth,
                              labelText: 'Month',
                              items: List.generate(12, (index) => index + 1),
                              itemBuilder: (month) => DateFormat('MMM').format(DateTime(2025, month)),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value;
                                  _fetchOvertimeRecords();
                                });
                              },
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: _buildDropdown(
                              value: _selectedYear,
                              labelText: 'Year',
                              items: List.generate(10, (index) => DateTime.now().year - index),
                              itemBuilder: (year) => year.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value;
                                  _fetchOvertimeRecords();
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: _fetchOvertimeRecords,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Text('Refresh', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: filterController,
                        decoration: InputDecoration(
                          hintText: 'Search by ID, name, or date',
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
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: _showAddOvertimeDialog,
                    backgroundColor: Colors.teal[700],
                    mini: true,
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
                    : Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            scrollDirection: Axis.vertical,
                            child: _buildOvertimeTable(),
                          ),
                        ),
                      ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Previous'),
                  ),
                  Text(
                    'Page ${currentPage + 1} of ${(filteredRecords.length / itemsPerPage).ceil()}',
                    style: TextStyle(color: Colors.teal[900]),
                  ),
                  ElevatedButton(
                    onPressed: (currentPage + 1) * itemsPerPage < filteredRecords.length
                        ? () => setState(() => currentPage++) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}