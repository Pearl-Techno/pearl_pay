import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exports/housing_levy_export.dart';
import '../exports/nssf_export.dart';
import '../exports/paye_export.dart';
import '../exports/shif_export.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';

class ExportsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const ExportsScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

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
    final userCompanyId = user['company_id'] != null
        ? int.tryParse(user['company_id'].toString())
        : null;
    final userCompanyName = user['company_name']?.toString() ?? 'Unknown';
    final isAdmin = user['role'] == 'admin';

    if (userCompanyId == null || user['role'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('User data is incomplete (missing company ID or role)')),
        );
      });
    }

    // Initialize export classes with user, apiService, and company_id
    final nssfExport = NSSFExport(
      user: user,
      apiService: apiService,
      companyId: userCompanyId,
    );
    final shifExport = SHIFExport(
      user: user,
      apiService: apiService,
      companyId: userCompanyId,
    );
    final housingLevyExport = HousingLevyExport(
      user: user,
      apiService: apiService,
      companyId: userCompanyId,
    );
    final payeExport = PAYEExport(
      user: user,
      apiService: apiService,
      companyId: userCompanyId,
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Exports',
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
                        child: Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal[200]!),
                                ),
                                child: Text(
                                  userCompanyName,
                                  style: TextStyle(
                                    color: Colors.teal[900],
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Export Options',
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
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'NSSF Export',
                            subtitle: 'Export NSSF contributions',
                            exportInstance: nssfExport,
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                            enabled: isAdmin && userCompanyId != null,
                          ),
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'SHIF Export',
                            subtitle: 'Export SHIF contributions',
                            exportInstance: shifExport,
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                            enabled: isAdmin && userCompanyId != null,
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
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'Housing Levy',
                            subtitle: 'Export housing levy data',
                            exportInstance: housingLevyExport,
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                            enabled: isAdmin && userCompanyId != null,
                          ),
                          _buildExportTile(
                            context,
                            icon: Icons.file_download,
                            title: 'PAYE Export',
                            subtitle: 'Export PAYE data',
                            exportInstance: payeExport,
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 2,
                            enabled: isAdmin && userCompanyId != null,
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

  Widget _buildExportTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required dynamic exportInstance, // NSSFExport, SHIFExport, etc.
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
                if (kDebugMode) {
                  print('Navigating to $title details page');
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        exportInstance.buildDetailsPage(context),
                  ),
                );
              }
            : () {
                if (kDebugMode) {
                  print('Export tile disabled: $title');
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Navigation disabled: Admin access required or invalid company ID')),
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
