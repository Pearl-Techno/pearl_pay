import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// HousingLevyExport: Component for displaying and exporting Housing Levy data
class HousingLevyExport {
  final String title = 'Housing Levy Export';
  final IconData icon = Icons.home;
  final Map<String, dynamic> user;
  final ApiService apiService;
  final int? companyId; // Explicit company ID for restriction

  HousingLevyExport({
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

  // Build Details Page: Creates the Housing Levy export details page
  Widget buildDetailsPage(BuildContext context) {
    return _HousingLevyExportDetailsPage(
      apiService: apiService,
      user: user,
      companyId: companyId,
    );
  }

  // Export: Generates a full Housing Levy CSV for the current month/year
  Future<String> export() async {
    if (companyId == null) {
      throw Exception('No company ID provided for export');
    }
    final companyName = user['company_name']?.toString() ?? 'Unknown';
    final month = DateTime.now().month;
    final year = DateTime.now().year;
    final employees = await _fetchHousingLevyDataForExport(
      apiService: apiService,
      companyId: companyId!,
      month: month,
      year: year,
      companyName: companyName,
    );
    return await _exportHousingLevyToCSV(
      employees: employees,
      exportType: 'full',
      companyName: companyName,
      year: year,
      month: month,
    );
  }

  // Fetch Housing Levy Data for Export: Retrieves and filters employee and salary data
  static Future<List<Map<String, dynamic>>> _fetchHousingLevyDataForExport({
    required ApiService apiService,
    required int companyId,
    required int month,
    required int year,
    required String companyName,
  }) async {
    try {
      final employees = await apiService.getEmployeeList(companyId);
      final salaries = await apiService.getSalaries(companyId, month: month, year: year);

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == month &&
            paymentDate.year == year;
        final hasHousingLevy =
            (double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && hasHousingLevy;
      }).toList();

      final housingLevyEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        return housingLevyEmployeeIds
            .contains(employee['employee_id'].toString());
      }).map((employee) {
        final salary = filteredSalaries.firstWhere(
          (s) =>
              s['employee_id'].toString() == employee['employee_id'].toString(),
          orElse: () => {},
        );
        return {
          'employee_id': employee['employee_id'] ?? 'N/A',
          'fullname': employee['fullname'] ?? 'N/A',
          'company_id': employee['company_id'] ?? companyId,
          'company_name': employee['company_name']?.toString() ?? companyName,
          'national_id': employee['national_id'] ?? 'N/A',
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'gross_pay': salary['gross_pay']?.toString() ?? '0.0',
          'housing_levy': salary['housing_levy']?.toString() ?? '0.0',
        };
      }).toList();

      if (kDebugMode) {
        print(
            'Fetched Housing Levy data for export: $companyName ($companyId)');
        print('Filtered employees: ${filteredEmployees.length}');
      }

      return filteredEmployees;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching Housing Levy data for export: $e');
      }
      throw Exception('Failed to load Housing Levy data: $e');
    }
  }

  // Export Housing Levy to CSV: Generates CSV for Housing Levy data
  static Future<String> _exportHousingLevyToCSV({
    required List<Map<String, dynamic>> employees,
    required String exportType,
    required String companyName,
    required int year,
    required int month,
  }) async {
    if (employees.isEmpty) {
      throw Exception('No data available to export');
    }

    try {
      List<List<dynamic>> rows;
      String fileName;

      final numberFormat = NumberFormat('#,##0.00', 'en_US');
      final monthYear = DateFormat('MMM_yyyy').format(DateTime(year, month));
      final sanitizedCompanyName = companyName.replaceAll(' ', '_');

      if (exportType == 'summary') {
        final totalHousingLevy = employees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(
                        employee['housing_levy']?.toString() ?? '0.0') ??
                    0.0));
        final totalGrossPay = employees.fold<double>(
            0.0,
            (sum, employee) =>
                sum +
                (double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ??
                    0.0));

        rows = [
          ['Total Employees', 'Total Gross Pay', 'Total Housing Levy'],
          [
            employees.length,
            numberFormat.format(totalGrossPay),
            numberFormat.format(totalHousingLevy),
          ],
        ];
        fileName =
            'housing_levy_summary_${sanitizedCompanyName}_$monthYear.csv';
      } else {
        rows = [
          [
            'National ID',
            'Name',
            'KRA PIN',
            if (exportType == 'full') 'Gross Pay',
            'Housing Levy Amount'
          ],
          ...employees.map((employee) => [
                employee['national_id'] ?? 'N/A',
                employee['fullname'] ?? 'N/A',
                employee['kra_pin'] ?? 'N/A',
                if (exportType == 'full')
                  numberFormat.format(double.tryParse(
                          employee['gross_pay']?.toString() ?? '0.0') ??
                      0.0),
                numberFormat.format(double.tryParse(
                        employee['housing_levy']?.toString() ?? '0.0') ??
                    0.0),
              ]),
        ];
        fileName = exportType == 'contributions'
            ? 'housing_levy_contributions_${sanitizedCompanyName}_$monthYear.csv'
            : 'housing_levy_export_${sanitizedCompanyName}_$monthYear.csv';
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

      return filePath;
    } catch (e) {
      throw Exception('Failed to export: $e');
    }
  }
}

class _HousingLevyExportDetailsPage extends StatefulWidget {
  final ApiService apiService;
  final Map<String, dynamic> user;
  final int? companyId;

  const _HousingLevyExportDetailsPage({
    required this.apiService,
    required this.user,
    this.companyId,
  });

  @override
  _HousingLevyExportDetailsPageState createState() =>
      _HousingLevyExportDetailsPageState();
}

