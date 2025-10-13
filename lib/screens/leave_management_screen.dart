import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart'; // Import LoginScreen for logout navigation

class LeaveManagementScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const LeaveManagementScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _LeaveManagementScreenState createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  bool _isLoading = false;
  int _leaveBalance = 0;
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _companies = [];
  String? _selectedEmployeeId;
  int? _selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // Logout function to clear SharedPreferences and navigate to LoginScreen
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await widget.apiService.getCompanies();
      final userCompanyId = widget.user['company_id'] as int?;
      final isAdmin = widget.user['role'] == 'admin';

      setState(() {
        _companies = companies;
        if (isAdmin) {
          companyIds = companies
              .map((c) => c['id'] as int?)
              .where((id) => id != null)
              .cast<int>()
              .toSet()
              .toList();
          companyIdToName = {
            for (var c in companies)
              if (c['id'] != null)
                c['id'] as int: c['company_name']?.toString() ?? 'Unknown'
          };
          companyIds.insert(0, 0); // 0 for 'All Companies'
          companyIdToName[0] = 'All Companies';
        } else if (userCompanyId != null) {
          final userCompany = companies.firstWhere(
            (c) => c['id'] == userCompanyId,
            orElse: () => {
              'id': userCompanyId,
              'company_name':
                  widget.user['company_name']?.toString() ?? 'Unknown'
            },
          );
          companyIds = [userCompanyId];
          companyIdToName = {
            userCompanyId: userCompany['company_name']?.toString() ?? 'Unknown'
          };
        }
        _selectedCompanyId = companyIds.isNotEmpty ? companyIds[0] : null;
      });

      if (_selectedCompanyId != null) {
        await _fetchData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load companies: $e')),
      );
    }
  }

  Future<void> _fetchData() async {
    if (_selectedCompanyId == null) {
      setState(() {
        _leaveBalance = 0;
        _leaveRequests = [];
        _employees = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isAdmin = widget.user['role'] == 'admin';
      final userEmployeeId = widget.user['employee_id']?.toString();

      // Fetch leave balance
      int leaveBalance = 0;
      if (userEmployeeId != null && _selectedCompanyId != 0) {
        final balance = await widget.apiService.getLeaveBalance(
          companyId: _selectedCompanyId!,
          employeeId: isAdmin && _selectedEmployeeId != null
              ? _selectedEmployeeId!
              : userEmployeeId,
        );
        leaveBalance = balance['days_remaining'] ?? 0;
      }

      // Fetch employees
      List<Map<String, dynamic>> employees = [];
      if (_selectedCompanyId == 0 && isAdmin) {
        final futures =
            companyIds.where((id) => id != 0).map((companyId) async {
          return await widget.apiService.getEmployeeList(companyId);
        });
        final results = await Future.wait(futures);
        employees = results.expand((e) => e).toList();
      } else if (_selectedCompanyId != 0) {
        employees =
            await widget.apiService.getEmployeeList(_selectedCompanyId!);
      }

      // Fetch leave requests
      List<Map<String, dynamic>> leaveRequests = [];
      if (_selectedCompanyId == 0 && isAdmin) {
        final futures =
            companyIds.where((id) => id != 0).map((companyId) async {
          return await widget.apiService.getLeaveRequests(companyId);
        });
        final results = await Future.wait(futures);
        leaveRequests = results.expand((r) => r).toList();
      } else if (_selectedCompanyId != 0) {
        leaveRequests =
            await widget.apiService.getLeaveRequests(_selectedCompanyId!);
        if (!isAdmin && userEmployeeId != null) {
          leaveRequests = leaveRequests
              .where((request) => request['employee_id'] == userEmployeeId)
              .toList();
        }
      }

      setState(() {
        _leaveBalance = leaveBalance;
        _leaveRequests = leaveRequests;
        _employees = employees;
        _selectedEmployeeId = isAdmin && employees.isNotEmpty
            ? employees[0]['employee_id']
            : userEmployeeId;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  Future<void> _submitLeaveRequest() async {
    final isAdmin = widget.user['role'] == 'admin';
    final userEmployeeId = widget.user['employee_id']?.toString();
    final employeeId = isAdmin ? _selectedEmployeeId : userEmployeeId;

    if (_selectedCompanyId == null ||
        _selectedCompanyId == 0 ||
        employeeId == null ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please select a valid company, employee, and dates')),
      );
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
      await widget.apiService.requestLeave(leaveData, _selectedCompanyId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted successfully')),
      );
      _startDateController.clear();
      _endDateController.clear();
      _reasonController.clear();
      await _fetchData();
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting leave request: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit leave request: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLeaveStatus(int requestId, String status) async {
    if (_selectedCompanyId == null || _selectedCompanyId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid company selected')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.apiService.updateLeaveStatus(
        requestId: requestId,
        status: status,
        companyId: _selectedCompanyId!,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave $status successfully')),
      );
      await _fetchData();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating leave status: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update leave status: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCsv() async {
    if (_leaveRequests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leave requests available to export')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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
          final company = _companies.firstWhere(
            (c) => c['id'] == request['company_id'],
            orElse: () => {'company_name': 'Unknown'},
          );
          return [
            request['id']?.toString() ?? 'N/A',
            request['employee_id']?.toString() ?? 'N/A',
            request['employee_name']?.toString() ?? 'Unknown Employee',
            company['company_name']?.toString() ?? 'Unknown',
            request['start_date']?.toString() ?? 'N/A',
            request['end_date']?.toString() ?? 'N/A',
            request['reason']?.toString() ?? 'N/A',
            request['status']?.toString() ?? 'N/A',
            request['created_at']?.toString() ?? 'N/A',
          ];
        }).toList(),
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
      final filename = 'leave_requests_$formattedDate.csv';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsString(csvString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported to $filePath'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLeaveRequestForm() {
    final isAdmin = widget.user['role'] == 'admin';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Text(
          'Apply Leave',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.teal[900],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin) _buildEmployeeDropdown(),
              _buildTextField(_startDateController, 'Start Date (YYYY-MM-DD)',
                  onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  _startDateController.text =
                      pickedDate.toIso8601String().split('T')[0];
                }
              }),
              _buildTextField(_endDateController, 'End Date (YYYY-MM-DD)',
                  onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  _endDateController.text =
                      pickedDate.toIso8601String().split('T')[0];
                }
              }),
              _buildTextField(_reasonController, 'Reason', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.teal[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitLeaveRequest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedEmployeeId,
        decoration: InputDecoration(
          labelText: 'Select Employee',
          labelStyle: TextStyle(color: Colors.teal[900]),
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
        items: _employees.map((employee) {
          return DropdownMenuItem<String>(
            value: employee['employee_id'],
            child: Text(
              employee['fullname'] ?? 'Unknown Employee',
              style: TextStyle(color: Colors.grey[800]),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedEmployeeId = value;
            _fetchData(); // Refresh leave balance for selected employee
          });
        },
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<int>(
        value: _selectedCompanyId,
        decoration: InputDecoration(
          labelText: 'Select Company',
          labelStyle: TextStyle(color: Colors.teal[900]),
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
        items: companyIds.map((id) {
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              companyIdToName[id] ?? 'Unknown',
              style: TextStyle(color: Colors.grey[800]),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCompanyId = value;
            _selectedEmployeeId = null;
            _fetchData();
          });
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal[900]),
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
        maxLines: maxLines,
        readOnly: onTap != null,
        onTap: onTap,
        style: TextStyle(color: Colors.grey[800]),
      ),
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.grey.withOpacity(0.3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.teal[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.teal[500]),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal[900],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin';
    final userEmployeeId = widget.user['employee_id']?.toString();

    return Scaffold(
      appBar: CustomAppBar(
        title: isAdmin ? 'Leave Management (Admin)' : 'My Leave',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.teal[700]),
                    title: Text('Profile: ${widget.user['username']}'),
                    subtitle: Text('Role: ${widget.user['role']}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      _logout(context);
                    },
                  ),
                ],
              ),
            ),
          );
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
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdmin ? 'Leave Management' : 'My Leave Overview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isAdmin && _selectedCompanyId == 0)
                            _buildSectionTile(
                              icon: Icons.info,
                              title: 'All Companies',
                              subtitle: 'Showing data for all companies',
                            )
                          else
                            _buildSectionTile(
                              icon: Icons.event,
                              title: isAdmin
                                  ? 'Selected Employee Leave Balance'
                                  : 'Your Leave Balance',
                              subtitle: _selectedEmployeeId == null
                                  ? 'No employee selected'
                                  : '$_leaveBalance days remaining',
                            ),
                          const SizedBox(height: 16),
                          if (isAdmin)
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
                                    if (companyIds.length > 1)
                                      _buildCompanyDropdown(),
                                    _buildEmployeeDropdown(),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showLeaveRequestForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    isAdmin
                                        ? 'Apply Leave for Employee'
                                        : 'Apply for Leave',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _exportToCsv,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text(
                                          'Export to CSV',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isAdmin
                                ? 'All Leave Requests'
                                : 'Your Leave Requests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _leaveRequests.isEmpty
                              ? Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.teal[50]!
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                        child: Text('No leave requests found')),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _leaveRequests.length,
                                  itemBuilder: (context, index) {
                                    final request = _leaveRequests[index];
                                    final isPending =
                                        request['status'] == 'Pending';
                                    return Card(
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
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
                                        child: ListTile(
                                          leading: const Icon(Icons.person,
                                              color: Colors.teal),
                                          title: Text(
                                            request['employee_name'] ??
                                                'Unknown Employee',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.teal[900],
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Leave: ${request['start_date']} to ${request['end_date']} (${request['status']})\nReason: ${request['reason']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          trailing: isAdmin && isPending
                                              ? Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.check,
                                                          color: Colors.green),
                                                      onPressed: () =>
                                                          _updateLeaveStatus(
                                                              request['id'],
                                                              'Approved'),
                                                      tooltip: 'Approve',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.pause,
                                                          color: Colors.orange),
                                                      onPressed: () =>
                                                          _updateLeaveStatus(
                                                              request['id'],
                                                              'Suspended'),
                                                      tooltip: 'Suspend',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.red),
                                                      onPressed: () =>
                                                          _updateLeaveStatus(
                                                              request['id'],
                                                              'Rejected'),
                                                      tooltip: 'Reject',
                                                    ),
                                                  ],
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
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
}
