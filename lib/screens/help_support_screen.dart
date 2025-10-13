import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../help_support/contact_support_screen.dart';
import '../help_support/faq_screen.dart';
import '../help_support/send_feedback_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const HelpSupportScreen({
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
    if (user['username'] == null || user['role'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User data is incomplete (missing username or role)')),
        );
      });
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Help & Support',
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
                      'How can we help you?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildHelpTile(
                            context,
                            icon: Icons.help_outline,
                            title: 'FAQ',
                            subtitle: 'View frequently asked questions',
                            destination: const FAQScreen(),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 3,
                          ),
                          const SizedBox(width: 16),
                          _buildHelpTile(
                            context,
                            icon: Icons.contact_support,
                            title: 'Contact Support',
                            subtitle: 'Get assistance from our team',
                            destination: ContactSupportScreen(
                              user: user,
                              apiService: apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 3,
                          ),
                          const SizedBox(width: 16),
                          _buildHelpTile(
                            context,
                            icon: Icons.feedback,
                            title: 'Send Feedback',
                            subtitle: 'Share your thoughts',
                            destination: SendFeedbackScreen(
                              user: user,
                              apiService: apiService,
                            ),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[700]!,
                            tileCount: 3,
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

  Widget _buildHelpTile(
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
          height: 110,
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
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
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
