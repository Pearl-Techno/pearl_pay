import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// SHIFExport: Component for displaying and exporting SHIF data
class SHIFExport {
  final String title = 'SHIF Export';
  final Map<String, dynamic> user; // User data from HomeScreen/ExportsScreen
  final ApiService apiService; // ApiService for backend calls
  final int? companyId; // Explicit company ID for restriction
  final IconData icon = Icons.medical_services;

  SHIFExport({
    required this.user,
    required this.apiService,
    this.companyId,
  });

  // Build Card: Creates a clickable card for the ExportsScreen
  Widget buildCard(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal[700]),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.teal[900],
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.file_download, color: Colors.teal[700]),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => buildDetailsPage(context)),
          );
        },
      ),
    );
  }

  // Build Details Page: Creates the SHIF export details page
  Widget buildDetailsPage(BuildContext context) {
    return _SHIFExportDetailsPage(
      apiService: apiService,
      user: user,
      companyId: companyId,
    );
  }

  // Export: Generates a detailed report CSV for the current month/year
  Future<String> export() async {
    if (companyId == null) {
      throw Exception('No company ID provided for export');
    }
    final detailsPage = _SHIFExportDetailsPage(
      apiService: apiService,
      user: user,
      companyId: companyId,
    );
    final state = detailsPage.createState();
    state.selectedMonth = DateTime.now().month;
    state.selectedYear = DateTime.now().year;
    await state._fetchSHIFData();
    return await state._exportToCSV(
      fileNamePrefix: 'shif_detailed_report',
      headers: [
        'Employee ID',
        'First Name',
        'Last Name',
        'National ID',
        'NHIF Number',
        'Amount',
        'Phone Number',
        'Company Name'
      ],
      fields: [
        'employee_id',
        'first_name',
        'last_name',
        'national_id',
        'nhif_number',
        'amount',
        'phone_number',
        'company_name'
      ],
    );
  }
}

class _SHIFExportDetailsPage extends StatefulWidget {
  final ApiService apiService;
  final Map<String, dynamic> user;
  final int? companyId;

  const _SHIFExportDetailsPage({
    required this.apiService,
    required this.user,
    this.companyId,
  });

  @override
  _SHIFExportDetailsPageState createState() => _SHIFExportDetailsPageState();
}

