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

class TimeAndAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const TimeAndAttendanceScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _TimeAndAttendanceScreenState createState() => _TimeAndAttendanceScreenState();
}

class _TimeAndAttendanceScreenState extends State<TimeAndAttendanceScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _attendanceRecords = [];
  DateTime _selectedDate = DateTime.now();
  int? _selectedCompanyId;
  List<int> companyIds = [];
  Map<int, String> companyIdToName = {};

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
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
        await _fetchAttendanceRecords();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load companies: $e')),
      );
    }
  }

  Future<void> _fetchAttendanceRecords() async {
    if (_selectedCompanyId == null) {
      setState(() {
        _attendanceRecords = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isAdmin = widget.user['role'] == 'admin';
      List<Map<String, dynamic>> records = [];

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (_selectedCompanyId == 0 && isAdmin) {
        // Fetch attendance for all companies
        final futures = companyIds.where((id) => id != 0).map((companyId) async {
          return await widget.apiService.getAttendanceRecords(
            companyId: companyId,
            date: dateStr,
            employeeId: null, // Admin fetching all employees
          );
        });
        final results = await Future.wait(futures);
        records = results.expand((r) => r).toList();
      } else {
        // Fetch attendance for a single company
        records = await widget.apiService.getAttendanceRecords(
          companyId: _selectedCompanyId!,
          date: dateStr,
          employeeId: isAdmin ? null : widget.user['employee_id'],
        );
      }

      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching attendance records: $e');
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load attendance records: $e')),
      );
    }
  }

  Future<void> _recordAttendance(bool isClockIn) async {
    if (widget.user['employee_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.recordAttendance(
        companyId: widget.user['company_id'],
        employeeId: widget.user['employee_id'],
        isClockIn: isClockIn,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully ${isClockIn ? 'clocked in' : 'clocked out'}'),
          backgroundColor: Colors.teal,
        ),
      );
      await _fetchAttendanceRecords(); // Refresh records
    } catch (e) {
      if (kDebugMode) {
        print('Error recording attendance: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record attendance: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCsv() async {
    if (_attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance data available to export')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final companyName = _selectedCompanyId == 0
          ? 'All Companies'
          : companyIdToName[_selectedCompanyId] ?? 'Unknown';
      final dateStr = DateFormat('MMM dd yyyy').format(_selectedDate);

      final csvData = [
        ['Attendance Report for', companyName, dateStr],
        ['Employee ID', 'Employee Name', 'Clock In', 'Clock Out', 'Hours Worked', 'Status'],
        ..._attendanceRecords.map((data) {
          final hoursWorked = data['hours_worked']?.toString() ?? 'N/A';
          final status = data['status']?.toString() ?? 'N/A';
          return [
            data['employee_id']?.toString() ?? 'N/A',
            data['employee_name']?.toString() ?? 'Unknown',
            data['clock_in']?.toString() ?? 'N/A',
            data['clock_out']?.toString() ?? 'N/A',
            hoursWorked,
            status,
          ];
        }).toList(),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);

      String baseDir = Platform.isWindows
          ? r'C:\reports'
          : '${(await getApplicationDocumentsDirectory()).path}/reports';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filename =
          'attendance_report_${companyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateFormat('MMM_dd_yyyy').format(_selectedDate)}.csv';
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

  Widget _buildDropdown<T>({
    required T? value,
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

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.teal[700]!,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.teal[900]!,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) {
          setState(() {
            _selectedDate = pickedDate;
            _fetchAttendanceRecords();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Date',
              style: TextStyle(color: Colors.teal[900]),
            ),
            Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: TextStyle(color: Colors.teal[900]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> data) {
    final hoursWorked = data['hours_worked']?.toString() ?? 'N/A';
    final status = data['status']?.toString() ?? 'N/A';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.teal),
        title: Text(data['employee_name'] ?? 'Unknown'),
        subtitle: Text(
          'Clock In: ${data['clock_in'] ?? 'N/A'}\n'
          'Clock Out: ${data['clock_out'] ?? 'N/A'}\n'
          'Hours: $hoursWorked\n'
          'Status: $status',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Time & Attendance',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          if (kDebugMode) {
            print('Notifications tapped');
          }
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
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _recordAttendance(true),
                                    icon: const Icon(Icons.login),
                                    label: const Text('Clock In'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _recordAttendance(false),
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Clock Out'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: _buildDatePicker()),
                                if (isAdmin) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildDropdown(
                                      value: _selectedCompanyId,
                                      items: companyIds,
                                      itemBuilder: (id) =>
                                          companyIdToName[id] ?? 'Unknown',
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCompanyId = value;
                                          _fetchAttendanceRecords();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _exportToCsv,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Export to CSV'),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _attendanceRecords.isEmpty
                          ? Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                                child: const Center(
                                    child: Text('No attendance records available')),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _attendanceRecords.length,
                              itemBuilder: (context, index) =>
                                  _buildAttendanceCard(_attendanceRecords[index]),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}