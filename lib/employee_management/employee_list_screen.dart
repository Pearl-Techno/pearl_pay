import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/user.dart';
import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

// EmployeeListScreen: Displays a list of employees with export and action options
class EmployeeListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const EmployeeListScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Map<String, dynamic>> _employees = [];
  int? _companyId;
  String _companyName = 'Unknown';
  bool _isLoading = true;
  bool _isLoadingCompanies = true;
  bool _isExporting = false;
  String? _errorMessage;
  late User _userModel;
  final ScrollController _horizontalScrollController = ScrollController();
  List<Map<String, dynamic>> _failedAuditLogs = [];

  @override
  void initState() {
    super.initState();
    try {
      _userModel = User(
        companyId: int.parse(widget.user['company_id']?.toString() ?? '0'),
        employeeId: widget.user['employee_id']?.toString() ?? 'N/A',
        role: (widget.user['role']?.toString() ?? 'unknown').toLowerCase(),
        userId: widget.user['user_id']?.toString(),
        username: widget.user['username']?.toString(),
        companyName: widget.user['company_name']?.toString(),
      );
    } catch (e) {
      developer.log('Invalid user data: $e', name: 'EmployeeListScreen');
      setState(() {
        _errorMessage = 'Invalid user data';
        _isLoadingCompanies = false;
        _isLoading = false;
      });
      return;
    }
    developer.log('User data: ${_userModel.toMap()}',
        name: 'EmployeeListScreen');
    _fetchCompanies();
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();
    if (message.contains('network')) {
      return 'Network error: Please check your internet connection.';
    } else if (message.contains('unauthorized') ||
        message.contains('access denied')) {
      return 'Access denied: Please re-authenticate or contact support.';
    } else if (message.contains('duplicate')) {
      return 'Duplicate entry detected.';
    } else if (message.contains('share')) {
      return 'Unable to share file. Please check the file manually in your device storage. already exported.';
    }
    return 'An unexpected error occurred: $error';
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoadingCompanies = true;
      _errorMessage = null;
    });
    try {
      final userCompanyId = _userModel.companyId;
      final userCompanyName = _userModel.companyName ?? 'Unknown';

      if (userCompanyId == 0) {
        throw Exception('No company assigned to this user');
      }

      developer.log('Fetching companies for userCompanyId: $userCompanyId',
          name: 'EmployeeListScreen');

      final companies = await widget.apiService.getCompanies();
      developer.log('Companies received: $companies',
          name: 'EmployeeListScreen');

      final userCompany = companies.firstWhere(
        (c) {
          final companyId =
              c['id'] is String ? int.tryParse(c['id']) : c['id'] as int?;
          return companyId == userCompanyId;
        },
        orElse: () => {
          'id': userCompanyId,
          'company_name': userCompanyName,
        },
      );

      setState(() {
        _companyId = userCompanyId;
        _companyName =
            userCompany['company_name']?.toString() ?? userCompanyName;
        _isLoadingCompanies = false;
      });

      developer.log('Selected company: $_companyName (ID: $_companyId)',
          name: 'EmployeeListScreen');

      await _fetchEmployees();
    } catch (e) {
      developer.log('Error fetching companies: $e', name: 'EmployeeListScreen');
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e);
        _isLoadingCompanies = false;
        _isLoading = false;
        _companyId = _userModel.companyId;
        _companyName = _userModel.companyName ?? 'Unknown';
      });

      if (_companyId != null && _companyId != 0) {
        await _fetchEmployees();
      } else {
        setState(() {
          _errorMessage = 'No company assigned to this user';
        });
      }
    }
  }

  Future<void> _fetchEmployees() async {
    if (_companyId == null || _companyId == 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      developer.log('Fetching employees for companyId: $_companyId',
          name: 'EmployeeListScreen');
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      developer.log('Employees received: $employees',
          name: 'EmployeeListScreen');
      setState(() {
        _employees = employees
            .map((e) => {
                  ...e,
                  'employee_status':
                      ['Active', 'Inactive'].contains(e['employee_status'])
                          ? e['employee_status']
                          : 'Active',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error fetching employees: $e', name: 'EmployeeListScreen');
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(
      String action, String employeeName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Confirm $action', style: TextStyle(color: Colors.teal[900])),
        content: Text(
          'Are you sure you want to $action ${employeeName.toLowerCase()}?',
          style: TextStyle(color: Colors.grey[800]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.teal[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showUpdateDialog(Map<String, dynamic> employee) async {
    String? selectedField;
    final TextEditingController controller = TextEditingController();
    final fields = [
      'fullname',
      'national_id',
      'kra_pin',
      'position_name',
      'nssf',
      'nhif',
      'email',
      'tel',
      'basic',
      'house_allowance',
      'gross_pay',
      'bank_name',
      'bank_branch',
      'account_number',
      'employee_status',
    ];
    List<String> positions = [];

    try {
      final positionData = await widget.apiService.getPositions();
      positions = positionData
          .map((p) => p['description']?.toString() ?? '')
          .where((desc) => desc.isNotEmpty)
          .toList();
    } catch (e) {
      developer.log('Error fetching positions: $e', name: 'EmployeeListScreen');
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update Employee: ${employee['fullname']}',
              style: TextStyle(color: Colors.teal[900])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedField,
                hint: Text('Select field to update',
                    style: TextStyle(color: Colors.teal[700])),
                isExpanded: true,
                items: fields.map((field) {
                  return DropdownMenuItem(
                    value: field,
                    child: Text(field.replaceAll('_', ' ').toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedField = value;
                    controller.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: selectedField == null
                      ? 'Enter new value'
                      : 'New ${selectedField!.replaceAll('_', ' ').toUpperCase()}',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.teal[700]),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal[700]!),
                  ),
                ),
                keyboardType: ['basic', 'house_allowance', 'gross_pay']
                        .contains(selectedField)
                    ? TextInputType.number
                    : selectedField == 'employee_status' ||
                            selectedField == 'position_name'
                        ? TextInputType.none
                        : TextInputType.text,
                onTap: selectedField == 'employee_status'
                    ? () async {
                        final status = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Select Status'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('Active'),
                                  onTap: () => Navigator.pop(context, 'Active'),
                                ),
                                ListTile(
                                  title: const Text('Inactive'),
                                  onTap: () =>
                                      Navigator.pop(context, 'Inactive'),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (status != null) {
                          setDialogState(() {
                            controller.text = status;
                          });
                        }
                      }
                    : selectedField == 'position_name'
                        ? () async {
                            final position = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Select Position'),
                                content: positions.isEmpty
                                    ? const Text('No positions available')
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: positions
                                            .map((p) => ListTile(
                                                  title: Text(p),
                                                  onTap: () =>
                                                      Navigator.pop(context, p),
                                                ))
                                            .toList(),
                                      ),
                              ),
                            );
                            if (position != null) {
                              setDialogState(() {
                                controller.text = position;
                              });
                            }
                          }
                        : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.teal[700])),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedField == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text('Please select a field to update'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                if (controller.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text('Please enter a value'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                if (selectedField == 'email' &&
                    !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text('Invalid email format'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                if (selectedField == 'tel' &&
                    !RegExp(r'^\+?[\d\s-]{10,15}$').hasMatch(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text('Invalid phone number format'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                if (selectedField == 'kra_pin' &&
                    !RegExp(r'^[A-Za-z0-9]{10,11}$')
                        .hasMatch(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text(
                            'Invalid KRA PIN (10-11 alphanumeric characters)'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                if (['basic', 'house_allowance', 'gross_pay']
                    .contains(selectedField)) {
                  final value = double.tryParse(controller.text);
                  if (value == null || value < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: const Text(
                              'Please enter a valid positive number'),
                          backgroundColor: Colors.red[700]),
                    );
                    return;
                  }
                }
                if (selectedField == 'employee_status' &&
                    !['Active', 'Inactive'].contains(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text(
                            'Invalid status. Must be Active or Inactive'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                if (selectedField == 'position_name' &&
                    positions.isNotEmpty &&
                    !positions.contains(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text(
                            'Invalid position. Select from available positions'),
                        backgroundColor: Colors.red[700]),
                  );
                  return;
                }

                try {
                  await widget.apiService.updateEmployee(
                    companyId: _companyId!,
                    employeeId: employee['employee_id'].toString(),
                    field: selectedField!,
                    value: controller.text,
                  );
                  try {
                    await widget.apiService.logEmployeeAction({
                      'user_id': _userModel.userId,
                      'action': 'update_employee',
                      'details':
                          'Updated $selectedField for employee ${employee['employee_id']}',
                    });
                  } catch (e) {
                    _failedAuditLogs.add({
                      'user_id': _userModel.userId,
                      'action': 'update_employee',
                      'details':
                          'Updated $selectedField for employee ${employee['employee_id']}',
                      'error': e.toString(),
                    });
                    developer.log('Failed to log employee action: $e',
                        name: 'EmployeeListScreen');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$selectedField updated successfully'),
                        backgroundColor: Colors.teal[700]),
                  );
                  Navigator.pop(context);
                  await _fetchEmployees();
                } catch (e) {
                  developer.log('Error updating employee: $e',
                      name: 'EmployeeListScreen');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(_getFriendlyErrorMessage(e)),
                        backgroundColor: Colors.red[700]),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final List<List<dynamic>> rows = [
        [
          'employee_id',
          'fullname',
          'national_id',
          'kra_pin',
          'position',
          'position_name',
          'nssf',
          'nhif',
          'email',
          'tel',
          'basic',
          'house_allowance',
          'gross_pay',
          'residential_status',
          'employee_type',
          'housing_type',
          'bank_name',
          'bank_branch',
          'account_number',
          'employee_status',
          'update_date',
        ],
        ..._employees.map((employee) => [
              employee['employee_id']?.toString() ?? '',
              employee['fullname']?.toString() ?? '',
              employee['national_id']?.toString() ?? '',
              employee['kra_pin']?.toString() ?? '',
              employee['position']?.toString() ?? '',
              employee['position_name']?.toString() ?? '',
              employee['nssf']?.toString() ?? '',
              employee['nhif']?.toString() ?? '',
              employee['email']?.toString() ?? '',
              employee['tel']?.toString() ?? '',
              employee['basic']?.toString() ?? '',
              employee['house_allowance']?.toString() ?? '',
              employee['gross_pay']?.toString() ?? '',
              employee['residential_status']?.toString() ?? 'Resident',
              employee['employee_type']?.toString() ?? 'Primary Employee',
              employee['housing_type']?.toString() ?? 'Benefit Not Given',
              employee['bank_name']?.toString() ?? '',
              employee['bank_branch']?.toString() ?? '',
              employee['account_number']?.toString() ?? '',
              employee['employee_status']?.toString() ?? 'Active',
              employee['update_date']?.toString() ?? '',
            ]),
      ];

      String csv = const ListToCsvConverter().convert(rows);
      final directory =
          kIsWeb ? null : await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName =
          'employee_list_${_companyName.replaceAll(' ', '_')}_$timestamp.csv';
      late String filePath;

      if (kIsWeb) {
        // Web: Use FilePicker to save file
        final bytes = utf8.encode(csv);
        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (result == null) {
          throw Exception('File save cancelled');
        }
        filePath = result;
      } else {
        // Mobile/Desktop: Save to application documents directory
        filePath = '${directory!.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(csv);
        await Share.shareXFiles([XFile(filePath)],
            text: 'Employee List CSV - $_companyName');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Employee list exported to $filePath'),
            backgroundColor: Colors.teal[700]),
      );
    } catch (e) {
      developer.log('Error exporting to CSV: $e', name: 'EmployeeListScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red[700]),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();
      const columns = [
        'Employee ID',
        'Full Name',
        'National ID',
        'KRA PIN',
        'Position',
        'NSSF',
        'NHIF',
        'Tel',
        'Basic Salary',
        'House Allowance',
        'Gross Pay',
        'Bank Name',
        'Account Number',
        'Status',
        'Last Updated',
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Employee List - $_companyName',
                style:
                    pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: columns,
              data: _employees
                  .map((employee) => [
                        employee['employee_id']?.toString() ?? '',
                        employee['fullname']?.toString() ?? '',
                        employee['national_id']?.toString() ?? '',
                        employee['kra_pin']?.toString() ?? '',
                        employee['position_name']?.toString() ??
                            employee['position']?.toString() ??
                            '',
                        employee['nssf']?.toString() ?? '',
                        employee['nhif']?.toString() ?? '',
                        employee['tel']?.toString() ?? '',
                        employee['basic']?.toString() ?? '',
                        employee['house_allowance']?.toString() ?? '',
                        employee['gross_pay']?.toString() ?? '',
                        employee['bank_name']?.toString() ?? '',
                        employee['account_number']?.toString() ?? '',
                        employee['employee_status']?.toString() ?? 'Active',
                        employee['update_date']?.toString() ?? '',
                      ])
                  .toList(),
              border: pw.TableBorder.all(),
              headerStyle:
                  pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 6),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ],
        ),
      );

      final directory =
          kIsWeb ? null : await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName =
          'employee_list_${_companyName.replaceAll(' ', '_')}_$timestamp.pdf';
      late String filePath;

      if (kIsWeb) {
        // Web: Use FilePicker to save file
        final bytes = await pdf.save();
        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result == null) {
          throw Exception('File save cancelled');
        }
        filePath = result;
      } else {
        // Mobile/Desktop: Save to application documents directory
        filePath = '${directory!.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());
        await Share.shareXFiles([XFile(filePath)],
            text: 'Employee List PDF - $_companyName');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Employee list exported to $filePath'),
            backgroundColor: Colors.teal[700]),
      );
    } catch (e) {
      developer.log('Error exporting to PDF: $e', name: 'EmployeeListScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red[700]),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minTableWidth = MediaQuery.of(context).size.width * 0.9;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Employees - $_companyName',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          developer.log('Notifications tapped', name: 'EmployeeListScreen');
        },
        onProfileTap: () {
          developer.log('Profile tapped', name: 'EmployeeListScreen');
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
        child: _isLoadingCompanies
            ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Company: $_companyName',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[900]),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: Colors.teal[700]))
                          : _errorMessage != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                            color: Colors.teal[900],
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _fetchEmployees,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[700],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Retry'),
                                      ),
                                      if (_errorMessage!
                                          .contains('Access denied'))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: TextButton(
                                            onPressed: () {
                                              developer.log(
                                                  'Re-authenticate clicked',
                                                  name: 'EmployeeListScreen');
                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        const LoginScreen()),
                                              );
                                            },
                                            child: Text('Re-authenticate',
                                                style: TextStyle(
                                                    color: Colors.teal[700])),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : _employees.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No employees found for $_companyName',
                                        style: TextStyle(
                                            color: Colors.teal[900],
                                            fontSize: 16),
                                      ),
                                    )
                                  : Card(
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width -
                                                32,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.teal[50]!
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Scrollbar(
                                          controller:
                                              _horizontalScrollController,
                                          thumbVisibility: true,
                                          thickness: 8.0,
                                          radius: const Radius.circular(4),
                                          child: SingleChildScrollView(
                                            controller:
                                                _horizontalScrollController,
                                            scrollDirection: Axis.horizontal,
                                            child: Container(
                                              constraints: BoxConstraints(
                                                  minWidth: minTableWidth),
                                              child: Scrollbar(
                                                thumbVisibility: true,
                                                thickness: 8.0,
                                                radius:
                                                    const Radius.circular(4),
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  child: DataTable(
                                                    columnSpacing: 16.0,
                                                    dataRowHeight: 60,
                                                    headingRowColor:
                                                        MaterialStateProperty
                                                            .all(Colors
                                                                .teal[100]),
                                                    columns: const [
                                                      DataColumn(
                                                        label: Text(
                                                            'Employee ID',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Full Name',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                            'National ID',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('KRA PIN',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Position',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('NSSF',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('NHIF',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Tel',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                            'Basic Salary',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                            'House Allowance',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Gross Pay',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Bank Name',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                            'Account Number',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Status',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text(
                                                            'Last Updated',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                      DataColumn(
                                                        label: Text('Actions',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .teal)),
                                                      ),
                                                    ],
                                                    rows: _employees
                                                        .map((employee) {
                                                      final isActive = employee[
                                                              'employee_status'] ==
                                                          'Active';
                                                      return DataRow(
                                                        cells: [
                                                          DataCell(Text(
                                                              employee['employee_id']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['fullname']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['national_id']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['kra_pin']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['position_name']
                                                                      ?.toString() ??
                                                                  employee[
                                                                          'position']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['nssf']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['nhif']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['tel']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['basic']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['house_allowance']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['gross_pay']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['bank_name']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['account_number']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['employee_status']
                                                                      ?.toString() ??
                                                                  'Active',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(Text(
                                                              employee['update_date']
                                                                      ?.toString() ??
                                                                  '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      800]))),
                                                          DataCell(
                                                            Row(
                                                              children: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      _showUpdateDialog(
                                                                          employee),
                                                                  style: TextButton.styleFrom(
                                                                      foregroundColor:
                                                                          Colors
                                                                              .teal[700]),
                                                                  child: const Text(
                                                                      'Update'),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      isActive
                                                                          ? null
                                                                          : () async {
                                                                              final confirmed = await _showConfirmationDialog('Activate', employee['fullname']?.toString() ?? 'Employee');
                                                                              if (!confirmed)
                                                                                return;
                                                                              try {
                                                                                await widget.apiService.activateEmployee(
                                                                                  _companyId!,
                                                                                  employee['employee_id'].toString(),
                                                                                );
                                                                                try {
                                                                                  await widget.apiService.logEmployeeAction({
                                                                                    'user_id': _userModel.userId,
                                                                                    'action': 'activate_employee',
                                                                                    'details': 'Activated employee ${employee['employee_id']}',
                                                                                  });
                                                                                } catch (e) {
                                                                                  _failedAuditLogs.add({
                                                                                    'user_id': _userModel.userId,
                                                                                    'action': 'activate_employee',
                                                                                    'details': 'Activated employee ${employee['employee_id']}',
                                                                                    'error': e.toString(),
                                                                                  });
                                                                                  developer.log('Failed to log employee action: $e', name: 'EmployeeListScreen');
                                                                                }
                                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                                  SnackBar(content: const Text('Employee activated'), backgroundColor: Colors.teal[700]),
                                                                                );
                                                                                await _fetchEmployees();
                                                                              } catch (e) {
                                                                                developer.log('Error activating employee: $e', name: 'EmployeeListScreen');
                                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                                  SnackBar(content: Text(_getFriendlyErrorMessage(e)), backgroundColor: Colors.red[700]),
                                                                                );
                                                                              }
                                                                            },
                                                                  style: TextButton.styleFrom(
                                                                      foregroundColor:
                                                                          Colors
                                                                              .teal[700]),
                                                                  child: const Text(
                                                                      'Activate'),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      !isActive
                                                                          ? null
                                                                          : () async {
                                                                              final confirmed = await _showConfirmationDialog('Deactivate', employee['fullname']?.toString() ?? 'Employee');
                                                                              if (!confirmed)
                                                                                return;
                                                                              try {
                                                                                await widget.apiService.deactivateEmployee(
                                                                                  _companyId!,
                                                                                  employee['employee_id'].toString(),
                                                                                );
                                                                                try {
                                                                                  await widget.apiService.logEmployeeAction({
                                                                                    'user_id': _userModel.userId,
                                                                                    'action': 'deactivate_employee',
                                                                                    'details': 'Deactivated employee ${employee['employee_id']}',
                                                                                  });
                                                                                } catch (e) {
                                                                                  _failedAuditLogs.add({
                                                                                    'user_id': _userModel.userId,
                                                                                    'action': 'deactivate_employee',
                                                                                    'details': 'Deactivated employee ${employee['employee_id']}',
                                                                                    'error': e.toString(),
                                                                                  });
                                                                                  developer.log('Failed to log employee action: $e', name: 'EmployeeListScreen');
                                                                                }
                                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                                  SnackBar(content: const Text('Employee deactivated'), backgroundColor: Colors.teal[700]),
                                                                                );
                                                                                await _fetchEmployees();
                                                                              } catch (e) {
                                                                                developer.log('Error deactivating employee: $e', name: 'EmployeeListScreen');
                                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                                  SnackBar(content: Text(_getFriendlyErrorMessage(e)), backgroundColor: Colors.red[700]),
                                                                                );
                                                                              }
                                                                            },
                                                                  style: TextButton.styleFrom(
                                                                      foregroundColor:
                                                                          Colors
                                                                              .teal[700]),
                                                                  child: const Text(
                                                                      'Deactivate'),
                                                                ),
                                                              ],
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
                                    ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _isLoading || _isExporting
                          ? const Center(
                              child:
                                  CircularProgressIndicator(color: Colors.teal))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: _isExporting ? null : _exportToCSV,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Export to CSV'),
                                ),
                                ElevatedButton(
                                  onPressed: _isExporting ? null : _exportToPDF,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Export to PDF'),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }
}
