import 'dart:io' show Platform; // Add this for platform detection

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/custom_app_bar.dart';

class HelpSettingsScreen extends StatelessWidget {
  const HelpSettingsScreen({super.key});

  // Function to launch email
  Future<void> _launchEmail(String email, BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Support Request'},
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showErrorSnackBar(context, 'Could not launch email client');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error launching email: $e');
    }
  }

  // Function to launch phone (mobile only)
  Future<void> _launchPhone(String phone, BuildContext context) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _showErrorSnackBar(context, 'Phone calls are not supported on desktop');
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showErrorSnackBar(context, 'Could not launch phone dialer');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error launching phone: $e');
    }
  }

  // Function to launch WhatsApp
  Future<void> _launchWhatsApp(String phone, BuildContext context) async {
    final Uri whatsappUri = Uri.parse('https://wa.me/$phone');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(context, 'Could not launch WhatsApp');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error launching WhatsApp: $e');
    }
  }

  // Helper function to show error SnackBar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Help & Support',
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[900],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.person,
                                color: Colors.teal[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Developer/Support: Wesonga Mukoya',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _launchPhone('+254788330998', context),
                          child: Row(
                            children: [
                              Icon(Icons.phone,
                                  color: Colors.teal[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Call: +254 788330998',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              _launchWhatsApp('+254788330998', context),
                          child: Row(
                            children: [
                              Icon(Icons.chat,
                                  color: Colors.teal[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'WhatsApp: +254 788330998',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              _launchEmail('mu.wesonga@gmail.com', context),
                          child: Row(
                            children: [
                              Icon(Icons.email,
                                  color: Colors.teal[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Email: mu.wesonga@gmail.com',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.teal[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Resources',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[900],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: Icon(Icons.help_outline,
                              color: Colors.teal[700], size: 24),
                          title: Text(
                            'Visit Help Center',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal[700],
                            ),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Help Center coming soon!'),
                                backgroundColor: Colors.teal[700],
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.feedback,
                              color: Colors.teal[700], size: 24),
                          title: Text(
                            'Send Feedback',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal[700],
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, '/send_feedback');
                          },
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
}
