import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  // Create an HTTP client and pass it to ApiService
  final http.Client _httpClient = http.Client();
  final ApiService apiService = ApiService(client: http.Client());

  List<Map<String, dynamic>> employees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  void fetchEmployees() async {
    try {
      final data = await apiService.getEmployeeList();
      setState(() {
        employees = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load employees: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Close the HTTP client to prevent memory leaks
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee List'),
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Full Name',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('National ID',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('KRA PIN',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Position',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('NSSF',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('NHIF',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Tel',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Basic Salary',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('House Allowance',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Gross Pay',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Bank Name',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Account Number',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                    rows: employees
                        .map(
                          (employee) => DataRow(
                            cells: [
                              DataCell(Text(employee['employee_id'] ?? '')),
                              DataCell(Text(employee['fullname'] ?? '')),
                              DataCell(Text(employee['national_id'] ?? '')),
                              DataCell(Text(employee['kra_pin'] ?? '')),
                              DataCell(Text(employee['position'] ?? '')),
                              DataCell(Text(employee['nssf'] ?? '')),
                              DataCell(Text(employee['nhif'] ?? '')),
                              DataCell(Text(employee['tel'] ?? '')),
                              DataCell(Text(employee['basic'] ?? '')),
                              DataCell(Text(employee['house_allowance'] ?? '')),
                              DataCell(Text(employee['gross_pay'] ?? '')),
                              DataCell(Text(employee['bank_name'] ?? '')),
                              DataCell(Text(employee['account_number'] ?? '')),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
      ),
    );
  }
}
