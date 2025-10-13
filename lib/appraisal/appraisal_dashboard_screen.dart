import 'package:flutter/material.dart';
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:pearl_pay/widgets/custom_app_bar.dart' as custom_widgets;

import 'appraisal_detail_screen.dart';
import 'employee_appraisal_screen.dart';
import 'self_appraisal_screen.dart';

class AppraisalDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AppraisalDashboardScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  _AppraisalDashboardScreenState createState() =>
      _AppraisalDashboardScreenState();
}

class _AppraisalDashboardScreenState extends State<AppraisalDashboardScreen> {
  late User userModel;
  List<Map<String, dynamic>> appraisals = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedFilter = 'All';
  List<Map<String, dynamic>> _employees = [];
  bool _isLoadingEmployees = false;

  @override
  void initState() {
    super.initState();
    userModel = User.fromMap(widget.user);
    _fetchAppraisals();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoadingEmployees = true;
    });
    try {
      final employees =
          await widget.apiService.getEmployeeList(userModel.companyId);
      setState(() {
        _employees = employees;
        _isLoadingEmployees = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingEmployees = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load employees: $e',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _fetchAppraisals() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await widget.apiService.getAppraisals(
        companyId: userModel.companyId,
        role: userModel.role,
        employeeId: userModel.employeeId,
        filter: selectedFilter,
      );
      setState(() {
        appraisals = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _updateAppraisalStatus(String appraisalId, String status) async {
    try {
      await widget.apiService.updateAppraisalStatus(
        appraisalId: appraisalId,
        status: status,
        companyId: userModel.companyId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appraisal status updated to $status',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _fetchAppraisals();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _showEmployeeSelectionDialog() async {
    String? selectedEmployeeId;
    String? selectedEmployeeName;
    String? selectedEmployeePosition;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Text(
            'Select Employee to Appraise',
            style: TextStyle(
              color: Colors.teal.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingEmployees)
                const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.teal.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: selectedEmployeeId,
                  hint: Text(
                    'Select Employee',
                    style: TextStyle(color: Colors.teal.shade700, fontSize: 16),
                  ),
                  isExpanded: true,
                  items: _employees.map((employee) {
                    return DropdownMenuItem<String>(
                      value: employee['employee_id'].toString(),
                      child: Text(
                        '${employee['fullname']} (ID: ${employee['employee_id']})',
                        style: TextStyle(
                            color: Colors.teal.shade900, fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedEmployeeId = value;
                      final employee = _employees.firstWhere(
                          (e) => e['employee_id'].toString() == value);
                      selectedEmployeeName = employee['fullname'];
                      selectedEmployeePosition = employee['position'];
                    });
                  },
                  style: TextStyle(color: Colors.teal.shade900, fontSize: 16),
                  dropdownColor: Colors.white,
                  underline: const SizedBox(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.teal.shade700, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: selectedEmployeeId == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'employeeId': selectedEmployeeId,
                        'employeeName': selectedEmployeeName,
                        'employeePosition': selectedEmployeePosition,
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('Proceed', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmployeeAppraisalScreen(
              user: userModel,
              apiService: widget.apiService,
              onSubmit: _fetchAppraisals,
              employeeId: value['employeeId'],
              employeeName: value['employeeName'] ?? 'Unknown',
              employeePosition: value['employeePosition'] ?? 'Unknown',
            ),
          ),
        );
      }
    });
  }

  String _getEmployeeName(String employeeId) {
    final employee = _employees.firstWhere(
      (e) => e['employee_id'].toString() == employeeId,
      orElse: () => {'fullname': 'Unknown'},
    );
    return employee['fullname'] as String;
  }

  String _getEmployeePosition(String employeeId) {
    final employee = _employees.firstWhere(
      (e) => e['employee_id'].toString() == employeeId,
      orElse: () => {'position': 'Unknown'},
    );
    return employee['position'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final isEmployee = userModel.role == 'employee';
    final isManager = userModel.role == 'manager';
    final isAdmin = userModel.role == 'admin';

    return Scaffold(
      appBar: custom_widgets.CustomAppBar(
        title: 'Appraisal Dashboard',
        backgroundColor: Colors.teal.shade800,
        onNotificationTap: () {},
        onProfileTap: () {},
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.teal.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchAppraisals,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Retry',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isEmployee || isAdmin)
                              _buildActionButton(
                                label: 'Self Appraisal',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SelfAppraisalScreen(
                                        user: userModel,
                                        apiService: widget.apiService,
                                        onSubmit: _fetchAppraisals,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (isAdmin)
                              _buildActionButton(
                                label: 'Employee Appraisal',
                                onPressed: _showEmployeeSelectionDialog,
                              ),
                            if (isManager || isAdmin)
                              Container(
                                width: 120,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.teal.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedFilter,
                                  isExpanded: true,
                                  items: [
                                    'All',
                                    'Pending',
                                    'Approved',
                                    'Rejected'
                                  ]
                                      .map((e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e,
                                                style: TextStyle(
                                                    color: Colors.teal.shade900,
                                                    fontSize: 16)),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedFilter = value;
                                      _fetchAppraisals();
                                    });
                                  },
                                  style: TextStyle(
                                      color: Colors.teal.shade900,
                                      fontSize: 16),
                                  dropdownColor: Colors.white,
                                  underline: const SizedBox(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchAppraisals,
                          color: Colors.teal.shade600,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 24,
                                      headingRowHeight: 56,
                                      dataRowHeight: 72,
                                      headingTextStyle: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade900,
                                      ),
                                      dataTextStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.teal.shade800,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.teal.shade200),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('Appraisal ID')),
                                        DataColumn(label: Text('Employee ID')),
                                        DataColumn(
                                            label: Text('Employee Name')),
                                        DataColumn(label: Text('Position')),
                                        DataColumn(label: Text('Period')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: appraisals.map((appraisal) {
                                        final employeeName = _getEmployeeName(
                                            appraisal['employee_id']
                                                .toString());
                                        final employeePosition =
                                            _getEmployeePosition(
                                                appraisal['employee_id']
                                                    .toString());
                                        return DataRow(cells: [
                                          DataCell(Text(
                                              appraisal['appraisal_id']
                                                  .toString())),
                                          DataCell(Text(appraisal['employee_id']
                                              .toString())),
                                          DataCell(Text(employeeName)),
                                          DataCell(Text(employeePosition)),
                                          DataCell(Text(appraisal['period'])),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                    appraisal['status']),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                appraisal['status'],
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if ((isManager || isAdmin) &&
                                                    appraisal['status'] ==
                                                        'Pending') ...[
                                                  _buildTableButton(
                                                    label: 'Approve',
                                                    color: Colors.teal.shade600,
                                                    onPressed: () {
                                                      _updateAppraisalStatus(
                                                          appraisal[
                                                                  'appraisal_id']
                                                              .toString(),
                                                          'Approved');
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildTableButton(
                                                    label: 'Reject',
                                                    color: Colors.red.shade600,
                                                    onPressed: () {
                                                      _updateAppraisalStatus(
                                                          appraisal[
                                                                  'appraisal_id']
                                                              .toString(),
                                                          'Rejected');
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                _buildTableButton(
                                                  label: 'View Details',
                                                  color: Colors.teal.shade600,
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            AppraisalDetailScreen(
                                                          appraisal: appraisal,
                                                          user: userModel,
                                                          apiService:
                                                              widget.apiService,
                                                          employeeName:
                                                              employeeName,
                                                          employeePosition:
                                                              employeePosition,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildActionButton(
      {required String label, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 4,
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildTableButton(
      {required String label,
      required Color color,
      required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(80, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.teal.shade600;
    }
  }
}
