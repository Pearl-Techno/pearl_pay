import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

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
          SnackBar(
            content: Text('Saving insurance relief...'),
            backgroundColor: Colors.teal[700],
          ),
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
            backgroundColor: Colors.teal[700],
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
      appBar: CustomAppBar(
        title: 'Insurance Relief',
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
          child: _isLoadingEmployees || _isLoadingReliefs
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
                                      _fetchReliefRecords();
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
                                            child: Text(
                                              year.toString(),
                                              style: TextStyle(
                                                  color: Colors.teal[900]),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedYear = value!;
                                      _fetchReliefRecords();
                                    });
                                  },
                                  dropdownColor: Colors.white,
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.teal[700]),
                                ),
                                ElevatedButton(
                                  onPressed: _fetchReliefRecords,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text(
                                    'Fetch Reliefs',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Expanded(
                          flex: 1,
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
                                          if (value == null)
                                            return 'Please select a company';
                                          return null;
                                        },
                                        dropdownColor: Colors.white,
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: Colors.teal[700]),
                                      ),
                                      const SizedBox(height: 16.0),
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
                                          if (value == null)
                                            return 'Please select an employee';
                                          return null;
                                        },
                                        dropdownColor: Colors.white,
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: Colors.teal[700]),
                                      ),
                                      const SizedBox(height: 16.0),
                                      TextFormField(
                                        controller: _premiumController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Premium Amount (KSh)',
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
                                            return 'Please enter a premium amount';
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
                                      TextFormField(
                                        controller: _percentageController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Relief Percentage (%)',
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
                                          hintText: 'e.g., 15',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[600]),
                                          suffixText: '%',
                                          suffixStyle: TextStyle(
                                              color: Colors.teal[900]),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a percentage';
                                          }
                                          final percent =
                                              double.tryParse(value);
                                          if (percent == null ||
                                              percent < 0 ||
                                              percent > 100) {
                                            return 'Please enter a valid percentage (0-100)';
                                          }
                                          return null;
                                        },
                                        style:
                                            TextStyle(color: Colors.grey[800]),
                                      ),
                                      const SizedBox(height: 16.0),
                                      TextFormField(
                                        controller: _reliefController,
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: 'Calculated Relief (KSh)',
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
                                          prefixText: 'KSh ',
                                          prefixStyle: TextStyle(
                                              color: Colors.teal[900]),
                                        ),
                                        style:
                                            TextStyle(color: Colors.grey[800]),
                                      ),
                                      const SizedBox(height: 24.0),
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
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16.0),
                              Text(
                                'Insurance Relief Records',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[900],
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Expanded(
                                child: _reliefRecords.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No relief records found',
                                          style: TextStyle(
                                              color: Colors.teal[900],
                                              fontSize: 16),
                                        ),
                                      )
                                    : Card(
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: ListView.builder(
                                            itemCount: _reliefRecords.length,
                                            itemBuilder: (context, index) {
                                              final record =
                                                  _reliefRecords[index];
                                              final employee =
                                                  _employees.firstWhere(
                                                      (emp) =>
                                                          emp['employee_id']
                                                              .toString() ==
                                                          record['employee_id'],
                                                      orElse: () => {
                                                            'fullname':
                                                                'Unknown'
                                                          });
                                              return Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4.0,
                                                        horizontal: 8.0),
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: ListTile(
                                                  title: Text(
                                                    employee['fullname'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.teal[900]),
                                                  ),
                                                  subtitle: Text(
                                                    'Premium: KSh ${record['premium_amount'] ?? 'N/A'} | Relief: KSh ${record['relief_amount'] ?? 'N/A'} | ${record['date'] ?? 'N/A'}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]),
                                                  ),
                                                  trailing: Text(
                                                    '${record['relief_percentage'] ?? 'N/A'}%',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.teal[700]),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
