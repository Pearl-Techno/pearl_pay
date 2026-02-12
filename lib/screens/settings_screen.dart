import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../company_management/add_company_screen.dart';
import '../services/services.dart'; // Import ApiService
import '../settings_screens/about_settings_screen.dart';
import '../settings_screens/account_settings_screen.dart';
import '../settings_screens/help_settings_screen.dart';
import '../settings_screens/housing_levy_rates_screen.dart';
import '../settings_screens/language_settings_screen.dart';
import '../settings_screens/loan_rates_screen.dart';
import '../settings_screens/notifications_settings_screen.dart';
import '../settings_screens/nssf_rates_screen.dart';
import '../settings_screens/overtime_rates_screen.dart';
import '../settings_screens/paye_rates_screen.dart';
import '../settings_screens/privacy_settings_screen.dart';
import '../settings_screens/shif_rates_screen.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart'; // Import LoginScreen for logout navigation

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'admin'; // Check if user is admin

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Settings',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          developer.log('Notifications tapped', name: 'SettingsScreen');
        },
        onProfileTap: () {
          // Show profile options, including logout
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First row with 4-7 tiles (Add Company is admin-only)
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSettingsTile(
                            context,
                            icon: Icons.account_circle,
                            title: 'Account',
                            subtitle: 'Manage account',
                            destination: AccountSettingsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.notifications,
                            title: 'Notifications',
                            subtitle: 'Manage alerts',
                            destination: NotificationsSettingsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.lock,
                            title: 'Privacy',
                            subtitle: 'Privacy settings',
                            destination: PrivacySettingsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.language,
                            title: 'Language',
                            subtitle: 'Language options',
                            destination: LanguageSettingsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            backgroundColor: Colors.orange[50]!,
                            iconColor: Colors.orange[500]!,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.help,
                            title: 'Help',
                            subtitle: 'Get support',
                            destination: HelpSettingsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            backgroundColor: Colors.purple[50]!,
                            iconColor: Colors.purple[500]!,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.info,
                            title: 'About',
                            subtitle: 'App info',
                            destination: AboutSettingsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[500]!,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                          if (isAdmin) // Admin-only
                            _buildSettingsTile(
                              context,
                              icon: Icons.business,
                              title: 'Add Company',
                              subtitle: 'Add company',
                              destination: AddCompanyScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.indigo[50]!,
                              iconColor: Colors.indigo[500]!,
                              tileCount: isAdmin ? 7 : 6,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Second row with 0-6 tiles (all admin-only)
                    if (isAdmin) // Only show for admins
                      SizedBox(
                        height: 110,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSettingsTile(
                              context,
                              icon: Icons.attach_money,
                              title: 'SHIF Rates',
                              subtitle: 'Set SHIF rates',
                              destination: SHIFRatesScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.blue[50]!,
                              iconColor: Colors.blue[500]!,
                              tileCount: 6,
                            ),
                            _buildSettingsTile(
                              context,
                              icon: Icons.attach_money,
                              title: 'NSSF Rates',
                              subtitle: 'Set NSSF rates',
                              destination: NSSFRatesScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.green[50]!,
                              iconColor: Colors.green[500]!,
                              tileCount: 6,
                            ),
                            _buildSettingsTile(
                              context,
                              icon: Icons.attach_money,
                              title: 'Housing Levy',
                              subtitle: 'Set levy rates',
                              destination: HousingLevyRatesScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.yellow[50]!,
                              iconColor: Colors.yellow[700]!,
                              tileCount: 6,
                            ),
                            _buildSettingsTile(
                              context,
                              icon: Icons.attach_money,
                              title: 'Loan Rates',
                              subtitle: 'Set loan rates',
                              destination: LoanRatesScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.orange[50]!,
                              iconColor: Colors.orange[500]!,
                              tileCount: 6,
                            ),
                            _buildSettingsTile(
                              context,
                              icon: Icons.attach_money,
                              title: 'Overtime Rates',
                              subtitle: 'Set overtime rates',
                              destination: OvertimeRatesScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.purple[50]!,
                              iconColor: Colors.purple[500]!,
                              tileCount: 6,
                            ),
                            _buildSettingsTile(
                              context,
                              icon: Icons.attach_money,
                              title: 'PAYE Rates',
                              subtitle: 'Set PAYE rates',
                              destination: PAYERatesScreen(
                                user: widget.user,
                                apiService: widget.apiService,
                              ),
                              backgroundColor: Colors.teal[50]!,
                              iconColor: Colors.teal[500]!,
                              tileCount: 6,
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

  Widget _buildSettingsTile(
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
      shadowColor: Colors.grey.withValues(alpha: 0.3),
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
