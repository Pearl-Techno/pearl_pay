import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'add_loan_screen.dart';

class LoansScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const LoansScreen({super.key, required this.user, required this.apiService});

  @override
  _LoansScreenState createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<Map<String, dynamic>> loans = [];
  List<Map<String, dynamic>> employees = [];
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};
  bool isLoadingCompanies = false;
  bool isLoadingEmployees = false;
  bool isLoadingLoans = false;
  String? errorMessage;

  String searchKeyword = '';
  Map<String, bool> selectedLoans = {};
  double totalLoanAmount = 0.0; // Total amount repaid
  double totalInterest = 0.0; // Total interest
  double totalRemainingAmount = 0.0; // Total remaining amount
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    print('Initializing LoansScreen...');
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    setState(() => isLoadingCompanies = true);
    try {
      final companies = await widget.apiService.getCompanies();
      final userCompanyId = widget.user.companyId != null
          ? int.tryParse(widget.user.companyId.toString())
          : null;
      final isAdmin = widget.user.role == 'admin';

      if (userCompanyId == null) {
        throw Exception('No valid company ID for user');
      }

      setState(() {
        if (isAdmin) {
          companyIds = [userCompanyId];
          companyIdToName = {
            userCompanyId: widget.user.companyName ?? 'Unknown'
          };
          companyIds.insert(0, 0); // 0 for 'All Companies'
          companyIdToName[0] = 'All Companies';
        } else {
          final userCompany = companies.firstWhere(
            (c) => int.tryParse(c['id']?.toString() ?? '') == userCompanyId,
            orElse: () => {
              'id': userCompanyId.toString(),
              'company_name': widget.user.companyName ?? 'Unknown'
            },
          );
          companyIds = [userCompanyId];
          companyIdToName = {
            userCompanyId: userCompany['company_name']?.toString() ?? 'Unknown'
          };
        }
        _selectedCompanyId = companyIds.isNotEmpty ? companyIds[0] : null;
        isLoadingCompanies = false;
      });

      await _fetchEmployeesAndLoans();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load companies: $e';
        isLoadingCompanies = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load companies: $e')),
      );
    }
  }

  Future<void> _fetchEmployeesAndLoans() async {
    setState(() {
      isLoadingEmployees = true;
      isLoadingLoans = true;
    });

    try {
      List<Map<String, dynamic>> fetchedEmployees = [];
      List<Map<String, dynamic>> fetchedLoans = [];
      final isAdmin = widget.user.role == 'admin';
      final userCompanyId = widget.user.companyId != null
          ? int.tryParse(widget.user.companyId.toString())
          : null;

      if (userCompanyId == null) {
        throw Exception('No valid company ID for user');
      }

      if (isAdmin && _selectedCompanyId == 0) {
        try {
          fetchedEmployees =
              await widget.apiService.getEmployeeList(userCompanyId);
          fetchedLoans = await widget.apiService.fetchLoans(userCompanyId);
        } catch (e) {
          if (kDebugMode) {
            print('Unauthorized access for company ID $userCompanyId: $e');
          }
          throw Exception('Access denied: $e');
        }
      } else if (_selectedCompanyId != null && _selectedCompanyId != 0) {
        if (_selectedCompanyId == userCompanyId) {
          try {
            fetchedEmployees =
                await widget.apiService.getEmployeeList(_selectedCompanyId!);
            if (isAdmin) {
              fetchedLoans =
                  await widget.apiService.fetchLoans(_selectedCompanyId!);
            } else {
              fetchedLoans = await widget.apiService.fetchLoansForEmployee(
                  widget.user.employeeId.toString(), _selectedCompanyId!);
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                  'Unauthorized access for company ID $_selectedCompanyId: $e');
            }
            throw Exception('Access denied: $e');
          }
        } else {
          throw Exception(
              'Unauthorized access to company ID $_selectedCompanyId');
        }
      } else {
        throw Exception('Invalid company ID selected');
      }

      setState(() {
        employees = fetchedEmployees;
        loans = fetchedLoans;

        // Map employee and company names to loans
        for (var loan in loans) {
          final employee = employees.firstWhere(
            (e) =>
                e['employee_id'].toString() == loan['employee_id'].toString(),
            orElse: () => {'fullname': 'Unknown', 'company_id': null},
          );
          loan['employee_name'] = employee['fullname'] ?? 'Unknown';
          loan['company_name'] =
              companyIdToName[employee['company_id'] ?? userCompanyId] ??
                  'Unknown';
        }

        isLoadingEmployees = false;
        isLoadingLoans = false;
      });

      _filterAndCalculateTotals();
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
        isLoadingEmployees = false;
        isLoadingLoans = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  void _filterAndCalculateTotals() {
    print('Filtering loans and calculating totals...');
    setState(() {
      final filteredLoans = loans.where((loan) {
        final matchesCompany = _selectedCompanyId == null ||
            _selectedCompanyId == 0 ||
            loan['company_id'] == _selectedCompanyId;
        final matchesKeyword = searchKeyword.isEmpty ||
            (loan['employee_name'] ?? '')
                .toLowerCase()
                .contains(searchKeyword) ||
            (loan['company_name'] ?? '').toLowerCase().contains(searchKeyword);
        return matchesCompany && matchesKeyword;
      }).toList();

      if (kDebugMode) {
        print('Filtered loans: ${filteredLoans.length}/${loans.length}');
      }

      loans = filteredLoans;

      totalLoanAmount = loans.fold(
          0.0,
          (sum, loan) =>
              sum + (loan['total_amount_repaid']?.toDouble() ?? 0.0));
      totalInterest = loans.fold(
          0.0, (sum, loan) => sum + (loan['interest']?.toDouble() ?? 0.0));
      totalRemainingAmount = loans.fold(0.0,
          (sum, loan) => sum + (loan['remaining_amount']?.toDouble() ?? 0.0));

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

  Future<void> _repayLoan() async {
    if (selectedLoans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one loan to repay')),
      );
      return;
    }

    if (widget.user.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Access denied: Only admins can process repayments')),
      );
      return;
    }

    setState(() => isLoadingLoans = true);

    try {
      for (var loan in loans
          .where((loan) => selectedLoans[loan['loan_id'].toString()] == true)) {
        final employee = employees.firstWhere(
          (e) => e['employee_id'].toString() == loan['employee_id'].toString(),
          orElse: () => {'company_id': _selectedCompanyId},
        );
        final companyId = employee['company_id'] ?? _selectedCompanyId;
        if (companyId == 0 || companyId == null) {
          throw Exception('Invalid company ID for loan repayment');
        }

        final repaymentData = {
          'employee_id': loan['employee_id'],
          'repayment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'amount': loan['remaining_amount']?.toDouble() ?? 0.0,
        };

        await widget.apiService.processLoanRepayment(repaymentData, companyId);
        print('Processed repayment for loan ID: ${loan['loan_id']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bulk repayment processed successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );

      await _fetchEmployeesAndLoans();
    } catch (e) {
      print('Error during bulk repayment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process bulk repayment: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _repayLoan,
          ),
        ),
      );
    } finally {
      setState(() => isLoadingLoans = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';
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
          child: isLoadingCompanies || isLoadingEmployees || isLoadingLoans
              ? Center(
                  child: CircularProgressIndicator(color: Colors.teal[700]))
              : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            errorMessage!,
                            style: TextStyle(
                                color: Colors.teal[900], fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchCompanies,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildDropdown(
                                      value: _selectedMonth,
                                      items: List.generate(
                                          12, (index) => index + 1),
                                      itemBuilder: (month) => DateFormat('MMMM')
                                          .format(
                                              DateTime(_selectedYear, month)),
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
                                          10,
                                          (index) =>
                                              DateTime.now().year - index),
                                      itemBuilder: (year) => year.toString(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedYear = value!;
                                          _filterAndCalculateTotals();
                                        });
                                      },
                                    ),
                                    _buildDropdown(
                                      value: _selectedCompanyId ?? 0,
                                      items: companyIds,
                                      itemBuilder: (id) =>
                                          companyIdToName[id] ?? 'Unknown',
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCompanyId = value;
                                          _fetchEmployeesAndLoans();
                                        });
                                      },
                                    ),
                                    ElevatedButton(
                                      onPressed: _fetchEmployeesAndLoans,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[700],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by Employee Name or Company',
                                    prefixIcon: Icon(Icons.search,
                                        color: Colors.teal[700]),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.teal[200]!)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.teal[200]!)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.teal[700]!)),
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
                        const SizedBox(height: 16),
                        if (loans.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Instructions: Check the box next to a loan to include it in bulk repayment.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.teal[900]),
                            ),
                          ),
                        Expanded(
                          child: loans.isEmpty
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
          if (isAdmin)
            FloatingActionButton(
              onPressed: _repayLoan,
              backgroundColor: Colors.teal[700],
              heroTag: 'bulk_repayment',
              tooltip: 'Bulk Repayment',
              child: const Icon(Icons.payment, color: Colors.white),
            ),
          if (isAdmin) const SizedBox(height: 16),
          if (isAdmin)
            FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddLoanScreen(
                          user: widget.user.toMap(),
                          apiService: widget.apiService)),
                ).then((_) {
                  print('Returning to LoansScreen after adding a loan...');
                  _fetchEmployeesAndLoans();
                });
              },
              backgroundColor: Colors.teal[700],
              heroTag: 'add_loan',
              tooltip: 'Add Loan',
              child: const Icon(Icons.add, color: Colors.white),
            ),
        ],
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    print('Building table columns...');
    return [
      const DataColumn(label: Text('Select')),
      const DataColumn(label: Text('Employee Name')),
      const DataColumn(label: Text('Amount')),
      const DataColumn(label: Text('Total Amount Repaid')),
      const DataColumn(label: Text('Interest')),
      const DataColumn(label: Text('Remaining Amount')),
      const DataColumn(label: Text('Interest Rate')),
      const DataColumn(label: Text('Loan Period (Months)')),
      const DataColumn(label: Text('Created At')),
    ].map((column) {
      return DataColumn(
        label: Text(
          column.label
              .toString()
              .split('.')
              .last
              .replaceAll('_', ' ')
              .capitalize(),
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
                  .format(loan['amount']?.toDouble() ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['total_amount_repaid']?.toDouble() ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['interest']?.toDouble() ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              NumberFormat.currency(locale: "en_US", symbol: "KES ")
                  .format(loan['remaining_amount']?.toDouble() ?? 0),
              style: TextStyle(color: Colors.grey[800]))),
          DataCell(Text(
              '${(loan['interest_rate']?.toDouble() ?? 0).toStringAsFixed(2)}%',
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
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