class _HousingLevyExportDetailsPageState
    extends State<_HousingLevyExportDetailsPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  String searchKeyword = '';
  late int effectiveCompanyId;
  late String companyName;

  @override
  void initState() {
    super.initState();
    // Validate company ID
    effectiveCompanyId = widget.companyId ??
        (widget.user['company_id'] != null
            ? int.tryParse(widget.user['company_id'].toString()) ?? 0
            : 0);
    companyName = widget.user['company_name']?.toString() ?? 'Unknown';
    if (effectiveCompanyId == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: No valid company ID')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _fetchHousingLevyData();
  }

  // Fetch Housing Levy Data: Retrieves and filters employee and salary data
  Future<void> _fetchHousingLevyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final employees =
          await widget.apiService.getEmployeeList(effectiveCompanyId);
      final salaries = await widget.apiService.getSalaries(effectiveCompanyId, month: selectedMonth, year: selectedYear);

      final filteredSalaries = salaries.where((salary) {
        final paymentDate = DateTime.tryParse(salary['payment_date'] ?? '');
        final matchesMonthYear = paymentDate != null &&
            paymentDate.month == selectedMonth &&
            paymentDate.year == selectedYear;
        final hasHousingLevy =
            (double.tryParse(salary['housing_levy']?.toString() ?? '0.0') ??
                    0.0) >
                0;
        return matchesMonthYear && hasHousingLevy;
      }).toList();

      final housingLevyEmployeeIds = filteredSalaries
          .map((salary) => salary['employee_id'].toString())
          .toSet();

      final filteredEmployees = employees.where((employee) {
        final matchesSearch = searchKeyword.isEmpty ||
            (employee['fullname'] ?? '').toLowerCase().contains(searchKeyword);
        return housingLevyEmployeeIds
                .contains(employee['employee_id'].toString()) &&
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
          'company_id': employee['company_id'] ?? effectiveCompanyId,
          'company_name': employee['company_name']?.toString() ?? companyName,
          'national_id': employee['national_id'] ?? 'N/A',
          'kra_pin': employee['kra_pin'] ?? 'N/A',
          'gross_pay': salary['gross_pay']?.toString() ?? '0.0',
          'housing_levy': salary['housing_levy']?.toString() ?? '0.0',
        };
      }).toList();

      setState(() {
        _employees = employees;
        _filteredEmployees = filteredEmployees;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
            'Fetched Housing Levy data for company: $companyName ($effectiveCompanyId)');
        print('Filtered employees: ${filteredEmployees.length}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load Housing Levy data: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching Housing Levy data: $e');
      }
    }
  }

  // Export to CSV: Exports Housing Levy data with customizable fields
  Future<String> _exportToCSV(String exportType) async {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return '';
    }

    setState(() => _isExporting = true);

    try {
      final filePath = await HousingLevyExport._exportHousingLevyToCSV(
        employees: _filteredEmployees,
        exportType: exportType,
        companyName: companyName,
        year: selectedYear,
        month: selectedMonth,
      );

      if (!mounted) return '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          backgroundColor: Colors.teal[700],
        ),
      );
      return filePath;
    } catch (e) {
      if (!mounted) return '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _exportToCSV(exportType),
          ),
        ),
      );
      return '';
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // Filter Employees by Search Keyword
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

  // Build Dropdown: Creates a styled dropdown widget
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
        title: 'Housing Levy Export',
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
                          onPressed: _fetchHousingLevyData,
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
                                            companyName,
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
                                          value: selectedMonth,
                                          items: List.generate(
                                              12, (index) => index + 1),
                                          itemBuilder: (month) =>
                                              DateFormat('MMMM').format(
                                                  DateTime(
                                                      selectedYear, month)),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedMonth = value!;
                                              _fetchHousingLevyData();
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDropdown(
                                          value: selectedYear,
                                          items: List.generate(
                                              10,
                                              (index) =>
                                                  DateTime.now().year - index),
                                          itemBuilder: (year) =>
                                              year.toString(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedYear = value!;
                                              _fetchHousingLevyData();
                                            });
                                          },
                                        ),
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
                                          'No Housing Levy data available for selected filters',
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
                                          columns: const [
                                            DataColumn(
                                                label: Text('National ID',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Name',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('KRA PIN',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Gross Pay',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                            DataColumn(
                                                label: Text('Housing Levy',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.teal))),
                                          ],
                                          rows: _filteredEmployees
                                              .map((employee) {
                                            final numberFormat = NumberFormat(
                                                '#,##0.00', 'en_US');
                                            return DataRow(
                                              cells: [
                                                DataCell(Text(
                                                    employee['national_id'] ??
                                                        'N/A',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    employee['fullname'] ??
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
                                                    'KES ${numberFormat.format(double.tryParse(employee['gross_pay']?.toString() ?? '0.0') ?? 0.0)}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[800]))),
                                                DataCell(Text(
                                                    'KES ${numberFormat.format(double.tryParse(employee['housing_levy']?.toString() ?? '0.0') ?? 0.0)}',
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
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isExporting
                                            ? null
                                            : () =>
                                                _exportToCSV('contributions'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: _isExporting
                                            ? const CircularProgressIndicator(
                                                color: Colors.white)
                                            : const Text(
                                                'Export Contributions'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isExporting
                                            ? null
                                            : () => _exportToCSV('summary'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: _isExporting
                                            ? const CircularProgressIndicator(
                                                color: Colors.white)
                                            : const Text('Export Summary'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isExporting
                                            ? null
                                            : () => _exportToCSV('full'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
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
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
