import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  _LeaveManagementScreenState createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  final ApiService apiService = ApiService(client: http.Client());
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

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch admin's own leave balance (optional for admin view)
      final balance = await apiService.getLeaveBalance();
      setState(() {
        _leaveBalance = balance['days_remaining'] ?? 0;
      });

      // Fetch all leave requests
      final requests = await apiService.getLeaveRequests();
      setState(() {
        _leaveRequests = requests;
      });

      // Fetch all employees
      final employees = await apiService.fetchEmployees();
      setState(() {
        _employees = employees;
        _selectedEmployeeId =
            employees.isNotEmpty ? employees[0]['employee_id'] : null;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (_selectedEmployeeId == null ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee and dates')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final leaveData = {
      'employee_id': _selectedEmployeeId,
      'start_date': _startDateController.text,
      'end_date': _endDateController.text,
      'reason': _reasonController.text,
      'status': 'Pending',
    };

    try {
      await apiService.requestLeave(leaveData);
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
    setState(() => _isLoading = true);
    try {
      await apiService.updateLeaveStatus(requestId, status);
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

  void _showLeaveRequestForm() {
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
              _buildDropdown(),
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

  Widget _buildDropdown() {
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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Leave Management (Admin)',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) print('Notifications tapped');
        },
        onProfileTap: () {
          if (kDebugMode) print('Profile tapped');
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
                            'Leave Overview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSectionTile(
                            icon: Icons.event,
                            title: 'Admin Leave Balance',
                            subtitle: '$_leaveBalance days remaining',
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showLeaveRequestForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Apply Leave for Employee',
                                style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All Leave Requests',
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
                                            'Leave: ${request['start_date']} to ${request['end_date']} (${request['status']})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          trailing: isPending
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
