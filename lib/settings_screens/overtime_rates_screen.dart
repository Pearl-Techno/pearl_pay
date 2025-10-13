import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class OvertimeRatesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const OvertimeRatesScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _OvertimeRatesScreenState createState() => _OvertimeRatesScreenState();
}

class _OvertimeRatesScreenState extends State<OvertimeRatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _overtimeRateController = TextEditingController();
  bool _isLoading = false;
  bool get _isAdmin => widget.user['role']?.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadOvertimeRate();
  }

  @override
  void dispose() {
    _overtimeRateController.dispose();
    super.dispose();
  }

  // Load current Overtime rate
  Future<void> _loadOvertimeRate() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['company_id'] == null) {
        throw Exception('User data is incomplete (missing company ID)');
      }

     // final rate = await widget.apiService.getOvertimeRate(
     //     widget.user['company_id'].toString());
     // setState(() {
     //   _overtimeRateController.text = rate['overtime_rate']?.toString() ?? '150.0';
     // });
      _overtimeRateController.text = '150.0'; // Placeholder for actual rate
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading Overtime rate: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadOvertimeRate,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Save Overtime rate
  Future<void> _saveOvertimeRate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['company_id'] == null || widget.user['id'] == null) {
        throw Exception('User data is incomplete (missing company ID or user ID)');
      }

      final data = {
        'company_id': widget.user['company_id'].toString(),
        'user_id': widget.user['id'].toString(),
        'overtime_rate': double.parse(_overtimeRateController.text),
      };

    //  await widget.apiService.updateOvertimeRate(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Overtime rate saved successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving Overtime rate: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _saveOvertimeRate,
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
        title: 'Overtime Rates',
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
                  'Set Overtime Rates',
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
                              if (!_isAdmin)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    'Note: Only admins can edit Overtime rates.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              Form(
                                key: _formKey,
                                child: TextFormField(
                                  controller: _overtimeRateController,
                                  decoration: InputDecoration(
                                    labelText: 'Overtime Rate (%)',
                                    labelStyle:
                                        TextStyle(color: Colors.teal[900]),
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
                                    prefixIcon: Icon(Icons.percent,
                                        color: Colors.teal[700]),
                                    enabled: _isAdmin,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Overtime rate is required';
                                    }
                                    final rate = double.tryParse(value);
                                    if (rate == null) {
                                      return 'Enter a valid number';
                                    }
                                    if (rate <= 0 || rate > 200) {
                                      return 'Rate must be between 0 and 200%';
                                    }
                                    return null;
                                  },
                                  readOnly: !_isAdmin,
                                ),
                              ),
                              if (_isAdmin) ...[
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _saveOvertimeRate,
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
