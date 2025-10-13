import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AddEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AddEmployeeScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  _AddEmployeeScreenState createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _fullnameController = TextEditingController();
  int? _selectedCompanyId;
  String? _selectedCompanyName;
  final _nationalIdController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _positionController = TextEditingController();
  final _nssfController = TextEditingController();
  final _nhifController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _basicController = TextEditingController();
  final _houseAllowanceController = TextEditingController(text: '0.00');
  final _grossPayController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankBranchController = TextEditingController();
  final _accountNumberController = TextEditingController();

  String _residentialStatus = 'Resident';
  String _employeeType = 'Primary Employee';
  String _housingType = 'Benefit Not Given';
  bool _noHouseAllowance = false;
  bool _isLoading = false;
  bool _isLoadingCompanies = true;
  List<int> _companyIds = [];
  Map<int, String> _companyIdToName = {};
  List<Map<String, dynamic>> _failedAuditLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoadingCompanies = true);
    try {
      final companyId = widget.user['company_id'];
      if (companyId == null || (companyId is! String && companyId is! int)) {
        throw Exception('Invalid or missing user company ID');
      }
      final parsedCompanyId =
          companyId is String ? int.tryParse(companyId) : companyId as int;
      if (parsedCompanyId == null) {
        throw Exception('Invalid user company ID format');
      }
      final userCompanyName =
          widget.user['company_name']?.toString() ?? 'Unknown';

      final companies = await widget.apiService.getCompanies();
      final userCompany = companies.firstWhere(
        (c) {
          final id =
              c['id'] is String ? int.tryParse(c['id']) : c['id'] as int?;
          return id == parsedCompanyId;
        },
        orElse: () => {
          'id': parsedCompanyId,
          'company_name': userCompanyName,
        },
      );

      setState(() {
        _companyIds = [parsedCompanyId];
        _companyIdToName = {
          parsedCompanyId:
              userCompany['company_name']?.toString() ?? userCompanyName
        };
        _selectedCompanyId = parsedCompanyId;
        _selectedCompanyName =
            _companyIdToName[parsedCompanyId] ?? userCompanyName;
        _isLoadingCompanies = false;
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red[700],
          ),
        );
        _isLoadingCompanies = false;
      });
    }
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _fullnameController.dispose();
    _nationalIdController.dispose();
    _kraPinController.dispose();
    _positionController.dispose();
    _nssfController.dispose();
    _nhifController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _basicController.dispose();
    _houseAllowanceController.dispose();
    _grossPayController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();
    if (message.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (message.contains('duplicate')) {
      return 'Employee ID already exists.';
    }
    return 'An unexpected error occurred: $error';
  }

  void _calculateGrossPay(String value) {
    final basicSalary = double.tryParse(_basicController.text) ?? 0.0;
    final houseAllowance = _noHouseAllowance ? 0.0 : basicSalary * 0.15;
    final grossPay = basicSalary + houseAllowance;

    setState(() {
      _houseAllowanceController.text = houseAllowance.toStringAsFixed(2);
      _grossPayController.text = grossPay.toStringAsFixed(2);
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _employeeIdController.clear();
    _fullnameController.clear();
    _nationalIdController.clear();
    _kraPinController.clear();
    _nssfController.clear();
    _nhifController.clear();
    _emailController.clear();
    _telController.clear();
    _basicController.clear();
    _houseAllowanceController.text = '0.00';
    _grossPayController.clear();
    _bankNameController.clear();
    _bankBranchController.clear();
    _accountNumberController.clear();
    setState(() {
      _noHouseAllowance = false;
      _residentialStatus = 'Resident';
      _employeeType = 'Primary Employee';
      _housingType = 'Benefit Not Given';
      _positionController.clear();
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCompanyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a company'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final employeeData = {
        'employee_id': _employeeIdController.text,
        'fullname': _fullnameController.text,
        'company_id': _selectedCompanyId,
        'company_name': _selectedCompanyName,
        'national_id': _nationalIdController.text,
        'kra_pin': _kraPinController.text,
        'position': _positionController.text,
        'nssf': _nssfController.text,
        'nhif': _nhifController.text,
        'email': _emailController.text,
        'tel': _telController.text,
        'basic': _basicController.text,
        'house_allowance': _houseAllowanceController.text,
        'gross_pay': _grossPayController.text,
        'residential_status': _residentialStatus,
        'employee_type': _employeeType,
        'housing_type': _housingType,
        'bank_name': _bankNameController.text,
        'bank_branch': _bankBranchController.text,
        'account_number': _accountNumberController.text,
        'added_by': widget.user['user_id'].toString(),
      };

      try {
        await widget.apiService.addEmployee(employeeData, _selectedCompanyId!);

        try {
          await widget.apiService.logEmployeeAction({
            'user_id': widget.user['user_id'],
            'employee_name': _fullnameController.text,
            'action': 'add',
          });
        } catch (e) {
          _failedAuditLogs.add({
            'user_id': widget.user['user_id'],
            'employee_name': _fullnameController.text,
            'action': 'add',
            'error': e.toString(),
          });
          if (kDebugMode) {
            print('Failed to log employee action: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee Added: ${employeeData['fullname']}'),
            backgroundColor: Colors.teal[700],
          ),
        );

        _resetForm();
      } catch (e) {
        if (kDebugMode) {
          print('Error adding employee: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red[700],
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        return;
      }

      final file = result.files.single;
      Uint8List? bytes;

      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        final fileOnDevice = File(file.path!);
        bytes = await fileOnDevice.readAsBytes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load file: No bytes or path available')),
        );
        return;
      }

      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load file content')),
        );
        return;
      }

      final csvString = utf8.decode(bytes).trim();
      final List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty || csvData.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty or invalid')),
        );
        return;
      }

      final headers =
          csvData[0].map((h) => h.toString().toLowerCase()).toList();
      final requiredHeaders = ['employee_id', 'fullname', 'basic', 'gross_pay'];
      if (!requiredHeaders.every((h) => headers.contains(h))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('CSV missing required headers: $requiredHeaders')),
        );
        return;
      }

      final List<Map<String, dynamic>> employees = [];
      List<String> invalidRows = [];

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length >= headers.length) {
          final employee = _parseCsvRow(row, headers, i);
          if (employee['isValid']) {
            employees.add(employee);
          } else {
            invalidRows.add(employee['error']);
          }
        } else {
          invalidRows.add(
              'Row $i: Incomplete data (expected ${headers.length} columns, found ${row.length})');
        }
      }

      if (employees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid employees found in the file')),
        );
        return;
      }

      _showPreviewDialog(employees, invalidRows);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getFriendlyErrorMessage(e)),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _parseCsvRow(
      List<dynamic> row, List<String> headers, int rowIndex) {
    final employee = <String, dynamic>{
      'employee_id': '',
      'fullname': '',
      'company_id': _selectedCompanyId ?? widget.user['company_id'],
      'company_name': _selectedCompanyName ?? widget.user['company_name'],
      'national_id': '',
      'kra_pin': '',
      'position': '',
      'nssf': '',
      'nhif': '',
      'email': '',
      'tel': '',
      'basic': '',
      'house_allowance': '0.00',
      'gross_pay': '',
      'residential_status': 'Resident',
      'employee_type': 'Primary Employee',
      'housing_type': 'Benefit Not Given',
      'bank_name': '',
      'bank_branch': '',
      'account_number': '',
      'added_by': widget.user['user_id'].toString(),
    };

    for (int j = 0; j < headers.length && j < row.length; j++) {
      final value = row[j]?.toString() ?? '';
      if (headers[j] != 'company_name' && headers[j] != 'company_id') {
        employee[headers[j]] = value;
      }
    }

    if (employee['employee_id'].isEmpty) {
      return {'isValid': false, 'error': 'Row $rowIndex: Missing Employee ID'};
    }
    if (employee['fullname'].isEmpty) {
      return {'isValid': false, 'error': 'Row $rowIndex: Missing Full Name'};
    }
    if (employee['basic'].isEmpty ||
        double.tryParse(employee['basic']) == null) {
      return {
        'isValid': false,
        'error': 'Row $rowIndex: Missing or invalid Basic Salary'
      };
    }
    if (employee['gross_pay'].isEmpty ||
        double.tryParse(employee['gross_pay']) == null) {
      return {
        'isValid': false,
        'error': 'Row $rowIndex: Missing or invalid Gross Pay'
      };
    }

    final basicValue = double.parse(employee['basic']);
    final houseAllowance = employee['housing_type'] == 'Benefit Not Given'
        ? 0.0
        : (double.tryParse(employee['house_allowance']) ?? (basicValue * 0.15));
    employee['house_allowance'] = houseAllowance.toStringAsFixed(2);
    employee['gross_pay'] = (basicValue + houseAllowance).toStringAsFixed(2);

    return {'isValid': true, 'error': '', ...employee};
  }

  void _showPreviewDialog(
      List<Map<String, dynamic>> employees, List<String> invalidRows) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Employee Data Preview',
            style: TextStyle(color: Colors.teal[900])),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.teal[100]),
                    columns: [
                      _buildDataColumn('Employee ID'),
                      _buildDataColumn('Full Name'),
                      _buildDataColumn('Company Name'),
                      _buildDataColumn('National ID'),
                      _buildDataColumn('KRA PIN'),
                      _buildDataColumn('Position'),
                      _buildDataColumn('NSSF'),
                      _buildDataColumn('NHIF'),
                      _buildDataColumn('Email'),
                      _buildDataColumn('Tel'),
                      _buildDataColumn('Basic'),
                      _buildDataColumn('House Allowance'),
                      _buildDataColumn('Gross Pay'),
                      _buildDataColumn('Residential Status'),
                      _buildDataColumn('Employee Type'),
                      _buildDataColumn('Housing Type'),
                      _buildDataColumn('Bank Name'),
                      _buildDataColumn('Bank Branch'),
                      _buildDataColumn('Account Number'),
                    ],
                    rows: employees.map((employee) {
                      return DataRow(cells: [
                        _buildDataCell(employee['employee_id']),
                        _buildDataCell(employee['fullname']),
                        _buildDataCell(employee['company_name']),
                        _buildDataCell(employee['national_id']),
                        _buildDataCell(employee['kra_pin']),
                        _buildDataCell(employee['position']),
                        _buildDataCell(employee['nssf']),
                        _buildDataCell(employee['nhif']),
                        _buildDataCell(employee['email']),
                        _buildDataCell(employee['tel']),
                        _buildDataCell(employee['basic']),
                        _buildDataCell(employee['house_allowance']),
                        _buildDataCell(employee['gross_pay']),
                        _buildDataCell(employee['residential_status']),
                        _buildDataCell(employee['employee_type']),
                        _buildDataCell(employee['housing_type']),
                        _buildDataCell(employee['bank_name']),
                        _buildDataCell(employee['bank_branch']),
                        _buildDataCell(employee['account_number']),
                      ]);
                    }).toList(),
                  ),
                  if (invalidRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Invalid Rows:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700])),
                    ...invalidRows.map((error) =>
                        Text(error, style: TextStyle(color: Colors.red[700]))),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.teal[700])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitBulkEmployees(employees);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Stream<int> _processEmployees(List<Map<String, dynamic>> employees) async* {
    for (int i = 0; i < employees.length; i++) {
      yield i + 1;
      final employee = employees[i];
      try {
        final companyId = employee['company_id'] as int;
        await widget.apiService.addEmployee(employee, companyId);

        try {
          await widget.apiService.logEmployeeAction({
            'user_id': widget.user['user_id'],
            'employee_name': employee['fullname'],
            'action': 'add',
          });
        } catch (e) {
          _failedAuditLogs.add({
            'user_id': widget.user['user_id'],
            'employee_name': employee['fullname'],
            'action': 'add',
            'error': e.toString(),
          });
          if (kDebugMode) {
            print('Failed to log employee action: $e');
          }
        }
      } catch (e) {
        throw e; // Let the caller handle the error
      }
    }
  }

  Future<void> _submitBulkEmployees(
      List<Map<String, dynamic>> employees) async {
    setState(() => _isLoading = true);
    int successCount = 0;
    List<String> failedEmployees = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: StreamBuilder<int>(
          stream: _processEmployees(employees),
          builder: (context, snapshot) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.teal[700]),
                const SizedBox(height: 16),
                Text(
                    'Processing ${snapshot.data ?? 0}/${employees.length} employees'),
              ],
            );
          },
        ),
      ),
    );

    try {
      for (final employee in employees) {
        try {
          final companyId = employee['company_id'] as int;
          await widget.apiService.addEmployee(employee, companyId);
          successCount++;
        } catch (e) {
          failedEmployees
              .add('${employee['fullname']} - ${_getFriendlyErrorMessage(e)}');
          if (kDebugMode) {
            print('Failed to add ${employee['fullname']}: $e');
          }
        }
      }

      Navigator.pop(context); // Close progress dialog

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added $successCount employees'),
            backgroundColor: Colors.teal[700],
          ),
        );
      }

      if (failedEmployees.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('Failed Employees',
                style: TextStyle(color: Colors.teal[900])),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: failedEmployees
                    .map((e) =>
                        Text(e, style: TextStyle(color: Colors.red[700])))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: Colors.teal[700])),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getFriendlyErrorMessage(e)),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadCsvTemplate() async {
    final template =
        '''employee_id,fullname,national_id,kra_pin,position,nssf,nhif,email,tel,basic,house_allowance,gross_pay,residential_status,employee_type,housing_type,bank_name,bank_branch,account_number
E001,John Doe,12345678,ABC123,Manager,NS123,NH123,john@example.com,1234567890,50000.00,7500.00,57500.00,Resident,Primary Employee,Benefit Given,Bank ABC,Main Branch,123456789''';
    try {
      final bytes = utf8.encode(template);
      final result = await FilePicker.platform.saveFile(
        fileName: 'employee_template.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV template downloaded to $result')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template download cancelled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getFriendlyErrorMessage(e)),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Widget _buildSectionTile(String title, List<Widget> fields) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.teal[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[900]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 16.0, runSpacing: 16.0, children: fields),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field
    final phoneRegex = RegExp(r'^\+?\d{10,12}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number (10-12 digits)';
    }
    return null;
  }

  String? _validateKraPin(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field
    final kraPinRegex = RegExp(r'^[A-Za-z0-9]{10,11}$');
    if (!kraPinRegex.hasMatch(value)) {
      return 'Please enter a valid KRA PIN (10-11 alphanumeric characters)';
    }
    return null;
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.teal[900]),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator ??
            (value) {
              if ((label == 'Employee ID' ||
                      label == 'Full Name' ||
                      label == 'Basic Salary' ||
                      label == 'Gross Pay') &&
                  (value == null || value.isEmpty)) {
                return 'Please enter $label';
              }
              if ((label == 'Basic Salary' || label == 'Gross Pay') &&
                  value != null &&
                  double.tryParse(value) == null) {
                return 'Please enter a valid number for $label';
              }
              return null;
            },
        enabled: enabled,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    String selectedItem,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: DropdownButtonFormField<String>(
        value: selectedItem.isNotEmpty ? selectedItem : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.teal[900]),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: TextStyle(color: Colors.teal[900])),
                ))
            .toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.teal[700]),
      ),
    );
  }

  Widget _buildCompanyField() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: TextFormField(
        initialValue:
            _selectedCompanyName ?? widget.user['company_name'] ?? 'Unknown',
        decoration: InputDecoration(
          labelText: 'Company Name',
          labelStyle: TextStyle(fontSize: 14, color: Colors.teal[900]),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        enabled: false,
        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Company name is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.3,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
            fontWeight: FontWeight.w600, color: Colors.teal[900], fontSize: 14),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Text(
        text,
        style: TextStyle(color: Colors.grey[800], fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add Employee - ${widget.user['company_name']}',
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
        child: _isLoadingCompanies
            ? Center(child: CircularProgressIndicator(color: Colors.teal[700]))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildActionButton(
                                    'Download Template', _downloadCsvTemplate),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTile(
                              'Personal Information',
                              [
                                _buildTextField(
                                    _employeeIdController, 'Employee ID'),
                                _buildTextField(
                                    _fullnameController, 'Full Name'),
                                _buildCompanyField(),
                                _buildTextField(
                                    _nationalIdController, 'National ID'),
                                _buildTextField(_kraPinController, 'KRA PIN',
                                    validator: _validateKraPin),
                                _buildTextField(_nssfController, 'NSSF Number'),
                                _buildTextField(_nhifController, 'NHIF Number'),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: widget.apiService.getPositions(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.teal[700]));
                                    } else if (snapshot.hasError) {
                                      return Text('Error: ${snapshot.error}',
                                          style: TextStyle(
                                              color: Colors.red[700]));
                                    } else {
                                      final positions = snapshot.data ?? [];
                                      if (positions.isEmpty) {
                                        return Column(
                                          children: [
                                            Text('No positions available',
                                                style: TextStyle(
                                                    color: Colors.teal[900])),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pushNamed(
                                                      context, '/add_position'),
                                              child: Text('Add a Position',
                                                  style: TextStyle(
                                                      color: Colors.teal[700])),
                                            ),
                                          ],
                                        );
                                      }
                                      final positionDescriptions = positions
                                          .map((p) =>
                                              p['description']?.toString() ??
                                              '')
                                          .where((desc) => desc.isNotEmpty)
                                          .toSet()
                                          .toList();
                                      if (positionDescriptions.isEmpty) {
                                        return Text(
                                            'No valid positions available',
                                            style: TextStyle(
                                                color: Colors.teal[900]));
                                      }
                                      if (!_positionController
                                              .text.isNotEmpty ||
                                          !positionDescriptions.contains(
                                              _positionController.text)) {
                                        _positionController.text =
                                            positionDescriptions.first;
                                      }
                                      return _buildDropdownField(
                                        'Position',
                                        positionDescriptions,
                                        _positionController.text,
                                        (value) => setState(() =>
                                            _positionController.text = value!),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTile(
                              'Contact Information',
                              [
                                _buildTextField(_emailController, 'Email',
                                    validator: _validateEmail),
                                _buildTextField(_telController, 'Tel',
                                    validator: _validatePhone),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTile(
                              'Salary Information',
                              [
                                _buildTextField(
                                    _basicController, 'Basic Salary',
                                    isNumber: true,
                                    onChanged: _calculateGrossPay),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _noHouseAllowance,
                                      onChanged: (value) {
                                        setState(() {
                                          _noHouseAllowance = value!;
                                          _calculateGrossPay(
                                              _basicController.text);
                                        });
                                      },
                                      activeColor: Colors.teal[700],
                                    ),
                                    Text('No House Allowance',
                                        style:
                                            TextStyle(color: Colors.teal[900])),
                                  ],
                                ),
                                _buildTextField(_houseAllowanceController,
                                    'House Allowance',
                                    isNumber: true, enabled: false),
                                _buildTextField(
                                    _grossPayController, 'Gross Pay',
                                    isNumber: true, enabled: false),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTile(
                              'Additional Information',
                              [
                                _buildDropdownField(
                                  'Residential Status',
                                  ['Resident', 'Non-resident'],
                                  _residentialStatus,
                                  (value) => setState(
                                      () => _residentialStatus = value!),
                                ),
                                _buildDropdownField(
                                  'Employee Type',
                                  ['Primary Employee', 'Secondary Employee'],
                                  _employeeType,
                                  (value) =>
                                      setState(() => _employeeType = value!),
                                ),
                                _buildDropdownField(
                                  'Housing Type',
                                  ['Benefit Given', 'Benefit Not Given'],
                                  _housingType,
                                  (value) =>
                                      setState(() => _housingType = value!),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTile(
                              'Bank Information',
                              [
                                _buildTextField(
                                    _bankNameController, 'Bank Name'),
                                _buildTextField(
                                    _bankBranchController, 'Bank Branch'),
                                _buildTextField(
                                    _accountNumberController, 'Account Number'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton('Add Employee', _submitForm),
                                _buildActionButton('Upload CSV', _pickFile),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
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
