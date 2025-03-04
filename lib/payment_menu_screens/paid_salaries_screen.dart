import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services.dart';

class PaidSalariesScreen extends StatefulWidget {
  const PaidSalariesScreen({super.key});

  @override
  _PaidSalariesScreenState createState() => _PaidSalariesScreenState();
}

class _PaidSalariesScreenState extends State<PaidSalariesScreen> {
  final ApiService _apiService = ApiService(client: http.Client());
  List<Map<String, dynamic>> _salaries = [];
  bool _isLoading = true;
  String? _selectedCompany;
  List<String> _companyNames = ['All Companies'];

  @override
  void initState() {
    super.initState();
    _fetchSalaries();
  }

  Future<void> _fetchSalaries() async {
    setState(() => _isLoading = true);
    try {
      final salaries = await _apiService.getSalaries();
      final paidSalaries = salaries
          .where((salary) => salary['status']?.toLowerCase() == 'paid')
          .toList();

      setState(() {
        _salaries = paidSalaries;
        _companyNames = ['All Companies'] +
            paidSalaries
                .map((s) => s['company_name'] as String?)
                .where((name) => name != null && name.isNotEmpty)
                .toSet()
                .cast<String>()
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load paid salaries: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredSalaries() {
    if (_selectedCompany == null || _selectedCompany == 'All Companies') {
      return _salaries;
    }
    return _salaries
        .where((salary) => salary['company_name'] == _selectedCompany)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paid Salaries'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.teal.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCompany ?? 'All Companies',
                decoration: const InputDecoration(
                  labelText: 'Filter by Company',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _companyNames
                    .map((company) => DropdownMenuItem(
                          value: company,
                          child: Text(company),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCompany = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _salaries.isEmpty
                        ? const Center(
                            child: Text('No paid salaries available'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                columns: const [
                                  DataColumn(
                                      label: Text('Employee ID',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Full Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Company Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Gross Pay',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Net Pay',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Payment Date',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                ],
                                rows: _getFilteredSalaries().map((salary) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                          salary['employee_id']?.toString() ??
                                              'N/A')),
                                      DataCell(
                                          Text(salary['fullname'] ?? 'N/A')),
                                      DataCell(Text(
                                          salary['company_name'] ?? 'N/A')),
                                      DataCell(Text(
                                          'KES ${salary['gross_pay']?.toString() ?? '0.00'}')),
                                      DataCell(Text(
                                          'KES ${salary['net_pay']?.toString() ?? '0.00'}')),
                                      DataCell(Text(
                                          salary['payment_date'] ?? 'N/A')),
                                    ],
                                  );
                                }).toList(),
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
