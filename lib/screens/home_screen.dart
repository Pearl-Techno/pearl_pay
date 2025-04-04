import 'package:flutter/material.dart';

import '../employee_management/add_employee_screen.dart';
import '../employee_management/employee_list_screen.dart';
import '../forms_generator.dart';
import '../widgets/custom_app_bar.dart';
import 'exports_screen.dart';
import 'help_support_screen.dart';
import 'leave_management_screen.dart';
import 'payments_screen.dart';
import 'payroll_summary_screen.dart';
import 'printables_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'time_and_attendance_screen.dart';

class HomeScreen extends StatelessWidget {
  final FormsGenerator formsGenerator = FormsGenerator();
  // final Settings settings = Settings();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Pearl Pay Dashboard',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First row with 6 tiles
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDashboardTile(
                            context,
                            icon: Icons.person_add,
                            title: 'Add Employee',
                            subtitle: 'Add new employee',
                            destination: const AddEmployeeScreen(),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 6,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.list,
                            title: 'Employee List',
                            subtitle: 'View employees',
                            destination: const EmployeeListScreen(),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: 6,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.payment,
                            title: 'Payments',
                            subtitle: 'Manage payments',
                            destination: const PaymentsScreen(),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: 6,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.account_balance_wallet,
                            title: 'Payroll Summary',
                            subtitle: 'View payroll',
                            destination: const PayrollSummaryScreen(),
                            backgroundColor: Colors.indigo[50]!,
                            iconColor: Colors.indigo[500]!,
                            tileCount: 6,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.report,
                            title: 'Reports',
                            subtitle: 'Generate reports',
                            destination: ReportsScreen(),
                            backgroundColor:
                                Colors.red[50]!, // Changed from green[50]
                            iconColor:
                                Colors.red[500]!, // Changed from green[500]
                            tileCount: 6,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.access_time,
                            title: 'Time & Attendance',
                            subtitle: 'Track time',
                            destination: const TimeAndAttendanceScreen(),
                            backgroundColor: Colors.purple[50]!,
                            iconColor: Colors.purple[500]!,
                            tileCount: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Second row with 5 tiles
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDashboardTile(
                            context,
                            icon: Icons.event,
                            title: 'Leave Management',
                            subtitle: 'Manage leaves',
                            destination: const LeaveManagementScreen(),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[500]!,
                            tileCount: 5,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.print,
                            title: 'Printables',
                            subtitle: 'Print documents',
                            destination: PrintablesScreen(),
                            backgroundColor: Colors.orange[50]!,
                            iconColor: Colors.orange[500]!,
                            tileCount: 5,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.file_download,
                            title: 'Exports',
                            subtitle: 'Export data',
                            destination: const ExportsScreen(),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 5,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.settings,
                            title: 'Settings',
                            subtitle: 'Configure app',
                            destination: const SettingsScreen(),
                            backgroundColor:
                                Colors.grey[50]!, // Changed from yellow[50]
                            iconColor:
                                Colors.grey[700]!, // Changed from yellow[700]
                            tileCount: 5,
                          ),
                          _buildDashboardTile(
                            context,
                            icon: Icons.help,
                            title: 'Help & Support',
                            subtitle: 'Get assistance',
                            destination: HelpSupportScreen(),
                            backgroundColor:
                                Colors.pink[50]!, // Changed from orange[50]
                            iconColor:
                                Colors.pink[500]!, // Changed from orange[500]
                            tileCount: 5,
                          ),
                        ],
                      ),
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

  Widget _buildDashboardTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
    required Color backgroundColor,
    required Color iconColor,
    required int tileCount,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0; // 16 on each side
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.grey.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: tileWidth,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, backgroundColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.teal[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
