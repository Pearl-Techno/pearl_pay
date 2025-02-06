import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services.dart';

class RepayLoanScreen extends StatefulWidget {
  final String employeeId;

  const RepayLoanScreen({required this.employeeId, super.key});

  @override
  _RepayLoanScreenState createState() => _RepayLoanScreenState();
}

class _RepayLoanScreenState extends State<RepayLoanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService(client: http.Client());

  Map<String, dynamic>? selectedLoan;
  double repayAmount = 0.0;
  double interest = 0.0;
  double totalRepaid = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchLoansForEmployee();
  }

  Future<void> _fetchLoansForEmployee() async {
    try {
      final loans = await apiService.fetchLoansForEmployee(widget.employeeId);

      if (loans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No active loans found for this employee')),
        );
        Navigator.pop(context); // Close the screen if no loans are available
        return;
      }

      setState(() {
        selectedLoan = loans.first; // Select the first loan by default
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching loans: $e')),
      );
    }
  }

  void _calculateRepayment() {
    if (selectedLoan == null || repayAmount <= 0) return;

    setState(() {
      interest = (selectedLoan!['amount'] * selectedLoan!['interest_rate'])
          .roundToDouble();
      totalRepaid = repayAmount + interest;
    });

    print(
        'Calculated repayment: Interest = $interest, Total Repaid = $totalRepaid');
  }

  Future<void> _processRepayment() async {
    if (!_formKey.currentState!.validate() || selectedLoan == null) return;

    setState(() => isLoading = true);

    try {
      final repaymentData = {
        'loan_id': selectedLoan!['loan_id'],
        'repay_amount': repayAmount,
        'repay_date': DateFormat('yyyy-MM-dd').format(repayDate!),
        'interest': interest,
        'total_repaid': totalRepaid,
      };

      print(
          'Processing loan repayment for loan ID: ${selectedLoan!['loan_id']}');
      await apiService.processLoanRepayment(repaymentData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loan repayment processed successfully')),
      );

      Navigator.pop(context); // Close the screen after successful repayment
    } catch (e) {
      print('Error processing loan repayment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process loan repayment: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectRepayDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        repayDate = pickedDate;
        print(
            'Selected repayment date: ${DateFormat('yyyy-MM-dd').format(pickedDate)}');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Repay Loan'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: selectedLoan == null
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Loan Details Display
                      Text(
                          'Employee: ${selectedLoan!['employee_name'] ?? 'Unknown'}'),
                      Text(
                          'Loan Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(selectedLoan!['amount'] ?? 0)}'),
                      Text(
                          'Interest Rate: ${(selectedLoan!['interest_rate'] * 100).toStringAsFixed(2)}%'),
                      Text(
                          'Loan Period: ${selectedLoan!['loan_period'] ?? 'Unknown'}'),
                      Text(
                          'Created At: ${selectedLoan!['created_at'] ?? 'N/A'}'),

                      SizedBox(height: 20),

                      // Repayment Date Picker
                      ElevatedButton(
                        onPressed: _selectRepayDate,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal),
                        child: Text('Select Repayment Date'),
                      ),
                      if (repayDate != null)
                        Text(
                          'Repayment Date: ${DateFormat('yyyy-MM-dd').format(repayDate!)}',
                          style: TextStyle(fontSize: 16),
                        ),

                      SizedBox(height: 16),

                      // Repayment Amount Field
                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Repayment Amount',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            repayAmount = double.tryParse(value) ?? 0.0;
                            _calculateRepayment();
                          });
                        },
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              double.tryParse(value) == null) {
                            return 'Please enter a valid repayment amount';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 10),

                      // Calculated Interest and Total Repaid
                      Text(
                        'Interest: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(interest)}',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total Repaid: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalRepaid)}',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),

                      SizedBox(height: 20),

                      // Process Repayment Button
                      ElevatedButton(
                        onPressed: isLoading ? null : _processRepayment,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal),
                        child: isLoading
                            ? CircularProgressIndicator()
                            : Text('Process Repayment'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  DateTime? repayDate;
  bool isLoading = false;
}
