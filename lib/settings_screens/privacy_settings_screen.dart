import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class PrivacySettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const PrivacySettingsScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PrivacySettingsScreenState createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _shareData = false;
  bool _allowTracking = true;
  bool _shareLocation = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load saved privacy preferences
  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

     // final prefs = await widget.apiService.getPrivacyPreferences(
       //   widget.user['id'].toString());
     // setState(() {
      //  _shareData = prefs['share_data'] ?? false;
      //  _allowTracking = prefs['allow_tracking'] ?? true;
      //  _shareLocation = prefs['share_location'] ?? false;
      //});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading privacy settings: $e'),
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

  // Save privacy preferences
  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

      final preferences = {
        'user_id': widget.user['id'].toString(),
        'share_data': _shareData,
        'allow_tracking': _allowTracking,
        'share_location': _shareLocation,
      };

     // await widget.apiService.updatePrivacyPreferences(preferences);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Privacy settings saved successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving privacy settings: $e'),
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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Privacy Settings',
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
                    title: Text('Profile: ${widget.user['username'] ?? 'Unknown'}'),
                    subtitle: Text('Role: ${widget.user['role'] ?? 'Unknown'}'),
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Settings',
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
                                  'Share Data',
                                  style: TextStyle(fontSize: 16),
                                ),
                                subtitle: const Text(
                                  'Allow data sharing for service improvements',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _shareData,
                                onChanged: (value) {
                                  setState(() {
                                    _shareData = value;
                                  });
                                },
                                activeColor: Colors.teal[700],
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                              ),
                              SwitchListTile(
                                title: const Text(
                                  'Allow Tracking',
                                  style: TextStyle(fontSize: 16),
                                ),
                                subtitle: const Text(
                                  'Enable usage tracking for analytics',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _allowTracking,
                                onChanged: (value) {
                                  setState(() {
                                    _allowTracking = value;
                                  });
                                },
                                activeColor: Colors.teal[700],
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                              ),
                              SwitchListTile(
                                title: const Text(
                                  'Share Location',
                                  style: TextStyle(fontSize: 16),
                                ),
                                subtitle: const Text(
                                  'Allow location sharing for personalized features',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _shareLocation,
                                onChanged: (value) {
                                  setState(() {
                                    _shareLocation = value;
                                  });
                                },
                                activeColor: Colors.teal[700],
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
