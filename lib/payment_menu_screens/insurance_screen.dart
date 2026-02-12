import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class InsuranceScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const InsuranceScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Insurance Management',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Add your notification handling logic here
          developer.log('Notifications tapped', name: 'InsuranceScreen');
        },
        onProfileTap: () {
          // Add your profile handling logic here
          developer.log('Profile tapped', name: 'InsuranceScreen');
        },
      ),
      body: const Center(
        child: Text('Insurance management screen will be implemented here.'),
      ),
    );
  }
}
