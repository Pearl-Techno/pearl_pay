
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../help_support/contact_support_screen.dart';
import '../help_support/send_feedback_screen.dart';
import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AboutSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AboutSettingsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  AboutSettingsScreenState createState() => AboutSettingsScreenState();
}

class AboutSettingsScreenState extends State<AboutSettingsScreen> {
  String _appVersion = '1.0.0';
  String _buildNumber = '1';
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  // Logout function to clear SharedPreferences and navigate to LoginScreen
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Logout',
                style: TextStyle(
                  color: Colors.teal[900],
                  fontWeight: FontWeight.w600,
                )),
            content: Text('Are you sure you want to log out?',
                style: TextStyle(
                  color: Colors.grey[700],
                )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Logout', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _loadAppInfo() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['username'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing username or role)');
      }

      // Fetch app version and build number
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load app info: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!)),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadAppInfo,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'About App',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Handle notifications
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) =>
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person, color: Colors.teal[800]),
                        ),
                        title: Text('Profile: ${widget.user['username'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.teal[900],
                              fontWeight: FontWeight.w600,
                            )),
                        subtitle: Text('Role: ${widget.user['role'] ?? 'Unknown'}',
                            style: TextStyle(color: Colors.grey[700])),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _logout();
                          },
                          icon: const Icon(Icons.logout, size: 20),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal[900],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: Colors.teal[700]),
                          )
                        : _error != null
                            ? Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'Error loading app info',
                                      style: TextStyle(
                                          color: Colors.red[700], fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _loadAppInfo,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal[700],
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                      'App Version', '$_appVersion+$_buildNumber'),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Developed by', 'xAI'),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                      '© ${DateTime.now().year}', 'All Rights Reserved'),
                                  const SizedBox(height: 16),
                                  _buildLink(
                                    'Visit xAI Website',
                                    'https://x.ai',
                                    Icons.language,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildLink(
                                    'Terms of Service',
                                    'https://x.ai/terms',
                                    Icons.description,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildLink(
                                    'Privacy Policy',
                                    'https://x.ai/privacy',
                                    Icons.privacy_tip,
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Get Involved',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[900],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNavTile(
                          icon: Icons.support_agent,
                          title: 'Contact Support',
                          destination: ContactSupportScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                        ),
                        _buildNavTile(
                          icon: Icons.feedback,
                          title: 'Send Feedback',
                          destination: SendFeedbackScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.teal[900],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildLink(String title, String url, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal[700], size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Colors.teal[700],
          decoration: TextDecoration.underline,
        ),
      ),
      onTap: () => _launchUrl(url),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required Widget destination,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal[700], size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
