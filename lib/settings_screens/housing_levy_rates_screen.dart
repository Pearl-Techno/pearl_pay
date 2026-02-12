import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class HousingLevyRatesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const HousingLevyRatesScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<HousingLevyRatesScreen> createState() => _HousingLevyRatesScreenState();
}

class _HousingLevyRatesScreenState extends State<HousingLevyRatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _housingLevyRateController = TextEditingController();
  bool _isLoading = false;
  bool get _isAdmin => widget.user['role']?.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadHousingLevyRate();
  }

  @override
  void dispose() {
    _housingLevyRateController.dispose();
    super.dispose();
  }

  // Load current Housing Levy rate
  Future<void> _loadHousingLevyRate() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['company_id'] == null) {
        throw Exception('User data is incomplete (missing company ID)');
      }

    // final rate = await widget.apiService.getHousingLevyRate(
      //    widget.user['company_id'].toString());
     // setState(() {
     //   _housingLevyRateController.text = rate['housing_levy_rate']?.toString() ?? '1.5';
     // });
      _housingLevyRateController.text = '1.5'; // Placeholder for actual rate
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading Housing Levy rate: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadHousingLevyRate,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Save Housing Levy rate
  Future<void> _saveHousingLevyRate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['company_id'] == null || widget.user['id'] == null) {
        throw Exception('User data is incomplete (missing company ID or user ID)');
      }

      // final data = {
      //   'company_id': widget.user['company_id'].toString(),
      //   'user_id': widget.user['id'].toString(),
      //   'housing_levy_rate': double.parse(_housingLevyRateController.text),
      // };

    //  await widget.apiService.updateHousingLevyRate(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Housing Levy rate saved successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving Housing Levy rate: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _saveHousingLevyRate,
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
        title: 'Housing Levy Rates',
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
                  'Set Housing Levy Rates',
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
                                    'Note: Only admins can edit Housing Levy rates.',
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
                                  controller: _housingLevyRateController,
                                  decoration: InputDecoration(
                                    labelText: 'Housing Levy Rate (%)',
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
                                      return 'Housing Levy rate is required';
                                    }
                                    final rate = double.tryParse(value);
                                    if (rate == null) {
                                      return 'Enter a valid number';
                                    }
                                    if (rate <= 0 || rate > 5) {
                                      return 'Rate must be between 0 and 5%';
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
                                      _isLoading ? null : _saveHousingLevyRate,
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
