import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class PayBillsScreen extends StatelessWidget {
  final User user;
  final ApiService apiService;
  const PayBillsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Pay Bills',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          // Add your notification handling logic here
          developer.log('Notifications tapped', name: 'PayBillsScreen');
        },
        onProfileTap: () {
          // Add your profile handling logic here
          developer.log('Profile tapped', name: 'PayBillsScreen');
        },
      ),
      body: Center(
        child: Text('Pay Bills Screen Content'),
      ),
    );
  }
}
