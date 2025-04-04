import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'add_loan_screen.dart';

class LoansScreen extends StatefulWidget {
  @override
  _LoansScreenState createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final ApiService apiService = ApiService(client: http.Client());
  List<Map<String, dynamic>> loans = [];
  List<Map<String, dynamic>> employees = [];
  List<String> companyNames = ['All Companies'];
  bool isLoading = false;

  String searchKeyword = '';
  Map<String, bool> selectedLoans = {};
  double totalLoanAmount = 0.0; // Now represents total_amount_repaid
  double totalInterest = 0.0; // New: Total interest amount
  double totalRemainingAmount = 0.0; // New: Total remaining amount
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedCompany;

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

      // Extract unique company names from employees
      companyNames = ['All Companies'] +
          employees
              .map((e) => e['company_name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .toSet()
              .cast<String>()
              .toList();

      if (loans.isEmpty) {
        print('No loans found in the database.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No loans available')),
        );
      }

      _filterAndCalculateTotals();
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

  void _filterAndCalculateTotals() {
    print('Filtering loans and calculating totals...');
    setState(() {
      loans = loans.where((loan) {
        final createdAt = DateTime.tryParse(loan['created_at'] ?? '');
        final employee = employees.firstWhere(
          (e) => e['id'].toString() == loan['employee_id'].toString(),
          orElse: () => {'company_name': 'Unknown', 'fullname': 'Unknown'},
        );
        loan['employee_name'] = employee['fullname'] ?? 'Unknown';
        loan['company_name'] = employee['company_name'] ?? 'Unknown';

        final matchesMonth =
            createdAt != null && createdAt.month == _selectedMonth;
        final matchesYear =
            createdAt != null && createdAt.year == _selectedYear;
        final matchesCompany = _selectedCompany == null ||
            _selectedCompany == 'All Companies' ||
            loan['company_name'] == _selectedCompany;
        final matchesKeyword = searchKeyword.isEmpty ||
            (loan['employee_name'] ?? '')
                .toLowerCase()
                .contains(searchKeyword) ||
            (loan['company_name'] ?? '').toLowerCase().contains(searchKeyword);

        return matchesMonth && matchesYear && matchesCompany && matchesKeyword;
      }).toList();

      totalLoanAmount = loans.fold(
          0.0, (sum, loan) => sum + (loan['total_amount_repaid'] ?? 0.0));
      totalInterest =
          loans.fold(0.0, (sum, loan) => sum + (loan['interest'] ?? 0.0));
      totalRemainingAmount = loans.fold(
          0.0, (sum, loan) => sum + (loan['remaining_amount'] ?? 0.0));

      print('Filtered loans count: ${loans.length}');
      print('Total Amount Repaid: $totalLoanAmount');
      print('Total Interest: $totalInterest');
      print('Total Remaining Amount: $totalRemainingAmount');
    });
  }

  void _filterLoans(String keyword) {
    print('Filtering loans by keyword: "$keyword"');
    setState(() {
      searchKeyword = keyword.toLowerCase();
      _filterAndCalculateTotals();
    });
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
          'employee_id': loan['employee_id'],
          'repayment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'amount_repaid': loan['amount'],
          'interest': loan['interest'],
          'total_amount_repaid': loan['total_amount_repaid'],
          'loan_amount': loan['amount'] +
              loan['remaining_amount'], // Reconstruct original loan amount
          'loan_rate': loan['interest_rate'],
          'loan_period': loan['loan_period'],
        };

        await apiService.processLoanRepayment(repaymentData);
        print('Processed repayment for loan ID: ${loan['loan_id']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk repayment processed successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );

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
      appBar: CustomAppBar(
        title: 'Loans Management',
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                                _filterAndCalculateTotals();
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
                                _filterAndCalculateTotals();
                              });
                            },
                          ),
                          _buildDropdown(
                            value: _selectedCompany ?? 'All Companies',
                            items: companyNames,
                            itemBuilder: (company) => company,
                            onChanged: (value) {
                              setState(() {
                                _selectedCompany = value;
                                _filterAndCalculateTotals();
                              });
                            },
                          ),
                          ElevatedButton(
                            onPressed: _fetchLoansAndEmployees,
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
                        decoration: InputDecoration(
                          hintText: 'Search by Employee Name or Company',
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
                        onChanged: _filterLoans,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (loans.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Instructions: Check the box next to a loan to include it in bulk repayment.',
                    style: TextStyle(fontSize: 12, color: Colors.teal[900]),
                  ),
                ),
              Expanded(
                child: isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]))
                    : loans.isEmpty
                        ? Center(
                            child: Text(
                              'No loans available for the selected filters',
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
                                  colors: [Colors.white, Colors.teal[50]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minWidth:
                                          MediaQuery.of(context).size.width -
                                              32),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 16,
                                      dataRowHeight: 60,
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                              Colors.teal[100]),
                                      columns: _buildTableColumns(),
                                      rows: _buildTableRows(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),
              if (loans.isNotEmpty)
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
                    padding: const EdgeInsets.all(16),
                    child: ListTile(
                      title: Text('Totals',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[900])),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount Repaid: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalLoanAmount)}',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          Text(
                            'Total Interest: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalInterest)}',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          Text(
                            'Total Remaining Amount: ${NumberFormat.currency(locale: "en_US", symbol: "KES ").format(totalRemainingAmount)}',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _repayLoan,
            backgroundColor: Colors.teal[700],
            heroTag: 'bulk_repayment',
            tooltip: 'Bulk Repayment',
            child: Icon(Icons.payment, color: Colors.white),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AddLoanScreen(employees: employees)),
              ).then((_) {
                print('Returning to LoansScreen after adding a loan...');
                _fetchLoansAndEmployees();
              });
            },
            backgroundColor: Colors.teal[700],
            heroTag: 'add_loan',
            tooltip: 'Add Loan',
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    print('Building table columns...');
    return [
      DataColumn(label: Text('Select')),
      DataColumn(label: Text('Employee Name')),
      DataColumn(label: Text('Amount Repaid')),
      DataColumn(label: Text('Total Amount Repaid')),
      DataColumn(label: Text('Interest')),
      DataColumn(label: Text('Remaining Amount')),
      DataColumn(label: Text('Interest Rate')),
      DataColumn(label: Text('Loan Period (Months)')),
      DataColumn(label: Text('Created At')),
    ].map((column) {
      return DataColumn(
        label: Text(
          column.label.toString().replaceAll('_', ' ').capitalize(),
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.teal[900],
              fontSize: 14),
        ),
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
            activeColor: Colors.teal[700],
          )),
          DataCell(Text(loan['employee_name']?.toString() ?? 'Unknown',
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['amount'] ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['total_amount_repaid'] ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['interest'] ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['remaining_amount'] ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text('${(loan['interest_rate'] ?? 0).toStringAsFixed(2)}%',
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text('${loan['loan_period'] ?? 0}',
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(loan['created_at'] ?? 'N/A',
              style: TextStyle(color: Colors.grey[800]))),
        ],
      );
    }).toList();
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
}

extension StringExtension on String {
  String capitalize() {
    print('Capitalizing string: "$this"');
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
