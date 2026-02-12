import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class NSSFExport {
  final String title = 'NSSF Export';
  final IconData icon = Icons.security;
  final Map<String, dynamic> user;
  final ApiService apiService;
  final int? companyId;

  NSSFExport({
    required this.user,
    required this.apiService,
    this.companyId,
  });

  Widget buildCard(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal[700]),
        title: Text(
          title,
          style:
              TextStyle(color: Colors.teal[900], fontWeight: FontWeight.w500),
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

  Widget buildDetailsPage(BuildContext context) {
    return _NSSFExportDetailsPage(
      apiService: apiService,
      user: user,
      companyId: companyId,
    );
  }
}

class _NSSFExportDetailsPage extends StatefulWidget {
  final ApiService apiService;
  final Map<String, dynamic> user;
  final int? companyId;

  const _NSSFExportDetailsPage({
    required this.apiService,
    required this.user,
    this.companyId,
  });

  @override
  _NSSFExportDetailsPageState createState() => _NSSFExportDetailsPageState();
}

class _NSSFExportDetailsPageState extends State<_NSSFExportDetailsPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  String? _companyName;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  String searchKeyword = '';

  @override
  void initState() {
    super.initState();
    final userCompanyId = widget.companyId ??
        (widget.user['company_id'] != null
            ? int.tryParse(widget.user['company_id'].toString())
            : null);
    if (userCompanyId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Access denied: No company ID provided')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _fetchNSSFData();
  }

  Future<void> _fetchNSSFData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCompanyId = widget.companyId ??
          (widget.user['company_id'] != null
              ? int.tryParse(widget.user['company_id'].toString())
              : null);
      final userCompanyName =
          widget.user['company_name']?.toString() ?? 'Unknown';

      if (userCompanyId == null) {
        throw Exception('No company ID provided');
      }

      final companies = await widget.apiService.getCompanies();
      final employees = await widget.apiService.getEmployeeList(userCompanyId);
      final salaries = await widget.apiService.getSalaries(userCompanyId, month: selectedMonth, year: selectedYear);

      // Find the user's company in fetched companies
      final userCompany = companies.firstWhere(
        (c) => int.tryParse(c['id']?.toString() ?? '') == userCompanyId,
        orElse: () => {
          'id': userCompanyId.toString(),
          'company_name': userCompanyName,
        },
      );

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == selectedMonth &&
            paymentDate.year == selectedYear;
        final hasNSSF =
            (double.tryParse(salary['nssf_deduction']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && hasNSSF;
      }).toList();

      final nssfEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        final matchesSearch = searchKeyword.isEmpty ||
            (employee['fullname'] ?? '').toLowerCase().contains(searchKeyword);
        return nssfEmployeeIds.contains(employee['employee_id'].toString()) &&
            matchesSearch;
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        return {
          'employee_id': employee['employee_id'] ?? 'N/A',
          'fullname': employee['fullname'] ?? 'N/A',
          'company_id': userCompanyId,
          'company_name':
              userCompany['company_name']?.toString() ?? userCompanyName,
          'national_id': employee['national_id'] ?? 'N/A',
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'nssf_number': employee['nssf'] ?? 'N/A',
          'gross_pay': salary['gross_pay'] ?? '0.0',
          'nssf_deduction': salary['nssf_deduction'] ?? '0.0',
        };
      }).toList();

      setState(() {
        _employees = employees;
        _filteredEmployees = filteredEmployees;
        _companyName =
            userCompany['company_name']?.toString() ?? userCompanyName;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
            'Fetched company: ${userCompany['company_name']} ($userCompanyId)');
        print('Filtered employees: ${filteredEmployees.length}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load NSSF data: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching NSSF data: $e');
      }
    }
  }

  Future<void> _exportToCSV(String exportType) async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      List<List<dynamic>> rows;
      String fileName;

      final numberFormat = NumberFormat('#,##0.00', 'en_US');
      final monthYear =
          DateFormat('MMM yyyy').format(DateTime(selectedYear, selectedMonth));

      if (exportType == 'summary') {
        final totalNSSF = _filteredEmployees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(
                        employee['nssf_deduction']?.toString() ?? '0.0') ??
                    0.0));
        final totalGrossPay = _filteredEmployees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ??
                    0.0));

        rows = [
          ['Total Employees', 'Total Gross Pay', 'Total NSSF Deduction'],
          [
            _filteredEmployees.length,
            numberFormat.format(totalGrossPay),
            numberFormat.format(totalNSSF),
          ],
        ];
        fileName = 'nssf_summary_${monthYear}_company${widget.companyId}.csv';
      } else {
        rows = [
          [
            'Employee ID',
            'Surname',
            'Other Names',
            'National ID',
            'KRA PIN',
            'NSSF Number',
            if (exportType == 'full') 'Gross Pay',
            'NSSF Deduction',
            'Voluntary'
          ],
          ..._filteredEmployees.map((employee) {
            final nameParts = _splitFullName(employee['fullname']);
            return [
              employee['employee_id'] ?? 'N/A',
              nameParts['surname'],
              nameParts['otherNames'],
              employee['national_id'] ?? 'N/A',
              employee['kra_pin'] ?? 'N/A',
              employee['nssf_number'] ?? 'N/A',
              if (exportType == 'full')
                numberFormat.format(double.tryParse(
                        employee['gross_pay']?.toString() ?? '0.0') ??
                    0.0),
              numberFormat.format(double.tryParse(
                      employee['nssf_deduction']?.toString() ?? '0.0') ??
                  0.0),
              '0',
            ];
          }),
        ];
        fileName = exportType == 'contributions'
            ? 'nssf_contributions_${monthYear}_company${widget.companyId}.csv'
            : 'nssf_export_${monthYear}_company${widget.companyId}.csv';
      }

      final csv = const ListToCsvConverter().convert(rows);
      String filePath;
      if (Platform.isWindows) {
        const String directoryPath = r'C:\payroll exports';
        final directory = Directory(directoryPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        filePath = '$directoryPath\\$fileName';
      } else {
        final directory = await getTemporaryDirectory();
        filePath = '${directory.path}/$fileName';
      }
      final file = File(filePath);

      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to $filePath'),
            backgroundColor: Colors.teal[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _exportToCSV(exportType),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Map<String, String> _splitFullName(String? fullName) {
    final nameParts = (fullName ?? 'N/A').trim().split(' ');
    if (nameParts.length == 1) {
      return {'surname': nameParts[0], 'otherNames': ''};
    }
    return {
      'surname': nameParts.last,
      'otherNames': nameParts.sublist(0, nameParts.length - 1).join(' '),
    };
  }

  void _filterEmployees(String keyword) {
    setState(() {
      searchKeyword = keyword.toLowerCase();
      _filteredEmployees = _employees.where((employee) {
        return (employee['fullname'] ?? '')
            .toLowerCase()
            .contains(searchKeyword);
      }).toList();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'NSSF Export',
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style:
                              TextStyle(color: Colors.teal[900], fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchNSSFData,
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
                : SingleChildScrollView(
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
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.teal[200]!),
                                          ),
                                          child: Text(
                                            _companyName ?? 'Unknown',
                                            style: TextStyle(
                                              color: Colors.teal[900],
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      _buildDropdown(
                                        value: selectedMonth,
                                        items: List.generate(
                                            12, (index) => index + 1),
                                        itemBuilder: (month) =>
                                            DateFormat('MMMM').format(
                                                DateTime(selectedYear, month)),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedMonth = value!;
                                            _fetchNSSFData();
                                          });
                                        },
                                      ),
                                      _buildDropdown(
                                        value: selectedYear,
                                        items: List.generate(
                                            10,
                                            (index) =>
                                                DateTime.now().year - index),
                                        itemBuilder: (year) => year.toString(),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedYear = value!;
                                            _fetchNSSFData();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search by Employee Name',
                                      prefixIcon: Icon(Icons.search,
                                          color: Colors.teal[700]),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.teal[200]!)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.teal[200]!)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: Colors.teal[700]!)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: _filterEmployees,
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
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
                              child: _filteredEmployees.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          'No NSSF data available for selected filters',
                                          style: TextStyle(
                                              color: Colors.teal[900],
                                              fontSize: 16),
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: DataTable(
                                          columnSpacing: 16,
                                          dataRowMinHeight: 60,
                                          dataRowMaxHeight: 60,
                                          headingRowColor:
                                              WidgetStateProperty.all(
                                                  Colors.teal[100]),
                                          columns: [
                                            DataColumn(
                                                label: Text('Employee ID',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('Surname',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('Other Names',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('National ID',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('KRA PIN',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('NSSF Number',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('Gross Pay',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                            DataColumn(
                                                label: Text('NSSF Deduction',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.teal[900]))),
                                          ],
                                          rows: _filteredEmployees
                                              .map((employee) {
                                            final nameParts = _splitFullName(
                                                employee['fullname']);
                                            final numberFormat = NumberFormat(
                                                '#,##0.00', 'en_US');
                                            return DataRow(
                                              cells: [
                                                DataCell(Text(
                                                    employee['employee_id']
                                                            ?.toString() ??
                                                        'N/A',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    nameParts['surname']!,
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    nameParts['otherNames']!,
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['national_id'] ??
                                                        'N/A',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['kra_pin'] ??
                                                        'N/A',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['nssf_number'] ??
                                                        'N/A',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['nssf_deduction']?.toString() ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_filteredEmployees.isNotEmpty)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _isExporting
                                          ? null
                                          : () => _exportToCSV('contributions'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: _isExporting
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : const Text('Export Contributions'),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isExporting
                                          ? null
                                          : () => _exportToCSV('summary'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: _isExporting
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : const Text('Export Summary'),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isExporting
                                          ? null
                                          : () => _exportToCSV('full'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: _isExporting
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : const Text('Export to CSV'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
