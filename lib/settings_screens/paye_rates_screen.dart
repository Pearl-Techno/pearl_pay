
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';


class PAYERatesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const PAYERatesScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PAYERatesScreenState createState() => _PAYERatesScreenState();
}

class _PAYERatesScreenState extends State<PAYERatesScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool get _isAdmin => widget.user['role']?.toLowerCase() == 'admin';

  // List to manage tax brackets
  final List<Map<String, dynamic>> _taxBrackets = [
    {
      'monthly_range': 'Up to 24,000',
      'annual_range': 'Up to 288,000',
      'rate': '10.0',
      'monthly_controller': TextEditingController(text: 'Up to 24,000'),
      'annual_controller': TextEditingController(text: 'Up to 288,000'),
      'rate_controller': TextEditingController(text: '10.0'),
    },
    {
      'monthly_range': '24,001 - 32,333',
      'annual_range': '288,001 - 388,000',
      'rate': '25.0',
      'monthly_controller': TextEditingController(text: '24,001 - 32,333'),
      'annual_controller': TextEditingController(text: '288,001 - 388,000'),
      'rate_controller': TextEditingController(text: '25.0'),
    },
    {
      'monthly_range': '32,334 - 500,000',
      'annual_range': '388,001 - 6,000,000',
      'rate': '30.0',
      'monthly_controller': TextEditingController(text: '32,334 - 500,000'),
      'annual_controller': TextEditingController(text: '388,001 - 6,000,000'),
      'rate_controller': TextEditingController(text: '30.0'),
    },
    {
      'monthly_range': '500,001 - 800,000',
      'annual_range': '6,000,001 - 9,600,000',
      'rate': '32.5',
      'monthly_controller': TextEditingController(text: '500,001 - 800,000'),
      'annual_controller': TextEditingController(text: '6,000,001 - 9,600,000'),
      'rate_controller': TextEditingController(text: '32.5'),
    },
    {
      'monthly_range': 'Above 800,000',
      'annual_range': 'Above 9,600,000',
      'rate': '35.0',
      'monthly_controller': TextEditingController(text: 'Above 800,000'),
      'annual_controller': TextEditingController(text: 'Above 9,600,000'),
      'rate_controller': TextEditingController(text: '35.0'),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPAYERates();
  }

  @override
  void dispose() {
    for (var bracket in _taxBrackets) {
      bracket['monthly_controller'].dispose();
      bracket['annual_controller'].dispose();
      bracket['rate_controller'].dispose();
    }
    super.dispose();
  }

  // Load current PAYE rates
  Future<void> _loadPAYERates() async {
    setState(() => _isLoading = true);
    try {
      // Validate user data
      if (widget.user['company_id'] == null) {
        throw Exception('User data is incomplete (missing company ID)');
      }

    //  final rates = await widget.apiService.getPAYERates(
      //    widget.user['company_id'].toString());
    //  setState(() {
    //    for (int i = 0; i < _taxBrackets.length && i < rates.length; i++) {
    //      _taxBrackets[i]['monthly_range'] = rates[i]['monthly_range'];
    //      _taxBrackets[i]['annual_range'] = rates[i]['annual_range'];
    //      _taxBrackets[i]['rate'] = rates[i]['rate'].toString();
    //      _taxBrackets[i]['monthly_controller'].text = rates[i]['monthly_range'];
    //      _taxBrackets[i]['annual_controller'].text = rates[i]['annual_range'];
    //      _taxBrackets[i]['rate_controller'].text = rates[i]['rate'].toString();
    //    }
    //  });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading PAYE rates: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadPAYERates,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Save PAYE rates
  Future<void> _savePAYERates() async {
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
        'rates': _taxBrackets.map((bracket) => {
              'monthly_range': bracket['monthly_controller'].text,
              'annual_range': bracket['annual_controller'].text,
              'rate': double.parse(bracket['rate_controller'].text),
            }).toList(),
      };

    //  await widget.apiService.updatePAYERates(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PAYE rates saved successfully'),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving PAYE rates: $e'),
          backgroundColor: Colors.red[700],
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _savePAYERates,
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

  // Validate income ranges
  bool _validateRanges() {
    List<double> monthlyBounds = [];
    List<double> annualBounds = [];

    for (var bracket in _taxBrackets) {
      String monthly = bracket['monthly_controller'].text;
      String annual = bracket['annual_controller'].text;

      // Extract bounds from range strings
      if (monthly.startsWith('Up to')) {
        monthlyBounds.add(double.parse(monthly.replaceAll('Up to', '').trim().replaceAll(',', '')));
      } else if (monthly.startsWith('Above')) {
        monthlyBounds.add(double.parse(monthly.replaceAll('Above', '').trim().replaceAll(',', '')));
      } else {
        var parts = monthly.split('-').map((e) => e.trim().replaceAll(',', '')).toList();
        monthlyBounds.add(double.parse(parts[0]));
        monthlyBounds.add(double.parse(parts[1]));
      }

      if (annual.startsWith('Up to')) {
        annualBounds.add(double.parse(annual.replaceAll('Up to', '').trim().replaceAll(',', '')));
      } else if (annual.startsWith('Above')) {
        annualBounds.add(double.parse(annual.replaceAll('Above', '').trim().replaceAll(',', '')));
      } else {
        var parts = annual.split('-').map((e) => e.trim().replaceAll(',', '')).toList();
        annualBounds.add(double.parse(parts[0]));
        annualBounds.add(double.parse(parts[1]));
      }
    }

    // Check for non-overlapping and increasing bounds
    for (int i = 1; i < monthlyBounds.length; i++) {
      if (monthlyBounds[i] <= monthlyBounds[i - 1]) {
        return false;
      }
    }
    for (int i = 1; i < annualBounds.length; i++) {
      if (annualBounds[i] <= annualBounds[i - 1]) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Set PAYE Rates',
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
                  'Set PAYE Rates',
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
                                    'Note: Only admins can edit PAYE rates.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: _taxBrackets
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    int index = entry.key;
                                    var bracket = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: bracket[
                                                  'monthly_controller'],
                                              decoration: InputDecoration(
                                                labelText: 'Monthly Range',
                                                labelStyle: TextStyle(
                                                    color: Colors.teal[900]),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[200]!),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[200]!),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[700]!),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                enabled: _isAdmin,
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Monthly range required';
                                                }
                                                return null;
                                              },
                                              readOnly: !_isAdmin,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: bracket[
                                                  'annual_controller'],
                                              decoration: InputDecoration(
                                                labelText: 'Annual Range',
                                                labelStyle: TextStyle(
                                                    color: Colors.teal[900]),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[200]!),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[200]!),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[700]!),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                enabled: _isAdmin,
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Annual range required';
                                                }
                                                return null;
                                              },
                                              readOnly: !_isAdmin,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller:
                                                  bracket['rate_controller'],
                                              decoration: InputDecoration(
                                                labelText: 'Rate (%)',
                                                labelStyle: TextStyle(
                                                    color: Colors.teal[900]),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[200]!),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[200]!),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.teal[700]!),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                prefixIcon: Icon(Icons.percent,
                                                    color: Colors.teal[700]),
                                                enabled: _isAdmin,
                                              ),
                                              keyboardType:
                                                  const TextInputType
                                                      .numberWithOptions(
                                                      decimal: true),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Rate required';
                                                }
                                                final rate =
                                                    double.tryParse(value);
                                                if (rate == null) {
                                                  return 'Enter a valid number';
                                                }
                                                if (rate <= 0 || rate > 100) {
                                                  return 'Rate must be between 0 and 100%';
                                                }
                                                return null;
                                              },
                                              readOnly: !_isAdmin,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (_isAdmin) ...[
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          if (_validateRanges()) {
                                            _savePAYERates();
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    'Invalid ranges: Ensure ranges are non-overlapping and increasing.'),
                                                backgroundColor:
                                                    Colors.red[700],
                                              ),
                                            );
                                          }
                                        },
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
