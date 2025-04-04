import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AddLoanScreen extends StatefulWidget {
  final List<Map<String, dynamic>> employees;

  const AddLoanScreen({required this.employees, super.key});

  @override
  _AddLoanScreenState createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService(client: http.Client());

  String? selectedCompany;
  String? selectedEmployeeId;
  String? selectedEmployeeName;
  List<String> companyNames = [];

  final TextEditingController amountController = TextEditingController();
  final TextEditingController loanPeriodController = TextEditingController();
  final TextEditingController interestRateController = TextEditingController();
  DateTime? createdAt;

  bool isLoading = false;
  double loanAmount = 0.0;
  double monthlyPayment = 0.0;
  double interestRate = 0.0;
  double interestAmount = 0.0;
  double totalRepayment = 0.0;

  @override
  void initState() {
    super.initState();
    companyNames = widget.employees
        .map((e) => e['company_name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList();

    // Add listeners to update calculations in real-time
    amountController.addListener(_calculateLoanDetails);
    loanPeriodController.addListener(_calculateLoanDetails);
    interestRateController.addListener(_calculateLoanDetails);
  }

  @override
  void dispose() {
    amountController.removeListener(_calculateLoanDetails);
    loanPeriodController.removeListener(_calculateLoanDetails);
    interestRateController.removeListener(_calculateLoanDetails);
    amountController.dispose();
    loanPeriodController.dispose();
    interestRateController.dispose();
    super.dispose();
  }

  void _calculateLoanDetails() {
    setState(() {
      loanAmount = double.tryParse(amountController.text) ?? 0.0;
      int loanPeriod = int.tryParse(loanPeriodController.text) ?? 0;
      interestRate = double.tryParse(interestRateController.text) ?? 0.0;

      if (loanPeriod > 0) {
        // Simple interest calculation: Interest = Principal * Rate * Time
        interestAmount = loanAmount * (interestRate / 100) * (loanPeriod / 12);
        totalRepayment = loanAmount + interestAmount;
        monthlyPayment = totalRepayment / loanPeriod;
      } else {
        interestAmount = 0.0;
        totalRepayment = loanAmount;
        monthlyPayment = 0.0;
      }

      if (kDebugMode) {
        print('Loan Amount: $loanAmount');
        print('Monthly Payment: $monthlyPayment');
        print('Interest Rate: $interestRate%');
        print('Interest Amount: $interestAmount');
        print('Total Repayment: $totalRepayment');
      }
    });
  }

  Future<void> _addNewLoan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final loanData = {
        'employee_id': selectedEmployeeId,
        'amount': double.parse(amountController.text),
        'loan_period': int.parse(loanPeriodController.text),
        'interest_rate': double.parse(interestRateController.text) / 100,
        'created_at': DateFormat('yyyy-MM-dd').format(createdAt!),
      };

      if (kDebugMode) {
        print('Adding new loan for employee ID: $selectedEmployeeId');
      }
      await apiService.addLoan(loanData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan added successfully for $selectedEmployeeName'),
          backgroundColor: Colors.teal[700],
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding loan: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add loan: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectCreationDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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

    if (pickedDate != null) {
      setState(() {
        createdAt = pickedDate;
        if (kDebugMode) {
          print(
              'Selected creation date: ${DateFormat('yyyy-MM-dd').format(pickedDate)}');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = selectedCompany == null
        ? widget.employees
        : widget.employees
            .where((e) => e['company_name'] == selectedCompany)
            .toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add New Loan',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Company',
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
                        value: selectedCompany,
                        items: companyNames.map((company) {
                          return DropdownMenuItem<String>(
                            value: company,
                            child: Text(company,
                                style: TextStyle(color: Colors.teal[900])),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCompany = newValue;
                            selectedEmployeeId = null;
                            selectedEmployeeName = null;
                            if (kDebugMode) {
                              print('Selected company: $selectedCompany');
                            }
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select a company'
                            : null,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.teal[700]),
                      ),
                      SizedBox(height: 16),

                      // Employee Dropdown
                      DropdownButtonFormField<String>(
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
                        value: selectedEmployeeId,
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
                            : filteredEmployees.map((employee) {
                                return DropdownMenuItem<String>(
                                  value: employee['employee_id'].toString(),
                                  child: Text(
                                      '${employee['employee_id']} - ${employee['fullname']}',
                                      style:
                                          TextStyle(color: Colors.teal[900])),
                                );
                              }).toList(),
                        onChanged: selectedCompany == null
                            ? null
                            : (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedEmployeeId = newValue;
                                    selectedEmployeeName =
                                        filteredEmployees.firstWhere((emp) =>
                                            emp['employee_id'].toString() ==
                                            newValue)['fullname'];
                                    if (kDebugMode) {
                                      print(
                                          'Selected employee: $selectedEmployeeName (ID: $selectedEmployeeId)');
                                    }
                                  });
                                }
                              },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select an employee'
                            : null,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.teal[700]),
                      ),
                      SizedBox(height: 16),

                      // Loan Amount Field
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Loan Amount',
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter loan amount'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),

                      // Loan Period Field
                      TextFormField(
                        controller: loanPeriodController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Loan Period (Months)',
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter loan period'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),

                      // Interest Rate Field
                      TextFormField(
                        controller: interestRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Interest Rate (%)',
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter interest rate'
                            : null,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      SizedBox(height: 16),

                      // Creation Date Picker
                      ElevatedButton(
                        onPressed: _selectCreationDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Select Creation Date'),
                      ),
                      if (createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Creation Date: ${DateFormat('yyyy-MM-dd').format(createdAt!)}',
                            style: TextStyle(
                                fontSize: 16, color: Colors.teal[900]),
                          ),
                        ),
                      SizedBox(height: 20),

                      // Loan Details Display
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Loan Details',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal[900])),
                              SizedBox(height: 8),
                              Text(
                                  'Loan Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(loanAmount)}',
                                  style: TextStyle(color: Colors.grey[800])),
                              Text(
                                  'Monthly Payment: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(monthlyPayment)}',
                                  style: TextStyle(color: Colors.grey[800])),
                              Text(
                                  'Interest Rate: ${interestRate.toStringAsFixed(2)}%',
                                  style: TextStyle(color: Colors.grey[800])),
                              Text(
                                  'Interest Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(interestAmount)}',
                                  style: TextStyle(color: Colors.grey[800])),
                              Text(
                                  'Total Repayment: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalRepayment)}',
                                  style: TextStyle(color: Colors.grey[800])),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Save Loan Button
                      ElevatedButton(
                        onPressed: isLoading ? null : _addNewLoan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Save Loan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
