import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class OvertimeScreen extends StatefulWidget {
  @override
  _OvertimeScreenState createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  String? selectedEmployee;
  String? selectedCompany; // For adding overtime
  String? filterCompany; // For filtering table
  DateTime? selectedDate;
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController monthlyHoursController =
      TextEditingController(text: '208'); // Default to 208
  final TextEditingController filterController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> employees = [];
  List<String> companyNames = ['All Companies'];
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
      employees = await apiService.getEmployeeList();
      setState(() {
        companyNames = ['All Companies'] +
            employees
                .map((e) => e['company_name'] as String?)
                .where((name) => name != null && name.isNotEmpty)
                .toSet()
                .cast<String>()
                .toList();
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
      overtimeRecords = await apiService.getOvertimeList();
      for (var record in overtimeRecords) {
        final employee = employees.firstWhere(
          (e) =>
              e['employee_id'].toString() == record['employee_id'].toString(),
          orElse: () => {'company_name': 'Unknown', 'fullname': 'Unknown'},
        );
        record['company_name'] = employee['company_name'] ?? 'Unknown';
        record['fullname'] = employee['fullname'] ?? 'Unknown';
      }
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
        final dateOvertime = DateTime.tryParse(record['date_overtime'] ?? '');
        final employeeId =
            record['employee_id']?.toString().toLowerCase() ?? '';
        final fullname = record['fullname']?.toString().toLowerCase() ?? '';
        final companyName =
            record['company_name']?.toString().toLowerCase() ?? '';
        final matchesMonth =
            dateOvertime != null && dateOvertime.month == _selectedMonth;
        final matchesYear =
            dateOvertime != null && dateOvertime.year == _selectedYear;
        final matchesCompany = filterCompany == null ||
            filterCompany == 'All Companies' ||
            record['company_name'] == filterCompany;
        final matchesKeyword = employeeId.contains(filter) ||
            fullname.contains(filter) ||
            (record['date_overtime']?.toLowerCase() ?? '').contains(filter) ||
            companyName.contains(filter);
        return matchesMonth && matchesYear && matchesCompany && matchesKeyword;
      }).toList();
      currentPage = 0;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            message.contains('successfully') ? Colors.teal[700] : Colors.red,
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
    double? selectedRateMultiplier; // Store the selected rate multiplier
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

            // Calculate overtime amount whenever inputs change
            void calculateOvertime() {
              try {
                if (_formKey.currentState == null ||
                    !_formKey.currentState!.validate()) {
                  setDialogState(() {
                    calculatedAmount = null;
                  });
                  return;
                }

                double hours = double.tryParse(hoursController.text) ?? 0;
                double minutes = double.tryParse(minutesController.text) ?? 0;
                double totalHours =
                    hours + (minutes / 60); // Convert minutes to hours

                if (totalHours <= 0 || selectedRateMultiplier == null) {
                  setDialogState(() {
                    calculatedAmount = null;
                  });
                  return;
                }

                double monthlyHours =
                    double.tryParse(monthlyHoursController.text) ?? 0;
                if (monthlyHours <= 0) {
                  setDialogState(() {
                    calculatedAmount = null;
                  });
                  return;
                }

                double basicPay = double.tryParse(employees.firstWhere(
                            (e) => e['id'].toString() == dialogSelectedEmployee,
                            orElse: () => {'basic': '0'})['basic'] ??
                        '0') ??
                    0;

                if (basicPay <= 0) {
                  setDialogState(() {
                    calculatedAmount = null;
                  });
                  return;
                }

                double hourlyRate = basicPay / monthlyHours;
                double amount =
                    hourlyRate * selectedRateMultiplier! * totalHours;

                setDialogState(() {
                  calculatedAmount = amount;
                });
              } catch (e) {
                setDialogState(() {
                  calculatedAmount = null;
                });
              }
            }

            // Add listeners to recalculate when inputs change
            hoursController.addListener(calculateOvertime);
            minutesController.addListener(calculateOvertime);
            monthlyHoursController.addListener(calculateOvertime);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Add New Overtime',
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
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: dialogSelectedCompany,
                          onChanged: (value) {
                            setDialogState(() {
                              dialogSelectedCompany = value;
                              dialogSelectedEmployee = null;
                              employeeId = null;
                              calculatedAmount = null;
                            });
                            setState(() {
                              selectedCompany = value;
                              selectedEmployee = null;
                            });
                            calculateOvertime();
                          },
                          items: companyNames
                              .where((company) => company != 'All Companies')
                              .map((company) => DropdownMenuItem<String>(
                                    value: company,
                                    child: Text(company,
                                        style:
                                            TextStyle(color: Colors.teal[900])),
                                  ))
                              .toList(),
                          decoration: InputDecoration(
                            labelText: 'Select Company',
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
                          ),
                          validator: (value) =>
                              value == null ? 'Please select a company' : null,
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.teal[700]),
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
                                            orElse: () => {
                                                  'employee_id': null
                                                })['employee_id']
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
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic)),
                                    enabled: false,
                                  )
                                ]
                              : filteredEmployees
                                  .map((e) => DropdownMenuItem<String>(
                                        value: e['id'].toString(),
                                        child: Text(
                                            '${e['employee_id']} - ${e['fullname']}',
                                            style: TextStyle(
                                                color: Colors.teal[900])),
                                      ))
                                  .toList(),
                          decoration: InputDecoration(
                            labelText: 'Select Employee',
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
                          ),
                          validator: (value) => value == null
                              ? 'Please select an employee'
                              : null,
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.teal[700]),
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
                            suffixIcon: IconButton(
                              icon: Icon(Icons.calendar_today,
                                  color: Colors.teal[700]),
                              onPressed: () => _selectDate(context),
                            ),
                          ),
                          validator: (value) => selectedDate == null
                              ? 'Please select a date'
                              : null,
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
                          ),
                          validator: (value) => _validateNumber(
                              value, 'Please enter total monthly hours'),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: hoursController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Overtime Hours',
                                  labelStyle:
                                      TextStyle(color: Colors.teal[900]),
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
                                ),
                                validator: (value) => _validateNumber(
                                    value, 'Please enter overtime hours'),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: minutesController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Overtime Minutes',
                                  labelStyle:
                                      TextStyle(color: Colors.teal[900]),
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
                          ),
                          validator: (value) =>
                              value == null ? 'Please select a rate' : null,
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.teal[700]),
                        ),
                        SizedBox(height: 16),
                        if (calculatedAmount != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calculated Overtime Amount: KES ${calculatedAmount!.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: Colors.teal[900],
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
                    // Remove listeners when dialog is closed
                    hoursController.removeListener(calculateOvertime);
                    minutesController.removeListener(calculateOvertime);
                    monthlyHoursController.removeListener(calculateOvertime);
                    Navigator.pop(context);
                  },
                  child:
                      Text('Cancel', style: TextStyle(color: Colors.teal[700])),
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

                      // Convert minutes to hours before saving
                      double hours = double.tryParse(hoursController.text) ?? 0;
                      double minutes =
                          double.tryParse(minutesController.text) ?? 0;
                      double totalHours = hours + (minutes / 60);

                      await _addOvertimeRecord(
                        employeeId!,
                        totalHours.toStringAsFixed(2),
                        selectedRateMultiplier!,
                        calculatedAmount!,
                      );

                      // Remove listeners when dialog is closed
                      hoursController.removeListener(calculateOvertime);
                      minutesController.removeListener(calculateOvertime);
                      monthlyHoursController.removeListener(calculateOvertime);
                      Navigator.pop(context);
                    } else {
                      _showError(
                          'Please ensure all fields are valid and amount is calculated.');
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
      // Prepare the overtime record using employee_id from employee data
      Map<String, dynamic> newRecord = {
        'employee_id': employeeId,
        'company_name': selectedCompany,
        'hours': totalHours, // Save total hours (including converted minutes)
        'rate': rateMultiplier.toString(), // Send as "1.5" instead of "1.5x"
        'date_overtime': selectedDate!.toIso8601String(),
        'amount': calculatedAmount.toStringAsFixed(2),
      };

      // Send the record to the backend
      await apiService.addOvertime(newRecord);
      _showError('Overtime added successfully');
      _fetchOvertimeRecords();

      // Reset the form
      setState(() {
        selectedEmployee = null;
        selectedCompany = null;
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

  Widget _buildOvertimeTable() {
    int start = currentPage * itemsPerPage;
    int end = start + itemsPerPage;
    final currentRecords = filteredRecords.sublist(
        start, end > filteredRecords.length ? filteredRecords.length : end);
    if (filteredRecords.isEmpty) {
      return Center(
        child: Text(
          'No overtime records available for the selected filters',
          style: TextStyle(color: Colors.teal[900], fontSize: 16),
        ),
      );
    }
    return ConstrainedBox(
      constraints:
          BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          dataRowHeight: 60,
          headingRowColor: MaterialStateProperty.all(Colors.teal[100]),
          columns: [
            DataColumn(
                label: Text('ID',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                        fontSize: 14))),
            DataColumn(
                label: Text('Employee ID',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                        fontSize: 14))),
            DataColumn(
                label: Text('Full Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                        fontSize: 14))),
            DataColumn(
                label: Text('Company Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                        fontSize: 14))),
            DataColumn(
                label: Text('Hours',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                        fontSize: 14))),
            DataColumn(
                label: Text('Rate',
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
            DataColumn(
                label: Text('Amount',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                        fontSize: 14))),
          ],
          rows: currentRecords.map((record) {
            return DataRow(
              cells: [
                DataCell(Text(record['id']?.toString() ?? '',
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text(record['employee_id']?.toString() ?? '',
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text(record['fullname'] ?? '',
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text(record['company_name'] ?? 'N/A',
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text('${record['hours'] ?? '0'}h',
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text('${record['rate'] ?? ''}x',
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text(
                    DateFormat('yyyy-MM-dd')
                        .format(DateTime.parse(record['date_overtime'])),
                    style: TextStyle(color: Colors.grey[800]))),
                DataCell(Text(record['amount'] ?? '0',
                    style: TextStyle(color: Colors.grey[800]))),
              ],
            );
          }).toList(),
        ),
      ),
    );
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
                child: Text(itemBuilder(item),
                    style: TextStyle(color: Colors.teal[900]))))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Overtime Payment',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          print('Profile tapped');
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDropdown(
                            value: _selectedMonth,
                            items: List.generate(12, (index) => index + 1),
                            itemBuilder: (month) => DateFormat('MMMM')
                                .format(DateTime(_selectedYear, month)),
                            onChanged: (value) {
                              setState(() {
                                _selectedMonth = value!;
                                _updateFilteredRecords();
                              });
                            },
                          ),
                          _buildDropdown(
                            value: _selectedYear,
                            items: List.generate(
                                10, (index) => DateTime.now().year - index),
                            itemBuilder: (year) => year.toString(),
                            onChanged: (value) {
                              setState(() {
                                _selectedYear = value!;
                                _updateFilteredRecords();
                              });
                            },
                          ),
                          _buildDropdown(
                            value: filterCompany ?? 'All Companies',
                            items: companyNames,
                            itemBuilder: (company) => company,
                            onChanged: (value) {
                              setState(() {
                                filterCompany = value;
                                _updateFilteredRecords();
                              });
                            },
                          ),
                          ElevatedButton(
                            onPressed: _fetchOvertimeRecords,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: filterController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, ID, or company',
                          prefixIcon:
                              Icon(Icons.search, color: Colors.teal[700]),
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
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]))
                    : Card(
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
                    onPressed: currentPage > 0
                        ? () => setState(() => currentPage--)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Previous'),
                  ),
                  Text(
                    'Page ${currentPage + 1} of ${(filteredRecords.length / itemsPerPage).ceil()}',
                    style: TextStyle(color: Colors.teal[900]),
                  ),
                  ElevatedButton(
                    onPressed: (currentPage + 1) * itemsPerPage <
                            filteredRecords.length
                        ? () => setState(() => currentPage++)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
