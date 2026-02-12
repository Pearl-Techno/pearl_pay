import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/user.dart';
import '../services/services.dart';

// Premium Design Constants
class EmployeeListConstants {
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
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Status colors
  static const Color successColor = Color(0xFF00B894);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color warningColor = Color(0xFFFFA502);
  static const Color activeColor = Color(0xFF00B894);
  static const Color inactiveColor = Color(0xFFFF4757);
  
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

class EmployeeListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const EmployeeListScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  EmployeeListScreenState createState() => EmployeeListScreenState();
}

class EmployeeListScreenState extends State<EmployeeListScreen> {
  // Data and State Management
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  int? _companyId;
  String _companyName = 'Unknown';
  bool _isLoading = true;
  bool _isLoadingCompanies = true;
  String? _errorMessage;
  late User _userModel;
  
  // Search and Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _positionFilter = 'All';
  
  // UI State
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final List<Map<String, dynamic>> _failedAuditLogs = [];
  List<String> _availablePositions = [];
  final Map<String, bool> _expandedRows = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _fetchCompanies();
    _loadPositions();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initializeUser() {
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
    }
  }

  Future<void> _loadPositions() async {
    try {
      final positionData = await widget.apiService.getPositions();
      setState(() {
        _availablePositions = positionData
            .map((p) => p['description']?.toString() ?? '')
            .where((desc) => desc.isNotEmpty)
            .toList();
      });
    } catch (e) {
      developer.log('Error loading positions: $e', name: 'EmployeeListScreen');
      _availablePositions = [];
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();
    if (message.contains('network')) {
      return 'Network error: Please check your internet connection.';
    } else if (message.contains('unauthorized') || message.contains('access denied')) {
      return 'Access denied: Please re-authenticate or contact support.';
    } else if (message.contains('duplicate')) {
      return 'Duplicate entry detected.';
    } else if (message.contains('share')) {
      return 'Unable to share file. Please check the file manually in your device storage.';
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

      final companies = await widget.apiService.getCompanies();
      final userCompany = companies.firstWhere(
        (c) {
          final companyId = c['id'] is String ? int.tryParse(c['id']) : c['id'] as int?;
          return companyId == userCompanyId;
        },
        orElse: () => {
          'id': userCompanyId,
          'company_name': userCompanyName,
        },
      );

      setState(() {
        _companyId = userCompanyId;
        _companyName = userCompany['company_name']?.toString() ?? userCompanyName;
        _isLoadingCompanies = false;
      });

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
      final employees = await widget.apiService.getEmployeeList(_companyId!);
      setState(() {
        _employees = employees.map((e) => {
          ...e,
          'employee_status': ['Active', 'Inactive'].contains(e['employee_status']) 
              ? e['employee_status'] 
              : 'Active',
        }).toList();
        _filteredEmployees = _employees;
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

  void _applyFilters() {
    setState(() {
      _filteredEmployees = _employees.where((employee) {
        final matchesSearch = _searchQuery.isEmpty ||
            employee['fullname']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            employee['employee_id']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            employee['email']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

        final matchesStatus = _statusFilter == 'All' ||
            employee['employee_status']?.toString() == _statusFilter;

        final matchesPosition = _positionFilter == 'All' ||
            employee['position']?.toString() == _positionFilter;

        return matchesSearch && matchesStatus && matchesPosition;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _positionFilter = 'All';
      _searchController.clear();
      _filteredEmployees = _employees;
    });
  }

  void _toggleRowExpansion(String employeeId) {
    setState(() {
      _expandedRows[employeeId] = !(_expandedRows[employeeId] ?? false);
    });
  }

  // Premium Update Dialog
  Future<void> _showUpdateDialog(Map<String, dynamic> employee) async {
    String? selectedField;
    final TextEditingController controller = TextEditingController();
    final List<String> fields = [
      'fullname', 'national_id', 'kra_pin', 'position_name', 'nssf', 'nhif',
      'email', 'tel', 'basic', 'house_allowance', 'gross_pay', 'bank_name',
      'bank_branch', 'account_number', 'employee_status', 'residential_status',
      'employee_type', 'housing_type'
    ];

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: EmployeeListConstants.surfaceColor,
            borderRadius: EmployeeListConstants.borderRadiusLarge,
            boxShadow: EmployeeListConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: EmployeeListConstants.accentGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Employee',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: EmployeeListConstants.textPrimary,
                          ),
                        ),
                        Text(
                          employee['fullname']?.toString() ?? 'Unknown Employee',
                          style: TextStyle(
                            fontSize: 14,
                            color: EmployeeListConstants.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: EmployeeListConstants.textTertiary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Field Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Field to Update',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EmployeeListConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: EmployeeListConstants.borderRadiusMedium,
                      boxShadow: EmployeeListConstants.subtleShadow,
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedField,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: EmployeeListConstants.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: EmployeeListConstants.borderRadiusMedium,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: EmployeeListConstants.borderRadiusMedium,
                          borderSide: BorderSide(
                color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: EmployeeListConstants.borderRadiusMedium,
                          borderSide: BorderSide(
                            color: EmployeeListConstants.primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                      items: fields.map((field) {
                        return DropdownMenuItem(
                          value: field,
                          child: Text(
                            _formatFieldName(field),
                            style: TextStyle(
                              fontSize: 14,
                              color: EmployeeListConstants.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedField = value;
                          controller.clear();
                        });
                      },
                      dropdownColor: EmployeeListConstants.cardColor,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: EmployeeListConstants.textTertiary,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: EmployeeListConstants.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Value Input
              if (selectedField != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: EmployeeListConstants.accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_rounded,
                            size: 12,
                            color: EmployeeListConstants.accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current: ${employee[selectedField] ?? "Not set"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: EmployeeListConstants.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDynamicInputField(selectedField!, controller, employee),
                  ],
                ),
              
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
                        borderRadius: EmployeeListConstants.borderRadiusMedium,
                      ),
                      side: BorderSide(color: EmployeeListConstants.textTertiary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: EmployeeListConstants.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: selectedField == null || controller.text.isEmpty
                        ? null
                        : () => _performUpdate(selectedField, controller.text, employee),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      backgroundColor: EmployeeListConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: EmployeeListConstants.borderRadiusMedium,
                      ),
                      disabledBackgroundColor: EmployeeListConstants.primaryColor.withValues(alpha: 0.5),
                    ),
                    child: const Text(
                      'Update',
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

  Widget _buildDynamicInputField(String field, TextEditingController controller, Map<String, dynamic> employee) {
    switch (field) {
      case 'employee_status':
        return _buildPremiumDropdown(
          items: ['Active', 'Inactive'],
          value: controller.text,
          onChanged: (value) => controller.text = value!,
          hintText: 'Select status',
        );
      case 'position_name':
        return _buildPremiumDropdown(
          items: _availablePositions,
          value: controller.text,
          onChanged: (value) => controller.text = value!,
          hintText: 'Select position',
        );
      case 'residential_status':
        return _buildPremiumDropdown(
          items: ['Resident', 'Non-resident'],
          value: controller.text,
          onChanged: (value) => controller.text = value!,
          hintText: 'Select residential status',
        );
      case 'employee_type':
        return _buildPremiumDropdown(
          items: ['Primary Employee', 'Secondary Employee'],
          value: controller.text,
          onChanged: (value) => controller.text = value!,
          hintText: 'Select employee type',
        );
      case 'housing_type':
        return _buildPremiumDropdown(
          items: ['Benefit Given', 'Benefit Not Given'],
          value: controller.text,
          onChanged: (value) => controller.text = value!,
          hintText: 'Select housing type',
        );
      default:
        return Container(
          decoration: BoxDecoration(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            boxShadow: EmployeeListConstants.subtleShadow,
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter ${_formatFieldName(field).toLowerCase()}',
              hintStyle: TextStyle(
              color: EmployeeListConstants.textTertiary.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              filled: true,
              fillColor: EmployeeListConstants.cardColor,
              border: OutlineInputBorder(
                borderRadius: EmployeeListConstants.borderRadiusMedium,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: EmployeeListConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: EmployeeListConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: EmployeeListConstants.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            keyboardType: _getKeyboardType(field),
            style: TextStyle(
              fontSize: 14,
              color: EmployeeListConstants.textPrimary,
            ),
          ),
        );
    }
  }

  Widget _buildPremiumDropdown({
    required List<String> items,
    required String value,
    required ValueChanged<String?> onChanged,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: EmployeeListConstants.borderRadiusMedium,
        boxShadow: EmployeeListConstants.subtleShadow,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value.isNotEmpty ? value : null,
        decoration: InputDecoration(
          hintText: hintText, hintStyle: TextStyle(
            color: EmployeeListConstants.textTertiary.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: EmployeeListConstants.cardColor,
          border: OutlineInputBorder(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: EmployeeListConstants.primaryColor,
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
                color: EmployeeListConstants.textPrimary,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: EmployeeListConstants.cardColor,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: EmployeeListConstants.textTertiary,
        ),
        style: TextStyle(
          fontSize: 14,
          color: EmployeeListConstants.textPrimary,
        ),
      ),
    );
  }

  TextInputType _getKeyboardType(String field) {
    if (['basic', 'house_allowance', 'gross_pay'].contains(field)) {
      return TextInputType.numberWithOptions(decimal: true);
    } else if (field == 'email') {
      return TextInputType.emailAddress;
    } else if (field == 'tel') {
      return TextInputType.phone;
    }
    return TextInputType.text;
  }

  Future<void> _performUpdate(String? selectedField, String newValue, Map<String, dynamic> employee) async {
    if (selectedField == null || selectedField.isEmpty) {
      _showErrorSnackBar('Please select a field to update');
      return;
    }

    if (newValue.isEmpty) {
      _showErrorSnackBar('Please enter a new value');
      return;
    }

    final employeeName = employee['fullname']?.toString() ?? 'Employee';
    final confirmed = await _showConfirmationDialog(
      'Update ${_formatFieldName(selectedField)}',
      'Are you sure you want to update ${_formatFieldName(selectedField).toLowerCase()} for $employeeName to "$newValue"?',
    );

    if (!confirmed) return;

    try {
      await widget.apiService.updateEmployee(
        companyId: _companyId!,
        employeeId: employee['employee_id'].toString(),
        field: selectedField,
        value: newValue,
      );
      if (!mounted) return;

      await _logEmployeeAction(
        'update_employee',
        'Updated $selectedField to "$newValue" for employee ${employee['employee_id']}',
      );

      if (!mounted) return;

      _showSuccessSnackBar('${_formatFieldName(selectedField)} updated successfully!');
      
      Navigator.pop(context);
      await _fetchEmployees();
    } catch (e) {
      developer.log('Error updating employee: $e', name: 'EmployeeListScreen');
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    }
  }

  // Premium Status Management
  Future<void> _toggleEmployeeStatus(Map<String, dynamic> employee, bool activate) async {
    final action = activate ? 'activate' : 'deactivate';
    final employeeName = employee['fullname']?.toString() ?? 'Employee';

    final confirmed = await _showConfirmationDialog(
      '${activate ? 'Activate' : 'Deactivate'} Employee',
      'Are you sure you want to $action $employeeName?',
      isStatusChange: true,
      isActivate: activate,
    );

    if (!confirmed) return;

    try {
      if (activate) {
        await widget.apiService.activateEmployee(_companyId!, employee['employee_id'].toString());
      } else {
        await widget.apiService.deactivateEmployee(_companyId!, employee['employee_id'].toString());
      }

      await _logEmployeeAction(
        '${action}_employee',
        '${activate ? 'Activated' : 'Deactivated'} employee ${employee['employee_id']}',
      );

      _showSuccessSnackBar('Employee ${activate ? 'activated' : 'deactivated'} successfully!');
      await _fetchEmployees();
    } catch (e) {
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    }
  }

  // Premium Confirmation Dialog
  Future<bool> _showConfirmationDialog(String title, String content, {bool isStatusChange = false, bool isActivate = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: EmployeeListConstants.surfaceColor,
            borderRadius: EmployeeListConstants.borderRadiusLarge,
            boxShadow: EmployeeListConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: isStatusChange
                      ? LinearGradient(
                          colors: isActivate
                              ? [EmployeeListConstants.successColor, Colors.green[400]!]
                              : [EmployeeListConstants.errorColor, Colors.red[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : EmployeeListConstants.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isStatusChange
                      ? (isActivate ? Icons.person_add_alt_1_rounded : Icons.person_off_rounded)
                      : Icons.warning_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: EmployeeListConstants.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: EmployeeListConstants.textTertiary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: EmployeeListConstants.borderRadiusMedium,
                        ),
                        side: BorderSide(
                        color: EmployeeListConstants.textTertiary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: EmployeeListConstants.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isStatusChange
                            ? (isActivate ? EmployeeListConstants.successColor : EmployeeListConstants.errorColor)
                            : EmployeeListConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: EmployeeListConstants.borderRadiusMedium,
                        ),
                      ),
                      child: Text(
                        isStatusChange ? (isActivate ? 'Activate' : 'Deactivate') : 'Confirm',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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
    return confirmed ?? false;
  }

  // Premium Export functionality
  Future<void> _exportToCSV() async {
    if (_employees.isEmpty) {
      _showErrorSnackBar('No data available to export');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final List<List<dynamic>> rows = [
        [
          'Employee ID', 'Full Name', 'National ID', 'KRA PIN', 'Position', 'Position Name',
          'NSSF', 'NHIF', 'Email', 'Phone', 'Basic Salary', 'House Allowance', 'Gross Pay',
          'Residential Status', 'Employee Type', 'Housing Type', 'Bank Name', 'Bank Branch',
          'Account Number', 'Status', 'Last Updated',
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
      final directory = kIsWeb ? null : await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'employee_list_${_companyName.replaceAll(' ', '_')}_$timestamp.csv';
      late String filePath;

      if (kIsWeb) {
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
        filePath = '${directory!.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(csv);await Share.shareXFiles([XFile(filePath)],
            text: 'Employee List CSV - $_companyName');
      }

      _showSuccessSnackBar('Employee list exported to CSV successfully!');
    } catch (e) {
      developer.log('Error exporting to CSV: $e', name: 'EmployeeListScreen');
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (_employees.isEmpty) {
      _showErrorSnackBar('No data available to export');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      const columns = [
        'Employee ID', 'Full Name', 'National ID', 'KRA PIN', 'Position',
        'NSSF', 'NHIF', 'Phone', 'Basic Salary', 'House Allowance', 'Gross Pay',
        'Bank Name', 'Account Number', 'Status', 'Last Updated',
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                children: [
                  pw.Text(
                    'Employee List - $_companyName',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Employees: ${_employees.length}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: columns,
              data: _employees
                  .map((employee) => [
                        employee['employee_id']?.toString() ?? '',
                        employee['fullname']?.toString() ?? '',
                        employee['national_id']?.toString() ?? '',
                        employee['kra_pin']?.toString() ?? '',
                        employee['position_name']?.toString() ??
                            employee['position']?.toString() ?? '',
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
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ],
        ),
      );

      final directory = kIsWeb ? null : await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'employee_list_${_companyName.replaceAll(' ', '_')}_$timestamp.pdf';
      late String filePath;

      if (kIsWeb) {
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
        filePath = '${directory!.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());await Share.shareXFiles([XFile(filePath)],
            text: 'Employee List PDF - $_companyName');
      }

      _showSuccessSnackBar('Employee list exported to PDF successfully!');
    } catch (e) {
      developer.log('Error exporting to PDF: $e', name: 'EmployeeListScreen');
      _showErrorSnackBar(_getFriendlyErrorMessage(e));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // Utility Methods
  String _formatFieldName(String field) {
    return field.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'KSh 0';
    final number = amount is String ? double.tryParse(amount) : amount.toDouble();
    return 'KSh ${NumberFormat('#,##0').format(number ?? 0)}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: EmployeeListConstants.errorColor,
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            boxShadow: EmployeeListConstants.mediumShadow,
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
            color: EmployeeListConstants.successColor,
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            boxShadow: EmployeeListConstants.mediumShadow,
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

  Future<void> _logEmployeeAction(String action, String details) async {
    try {
      await widget.apiService.logEmployeeAction({
        'user_id': _userModel.userId,
        'action': action,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _failedAuditLogs.add({
        'user_id': _userModel.userId,
        'action': action,
        'details': details,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      developer.log('Failed to log employee action: $e', name: 'EmployeeListScreen');
    }
  }

  // Premium UI Components
  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: EmployeeListConstants.primaryGradient,
        boxShadow: EmployeeListConstants.mediumShadow,
      ),
      child: SafeArea(
        bottom: false,
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
                        'Employee Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _companyName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Export Menu
                PopupMenuButton<String>(
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isExporting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(
                            Icons.table_chart_rounded,
                            color: EmployeeListConstants.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          const Text('Export to CSV'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            color: EmployeeListConstants.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          const Text('Export to PDF'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'csv') _exportToCSV();
                    if (value == 'pdf') _exportToPDF();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Stats
            Row(
              children: [
                _buildStatCard(
                  title: 'Total',
                  value: _employees.length.toString(),
                  color: EmployeeListConstants.primaryColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Active',
                  value: _employees.where((e) => e['employee_status'] == 'Active').length.toString(),
                  color: EmployeeListConstants.activeColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Inactive',
                  value: _employees.where((e) => e['employee_status'] == 'Inactive').length.toString(),
                  color: EmployeeListConstants.inactiveColor,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Search and Filters
            _buildSearchAndFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: EmployeeListConstants.borderRadiusMedium,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: EmployeeListConstants.borderRadiusMedium,
            ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: EmployeeListConstants.borderRadiusMedium,
              boxShadow: EmployeeListConstants.subtleShadow,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search employees by name, ID, or email...',
                hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: EmployeeListConstants.borderRadiusMedium,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: EmployeeListConstants.borderRadiusMedium,
                  borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: EmployeeListConstants.borderRadiusMedium,
                  borderSide: BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                              Icons.clear_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filters Row
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _statusFilter,
                  items: ['All', 'Active', 'Inactive'],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                      _applyFilters();
                    });
                  },
                  hintText: 'Status',
                  icon: Icons.filter_list_rounded,
                ),
              ),
              const SizedBox(width: 12),
              if (_availablePositions.isNotEmpty)
                Expanded(
                  child: _buildFilterDropdown(
                    value: _positionFilter,
                    items: ['All', ..._availablePositions],
                    onChanged: (value) {
                      setState(() {
                        _positionFilter = value!;
                        _applyFilters();
                      });
                    },
                    hintText: 'Position',
                    icon: Icons.work_rounded,
                  ),
                ),
              if (_searchQuery.isNotEmpty || _statusFilter != 'All' || _positionFilter != 'All')
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: EmployeeListConstants.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: EmployeeListConstants.borderRadiusMedium,
        boxShadow: EmployeeListConstants.subtleShadow,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: EmployeeListConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: EmployeeListConstants.primaryColor,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmployeeTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EmployeeListConstants.surfaceColor,
        borderRadius: EmployeeListConstants.borderRadiusLarge,
        boxShadow: EmployeeListConstants.mediumShadow,
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EmployeeListConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: EmployeeListConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.table_chart_rounded,
                    color: EmployeeListConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Employee List',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: EmployeeListConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${_filteredEmployees.length} employees',
                  style: TextStyle(
                    fontSize: 14,
                    color: EmployeeListConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Table Content
          Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                      columnSpacing: 24,
                      horizontalMargin: 24,
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 60,
                      headingRowHeight: 60,
                      headingTextStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: EmployeeListConstants.textSecondary,
                      ),
                      headingRowColor: WidgetStateProperty.all(
                        EmployeeListConstants.cardColor,
                      ),
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Full Name')),
                        DataColumn(label: Text('Position')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Basic Salary')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _filteredEmployees.map((employee) {
                        final isActive = employee['employee_status'] == 'Active';
                        final employeeId = employee['employee_id'].toString();
                        final isExpanded = _expandedRows[employeeId] ?? false;

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return EmployeeListConstants.primaryColor.withValues(alpha: 0.1);
                              }
                              final index = _filteredEmployees.indexOf(employee);
                              return index.isEven ? EmployeeListConstants.backgroundColor : null;
                            },
                          ),
                          cells: [
                            DataCell(
                              Text(
                                employee['employee_id']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: EmployeeListConstants.textPrimary,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                employee['fullname']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: EmployeeListConstants.textPrimary,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                employee['position_name'] ?? employee['position'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: EmployeeListConstants.textSecondary,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                employee['email']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: EmployeeListConstants.textSecondary,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                employee['tel']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: EmployeeListConstants.textSecondary,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatCurrency(employee['basic']),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: EmployeeListConstants.primaryColor,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? EmployeeListConstants.activeColor.withValues(alpha: 0.1)
                                      : EmployeeListConstants.inactiveColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isActive
                                        ? EmployeeListConstants.activeColor.withValues(alpha: 0.3)
                                        : EmployeeListConstants.inactiveColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  employee['employee_status']?.toString() ?? 'Active',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? EmployeeListConstants.activeColor
                                        : EmployeeListConstants.inactiveColor,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.edit_rounded,
                                    color: EmployeeListConstants.primaryColor,
                                    onPressed: () => _showUpdateDialog(employee),
                                    tooltip: 'Edit Employee',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: isActive
                                        ? Icons.person_off_rounded
                                        : Icons.person_add_alt_1_rounded,
                                    color: isActive
                                        ? EmployeeListConstants.inactiveColor
                                        : EmployeeListConstants.activeColor,
                                    onPressed: () =>
                                        _toggleEmployeeStatus(employee, !isActive),
                                    tooltip: isActive ? 'Deactivate' : 'Activate',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionButton(
                                    icon: isExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: EmployeeListConstants.textTertiary,
                                    onPressed: () => _toggleRowExpansion(employeeId),
                                    tooltip: isExpanded ? 'Hide Details' : 'Show Details',
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
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildEmployeeDetails(Map<String, dynamic> employee) {
    final employeeId = employee['employee_id'].toString();
    if (!(_expandedRows[employeeId] ?? false)) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EmployeeListConstants.cardColor,
        borderRadius: EmployeeListConstants.borderRadiusMedium,
        border: Border.all(
          color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1),
        ),
        boxShadow: EmployeeListConstants.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: EmployeeListConstants.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_rounded,
                  size: 18,
                  color: EmployeeListConstants.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Employee Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: EmployeeListConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _buildDetailItem('National ID', employee['national_id']?.toString() ?? 'N/A'),
              _buildDetailItem('KRA PIN', employee['kra_pin']?.toString() ?? 'N/A'),
              _buildDetailItem('NSSF', employee['nssf']?.toString() ?? 'N/A'),
              _buildDetailItem('NHIF', employee['nhif']?.toString() ?? 'N/A'),
              _buildDetailItem('Residential Status', employee['residential_status']?.toString() ?? 'Resident'),
              _buildDetailItem('Employee Type', employee['employee_type']?.toString() ?? 'Primary Employee'),
              _buildDetailItem('Housing Type', employee['housing_type']?.toString() ?? 'Benefit Not Given'),
              _buildDetailItem('Bank Name', employee['bank_name']?.toString() ?? 'N/A'),
              _buildDetailItem('Bank Branch', employee['bank_branch']?.toString() ?? 'N/A'),
              _buildDetailItem('Account Number', employee['account_number']?.toString() ?? 'N/A'),
              _buildDetailItem('House Allowance', _formatCurrency(employee['house_allowance'])),
              _buildDetailItem('Gross Pay', _formatCurrency(employee['gross_pay'])),
              _buildDetailItem('Created', _formatDate(employee['created_at'])),
              _buildDetailItem('Last Updated', _formatDate(employee['update_date'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: EmployeeListConstants.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EmployeeListConstants.backgroundColor,
              borderRadius: EmployeeListConstants.borderRadiusSmall,
              border: Border.all(
                color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: EmployeeListConstants.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.tryParse(date.toString());
      if (dateTime == null) return date.toString();
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(EmployeeListConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Employees...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: EmployeeListConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: EmployeeListConstants.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: EmployeeListConstants.errorColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: EmployeeListConstants.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchEmployees,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: EmployeeListConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: EmployeeListConstants.borderRadiusMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: EmployeeListConstants.textTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: EmployeeListConstants.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Employees Found',
            style: TextStyle(
              fontSize: 18,
              color: EmployeeListConstants.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != 'All'
                ? 'No employees match your current filters.'
                : 'No employees found for $_companyName.',
            style: TextStyle(
              fontSize: 14,
              color: EmployeeListConstants.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmployeeListConstants.backgroundColor,
      body: _isLoadingCompanies
          ? _buildLoadingState()
          : Column(
              children: [
                _buildHeaderSection(),
                if (_isLoading)
                  Expanded(child: _buildLoadingState())
                else if (_errorMessage != null)
                  Expanded(child: _buildErrorState())
                else if (_filteredEmployees.isEmpty)
                  Expanded(child: _buildEmptyState())
                else
                  Expanded(
                    child: ListView(
                      children: [
                        _buildEmployeeTable(),
                        ..._filteredEmployees.map(_buildEmployeeDetails),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}