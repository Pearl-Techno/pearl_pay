import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class LanguageSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const LanguageSettingsScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _LanguageSettingsScreenState createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String? _selectedLanguage;
  bool _isLoading = false;
  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Swahili', 'code': 'sw'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'Spanish', 'code': 'es'},
    {'name': 'German', 'code': 'de'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load saved language preference
  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

     // final prefs = await widget.apiService.getLanguagePreference(
      //    widget.user['id'].toString());
     // setState(() {

     //   _selectedLanguage = prefs['language'] ?? 'English';
     // });
      // Simulate a network call
      await Future.delayed(const Duration(seconds: 2));

      // Mock response
      final prefs = {'language': 'English'}; // Replace with actual API call

      setState(() {
        _selectedLanguage = prefs['language'] ?? 'English';
      });
    } catch (e) {
      setState(() {
        _selectedLanguage = 'English'; // Fallback
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading language settings: $e'),
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

  // Save language preference
  Future<void> _savePreferences() async {
    if (_selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a language'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

      final preferences = {
        'user_id': widget.user['id'].toString(),
        'language': _selectedLanguage,
      };

     //await widget.apiService.updateLanguagePreference(preferences);

      // Update app locale (requires app restart or dynamic reload)
      // Placeholder for localization update
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Language settings saved. Restart app to apply changes.'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving language settings: $e'),
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
        title: 'Language Settings',
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
                  'Language Options',
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
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Select Language',
                                  labelStyle: TextStyle(color: Colors.teal[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.teal[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.teal[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.teal[700]!),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon:
                                      Icon(Icons.language, color: Colors.teal[700]),
                                ),
                                value: _selectedLanguage,
                                hint: const Text('Choose a language'),
                                items: _languages
                                    .map((lang) => DropdownMenuItem(
                                          value: lang['name'],
                                          child: Text(lang['name']!),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLanguage = value;
                                  });
                                },
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
