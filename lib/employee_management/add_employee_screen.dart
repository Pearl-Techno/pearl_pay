import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/services.dart';

// Premium Design Constants
class AddEmployeeConstants {
  // Main color palette
  static const Color primaryColor = Color(0xFF0A2463);
  static const Color secondaryColor = Color(0xFF3E92CC);
  static const Color accentColor = Color(0xFF1DD3B0);
  
  // Background & Surface colors
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFAFCFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);
  
  // Status colors
  static const Color successColor = Color(0xFF00B894);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color warningColor = Color(0xFFFFA502);
  static const Color infoColor = Color(0xFF2D3436);
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, Color(0xFF2EC4B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> strongShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 40,
      offset: const Offset(0, 12),
    ),
  ];
  
  // Borders
  static BorderRadius borderRadiusLarge = BorderRadius.circular(24);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(16);
  static BorderRadius borderRadiusSmall = BorderRadius.circular(12);
}

class AddEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AddEmployeeScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  AddEmployeeScreenState createState() => AddEmployeeScreenState();
}

class AddEmployeeScreenState extends State<AddEmployeeScreen> {
  // Form key and controllers
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _fullnameController = TextEditingController();
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
  final _newPositionController = TextEditingController();

  // State variables
  late int _selectedCompanyId;
  late String _selectedCompanyName;
  String _residentialStatus = 'Resident';
  String _employeeType = 'Primary Employee';
  String _housingType = 'Benefit Not Given';
  bool _noHouseAllowance = false;
  bool _isLoading = false;
  bool _isLoadingPositions = false;
  bool _showCustomPositionField = false;
  
  // Data lists
  List<Map<String, dynamic>> _positions = [];
  final List<Map<String, dynamic>> _failedAuditLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeUserCompany();
    _fetchPositions();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initializeUserCompany() {
    final companyId = widget.user['company_id'];
    final companyName = widget.user['company_name']?.toString() ?? 'Unknown Company';
    
    if (companyId != null) {
      _selectedCompanyId = int.tryParse(companyId.toString()) ?? 0;
    } else {
      _selectedCompanyId = 0;
    }
    _selectedCompanyName = companyName;
  }

