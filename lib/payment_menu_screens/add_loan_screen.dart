import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services.dart';

class AddLoanScreen extends StatefulWidget {
  final List<Map<String, dynamic>> employees;

  const AddLoanScreen({required this.employees, super.key});

  @override
  _AddLoanScreenState createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService(client: http.Client());

  String? selectedEmployeeId;
  String? selectedEmployeeName;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController loanPeriodController = TextEditingController();
  final TextEditingController interestRateController = TextEditingController();
  DateTime? createdAt;

  Future<void> _addNewLoan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final loanData = {
        'employee_id': selectedEmployeeId,
        'amount': double.parse(amountController.text),
        'loan_period': int.parse(loanPeriodController.text),
        'interest_rate': double.parse(interestRateController.text) /
            100, // Convert to decimal
        'created_at': DateFormat('yyyy-MM-dd').format(createdAt!),
      };

      if (kDebugMode) {
        print('Adding new loan for employee ID: $selectedEmployeeId');
      }
      await apiService.addLoan(loanData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Loan added successfully for $selectedEmployeeName')),
      );

      Navigator.pop(context); // Close the screen after successful addition
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Loan'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown to select employee
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Employee',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedEmployeeId,
                  items: widget.employees.map((employee) {
                    return DropdownMenuItem<String>(
                      value: employee['employee_id'].toString(),
                      child: Text(employee['fullname']),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedEmployeeId = newValue;
                        selectedEmployeeName = widget.employees.firstWhere(
                            (emp) => emp['employee_id'] == newValue,
                            orElse: () => {'fullname': ''})['fullname'];
                        if (kDebugMode) {
                          print(
                            'Selected employee: $selectedEmployeeName (ID: $selectedEmployeeId)');
                        }
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an employee';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16),

                // Loan Amount Field
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Loan Amount',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter loan amount';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16),

                // Loan Period Field
                TextFormField(
                  controller: loanPeriodController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Loan Period (Months)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter loan period';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16),

                // Interest Rate Field
                TextFormField(
                  controller: interestRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Interest Rate (%)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter interest rate';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16),

                // Creation Date Picker
                ElevatedButton(
                  onPressed: _selectCreationDate,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Text('Select Creation Date'),
                ),
                if (createdAt != null)
                  Text(
                    'Creation Date: ${DateFormat('yyyy-MM-dd').format(createdAt!)}',
                    style: TextStyle(fontSize: 16),
                  ),

                SizedBox(height: 20),

                // Save Loan Button
                ElevatedButton(
                  onPressed: isLoading ? null : _addNewLoan,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: isLoading
                      ? CircularProgressIndicator()
                      : Text('Save Loan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isLoading = false;
}
