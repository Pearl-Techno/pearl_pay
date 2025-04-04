import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({super.key});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedEmployeeId;
  String? _selectedCompany;
  String? _selectedBenefitType;
  DateTime? _selectedDate;
  late ApiService _apiService;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _benefits = [];
  List<String> _companyNames = ['All Companies'];
  bool _isLoadingEmployees = true;
  bool _isLoadingBenefits = true;
  String? _errorMessage;
  final List<String> _benefitTypes = ['Cash', 'Non-Cash'];

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(client: http.Client());
    _fetchEmployees();
    _fetchBenefits();
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

  Future<void> _fetchBenefits() async {
    setState(() => _isLoadingBenefits = true);

    try {
      final allBenefits = <Map<String, dynamic>>[];
      for (var employee in _employees) {
        final employeeId = employee['employee_id'].toString();
        final benefits = await _apiService.fetchBenefits(
            employeeId, _selectedMonth, _selectedYear);
        allBenefits.addAll(benefits);
      }
      setState(() {
        _benefits = allBenefits;
        _isLoadingBenefits = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load benefits: $e';
        _isLoadingBenefits = false;
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
      final benefitType = _selectedBenefitType!;
      final description = _descriptionController.text;
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final date = _selectedDate ?? DateTime.now();

      final benefitData = {
        'employee_id': employeeId,
        'benefit_type': benefitType,
        'description': description,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(date),
      };

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Adding benefit...'),
              backgroundColor: Colors.teal[700]),
        );

        await _apiService.addBenefit(benefitData);

        final benefitDate = DateTime.parse(benefitData['date'] as String);
        setState(() {
          _selectedMonth = benefitDate.month;
          _selectedYear = benefitDate.year;
        });
        await _fetchBenefits();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Benefit Added: ${_employees.firstWhere((emp) => emp['employee_id'].toString() == employeeId)['fullname']}, $benefitType, $description, KSh $amount, ${DateFormat.yMMMd().format(date)}',
            ),
            backgroundColor: Colors.teal[700],
          ),
        );

        _descriptionController.clear();
        _amountController.clear();
        setState(() {
          _selectedEmployeeId = null;
          _selectedCompany = null;
          _selectedBenefitType = null;
          _selectedDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add benefit: $e'),
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
      appBar: CustomAppBar(
        title: 'Benefits',
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
          child: _isLoadingEmployees || _isLoadingBenefits
              ? Center(
                  child: CircularProgressIndicator(color: Colors.teal[700]),
                )
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.teal[900], fontSize: 16),
                      ),
                    )
                  : Column(
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
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                DropdownButton<int>(
                                  value: _selectedMonth,
                                  items: List.generate(12, (index) => index + 1)
                                      .map((month) => DropdownMenuItem(
                                            value: month,
                                            child: Text(
                                              DateFormat('MMMM').format(
                                                  DateTime(
                                                      _selectedYear, month)),
                                              style: TextStyle(
                                                  color: Colors.teal[900]),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMonth = value!;
                                    });
                                  },
                                  dropdownColor: Colors.white,
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.teal[700]),
                                ),
                                DropdownButton<int>(
                                  value: _selectedYear,
                                  items: List.generate(
                                          10,
                                          (index) =>
                                              DateTime.now().year - index + 1)
                                      .map((year) => DropdownMenuItem(
                                            value: year,
                                            child: Text(year.toString(),
                                                style: TextStyle(
                                                    color: Colors.teal[900])),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedYear = value!;
                                    });
                                  },
                                  dropdownColor: Colors.white,
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.teal[700]),
                                ),
                                ElevatedButton(
                                  onPressed: _fetchBenefits,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text(
                                    'Fetch Benefits',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Expanded(
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Company Dropdown
                                      DropdownButtonFormField<String>(
                                        value: _selectedCompany,
                                        decoration: InputDecoration(
                                          labelText: 'Select Company',
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
                                        ),
                                        items: _companyNames.map((company) {
                                          return DropdownMenuItem(
                                            value: company,
                                            child: Text(company,
                                                style: TextStyle(
                                                    color: Colors.teal[900])),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedCompany = value;
                                            _selectedEmployeeId = null;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Please select a company';
                                          }
                                          return null;
                                        },
                                        dropdownColor: Colors.white,
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: Colors.teal[700]),
                                      ),
                                      const SizedBox(height: 16.0),

                                      // Employee Dropdown
                                      DropdownButtonFormField<String>(
                                        value: _selectedEmployeeId,
                                        decoration: InputDecoration(
                                          labelText: 'Select Employee',
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
                                        ),
                                        items: _employees
                                            .where((employee) =>
                                                _selectedCompany == null ||
                                                _selectedCompany ==
                                                    'All Companies' ||
                                                employee['company_name'] ==
                                                    _selectedCompany)
                                            .map((employee) {
                                          return DropdownMenuItem(
                                            value: employee['employee_id']
                                                .toString(),
                                            child: Text(
                                                employee['fullname'] ??
                                                    'Unknown',
                                                style: TextStyle(
                                                    color: Colors.teal[900])),
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
                                        dropdownColor: Colors.white,
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: Colors.teal[700]),
                                      ),
                                      const SizedBox(height: 16.0),

                                      // Benefit Type Dropdown
                                      DropdownButtonFormField<String>(
                                        value: _selectedBenefitType,
                                        decoration: InputDecoration(
                                          labelText: 'Benefit Type',
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
                                        ),
                                        items: _benefitTypes.map((type) {
                                          return DropdownMenuItem(
                                            value: type,
                                            child: Text(type,
                                                style: TextStyle(
                                                    color: Colors.teal[900])),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedBenefitType = value;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Please select a benefit type';
                                          }
                                          return null;
                                        },
                                        dropdownColor: Colors.white,
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: Colors.teal[700]),
                                      ),
                                      const SizedBox(height: 16.0),

                                      // Description Field
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
                                              'e.g., Company Car, Lunch, etc.',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[600]),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a description';
                                          }
                                          return null;
                                        },
                                        style:
                                            TextStyle(color: Colors.grey[800]),
                                      ),
                                      const SizedBox(height: 16.0),

                                      // Amount Field
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
                                          hintText: 'e.g., 10000.00',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[600]),
                                          prefixText: 'KSh ',
                                          prefixStyle: TextStyle(
                                              color: Colors.teal[900]),
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
                                        style:
                                            TextStyle(color: Colors.grey[800]),
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
                                                  ? Colors.grey[600]
                                                  : Colors.teal[900],
                                              fontSize: 16,
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _selectDate(context),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal[700],
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
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
                                            backgroundColor: Colors.teal[700],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16.0),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
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
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Expanded(
                          child: _benefits.isEmpty
                              ? Center(
                                  child: Text(
                                    'No benefits recorded yet',
                                    style: TextStyle(
                                        color: Colors.teal[900], fontSize: 16),
                                  ),
                                )
                              : Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.teal[50]!
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: MediaQuery.of(context)
                                                  .size
                                                  .width -
                                              32,
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columnSpacing: 16,
                                            dataRowHeight: 60,
                                            headingRowColor:
                                                MaterialStateProperty.all(
                                                    Colors.teal[100]),
                                            columns: [
                                              DataColumn(
                                                  label: Text('Employee',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.teal[900],
                                                          fontSize: 14))),
                                              DataColumn(
                                                  label: Text('Type',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.teal[900],
                                                          fontSize: 14))),
                                              DataColumn(
                                                  label: Text('Description',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.teal[900],
                                                          fontSize: 14))),
                                              DataColumn(
                                                  label: Text('Amount (KSh)',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.teal[900],
                                                          fontSize: 14))),
                                              DataColumn(
                                                  label: Text('Date',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.teal[900],
                                                          fontSize: 14))),
                                            ],
                                            rows: _benefits.map((benefit) {
                                              final employee =
                                                  _employees.firstWhere(
                                                      (emp) =>
                                                          emp['employee_id']
                                                              .toString() ==
                                                          benefit['employee_id']
                                                              .toString(),
                                                      orElse: () => {
                                                            'fullname':
                                                                'Unknown Employee'
                                                          });
                                              return DataRow(cells: [
                                                DataCell(Text(
                                                    employee['fullname'] ??
                                                        'Unknown',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    benefit['benefit_type'] ??
                                                        'Unknown',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    benefit['description'] ??
                                                        'Unknown',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KSh ${benefit['amount'].toString()}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    DateFormat.yMMMd().format(
                                                        DateTime.parse(
                                                            benefit['date'] ??
                                                                '')),
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
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