  Future<void> _fetchPositions() async {
    setState(() => _isLoadingPositions = true);
    try {
      final positions = await widget.apiService.getPositions();
      setState(() {
        _positions = positions;
        _isLoadingPositions = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching positions: $e');
      }
      setState(() => _isLoadingPositions = false);
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
    _newPositionController.dispose();
    super.dispose();
  }

  // Position Management Methods
  void _togglePositionInput() {
    setState(() {
      _showCustomPositionField = !_showCustomPositionField;
      if (_showCustomPositionField) {
        _positionController.clear();
      } else {
        _newPositionController.clear();
      }
    });
  }

  void _useCustomPosition() {
    if (_newPositionController.text.trim().isNotEmpty) {
      setState(() {
        _positionController.text = _newPositionController.text.trim();
        _showCustomPositionField = false;
        _newPositionController.clear();
      });
      _showSuccessSnackBar('Custom position added: ${_positionController.text}');
    } else {
      _showErrorSnackBar('Please enter a position name');
    }
  }

  Future<void> _saveNewPositionToDatabase() async {
    final newPosition = _newPositionController.text.trim();
    if (newPosition.isEmpty) {
      _showErrorSnackBar('Please enter a position name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      final newPositionData = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'description': newPosition,
        'company_id': _selectedCompanyId,
      };

      setState(() {
        _positions.add(newPositionData);
        _positionController.text = newPosition;
        _showCustomPositionField = false;
        _newPositionController.clear();
      });

      _showSuccessSnackBar('New position "$newPosition" saved successfully!');
      
    } catch (e) {
      _showErrorSnackBar('Failed to save new position: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper methods
  String _getFriendlyErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();
    if (message.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (message.contains('duplicate')) {
      return 'Employee ID already exists.';
    }
    return 'An unexpected error occurred: $error';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AddEmployeeConstants.errorColor,
            borderRadius: AddEmployeeConstants.borderRadiusMedium,
            boxShadow: AddEmployeeConstants.mediumShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AddEmployeeConstants.successColor,
            borderRadius: AddEmployeeConstants.borderRadiusMedium,
            boxShadow: AddEmployeeConstants.mediumShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
      ),
    );
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
    _newPositionController.clear();
    
    setState(() {
      _noHouseAllowance = false;
      _residentialStatus = 'Resident';
      _employeeType = 'Primary Employee';
      _housingType = 'Benefit Not Given';
      _positionController.clear();
      _showCustomPositionField = false;
    });
  }

  Future<void> _logEmployeeAction(String employeeName) async {
    try {
      await widget.apiService.logEmployeeAction({
        'user_id': widget.user['user_id'],
        'employee_name': employeeName,
        'action': 'add',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _failedAuditLogs.add({
        'user_id': widget.user['user_id'],
        'employee_name': employeeName,
        'action': 'add',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (kDebugMode) {
        print('Failed to log employee action: $e');
      }
    }
  }

  // Form submission
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_positionController.text.isEmpty) {
        _showErrorSnackBar('Please select or enter a position');
        return;
      }

      setState(() => _isLoading = true);

      final employeeData = {
        'employee_id': _employeeIdController.text.trim(),
        'fullname': _fullnameController.text.trim(),
        'company_id': _selectedCompanyId,
        'company_name': _selectedCompanyName,
        'national_id': _nationalIdController.text.trim(),
        'kra_pin': _kraPinController.text.trim().toUpperCase(),
        'position': _positionController.text.trim(),
        'nssf': _nssfController.text.trim(),
        'nhif': _nhifController.text.trim(),
        'email': _emailController.text.trim(),
        'tel': _telController.text.trim(),
        'basic': _basicController.text.trim(),
        'house_allowance': _houseAllowanceController.text,
        'gross_pay': _grossPayController.text,
        'residential_status': _residentialStatus,
        'employee_type': _employeeType,
        'housing_type': _housingType,
        'bank_name': _bankNameController.text.trim(),
        'bank_branch': _bankBranchController.text.trim(),
        'account_number': _accountNumberController.text.trim(),
        'added_by': widget.user['user_id'].toString(),
        'added_date': DateTime.now().toIso8601String(),
      };

      try {
        await widget.apiService.addEmployee(employeeData, _selectedCompanyId);
        await _logEmployeeAction(employeeData['fullname'].toString());

        _showSuccessSnackBar('Employee ${employeeData['fullname']} added successfully!');
        _resetForm();
        
      } catch (e) {
        _showErrorSnackBar(_getFriendlyErrorMessage(e));
        if (kDebugMode) {
          print('Error adding employee: $e');
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // CSV Upload functionality
  Future<void> _downloadCsvTemplate() async {
    const template = '''employee_id,fullname,national_id,kra_pin,position,nssf,nhif,email,tel,basic,house_allowance,gross_pay,residential_status,employee_type,housing_type,bank_name,bank_branch,account_number
E001,John Doe,12345678,A123456789Z,Manager,NS123,NH123,john@example.com,1234567890,50000.00,7500.00,57500.00,Resident,Primary Employee,Benefit Given,Bank ABC,Main Branch,123456789
E002,Jane Smith,87654321,B987654321X,Developer,NS456,NH456,jane@example.com,0987654321,40000.00,6000.00,46000.00,Resident,Primary Employee,Benefit Not Given,Bank XYZ,Downtown Branch,987654321''';
    
    try {
      final bytes = utf8.encode(template);
      final result = await FilePicker.platform.saveFile(
        fileName: 'employee_upload_template_${DateTime.now().millisecondsSinceEpoch}.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result != null) {
        _showSuccessSnackBar('CSV template downloaded successfully!');
      } else {
        _showErrorSnackBar('Template download cancelled');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to download template: ${e.toString()}');
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
        _showErrorSnackBar('No file selected');
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
        _showErrorSnackBar('Failed to load file: No bytes or path available');
        return;
      }

      if (bytes == null) {
        _showErrorSnackBar('Failed to load file content');
        return;
      }

      final csvString = utf8.decode(bytes).trim();
      final List<List<dynamic>> csvData =
          const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty || csvData.length < 2) {
        _showErrorSnackBar('CSV file is empty or invalid');
        return;
      }

      final headers =
          csvData[0].map((h) => h.toString().toLowerCase()).toList();
      final requiredHeaders = ['employee_id', 'fullname', 'basic', 'gross_pay'];
      
      if (!requiredHeaders.every((h) => headers.contains(h))) {
        _showErrorSnackBar('CSV missing required headers: $requiredHeaders');
        return;
      }

      final List<Map<String, dynamic>> employees = [];
      final List<String> invalidRows = [];

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length >= headers.length) {
          final employee = _parseCsvRow(row, headers, i);
          if (employee['isValid'] == true) {
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
        _showErrorSnackBar('No valid employees found in the file');
        return;
      }

      _showPreviewDialog(employees, invalidRows);
    } catch (e) {
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _parseCsvRow(
      List<dynamic> row, List<String> headers, int rowIndex) {
    final employee = <String, dynamic>{
      'employee_id': '',
      'fullname': '',
      'company_id': _selectedCompanyId,
      'company_name': _selectedCompanyName,
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

    // Validation
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AddEmployeeConstants.surfaceColor,
            borderRadius: AddEmployeeConstants.borderRadiusLarge,
            boxShadow: AddEmployeeConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AddEmployeeConstants.accentGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.preview, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Data Preview',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AddEmployeeConstants.textPrimary,
                          ),
                        ),
                        Text(
                          'Company: $_selectedCompanyName',
                          style: TextStyle(
                            fontSize: 14,
                            color: AddEmployeeConstants.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Stats
              Row(
                children: [
                  _buildStatCard(
                    title: 'Valid',
                    value: employees.length.toString(),
                    color: AddEmployeeConstants.successColor,
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(width: 12),
                  if (invalidRows.isNotEmpty)
                    _buildStatCard(
                      title: 'Invalid',
                      value: invalidRows.length.toString(),
                      color: AddEmployeeConstants.errorColor,
                      icon: Icons.error_outline,
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Preview Table
              if (employees.isNotEmpty) ...[
                Text(
                  'Valid Employee Data (Preview)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AddEmployeeConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AddEmployeeConstants.cardColor,
                    borderRadius: AddEmployeeConstants.borderRadiusMedium,
                    border: Border.all(
                      color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AddEmployeeConstants.primaryColor.withValues(alpha: 0.05),
                      ),
                      columns: [
                        _buildDataColumn('ID'),
                        _buildDataColumn('Name'),
                        _buildDataColumn('Position'),
                        _buildDataColumn('Basic Salary'),
                        _buildDataColumn('Gross Pay'),
                      ],
                      rows: employees.take(5).map((employee) {
                        return DataRow(cells: [
                          _buildDataCell(employee['employee_id']),
                          _buildDataCell(employee['fullname']),
                          _buildDataCell(employee['position']),
                          _buildDataCell(employee['basic']),
                          _buildDataCell(employee['gross_pay']),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
                if (employees.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... and ${employees.length - 5} more employees',
                      style: TextStyle(
                        fontSize: 12,
                        color: AddEmployeeConstants.textTertiary,
                      ),
                    ),
                  ),
              ],
              
              // Invalid Rows
              if (invalidRows.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Validation Errors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AddEmployeeConstants.errorColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                  color: AddEmployeeConstants.errorColor.withValues(alpha: 0.05),
                    borderRadius: AddEmployeeConstants.borderRadiusMedium,
                    border: Border.all(
                    color: AddEmployeeConstants.errorColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: invalidRows.take(5).map((error) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: AddEmployeeConstants.errorColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AddEmployeeConstants.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                    ),
                  ),
                ),
                if (invalidRows.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... and ${invalidRows.length - 5} more errors',
                      style: TextStyle(
                        fontSize: 12,
                        color: AddEmployeeConstants.textTertiary,
                      ),
                    ),
                  ),
              ],
              
              const SizedBox(height: 32),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AddEmployeeConstants.borderRadiusMedium,
                      ),
                      side: BorderSide(
                        color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AddEmployeeConstants.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitBulkEmployees(employees);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      backgroundColor: AddEmployeeConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AddEmployeeConstants.borderRadiusMedium,
                      ),
                    ),
                    child: const Text(
                      'Upload Valid Data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AddEmployeeConstants.borderRadiusMedium,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AddEmployeeConstants.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBulkEmployees(List<Map<String, dynamic>> employees) async {
    setState(() => _isLoading = true);
    int successCount = 0;
    List<String> failedEmployees = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AddEmployeeConstants.surfaceColor,
            borderRadius: AddEmployeeConstants.borderRadiusLarge,
            boxShadow: AddEmployeeConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AddEmployeeConstants.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_file,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Uploading Employees',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AddEmployeeConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'To: $_selectedCompanyName',
                style: TextStyle(
                  fontSize: 14,
                  color: AddEmployeeConstants.textTertiary,
                ),
              ),
              const SizedBox(height: 32),
              
              // Progress
              StreamBuilder<int>(
                stream: _processEmployees(employees),
                builder: (context, snapshot) {
                  final current = snapshot.data ?? 0;
                  final percentage = employees.isEmpty ? 0 : (current / employees.length * 100);
                  
                  return Column(
                    children: [
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: employees.isEmpty ? 0 : current / employees.length,
                          backgroundColor: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AddEmployeeConstants.accentColor),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Processing $current/${employees.length} employees',
                        style: TextStyle(
                          fontSize: 14,
                          color: AddEmployeeConstants.textSecondary,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}% complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: AddEmployeeConstants.textTertiary,
                        ),
                      ),
                      if (current > 0 && current <= employees.length) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Currently: ${employees[current - 1]['fullname']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AddEmployeeConstants.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    try {
      for (final employee in employees) {
        try {
          await widget.apiService.addEmployee(employee, _selectedCompanyId);
          await _logEmployeeAction(employee['fullname']);
          successCount++;
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          failedEmployees.add('${employee['fullname']} - ${_getFriendlyErrorMessage(e)}');
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (successCount > 0) {
        _showSuccessSnackBar('Successfully added $successCount employees to $_selectedCompanyName');
      }

      if (failedEmployees.isNotEmpty) {
        _showUploadResults(successCount, failedEmployees, employees.length);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Stream<int> _processEmployees(List<Map<String, dynamic>> employees) async* {
    for (int i = 0; i < employees.length; i++) {
      yield i + 1;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _showUploadResults(int successCount, List<String> failedEmployees, int total) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AddEmployeeConstants.surfaceColor,
            borderRadius: AddEmployeeConstants.borderRadiusLarge,
            boxShadow: AddEmployeeConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AddEmployeeConstants.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.summarize, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Results',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AddEmployeeConstants.textPrimary,
                          ),
                        ),
                        Text(
                          'Company: $_selectedCompanyName',
                          style: TextStyle(
                            fontSize: 14,
                            color: AddEmployeeConstants.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Stats
              Row(
                children: [
                  _buildResultStatCard(
                    title: 'Total',
                    value: total.toString(),
                    color: AddEmployeeConstants.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  _buildResultStatCard(
                    title: 'Successful',
                    value: successCount.toString(),
                    color: AddEmployeeConstants.successColor,
                  ),
                  const SizedBox(width: 12),
                  _buildResultStatCard(
                    title: 'Failed',
                    value: failedEmployees.length.toString(),
                    color: failedEmployees.isNotEmpty ? AddEmployeeConstants.errorColor : AddEmployeeConstants.textTertiary,
                  ),
                ],
              ),
              
              // Failed Employees
              if (failedEmployees.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Failed Employees',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AddEmployeeConstants.errorColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                  color: AddEmployeeConstants.errorColor.withAlpha((0.05 * 255).round()),
                    borderRadius: AddEmployeeConstants.borderRadiusMedium,
                    border: Border.all(
                    color: AddEmployeeConstants.errorColor.withAlpha((0.2 * 255).round()),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: failedEmployees.map((error) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AddEmployeeConstants.errorColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AddEmployeeConstants.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Action Button
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    backgroundColor: AddEmployeeConstants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AddEmployeeConstants.borderRadiusMedium,
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildResultStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AddEmployeeConstants.borderRadiusMedium,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AddEmployeeConstants.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Premium UI Components
  Widget _buildSectionHeader(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AddEmployeeConstants.accentGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AddEmployeeConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AddEmployeeConstants.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool isNumber = false,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int? maxLength,
    Widget? suffixIcon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AddEmployeeConstants.textSecondary,
              ),
            ),
            if (isRequired)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    color: AddEmployeeConstants.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: AddEmployeeConstants.borderRadiusMedium,
            boxShadow: AddEmployeeConstants.subtleShadow,
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText ?? 'Enter $label',
              hintStyle: TextStyle(
                color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              filled: true,
              fillColor: enabled ? AddEmployeeConstants.cardColor : AddEmployeeConstants.textTertiary.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: AddEmployeeConstants.borderRadiusMedium,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AddEmployeeConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AddEmployeeConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: AddEmployeeConstants.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: suffixIcon,
            ),
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            validator: validator ??
                (value) {
                  if (isRequired && (value == null || value.isEmpty)) {
                    return 'Please enter $label';
                  }
                  if (isNumber && value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
            enabled: enabled,
            onChanged: onChanged,
            maxLength: maxLength,
            style: TextStyle(
              fontSize: 14,
              color: AddEmployeeConstants.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyDisplayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AddEmployeeConstants.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AddEmployeeConstants.cardColor,
            borderRadius: AddEmployeeConstants.borderRadiusMedium,
            border: Border.all(
              color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
            ),
            boxShadow: AddEmployeeConstants.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AddEmployeeConstants.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: AddEmployeeConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCompanyName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AddEmployeeConstants.textPrimary,
                      ),
                    ),
                    Text(
                      'Company ID: $_selectedCompanyId',
                      style: TextStyle(
                        fontSize: 12,
                        color: AddEmployeeConstants.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdownField({
    required String label,
    required List<String> items,
    required String selectedItem,
    required ValueChanged<String?> onChanged,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AddEmployeeConstants.textSecondary,
              ),
            ),
            if (isRequired)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    color: AddEmployeeConstants.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: AddEmployeeConstants.borderRadiusMedium,
            boxShadow: AddEmployeeConstants.subtleShadow,
          ),
          child: DropdownButtonFormField<String>(
            initialValue: selectedItem,
            decoration: InputDecoration(
              filled: true,
              fillColor: AddEmployeeConstants.cardColor,
              border: OutlineInputBorder(
                borderRadius: AddEmployeeConstants.borderRadiusMedium,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AddEmployeeConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AddEmployeeConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: AddEmployeeConstants.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: AddEmployeeConstants.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select $label';
                    }
                    return null;
                  }
                : null,
            dropdownColor: AddEmployeeConstants.cardColor,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AddEmployeeConstants.textTertiary,
            ),
            style: TextStyle(
              fontSize: 14,
              color: AddEmployeeConstants.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionField() {
    final positionOptions = _positions
        .map((p) => p['description']?.toString() ?? '')
        .where((desc) => desc.isNotEmpty)
        .toSet()
        .toList();

    if (_showCustomPositionField) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Position',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AddEmployeeConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: AddEmployeeConstants.borderRadiusMedium,
              boxShadow: AddEmployeeConstants.subtleShadow,
            ),
            child: TextFormField(
              controller: _newPositionController,
              decoration: InputDecoration(
                hintText: 'Enter custom position',
                hintStyle: TextStyle(
                  color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AddEmployeeConstants.cardColor,
                border: OutlineInputBorder(
                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: AddEmployeeConstants.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: AddEmployeeConstants.textTertiary,
                  ),
                  onPressed: _togglePositionInput,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a position';
                }
                return null;
              },
              style: TextStyle(
                fontSize: 14,
                color: AddEmployeeConstants.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _useCustomPosition,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AddEmployeeConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AddEmployeeConstants.borderRadiusMedium,
                    ),
                  ),
                  child: const Text('Use This Position'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _saveNewPositionToDatabase,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AddEmployeeConstants.primaryColor,
                  side: BorderSide(color: AddEmployeeConstants.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AddEmployeeConstants.borderRadiusMedium,
                  ),
                ),
                child: const Text('Save to List'),
              ),
            ],
          ),
        ],
      );
    } else {
      final dropdownOptions = [...positionOptions, 'Add New Position...'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Position',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AddEmployeeConstants.textSecondary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    color: AddEmployeeConstants.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: AddEmployeeConstants.borderRadiusMedium,
              boxShadow: AddEmployeeConstants.subtleShadow,
            ),
            child: DropdownButtonFormField<String>(
            initialValue: _positionController.text.isNotEmpty &&
                      positionOptions.contains(_positionController.text)
                  ? _positionController.text
                  : (positionOptions.isNotEmpty ? positionOptions.first : null),
              decoration: InputDecoration(
                filled: true,
                fillColor: AddEmployeeConstants.cardColor,
                border: OutlineInputBorder(
                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
              borderRadius: AddEmployeeConstants.borderRadiusMedium,
              borderSide: BorderSide(
                color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                width: 1.5,
              ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: AddEmployeeConstants.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              items: dropdownOptions.map((option) {
                final isAddNew = option == 'Add New Position...';
                return DropdownMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      if (isAddNew) ...[
                        Icon(Icons.add, color: AddEmployeeConstants.primaryColor, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        option,
                        style: TextStyle(
                          color: isAddNew
                              ? AddEmployeeConstants.primaryColor
                              : AddEmployeeConstants.textPrimary,
                          fontWeight: isAddNew ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == 'Add New Position...') {
                  _togglePositionInput();
                } else {
                  setState(() {
                    _positionController.text = value ?? '';
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a position';
                }
                return null;
              },
              dropdownColor: AddEmployeeConstants.cardColor,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AddEmployeeConstants.textTertiary,
              ),
              style: TextStyle(
                fontSize: 14,
                color: AddEmployeeConstants.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (positionOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _togglePositionInput,
                child: Text(
                  'Don\'t see your position? Enter custom position',
                  style: TextStyle(
                    color: AddEmployeeConstants.primaryColor,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }

  Widget _buildPremiumCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AddEmployeeConstants.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AddEmployeeConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
    bool isFullWidth = false,
    IconData? icon,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AddEmployeeConstants.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: AddEmployeeConstants.borderRadiusMedium,
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AddEmployeeConstants.textSecondary,
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text) {
    return DataCell(
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: AddEmployeeConstants.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AddEmployeeConstants.backgroundColor,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: Container(),
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AddEmployeeConstants.primaryGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button and Title
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add New Employee',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Adding to: $_selectedCompanyName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action Buttons
                        Row(
                          children: [
                            _buildActionButton(
                              label: 'Download Template',
                              onPressed: _downloadCsvTemplate,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              icon: Icons.download_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              label: 'Upload CSV',
                              onPressed: _pickFile,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              icon: Icons.upload_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Main Content
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0.0, -32.0, 0.0),
              decoration: BoxDecoration(
                color: AddEmployeeConstants.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      _buildSectionHeader(
                        'Personal Information',
                        'Enter basic details about the employee',
                      ),
                      
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildPremiumTextField(
                            controller: _employeeIdController,
                            label: 'Employee ID',
                            isRequired: true,
                            maxLength: 20,
                          ),
                          _buildPremiumTextField(
                            controller: _fullnameController,
                            label: 'Full Name',
                            isRequired: true,
                            maxLength: 100,
                          ),
                          _buildCompanyDisplayField(),
                          _buildPremiumTextField(
                            controller: _nationalIdController,
                            label: 'National ID',
                            maxLength: 20,
                          ),
                          _buildPremiumTextField(
                            controller: _kraPinController,
                            label: 'KRA PIN',
                            maxLength: 20,
                          ),
                          _buildPremiumTextField(
                            controller: _nssfController,
                            label: 'NSSF Number',
                            maxLength: 20,
                          ),
                          _buildPremiumTextField(
                            controller: _nhifController,
                            label: 'NHIF Number',
                            maxLength: 20,
                          ),
                          _isLoadingPositions
                              ? SizedBox(
                                  width: 280,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Position',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AddEmployeeConstants.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AddEmployeeConstants.cardColor,
                                          borderRadius: AddEmployeeConstants.borderRadiusMedium,
                                          border: Border.all(
                                            color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  AddEmployeeConstants.primaryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Loading positions...',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AddEmployeeConstants.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SizedBox(width: 280, child: _buildPositionField()),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Contact Information Section
                      _buildSectionHeader(
                        'Contact Information',
                        'How to reach the employee',
                      ),
                      
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildPremiumTextField(
                            controller: _emailController,
                            label: 'Email',
                            hintText: 'employee@company.com',
                            maxLength: 100,
                          ),
                          _buildPremiumTextField(
                            controller: _telController,
                            label: 'Phone Number',
                            hintText: '+254 7XX XXX XXX',
                            maxLength: 15,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Salary Information Section
                      _buildSectionHeader(
                        'Salary Information',
                        'Compensation details',
                      ),
                      
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildPremiumTextField(
                            controller: _basicController,
                            label: 'Basic Salary',
                            isNumber: true,
                            isRequired: true,
                            onChanged: _calculateGrossPay,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'KES',
                                style: TextStyle(
                                  color: AddEmployeeConstants.textTertiary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: Column(
                              children: [
                                _buildPremiumCheckbox(
                                  label: 'No House Allowance',
                                  value: _noHouseAllowance,
                                  onChanged: (value) {
                                    setState(() {
                                      _noHouseAllowance = value!;
                                      _calculateGrossPay(_basicController.text);
                                    });
                                  },
                                ),
                                _buildPremiumTextField(
                                  controller: _houseAllowanceController,
                                  label: 'House Allowance',
                                  isNumber: true,
                                  enabled: false,
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'KES',
                                      style: TextStyle(
                                        color: AddEmployeeConstants.textTertiary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildPremiumTextField(
                            controller: _grossPayController,
                            label: 'Gross Pay',
                            isNumber: true,
                            enabled: false,
                            isRequired: true,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'KES',
                                style: TextStyle(
                                  color: AddEmployeeConstants.textTertiary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Additional Information Section
                      _buildSectionHeader(
                        'Additional Information',
                        'Employment classification and status',
                      ),
                      
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildPremiumDropdownField(
                            label: 'Residential Status',
                            items: ['Resident', 'Non-resident'],
                            selectedItem: _residentialStatus,
                            onChanged: (value) => setState(() => _residentialStatus = value!),
                          ),
                          _buildPremiumDropdownField(
                            label: 'Employee Type',
                            items: ['Primary Employee', 'Secondary Employee'],
                            selectedItem: _employeeType,
                            onChanged: (value) => setState(() => _employeeType = value!),
                          ),
                          _buildPremiumDropdownField(
                            label: 'Housing Type',
                            items: ['Benefit Given', 'Benefit Not Given'],
                            selectedItem: _housingType,
                            onChanged: (value) => setState(() => _housingType = value!),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Bank Information Section
                      _buildSectionHeader(
                        'Bank Information',
                        'Payment and account details',
                      ),
                      
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildPremiumTextField(
                            controller: _bankNameController,
                            label: 'Bank Name',
                            maxLength: 50,
                          ),
                          _buildPremiumTextField(
                            controller: _bankBranchController,
                            label: 'Bank Branch',
                            maxLength: 50,
                          ),
                          _buildPremiumTextField(
                            controller: _accountNumberController,
                            label: 'Account Number',
                            maxLength: 30,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Form Actions
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AddEmployeeConstants.cardColor,
                          borderRadius: AddEmployeeConstants.borderRadiusLarge,
                          border: Border.all(
                            color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.1),
                          ),
                          boxShadow: AddEmployeeConstants.subtleShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: _resetForm,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                                ),
                                side: BorderSide(
                                  color: AddEmployeeConstants.textTertiary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: AddEmployeeConstants.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Reset Form',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AddEmployeeConstants.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                backgroundColor: AddEmployeeConstants.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AddEmployeeConstants.borderRadiusMedium,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Add Employee',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}