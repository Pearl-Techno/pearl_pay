import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class MedicalScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const MedicalScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<MedicalScreen> createState() => _MedicalScreenState();
}

class _MedicalScreenState extends State<MedicalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Medical Payment',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Add your notification handling logic here
          developer.log('Notifications tapped', name: 'MedicalScreen');
        },
        onProfileTap: () {
          // Add your profile handling logic here
          developer.log('Profile tapped', name: 'MedicalScreen');
        },
      ),
      body: Center(
        child: Text('Welcome to the Medical Screen!'),
      ),
    );
  }
}
