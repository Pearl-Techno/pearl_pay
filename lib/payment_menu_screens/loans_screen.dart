import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services.dart';
import 'add_loan_screen.dart';

class LoansScreen extends StatefulWidget {
  @override
  _LoansScreenState createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final ApiService apiService = ApiService(client: http.Client());
  List<Map<String, dynamic>> loans = [];
  List<Map<String, dynamic>> employees = [];
  bool isLoading = false;

  String searchKeyword = '';
  Map<String, bool> selectedLoans = {};
  double totalLoanAmount = 0.0;
  double totalInterestRate = 0.0;

  @override
  void initState() {
    super.initState();
    print('Initializing LoansScreen...');
    _fetchLoansAndEmployees();
  }

  Future<void> _fetchLoansAndEmployees() async {
    setState(() => isLoading = true);

    try {
      print('Fetching loans and employees from the backend...');
      loans = await apiService.fetchLoans();
      employees = await apiService.fetchEmployees();

      if (loans.isEmpty) {
        print('No loans found in the database.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No loans available')),
        );
      }

      _calculateTotals();
    } catch (e) {
      print('Error fetching loans and employees: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching loans: $e')),
      );
    } finally {
      setState(() => isLoading = false);
      print('Finished fetching loans and employees.');
    }
  }

  void _calculateTotals() {
    print('Calculating totals for loans...');
    totalLoanAmount =
        loans.fold(0.0, (sum, loan) => sum + (loan['amount'] ?? 0.0));
    totalInterestRate =
        loans.fold(0.0, (sum, loan) => sum + (loan['interest_rate'] ?? 0.0));

    print('Total Loan Amount: $totalLoanAmount');
    print(
        'Average Interest Rate: ${(totalInterestRate / loans.length).toStringAsFixed(2)}%');
  }

  void _filterLoans(String keyword) {
    print('Filtering loans by keyword: "$keyword"');

    setState(() {
      searchKeyword = keyword.toLowerCase();
      loans = loans.where((loan) {
        final employeeName =
            (loan['employee_name'] ?? '').toString().toLowerCase();
        return employeeName.contains(searchKeyword);
      }).toList();

      _calculateTotals(); // Recalculate totals after filtering
    });

    print('Filtered loans count: ${loans.length}');
  }

 void _repayLoan() async {
    if (selectedLoans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one loan to repay')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      for (var loan
          in loans.where((loan) => selectedLoans[loan['loan_id']] == true)) {
        final repaymentData = {
          'loan_id': loan['loan_id'],
          'repay_amount': loan['repay_amount'],
          'repay_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'interest': loan['interest_rate'],
          'total_repaid': loan['total_repaid'],
        };

        await apiService.processLoanRepayment(repaymentData);
        print('Processed repayment for loan ID: ${loan['loan_id']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk repayment processed successfully')),
      );

      // Refresh loans after repayment
      await _fetchLoansAndEmployees();
    } catch (e) {
      print('Error during bulk repayment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process bulk repayment: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Loans'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              decoration: InputDecoration(
                labelText: 'Search by Employee Name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterLoans,
            ),
            SizedBox(height: 16),

            // Instructions
            if (loans.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Instructions: Check the box next to a loan to include it in bulk repayment.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),

            // Loans Table
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : loans.isEmpty
                      ? Center(child: Text('No loans available'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: _buildTableColumns(),
                            rows: _buildTableRows(),
                          ),
                        ),
            ),

            // Totals Section
            if (loans.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text('Totals',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Total Loan Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalLoanAmount)}'),
                      Text(
                          'Average Interest Rate: ${(totalInterestRate / loans.length).toStringAsFixed(2)}%'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),

      // Floating Action Buttons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _repayLoan,
            backgroundColor: Colors.teal,
            heroTag: 'bulk_repayment',
            tooltip: 'Bulk Repayment',
            child: Icon(Icons.payment),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLoanScreen(employees: employees),
                ),
              ).then((_) {
                print('Returning to LoansScreen after adding a loan...');
                _fetchLoansAndEmployees(); // Refresh loans after adding
              });
            },
            backgroundColor: Colors.teal,
            heroTag: 'add_loan',
            tooltip: 'Add Loan',
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  

  List<DataColumn> _buildTableColumns() {
    print('Building table columns...');
    return [
      DataColumn(label: Text('Select')), // Checkbox column
      DataColumn(label: Text('Employee Name')),
      DataColumn(label: Text('Loan Amount')),
      DataColumn(label: Text('Interest Rate')),
      DataColumn(label: Text('Loan Period (Months)')),
      DataColumn(label: Text('Created At')),
      DataColumn(label: Text('Updated At')),
    ].map((column) {
      return DataColumn(
        label: Text(column.label.toString().replaceAll('_', ' ').capitalize()),
      );
    }).toList();
  }

  List<DataRow> _buildTableRows() {
    print('Building table rows for ${loans.length} loans...');
    return loans.map((loan) {
      return DataRow(
        onSelectChanged: (bool? selected) {
          if (selected != null) {
            print('Loan selection changed for loan ID: ${loan['loan_id']}');
            setState(() {
              selectedLoans[loan['loan_id'].toString()] = selected;
            });
          }
        },
        cells: [
          DataCell(Checkbox(
            value: selectedLoans[loan['loan_id'].toString()] ?? false,
            tristate: false,
            onChanged: (value) {
              print('Checkbox toggled for loan ID: ${loan['loan_id']}');
              setState(() {
                selectedLoans[loan['loan_id'].toString()] = value!;
              });
            },
          )),
          DataCell(Text(loan['employee_name']?.toString() ?? 'Unknown')),
          DataCell(Text(NumberFormat.currency(locale: "en_US", symbol: "KES ")
              .format(loan['amount'] ?? 0))),
          DataCell(
              Text('${(loan['interest_rate'] * 100).toStringAsFixed(2)}%')),
          DataCell(Text('${loan['loan_period'] ?? 0}')),
          DataCell(Text(loan['created_at'] ?? 'N/A')),
          DataCell(Text(loan['updated_at'] ?? 'N/A')),
        ],
      );
    }).toList();
  }
}



extension StringExtension on String {
  String capitalize() {
    print('Capitalizing string: "$this"');
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
