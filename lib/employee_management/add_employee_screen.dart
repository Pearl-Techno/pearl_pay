import 'dart:convert'; // For utf8.decode
import 'dart:io'; // For File handling on non-web platforms

import 'package:csv/csv.dart'; // For CSV parsing
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  _AddEmployeeScreenState createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _fullnameController = TextEditingController();
  String _selectedCompanyName = '';
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

  final http.Client _httpClient = http.Client();
  final ApiService apiService = ApiService(client: http.Client());

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
    _httpClient.close();
    super.dispose();
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final employeeData = {
        'employee_id': _employeeIdController.text,
        'fullname': _fullnameController.text,
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
      };

      try {
        await apiService.addEmployee(employeeData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee Added: ${employeeData['fullname']}'),
            backgroundColor: Colors.teal[700],
          ),
        );
        _formKey.currentState!.reset();
        setState(() => _selectedCompanyName = '');
      } catch (e) {
        if (kDebugMode) {
          print('Error adding employee: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add employee: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

 Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (kDebugMode) {
          print('No file selected');
        }
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
        if (kDebugMode) {
          print('Failed to load file: No bytes or path available');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load file: No bytes or path available')),
        );
        return;
      }

      if (bytes == null) {
        if (kDebugMode) {
          print('Failed to load file content');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load file content')),
        );
        return;
      }

      final csvString =
          utf8.decode(bytes).trim(); // Remove leading/trailing whitespace
      if (kDebugMode) {
        print('CSV Content:\n$csvString');
      }

      // Parse the entire CSV string at once
      final List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvString);
      if (kDebugMode) {
        print('Parsed CSV Data: $csvData');
      }

      if (csvData.isEmpty || csvData.length < 2) {
        if (kDebugMode) {
          print('CSV file is empty or has no data rows');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty or invalid')),
        );
        return;
      }

      final headers =
          csvData[0].map((h) => h.toString().toLowerCase()).toList();
      if (kDebugMode) {
        print('Parsed Headers: $headers');
      }
      final List<Map<String, dynamic>> employees = [];
      List<String> invalidRows = [];

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.isNotEmpty) {
          final employee = _parseCsvRow(row, headers, i);
          if (employee['isValid']) {
            employees.add(employee);
          } else {
            invalidRows.add(employee['error']);
          }
        }
      }

      if (invalidRows.isNotEmpty) {
        if (kDebugMode) {
          print('Invalid rows detected:');
          for (var error in invalidRows) {
            print(error);
          }
        }
      }

      if (employees.isEmpty) {
        if (kDebugMode) {
          print('No valid employees found in the file');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid employees found in the file')),
        );
        return;
      }

      _showPreviewDialog(employees, invalidRows);
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading file: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
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
      'company_name': '',
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
    };

    for (int j = 0; j < headers.length && j < row.length; j++) {
      final value = row[j]?.toString() ?? '';
      employee[headers[j]] = value;
    }

    if (employee['employee_id'].isEmpty) {
      return {'isValid': false, 'error': 'Row $rowIndex: Missing Employee ID'};
    }
    if (employee['fullname'].isEmpty) {
      return {'isValid': false, 'error': 'Row $rowIndex: Missing Full Name'};
    }
    if (employee['company_name'].isEmpty) {
      return {'isValid': false, 'error': 'Row $rowIndex: Missing Company Name'};
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
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBulkEmployees(
      List<Map<String, dynamic>> employees) async {
    setState(() => _isLoading = true);

    int successCount = 0;
    List<String> failedEmployees = [];

    try {
      for (final employee in employees) {
        try {
          await apiService.addEmployee(employee);
          successCount++;
        } catch (e) {
          failedEmployees.add('${employee['fullname']} - $e');
          if (kDebugMode) {
            print('Failed to add ${employee['fullname']}: $e');
          }
        }
      }

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added $successCount employees'),
            backgroundColor: Colors.teal[700],
          ),
        );
      }

      if (failedEmployees.isNotEmpty) {
        if (kDebugMode) {
          print('Failed employees:');
          for (var error in failedEmployees) {
            print(error);
          }
        }
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
      if (kDebugMode) {
        print('Failed to add employees: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add employees: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
                color: Colors.teal[900],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: fields,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false,
      bool enabled = true,
      void Function(String)? onChanged}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal[900]),
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
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (value) {
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
        style: TextStyle(color: Colors.grey[800]),
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items,
      String selectedItem, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: DropdownButtonFormField<String>(
        value: selectedItem.isNotEmpty ? selectedItem : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal[900]),
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

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add Employee',
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTile(
                        'Personal Information',
                        [
                          _buildTextField(_employeeIdController, 'Employee ID'),
                          _buildTextField(_fullnameController, 'Full Name'),
                          FutureBuilder<List<String>>(
                            future: apiService.getCompanies().then(
                                (companies) => companies
                                    .map((company) =>
                                        company['company_name'].toString())
                                    .toSet()
                                    .toList()),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.teal[700]));
                              } else if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}',
                                    style: TextStyle(color: Colors.red[700]));
                              } else {
                                final companies = snapshot.data ?? [];
                                if (companies.isEmpty) {
                                  return Text('No companies available',
                                      style:
                                          TextStyle(color: Colors.teal[900]));
                                }
                                if (_selectedCompanyName.isEmpty) {
                                  _selectedCompanyName = companies.first;
                                }
                                return _buildDropdownField(
                                  'Company Name',
                                  companies,
                                  _selectedCompanyName,
                                  (value) => setState(
                                      () => _selectedCompanyName = value!),
                                );
                              }
                            },
                          ),
                          _buildTextField(_nationalIdController, 'National ID'),
                          _buildTextField(_kraPinController, 'KRA PIN'),
                          _buildTextField(_nssfController, 'NSSF Number'),
                          _buildTextField(_nhifController, 'NHIF Number'),
                          FutureBuilder<List<String>>(
                            future: apiService.getPositions().then(
                                (positions) => positions
                                    .map((position) =>
                                        position['description'].toString())
                                    .toSet()
                                    .toList()),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.teal[700]));
                              } else if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}',
                                    style: TextStyle(color: Colors.red[700]));
                              } else {
                                final positions = snapshot.data ?? [];
                                if (positions.isEmpty) {
                                  return Text('No positions available',
                                      style:
                                          TextStyle(color: Colors.teal[900]));
                                }
                                if (!_positionController.text.isNotEmpty ||
                                    !positions
                                        .contains(_positionController.text)) {
                                  _positionController.text = positions.first;
                                }
                                return _buildDropdownField(
                                  'Position',
                                  positions,
                                  _positionController.text,
                                  (value) => setState(
                                      () => _positionController.text = value!),
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
                          _buildTextField(_emailController, 'Email'),
                          _buildTextField(_telController, 'Tel'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTile(
                        'Salary Information',
                        [
                          _buildTextField(_basicController, 'Basic Salary',
                              isNumber: true, onChanged: _calculateGrossPay),
                          Row(
                            children: [
                              Checkbox(
                                value: _noHouseAllowance,
                                onChanged: (value) {
                                  setState(() {
                                    _noHouseAllowance = value!;
                                    _calculateGrossPay(_basicController.text);
                                  });
                                },
                                activeColor: Colors.teal[700],
                              ),
                              Text('No House Allowance',
                                  style: TextStyle(color: Colors.teal[900])),
                            ],
                          ),
                          _buildTextField(
                              _houseAllowanceController, 'House Allowance',
                              isNumber: true, enabled: false),
                          _buildTextField(_grossPayController, 'Gross Pay',
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
                            (value) =>
                                setState(() => _residentialStatus = value!),
                          ),
                          _buildDropdownField(
                            'Employee Type',
                            ['Primary Employee', 'Secondary Employee'],
                            _employeeType,
                            (value) => setState(() => _employeeType = value!),
                          ),
                          _buildDropdownField(
                            'Housing Type',
                            ['Benefit Given', 'Benefit Not Given'],
                            _housingType,
                            (value) => setState(() => _housingType = value!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTile(
                        'Bank Information',
                        [
                          _buildTextField(_bankNameController, 'Bank Name'),
                          _buildTextField(_bankBranchController, 'Bank Branch'),
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
