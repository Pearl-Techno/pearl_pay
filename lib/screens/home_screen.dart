import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../appraisal/appraisal_dashboard_screen.dart';
import '../employee_management/add_employee_screen.dart';
import '../employee_management/employee_list_screen.dart';
import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'exports_screen.dart';
import 'help_support_screen.dart';
import 'leave_management_screen.dart';
import 'login_screen.dart';
import 'payments_screen.dart';
import 'payroll_summary_screen.dart';
import 'printables_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'time_and_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ApiService apiService;
  late User userModel;
  final ScrollController _firstRowScrollController = ScrollController();
  final ScrollController _secondRowScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    try {
      userModel = User.fromMap(widget.user);
      if (userModel.companyId == 0 ||
          userModel.username == null ||
          userModel.role == null) {
        throw ArgumentError('Invalid or missing required user data');
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid user data: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
        _logout(context);
      });
      return;
    }
    apiService = ApiService(client: http.Client(), user: userModel);
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    apiService.dispose();
    _firstRowScrollController.dispose();
    _secondRowScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = userModel.role == 'admin';
    final isManager = userModel.role == 'manager';
    final isOperator = userModel.role == 'operator';
    final isDirector = userModel.role == 'director';

    return Scaffold(
      appBar: CustomAppBar(
        title:
            'Welcome, ${userModel.username ?? 'User'} (${userModel.companyName ?? 'Company'})',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
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
                    title: Text('Profile: ${userModel.username ?? 'User'}'),
                    subtitle: Text('Role: ${userModel.role}'),
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      shadowColor: Colors.grey.withOpacity(0.3),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal[50]!, Colors.teal[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.business,
                                size: 32, color: Colors.teal[700]),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Managing ${userModel.companyName ?? 'Company'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[900],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dashboard Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: Scrollbar(
                        controller: _firstRowScrollController,
                        thumbVisibility: true,
                        thickness: 8.0,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          controller: _firstRowScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (isAdmin)
                                _buildDashboardTile(
                                  context,
                                  icon: Icons.person_add,
                                  title: 'Add Employee',
                                  subtitle: 'Add new employee',
                                  destination: AddEmployeeScreen(
                                    user: userModel.toMap(),
                                    apiService: apiService,
                                  ),
                                  backgroundColor: Colors.blue[50]!,
                                  iconColor: Colors.blue[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.list,
                                title: 'Employee List',
                                subtitle: 'View employees',
                                destination: EmployeeListScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.green[50]!,
                                iconColor: Colors.green[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.payment,
                                title: 'Payments',
                                subtitle: 'Manage payments',
                                destination: PaymentsScreen(
                                  user: userModel,
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.yellow[50]!,
                                iconColor: Colors.yellow[700]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.account_balance_wallet,
                                title: 'Payroll Summary',
                                subtitle: 'View payroll',
                                destination: PayrollSummaryScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.indigo[50]!,
                                iconColor: Colors.indigo[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.report,
                                title: 'Reports',
                                subtitle: 'Generate reports',
                                destination: ReportsScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.red[50]!,
                                iconColor: Colors.red[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.access_time,
                                title: 'Time & Attendance',
                                subtitle: 'Track time',
                                destination: TimeAndAttendanceScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.purple[50]!,
                                iconColor: Colors.purple[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              // New Appraisal Dashboard Tile
                              //if (isManager || isOperator || isDirector)
                                _buildDashboardTile(
                                  context,
                                  icon: Icons.assignment_ind,
                                  title: 'Appraisals',
                                  subtitle: _getAppraisalSubtitle(),
                                  destination: AppraisalDashboardScreen(
                                    user: userModel.toMap(),
                                    apiService: apiService,
                                  ),
                                  backgroundColor: Colors.orange[50]!,
                                  iconColor: Colors.orange[700]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: Scrollbar(
                        controller: _secondRowScrollController,
                        thumbVisibility: true,
                        thickness: 8.0,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          controller: _secondRowScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildDashboardTile(
                                context,
                                icon: Icons.event,
                                title: 'Leave Management',
                                subtitle: 'Manage leaves',
                                destination: LeaveManagementScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.teal[50]!,
                                iconColor: Colors.teal[500]!,
                                tileCount: 5,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.print,
                                title: 'Printables',
                                subtitle: 'Print documents',
                                destination: PrintablesScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.orange[50]!,
                                iconColor: Colors.orange[500]!,
                                tileCount: 5,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.file_download,
                                title: 'Exports',
                                subtitle: 'Export data',
                                destination: ExportsScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.blue[50]!,
                                iconColor: Colors.blue[500]!,
                                tileCount: 5,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.settings,
                                title: 'Settings',
                                subtitle: 'Configure app',
                                destination: SettingsScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.grey[50]!,
                                iconColor: Colors.grey[700]!,
                                tileCount: 5,
                              ),
                              _buildDashboardTile(
                                context,
                                icon: Icons.help,
                                title: 'Help & Support',
                                subtitle: 'Get assistance',
                                destination: HelpSupportScreen(
                                  user: userModel.toMap(),
                                  apiService: apiService,
                                ),
                                backgroundColor: Colors.pink[50]!,
                                iconColor: Colors.pink[500]!,
                                tileCount: 5,
                              ),
                            ],
                          ),
                        ),
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

  String _getAppraisalSubtitle() {
    switch (userModel.role) {
      case 'manager':
        return 'Manage team appraisals';
      case 'operator':
        return 'View all appraisals';
      case 'director':
        return 'Company-wide appraisals';
      default:
        return 'Performance appraisals';
    }
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
    const minTileWidth = 100.0;
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0;
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;
    final finalTileWidth = tileWidth < minTileWidth ? minTileWidth : tileWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
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
            width: finalTileWidth,
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
                  maxLines: 1,
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
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
