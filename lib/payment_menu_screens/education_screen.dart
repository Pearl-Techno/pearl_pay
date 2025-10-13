import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class EducationScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const EducationScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Education Payment',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Add your notification handling logic here
          print('Notifications tapped');
        },
        onProfileTap: () {
          // Add your profile handling logic here
          print('Profile tapped');
        },
      ),
      body: Center(
        child: Text('Education Payment Screen'),
      ),
    );
  }
}