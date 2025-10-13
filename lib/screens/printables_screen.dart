import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../printables/p10_screen.dart';
import '../printables/p9_screen.dart';
import '../printables/payslip_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';
import 'reports_screen.dart';

class PrintablesScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const PrintablesScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

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

  @override
  Widget build(BuildContext context) {
    // Validate user data
    if (user['company_id'] == null || user['role'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User data is incomplete (missing company ID or role)')),
        );
      });
    }

    final isAdmin = user['role'] == 'admin';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Printables',
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
                    title: Text('Profile: ${user['username'] ?? 'Unknown'}'),
                    subtitle: Text('Role: ${user['role'] ?? 'Unknown'}'),
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
                    Text(
                      'Printable Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First row with 2 tiles
                    SizedBox(
                      height: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMenuTile(
                            context,
                            icon: Icons.receipt_long,
                            title: 'Payslips',
                            subtitle: 'View and print payslips',
                            destination: PayslipScreen(
                              user: user,
                              apiService: apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.assignment,
                            title: 'P9 Forms',
                            subtitle: 'View and print P9 forms',
                            destination: P9Screen(
                              user: user,
                              apiService: apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Second row with 2 tiles
                    SizedBox(
                      height: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMenuTile(
                            context,
                            icon: Icons.assignment,
                            title: 'P10 Forms',
                            subtitle: 'View and print P10 forms',
                            destination: P10Screen(
                              user: user,
                              apiService: apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                            enabled: isAdmin,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.bar_chart,
                            title: 'Reports',
                            subtitle: 'View and print reports',
                            destination: ReportsScreen(
                              user: user,
                              apiService: apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                            enabled: isAdmin,
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

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
    required Color backgroundColor,
    required Color iconColor,
    required int tileCount,
    bool enabled = true,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0; // 16 on each side
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;

    return Card(
      elevation: enabled ? 6 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.grey.withOpacity(enabled ? 0.3 : 0.1),
      child: InkWell(
        onTap: enabled
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => destination),
                );
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Access restricted to admins only')),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: tileWidth,
          height: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                enabled ? Colors.white : Colors.grey[200]!,
                enabled ? backgroundColor : Colors.grey[300]!
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 28, color: enabled ? iconColor : Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.teal[900] : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.grey[700] : Colors.grey[500],
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
