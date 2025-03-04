import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services.dart';

class InsuranceReliefScreen extends StatefulWidget {
  const InsuranceReliefScreen({super.key});

  @override
  _InsuranceReliefScreenState createState() => _InsuranceReliefScreenState();
}

class _InsuranceReliefScreenState extends State<InsuranceReliefScreen> {
  final ApiService _apiService = ApiService(client: http.Client());
  final _formKey = GlobalKey<FormState>();
  final _premiumController = TextEditingController();
  final _percentageController = TextEditingController();
  final _reliefController = TextEditingController();

  String? _selectedCompany;
  String? _selectedEmployeeId;
  List<String> _companyNames = ['All Companies'];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _reliefRecords = [];
  bool _isLoadingEmployees = true;
  bool _isLoadingReliefs = true;
  String? _errorMessage;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _premiumController.addListener(_calculateRelief);
    _percentageController.addListener(_calculateRelief);
  }

  Future<void> _fetchInitialData() async {
    try {
      final employees = await _apiService.getAllEmployees();
      setState(() {
        _employees = employees;
        _companyNames = ['All Companies'] +
            employees
                .map((e) => e['company_name'] as String?)
                .where((name) => name != null && name.isNotEmpty)
                .toSet()
                .cast<String>()
                .toList();
        _isLoadingEmployees = false;
      });
      await _fetchReliefRecords();
    } catch (e) {
      setState(() {
        _isLoadingEmployees = false;
        _isLoadingReliefs = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _fetchReliefRecords() async {
    setState(() => _isLoadingReliefs = true);
    try {
      final reliefRecords = await _apiService.getInsuranceRelief(
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() {
        _reliefRecords = reliefRecords;
        _isLoadingReliefs = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load relief records: $e';
        _isLoadingReliefs = false;
      });
    }
  }

  void _calculateRelief() {
    final premium = double.tryParse(_premiumController.text) ?? 0.0;
    final percentage = double.tryParse(_percentageController.text) ?? 0.0;
    final relief = premium * (percentage / 100);
    _reliefController.text = relief.toStringAsFixed(2);
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final employeeId = _selectedEmployeeId!;
      final premium = double.parse(_premiumController.text);
      final percentage = double.parse(_percentageController.text);
      final relief = double.parse(_reliefController.text);

      final reliefData = {
        'employee_id': employeeId,
        'premium_amount': premium,
        'relief_percentage': percentage,
        'relief_amount': relief,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving insurance relief...')),
        );

        await _apiService.addInsuranceRelief(reliefData);

        final reliefDate = DateTime.parse(reliefData['date'] as String);
        setState(() {
          _selectedMonth = reliefDate.month;
          _selectedYear = reliefDate.year;
        });
        await _fetchReliefRecords();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insurance Relief Saved: ${_employees.firstWhere((emp) => emp['employee_id'].toString() == employeeId)['fullname']}, Premium: KSh $premium, Relief: KSh $relief',
            ),
            backgroundColor: Colors.teal,
          ),
        );

        _premiumController.clear();
        _percentageController.clear();
        _reliefController.clear();
        setState(() {
          _selectedCompany = null;
          _selectedEmployeeId = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save relief: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _premiumController.removeListener(_calculateRelief);
    _percentageController.removeListener(_calculateRelief);
    _premiumController.dispose();
    _percentageController.dispose();
    _reliefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Relief'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingEmployees || _isLoadingReliefs
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          DropdownButton<int>(
                            value: _selectedMonth,
                            items: List.generate(12, (index) => index + 1)
                                .map((month) => DropdownMenuItem(
                                      value: month,
                                      child: Text(DateFormat('MMMM').format(
                                          DateTime(_selectedYear, month))),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedMonth = value!;
                                _fetchReliefRecords();
                              });
                            },
                          ),
                          DropdownButton<int>(
                            value: _selectedYear,
                            items: List.generate(10,
                                    (index) => DateTime.now().year - index + 1)
                                .map((year) => DropdownMenuItem(
                                      value: year,
                                      child: Text(year.toString()),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedYear = value!;
                                _fetchReliefRecords();
                              });
                            },
                          ),
                          ElevatedButton(
                            onPressed: _fetchReliefRecords,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            child: const Text(
                              'Fetch Reliefs',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      Expanded(
                        flex: 1,
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                      _selectedEmployeeId = null;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null)
                                      return 'Please select a company';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),
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
                                    if (value == null)
                                      return 'Please select an employee';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),
                                TextFormField(
                                  controller: _premiumController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Premium Amount (KSh)',
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g., 10000.00',
                                    prefixText: 'KSh ',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a premium amount';
                                    }
                                    if (double.tryParse(value) == null ||
                                        double.parse(value) <= 0) {
                                      return 'Please enter a valid positive amount';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),
                                TextFormField(
                                  controller: _percentageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Relief Percentage (%)',
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g., 15',
                                    suffixText: '%',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a percentage';
                                    }
                                    final percent = double.tryParse(value);
                                    if (percent == null ||
                                        percent < 0 ||
                                        percent > 100) {
                                      return 'Please enter a valid percentage (0-100)';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16.0),
                                TextFormField(
                                  controller: _reliefController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Calculated Relief (KSh)',
                                    border: OutlineInputBorder(),
                                    prefixText: 'KSh ',
                                  ),
                                ),
                                const SizedBox(height: 24.0),
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
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16.0),
                            const Text(
                              'Insurance Relief Records',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Expanded(
                              child: _reliefRecords.isEmpty
                                  ? const Center(
                                      child: Text('No relief records found'))
                                  : ListView.builder(
                                      itemCount: _reliefRecords.length,
                                      itemBuilder: (context, index) {
                                        final record = _reliefRecords[index];
                                        final employee = _employees.firstWhere(
                                          (emp) =>
                                              emp['employee_id'].toString() ==
                                              record['employee_id'],
                                          orElse: () => {'fullname': 'Unknown'},
                                        );
                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: ListTile(
                                            title: Text(employee['fullname']),
                                            subtitle: Text(
                                              'Premium: KSh ${record['premium_amount'] ?? 'N/A'} | Relief: KSh ${record['relief_amount'] ?? 'N/A'} | ${record['date'] ?? 'N/A'}',
                                            ),
                                            trailing: Text(
                                                '${record['relief_percentage'] ?? 'N/A'}%'),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
