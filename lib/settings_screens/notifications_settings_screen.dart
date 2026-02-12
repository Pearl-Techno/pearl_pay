import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class NotificationsSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const NotificationsSettingsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _enableNotifications = true;
  bool _emailAlerts = false;
  bool _smsAlerts = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load saved notification preferences
  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

     // final prefs = await widget.apiService.getNotificationPreferences(
    //      widget.user['id'].toString());
     // setState(() {
      //  _enableNotifications = prefs['enable_notifications'] ?? true;
      //  _emailAlerts = prefs['email_alerts'] ?? false;
      //  _smsAlerts = prefs['sms_alerts'] ?? false;
      //});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading preferences: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadPreferences,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Save notification preferences
  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

      // final preferences = {
      //   'user_id': widget.user['id'].toString(),
      //   'enable_notifications': _enableNotifications,
      //   'email_alerts': _emailAlerts,
      //   'sms_alerts': _smsAlerts,
      // };

     // await widget.apiService.updateNotificationPreferences(preferences);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification settings saved successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving preferences: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _savePreferences,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Logout function
  Future<void> _logout() async {
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
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notification Settings',
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
                    title: Text('Profile: ${widget.user['username'] ?? 'Unknown'}'),
                    subtitle: Text('Role: ${widget.user['role'] ?? 'Unknown'}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Notifications',
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
                              color: Colors.teal[700],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text(
                                  'Enable Notifications',
                                  style: TextStyle(fontSize: 16),
                                ),
                                subtitle: const Text(
                                  'Receive push notifications for app updates',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _enableNotifications,
                                onChanged: (value) {
                                  setState(() {
                                    _enableNotifications = value;
                                    if (!value) {
                                      _emailAlerts = false;
                                      _smsAlerts = false;
                                    }
                                  });
                                },
                                activeTrackColor: Colors.teal[700],
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                              ),
                              SwitchListTile(
                                title: const Text(
                                  'Email Alerts',
                                  style: TextStyle(fontSize: 16),
                                ),
                                subtitle: const Text(
                                  'Receive notifications via email',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _emailAlerts,
                                onChanged: _enableNotifications
                                    ? (value) {
                                        setState(() {
                                          _emailAlerts = value;
                                        });
                                      }
                                    : null,
                                activeTrackColor: Colors.teal[700],
                                inactiveTrackColor: Colors.grey[300],
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                              ),
                              SwitchListTile(
                                title: const Text(
                                  'SMS Alerts',
                                  style: TextStyle(fontSize: 16),
                                ),
                                subtitle: const Text(
                                  'Receive notifications via SMS',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _smsAlerts,
                                onChanged: _enableNotifications
                                    ? (value) {
                                        setState(() {
                                          _smsAlerts = value;
                                        });
                                      }
                                    : null,
                                activeTrackColor: Colors.teal[700],
                                inactiveTrackColor: Colors.grey[300],
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _savePreferences,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(fontSize: 16),
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
}
