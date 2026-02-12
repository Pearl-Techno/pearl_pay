import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';

// Constants - Using same colors as other screens
class LeaveManagementConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
  static const Color greyColor = Color(0xFF9E9E9E);
  static const Color errorColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFFF9800);
}

class LeaveManagementScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const LeaveManagementScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  LeaveManagementScreenState createState() => LeaveManagementScreenState();
}

class LeaveManagementScreenState extends State<LeaveManagementScreen> {
  bool _isLoading = false;
  int _leaveBalance = 0;
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _employees = [];
  String? _selectedEmployeeId;

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // Helper method to safely parse integers
  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _safeParseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LeaveManagementConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: TextStyle(
            color: LeaveManagementConstants.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: LeaveManagementConstants.subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: LeaveManagementConstants.subtitleColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LeaveManagementConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final isAdmin = widget.user['role'] == 'admin';
      final userCompanyId = _safeParseInt(widget.user['company_id']);
      final userEmployeeId = _safeParseString(widget.user['employee_id']);

      if (userCompanyId == null) {
        throw Exception('Invalid company ID');
      }

      // Fetch leave balance for current user
      int leaveBalance = 0;
      if (userEmployeeId != null) {
        final balance = await widget.apiService.getLeaveBalance(
          companyId: userCompanyId,
          employeeId: userEmployeeId,
        );
        leaveBalance = _safeParseInt(balance['days_remaining']) ?? 0;
      }

      // Fetch employees (only for admin)
      List<Map<String, dynamic>> employees = [];
      if (isAdmin) {
        employees = await widget.apiService.getEmployeeList(userCompanyId);
      }

      // Fetch leave requests
      List<Map<String, dynamic>> leaveRequests = [];
      leaveRequests = await widget.apiService.getLeaveRequests(userCompanyId);
      
      // Filter leave requests for non-admin users
      if (!isAdmin && userEmployeeId != null) {
        leaveRequests = leaveRequests
            .where((request) => _safeParseString(request['employee_id']) == userEmployeeId)
            .toList();
      }

      setState(() {
        _leaveBalance = leaveBalance;
        _leaveRequests = leaveRequests;
        _employees = employees;
        // Set selected employee to current user for non-admin, or first employee for admin
        _selectedEmployeeId = isAdmin && employees.isNotEmpty
            ? _safeParseString(employees[0]['employee_id'])
            : userEmployeeId;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  Future<void> _submitLeaveRequest() async {
    final isAdmin = widget.user['role'] == 'admin';
    final userCompanyId = _safeParseInt(widget.user['company_id']);
    final userEmployeeId = _safeParseString(widget.user['employee_id']);
    final employeeId = isAdmin ? _selectedEmployeeId : userEmployeeId;

    if (userCompanyId == null || employeeId == null) {
      _showErrorSnackBar('Invalid user data');
      return;
    }

    if (_startDateController.text.isEmpty || _endDateController.text.isEmpty) {
      _showErrorSnackBar('Please select start and end dates');
      return;
    }

    setState(() => _isLoading = true);
    final leaveData = {
      'employee_id': employeeId,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'reason': _reasonController.text,
      'status': 'Pending',
    };

    try {
      await widget.apiService.requestLeave(leaveData, userCompanyId);
      _showSuccessSnackBar('Leave request submitted successfully');
      _startDateController.clear();
      _endDateController.clear();
      _reasonController.clear();
      await _fetchData();
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting leave request: $e');
      }
      _showErrorSnackBar('Failed to submit leave request: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLeaveStatus(int requestId, String status) async {
    final userCompanyId = _safeParseInt(widget.user['company_id']);
    
    if (userCompanyId == null) {
      _showErrorSnackBar('Invalid company data');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.apiService.updateLeaveStatus(
        requestId: requestId,
        status: status,
        companyId: userCompanyId,
      );
      _showSuccessSnackBar('Leave $status successfully');
      await _fetchData();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating leave status: $e');
      }
      _showErrorSnackBar('Failed to update leave status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCsv() async {
    if (_leaveRequests.isEmpty) {
      _showErrorSnackBar('No leave requests available to export');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final companyName = _safeParseString(widget.user['company_name']) ?? 'Unknown';
      
      final csvData = <List<dynamic>>[
        [
          'ID',
          'Employee ID',
          'Employee Name',
          'Company',
          'Start Date',
          'End Date',
          'Reason',
          'Status',
          'Created At',
        ],
        ..._leaveRequests.map((request) {
          return <dynamic>[
            _safeParseString(request['id']) ?? 'N/A',
            _safeParseString(request['employee_id']) ?? 'N/A',
            _safeParseString(request['employee_name']) ?? 'Unknown Employee',
            companyName,
            _safeParseString(request['start_date']) ?? 'N/A',
            _safeParseString(request['end_date']) ?? 'N/A',
            _safeParseString(request['reason']) ?? 'N/A',
            _safeParseString(request['status']) ?? 'N/A',
            _safeParseString(request['created_at']) ?? 'N/A',
          ];
        }),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);

      String baseDir = Platform.isWindows
          ? r'C:\leave_requests'
          : '${(await getApplicationDocumentsDirectory()).path}/leave_requests';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final date = DateTime.now();
      final formattedDate = DateFormat('MMM yyyy').format(date);
      final filename = 'leave_requests_${companyName}_$formattedDate.csv';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsString(csvString);

      _showSuccessSnackBar('CSV exported to $filePath');
    } catch (e) {
      _showErrorSnackBar('Failed to export CSV: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLeaveRequestForm() {
    final isAdmin = widget.user['role'] == 'admin';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LeaveManagementConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Apply Leave',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: LeaveManagementConstants.textColor,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show company info instead of dropdown
              _buildCompanyInfo(),
              const SizedBox(height: 16),
              if (isAdmin) _buildEmployeeDropdown(),
              _buildDatePickerField(
                controller: _startDateController,
                label: 'Start Date',
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                            primary: LeaveManagementConstants.primaryColor),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                              foregroundColor: LeaveManagementConstants.primaryColor),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (pickedDate != null) {
                    _startDateController.text =
                        pickedDate.toIso8601String().split('T')[0];
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildDatePickerField(
                controller: _endDateController,
                label: 'End Date',
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                            primary: LeaveManagementConstants.primaryColor),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                              foregroundColor: LeaveManagementConstants.primaryColor),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (pickedDate != null) {
                    _endDateController.text =
                        pickedDate.toIso8601String().split('T')[0];
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _reasonController,
                label: 'Reason',
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: LeaveManagementConstants.subtitleColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitLeaveRequest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LeaveManagementConstants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo() {
    final companyName = _safeParseString(widget.user['company_name']) ?? 'Unknown Company';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LeaveManagementConstants.primaryColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LeaveManagementConstants.primaryColor.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(Icons.business, color: LeaveManagementConstants.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company',
                  style: TextStyle(
                    color: LeaveManagementConstants.subtitleColor,
                    fontSize: 12,
                  ),
                ),
                Text(
                  companyName,
                  style: TextStyle(
                    color: LeaveManagementConstants.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: LeaveManagementConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: LeaveManagementConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin';
    final companyName = _safeParseString(widget.user['company_name']) ?? 'Unknown Company';
    
    return Scaffold(
      backgroundColor: LeaveManagementConstants.backgroundColor,
      appBar: CustomAppBar(
        title: isAdmin ? 'Leave Management' : 'My Leave',
        backgroundColor: LeaveManagementConstants.primaryColor,
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: LeaveManagementConstants.cardColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: LeaveManagementConstants.primaryColor),
                    title: Text(
                      'Profile: ${_safeParseString(widget.user['username']) ?? 'Unknown'}',
                      style: TextStyle(color: LeaveManagementConstants.textColor),
                    ),
                    subtitle: Text(
                      'Role: ${_safeParseString(widget.user['role']) ?? 'Unknown'}',
                      style: TextStyle(color: LeaveManagementConstants.subtitleColor),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.business, color: LeaveManagementConstants.primaryColor),
                    title: Text(
                      'Company: $companyName',
                      style: TextStyle(color: LeaveManagementConstants.textColor),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.logout, color: LeaveManagementConstants.errorColor),
                    title: Text(
                      'Logout',
                      style: TextStyle(color: LeaveManagementConstants.errorColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _logout(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildFiltersSection(),
                  const SizedBox(height: 16),
                  _buildStatisticsCards(),
                  const SizedBox(height: 16),
                  _buildContentSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final isAdmin = widget.user['role'] == 'admin';
    final companyName = _safeParseString(widget.user['company_name']) ?? 'Unknown Company';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [LeaveManagementConstants.primaryColor, LeaveManagementConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.beach_access,
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
                        isAdmin ? 'Leave Management' : 'My Leave',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAdmin 
                            ? 'Manage employee leave requests for $companyName'
                            : 'Track your leave balance and request time off',
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    final isAdmin = widget.user['role'] == 'admin';
    
    return Row(
      children: [
        if (isAdmin) ...[
          Expanded(
            child: _buildEmployeeDropdown(),
          ),
          const SizedBox(width: 12),
        ],
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildEmployeeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: LeaveManagementConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(Icons.person, color: LeaveManagementConstants.primaryColor, size: 20),
        title: DropdownButton<String>(
          value: _selectedEmployeeId,
          items: _employees.map((employee) {
            final employeeId = _safeParseString(employee['employee_id']);
            final fullName = _safeParseString(employee['fullname']) ?? 'Unknown Employee';
            return DropdownMenuItem<String>(
              value: employeeId,
              child: Text(
                fullName,
                style: TextStyle(
                  color: LeaveManagementConstants.textColor,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployeeId = value;
              _fetchData();
            });
          },
          underline: const SizedBox(),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: LeaveManagementConstants.primaryColor),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: LeaveManagementConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _fetchData,
        icon: Icon(Icons.refresh, color: LeaveManagementConstants.primaryColor),
        style: IconButton.styleFrom(
          backgroundColor: LeaveManagementConstants.cardColor,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final isAdmin = widget.user['role'] == 'admin';
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: isAdmin ? 'Selected Employee' : 'Your Leave Balance',
            value: '$_leaveBalance days',
            icon: Icons.calendar_today,
            color: LeaveManagementConstants.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Pending Requests',
            value: _leaveRequests.where((r) => _safeParseString(r['status']) == 'Pending').length.toString(),
            icon: Icons.pending,
            color: LeaveManagementConstants.warningColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            title: 'Apply Leave',
            icon: Icons.add,
            onTap: _showLeaveRequestForm,
            color: LeaveManagementConstants.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            title: 'Export',
            icon: Icons.download,
            onTap: _exportToCsv,
            color: LeaveManagementConstants.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LeaveManagementConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: LeaveManagementConstants.subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: LeaveManagementConstants.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LeaveManagementConstants.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
              color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: LeaveManagementConstants.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: LeaveManagementConstants.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_leaveRequests.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      children: [
        _buildTableHeader(),
        Expanded(child: _buildLeaveRequestsList()),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: LeaveManagementConstants.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Leave Data...',
            style: TextStyle(
              color: LeaveManagementConstants.subtitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.beach_access_outlined,
              size: 80,
                                color: LeaveManagementConstants.greyColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Leave Requests',
              style: TextStyle(
                color: LeaveManagementConstants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No leave requests found for ${_safeParseString(widget.user['company_name']) ?? 'your company'}',
              style: TextStyle(
                color: LeaveManagementConstants.subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showLeaveRequestForm,
              icon: Icon(Icons.add, size: 18),
              label: Text('Apply for Leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LeaveManagementConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    final isAdmin = widget.user['role'] == 'admin';
    final companyName = _safeParseString(widget.user['company_name']) ?? 'Unknown Company';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: LeaveManagementConstants.backgroundColor,
        border: Border(
          bottom: BorderSide(color: LeaveManagementConstants.backgroundColor.withAlpha(128)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: LeaveManagementConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'All Leave Requests' : 'Your Leave Requests',
                  style: TextStyle(
                    color: LeaveManagementConstants.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  companyName,
                  style: TextStyle(
                    color: LeaveManagementConstants.subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_leaveRequests.length} requests',
            style: TextStyle(
              color: LeaveManagementConstants.subtitleColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestsList() {
    final isAdmin = widget.user['role'] == 'admin';
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final request = _leaveRequests[index];
        final status = _safeParseString(request['status']) ?? 'Pending';
        final isPending = status == 'Pending';
        
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              color: LeaveManagementConstants.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 20,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin) Text(
                    _safeParseString(request['employee_name']) ?? 'Unknown Employee',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LeaveManagementConstants.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_safeParseString(request['start_date']) ?? 'N/A'} to ${_safeParseString(request['end_date']) ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: LeaveManagementConstants.subtitleColor,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    _safeParseString(request['reason']) ?? 'No reason provided',
                    style: TextStyle(
                      fontSize: 12,
                      color: LeaveManagementConstants.subtitleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(status),
                ],
              ),
              trailing: isAdmin && isPending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: LeaveManagementConstants.successColor),
                          onPressed: () => _updateLeaveStatus(_safeParseInt(request['id']) ?? 0, 'Approved'),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: LeaveManagementConstants.errorColor),
                          onPressed: () => _updateLeaveStatus(_safeParseInt(request['id']) ?? 0, 'Rejected'),
                          tooltip: 'Reject',
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return LeaveManagementConstants.successColor;
      case 'pending':
        return LeaveManagementConstants.warningColor;
      case 'rejected':
        return LeaveManagementConstants.errorColor;
      case 'suspended':
        return LeaveManagementConstants.greyColor;
      default:
        return LeaveManagementConstants.greyColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      case 'suspended':
        return Icons.pause_circle;
      default:
        return Icons.help_outline;
    }
  }

  // Dialog Widgets
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LeaveManagementConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: LeaveManagementConstants.backgroundColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: LeaveManagementConstants.primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: TextStyle(color: LeaveManagementConstants.textColor),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LeaveManagementConstants.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LeaveManagementConstants.backgroundColor),
            ),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: LeaveManagementConstants.primaryColor),
              title: Text(
                controller.text.isEmpty ? 'Select Date' : controller.text,
                style: TextStyle(
                  color: controller.text.isEmpty 
                      ? LeaveManagementConstants.subtitleColor 
                      : LeaveManagementConstants.textColor,
                ),
              ),
              trailing: Icon(Icons.arrow_drop_down, color: LeaveManagementConstants.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}