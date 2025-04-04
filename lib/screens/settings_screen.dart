import 'package:flutter/material.dart';

import '../company_management/add_company_screen.dart';
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


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Settings',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Add your notification handling logic here
          print('Notifications tapped');
        },
        onProfileTap: () {
          // Add your profile handling logic here
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
                      'Settings Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First row with 7 tiles
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
                            destination: const AccountSettingsScreen(),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 7,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.notifications,
                            title: 'Notifications',
                            subtitle: 'Manage alerts',
                            destination: const NotificationsSettingsScreen(),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: 7,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.lock,
                            title: 'Privacy',
                            subtitle: 'Privacy settings',
                            destination: const PrivacySettingsScreen(),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: 7,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.language,
                            title: 'Language',
                            subtitle: 'Language options',
                            destination: const LanguageSettingsScreen(),
                            backgroundColor: Colors.orange[50]!,
                            iconColor: Colors.orange[500]!,
                            tileCount: 7,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.help,
                            title: 'Help',
                            subtitle: 'Get support',
                            destination: const HelpSettingsScreen(),
                            backgroundColor: Colors.purple[50]!,
                            iconColor: Colors.purple[500]!,
                            tileCount: 7,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.info,
                            title: 'About',
                            subtitle: 'App info',
                            destination: const AboutSettingsScreen(),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[500]!,
                            tileCount: 7,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.business,
                            title: 'Add Company',
                            subtitle: 'Add company',
                            destination: const AddCompanyScreen(),
                            backgroundColor: Colors.indigo[50]!,
                            iconColor: Colors.indigo[500]!,
                            tileCount: 7,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Second row with 6 tiles
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
                            destination: const SHIFRatesScreen(),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.attach_money,
                            title: 'NSSF Rates',
                            subtitle: 'Set NSSF rates',
                            destination: const NSSFRatesScreen(),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.attach_money,
                            title: 'Housing Levy',
                            subtitle: 'Set levy rates',
                            destination: const HousingLevyRatesScreen(),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.attach_money,
                            title: 'Loan Rates',
                            subtitle: 'Set loan rates',
                            destination: const LoanRatesScreen(),
                            backgroundColor: Colors.orange[50]!,
                            iconColor: Colors.orange[500]!,
                            tileCount: 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.attach_money,
                            title: 'Overtime Rates',
                            subtitle: 'Set overtime rates',
                            destination: const OvertimeRatesScreen(),
                            backgroundColor: Colors.purple[50]!,
                            iconColor: Colors.purple[500]!,
                            tileCount: 6,
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.attach_money,
                            title: 'PAYE Rates',
                            subtitle: 'Set PAYE rates',
                            destination: const PAYERatesScreen(),
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