class _SHIFExportDetailsPageState extends State<_SHIFExportDetailsPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  late User _userModel;

  @override
  void initState() {
    super.initState();
    // Validate and convert user map to User object
    try {
      final effectiveCompanyId = widget.companyId ??
          (widget.user['company_id'] != null
              ? int.tryParse(widget.user['company_id'].toString())
              : null);
      if (effectiveCompanyId == null || effectiveCompanyId == 0) {
        throw Exception('No valid company ID provided');
      }
      _userModel = User(
        companyId: effectiveCompanyId,
        employeeId: widget.user['employee_id']?.toString() ?? 'N/A',
        role: (widget.user['role']?.toString() ?? 'unknown').toLowerCase(),
        userId: widget.user['user_id']?.toString(),
        username: widget.user['username']?.toString(),
        companyName: widget.user['company_name']?.toString() ?? 'Unknown',
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access denied: $e')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _fetchSHIFData();
  }

  // Fetch SHIF Data: Retrieves and filters employee and salary data
  Future<void> _fetchSHIFData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final companyId = _userModel.companyId;
      final employees = await widget.apiService.getEmployeeList(companyId);
      final salaries = await widget.apiService.getSalaries(companyId);

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == selectedMonth &&
            paymentDate.year == selectedYear;
        final hasSHIF =
            (double.tryParse(salary['nhif_deduction']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && hasSHIF;
      }).toList();

      final shifEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id']?.toString())
          .where((id) => id != null)
          .toSet();

      final filteredEmployees = employees.where((employee) {
        return shifEmployeeIds.contains(employee['employee_id']?.toString());
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id']?.toString() ==
              employee['employee_id']?.toString(),
          orElse: () => {},
        );
        final nameParts = _splitFullName(employee['fullname']);
        return {
          'employee_id': employee['employee_id']?.toString() ?? 'N/A',
          'first_name': nameParts['firstName'] ?? 'N/A',
          'last_name': nameParts['lastName'] ?? 'N/A',
          'national_id': employee['national_id']?.toString() ?? 'N/A',
          'nhif_number': employee['nhif']?.toString() ?? 'N/A',
          'amount': salary['nhif_deduction']?.toString() ?? '0.0',
          'phone_number': employee['tel']?.toString() ?? 'N/A',
          'company_name':
              employee['company_name']?.toString() ?? _userModel.companyName,
        };
      }).toList();

      setState(() {
        _employees = employees;
        _filteredEmployees = filteredEmployees;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
            'Fetched SHIF data for company: ${_userModel.companyName} ($companyId)');
        print('Filtered employees: ${filteredEmployees.length}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load SHIF data: $e';
      });
      if (kDebugMode) {
        print('Error fetching SHIF data: $e');
      }
    }
  }

  // Export to CSV: Exports SHIF data with customizable fields and file name
  Future<String> _exportToCSV({
    required String fileNamePrefix,
    required List<String> headers,
    required List<String> fields,
  }) async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return '';
    }

    setState(() => _isExporting = true);

    try {
      final numberFormat = NumberFormat('#,##0.00', 'en_US');
      final List<List<dynamic>> rows = [
        headers,
        ..._filteredEmployees.map((employee) => fields.map((field) {
              if (field == 'amount') {
                return numberFormat.format(
                    double.tryParse(employee[field]?.toString() ?? '0.0') ??
                        0.0);
              }
              return employee[field]?.toString() ?? 'N/A';
            }).toList()),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final monthYear = DateFormat('MMM_yyyy')
          .format(DateTime(selectedYear, selectedMonth))
          .replaceAll(' ', '_');
      final sanitizedCompanyName =
          (_userModel.companyName ?? 'Unknown').replaceAll(' ', '_');
      final filePath =
          '${directory.path}/${fileNamePrefix}_${sanitizedCompanyName}_$monthYear.csv';
      final file = File(filePath);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
      return filePath;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _exportToCSV(
              fileNamePrefix: fileNamePrefix,
              headers: headers,
              fields: fields,
            ),
          ),
        ),
      );
      return '';
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // Split Full Name: Splits a full name into first and last names
  Map<String, String> _splitFullName(String? fullName) {
    final nameParts = (fullName ?? 'N/A').trim().split(' ');
    if (nameParts.isEmpty) {
      return {'firstName': 'N/A', 'lastName': 'N/A'};
    }
    if (nameParts.length == 1) {
      return {'firstName': nameParts[0], 'lastName': ''};
    }
    return {
      'firstName': nameParts[0],
      'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    };
  }

  // Build Dropdown: Creates a styled dropdown widget
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.teal[900],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
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
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: CustomAppBar(
        title: 'SHIF Export',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) {
            print('Notifications tapped');
          }
        },
        onProfileTap: () {
          if (kDebugMode) {
            print('Profile tapped');
          }
        },
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchSHIFData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 6,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal[200]!),
                                ),
                                child: Text(
                                  _userModel.companyName ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.teal[900],
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdown(
                                label: 'Month',
                                value: selectedMonth,
                                items: List.generate(12, (index) => index + 1),
                                itemBuilder: (month) => DateFormat('MMMM')
                                    .format(DateTime(selectedYear, month)),
                                onChanged: (value) {
                                  setState(() {
                                    selectedMonth = value!;
                                    _fetchSHIFData();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdown(
                                label: 'Year',
                                value: selectedYear,
                                items: List.generate(
                                    10, (index) => DateTime.now().year - index),
                                itemBuilder: (year) => year.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedYear = value!;
                                    _fetchSHIFData();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: Colors.teal[700]),
                      )
                    : _filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              'No SHIF data available for selected month/year',
                              style: TextStyle(
                                color: Colors.teal[900],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : Card(
                            elevation: 6,
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
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    dataRowHeight: 60,
                                    headingRowColor: MaterialStateProperty.all(
                                        Colors.teal[100]),
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'Employee ID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'First Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Last Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'National ID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'NHIF Number',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Amount',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Phone Number',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Company Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: _filteredEmployees.map((employee) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              employee['employee_id'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee['first_name'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee['last_name'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee['national_id'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee['nhif_number'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              'KES ${numberFormat.format(double.tryParse(employee['amount']?.toString() ?? '0.0') ?? 0.0)}',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee['phone_number'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              employee['company_name'] ?? 'N/A',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoading
                    ? const SizedBox.shrink()
                    : Card(
                        elevation: 6,
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isExporting
                                      ? null
                                      : () => _exportToCSV(
                                            fileNamePrefix:
                                                'shif_contributions',
                                            headers: [
                                              'Employee ID',
                                              'NHIF Number',
                                              'Amount'
                                            ],
                                            fields: [
                                              'employee_id',
                                              'nhif_number',
                                              'amount'
                                            ],
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: _isExporting
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text('Export Contributions'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isExporting
                                      ? null
                                      : () => _exportToCSV(
                                            fileNamePrefix:
                                                'shif_detailed_report',
                                            headers: [
                                              'Employee ID',
                                              'First Name',
                                              'Last Name',
                                              'National ID',
                                              'NHIF Number',
                                              'Amount',
                                              'Phone Number',
                                              'Company Name'
                                            ],
                                            fields: [
                                              'employee_id',
                                              'first_name',
                                              'last_name',
                                              'national_id',
                                              'nhif_number',
                                              'amount',
                                              'phone_number',
                                              'company_name'
                                            ],
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: _isExporting
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text('Export Detailed Report'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isExporting
                                      ? null
                                      : () => _exportToCSV(
                                            fileNamePrefix: 'shif_export',
                                            headers: [
                                              'Employee ID',
                                              'First Name',
                                              'Last Name',
                                              'National ID',
                                              'NHIF Number',
                                              'Amount',
                                              'Phone Number'
                                            ],
                                            fields: [
                                              'employee_id',
                                              'first_name',
                                              'last_name',
                                              'national_id',
                                              'nhif_number',
                                              'amount',
                                              'phone_number'
                                            ],
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: _isExporting
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text('Export to CSV'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
