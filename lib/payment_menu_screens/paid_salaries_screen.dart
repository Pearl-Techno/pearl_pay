import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class PaidSalariesScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;
  const PaidSalariesScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PaidSalariesScreenState createState() => _PaidSalariesScreenState();
}

class _PaidSalariesScreenState extends State<PaidSalariesScreen> {
  late final ApiService _apiService;
  
  List<Map<String, dynamic>> _salaries = [];
  bool _isLoading = true;
  List<String> _companyNames = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(
      client: http.Client(),
      user: widget.user,
    );
    _fetchCompanies();
    _searchController.addListener(_fetchSalaries);
  }

  Future<void> _fetchCompanies() async {
    try {
      // Use widget.user.companyName directly to avoid unauthorized company data
      setState(() {
        _companyNames = [widget.user.companyName ?? 'Unknown'];
      });
      if (kDebugMode) {
        print('Company names set: $_companyNames');
      }
      _fetchSalaries();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting company: $e')),
      );
    }
  }

  Future<void> _fetchSalaries() async {
    setState(() => _isLoading = true);
    try {
      final salaries = await _apiService.getSalaries(widget.user.companyId);
      if (kDebugMode) {
        print('Fetched salaries: $salaries');
      }
      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        if (paymentDate == null) return false;
        final matchesMonth = paymentDate.month == _selectedMonth;
        final matchesYear = paymentDate.year == _selectedYear;
        final matchesCompany = salary['company_name'] == widget.user.companyName;
        final matchesStatus = salary['status']?.toLowerCase() == 'paid';
        final searchText = _searchController.text.toLowerCase();
        final matchesSearch = searchText.isEmpty ||
            salary['fullname']?.toLowerCase().contains(searchText) == true ||
            salary['employee_id']?.toString().contains(searchText) == true ||
            salary['company_name']?.toLowerCase().contains(searchText) == true;

        return matchesMonth &&
            matchesYear &&
            matchesCompany &&
            matchesStatus &&
            matchesSearch;
      }).toList();

      setState(() {
        _salaries = filteredSalaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load paid salaries: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Paid Salaries',
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
                  borderRadius: BorderRadius.circular(12),
                ),
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
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedMonth,
                              items: List.generate(12, (index) => index + 1),
                              itemBuilder: (month) => DateFormat('MMMM')
                                  .format(DateTime(_selectedYear, month)),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value!;
                                  _fetchSalaries();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedYear,
                              items: List.generate(
                                  10, (index) => DateTime.now().year - index),
                              itemBuilder: (year) => year.toString(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value!;
                                  _fetchSalaries();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _fetchSalaries,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Refresh'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Company: ${widget.user.companyName ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[900],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, ID, or company',
                          prefixIcon:
                              Icon(Icons.search, color: Colors.teal[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.teal[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]))
                    : _salaries.isEmpty
                        ? Center(
                            child: Text(
                              'No paid salaries available for selected filters',
                              style: TextStyle(
                                  color: Colors.teal[900], fontSize: 16),
                            ),
                          )
                        : Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    dataRowHeight: 60,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.teal[100]),
                                    columns: [
                                      _buildDataColumn('ID'),
                                      _buildDataColumn('Employee ID'),
                                      _buildDataColumn('Full Name'),
                                      _buildDataColumn('Company'),
                                      _buildDataColumn('Gross Pay'),
                                      _buildDataColumn('Basic Pay'),
                                      _buildDataColumn('Non-Cash Benefits'),
                                      _buildDataColumn('Other Earnings'),
                                      _buildDataColumn('Overtime'),
                                      _buildDataColumn('Absenteeism'),
                                      _buildDataColumn('Taxable Income'),
                                      _buildDataColumn('SHIF'),
                                      _buildDataColumn('PAYE'),
                                      _buildDataColumn('NSSF'),
                                      _buildDataColumn('Pension'),
                                      _buildDataColumn('Loan'),
                                      _buildDataColumn('Deductions'),
                                      _buildDataColumn('Housing Levy'),
                                      _buildDataColumn('Levy Relief'),
                                      _buildDataColumn('Net Pay'),
                                      _buildDataColumn('Status'),
                                      _buildDataColumn('Pay Date'),
                                    ],
                                    rows: _salaries.map((salary) {
                                      return DataRow(
                                        cells: [
                                          _buildDataCell(
                                              salary['id']?.toString() ??
                                                  'N/A'),
                                          _buildDataCell(salary['employee_id']
                                                  ?.toString() ??
                                              'N/A'),
                                          _buildDataCell(
                                              salary['fullname'] ?? 'N/A'),
                                          _buildDataCell(
                                              salary['company_name'] ?? 'N/A'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['gross_pay']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['basic_pay']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['non_cash_benefits']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['other_earnings']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['overtime_amount']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['absenteeism_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['taxable_income']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['nhif_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['paye_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['nssf_deduction']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['pension_contributions']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['loan_repayment']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['deductions']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['housing_levy_relief']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              'KES ${(double.tryParse(salary['net_pay']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(2)}'),
                                          _buildDataCell(
                                              salary['status'] ?? 'N/A'),
                                          _buildDataCell(
                                              salary['payment_date'] ?? 'N/A'),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
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

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.teal[900],
          fontSize: 14,
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Text(
        text,
        style: TextStyle(
          color: Colors.grey[800],
          fontSize: 12,
        ),
      ),
    );
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
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(color: Colors.teal[900]),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
      ),
    );
  }
}