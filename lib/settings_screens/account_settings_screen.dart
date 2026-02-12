import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class AccountSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AccountSettingsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Prefill form with user data
    _usernameController =
        TextEditingController(text: widget.user['username']?.toString() ?? '');
    _emailController =
        TextEditingController(text: widget.user['email']?.toString() ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Logout function to clear SharedPreferences and navigate to LoginScreen
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

  // Save account changes via API
  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Validate user data
      if (widget.user['id'] == null || widget.user['role'] == null) {
        throw Exception('User data is incomplete (missing ID or role)');
      }

      // final updatedData = {
      //   'user_id': widget.user['id'].toString(),
      //   'username': _usernameController.text.trim(),
      //   'email': _emailController.text.trim(),
      //   if (_passwordController.text.isNotEmpty)
      //     'password': _passwordController.text,
      // };

      //await widget.apiService.updateAccount(updatedData);

      // Update local user data
      widget.user['username'] = _usernameController.text.trim();
      widget.user['email'] = _emailController.text.trim();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account settings saved successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );

      // Clear password field after save
      _passwordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving account: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _saveAccount,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Account Settings',
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
                  'Manage Account',
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(color: Colors.teal[900]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[700]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon:
                                  Icon(Icons.person, color: Colors.teal[700]),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username is required';
                              }
                              if (value.trim().length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.teal[900]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[700]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon:
                                  Icon(Icons.email, color: Colors.teal[700]),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'New Password (optional)',
                              labelStyle: TextStyle(color: Colors.teal[900]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.teal[700]!),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon:
                                  Icon(Icons.lock, color: Colors.teal[700]),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.teal[700],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.teal[700]),
                                )
                              : ElevatedButton(
                                  onPressed: _saveAccount,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
