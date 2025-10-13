import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class BonusScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const BonusScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<BonusScreen> createState() => _BonusScreenState();
}

class _BonusScreenState extends State<BonusScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Bonuses',
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
        child: Text(
          'Welcome to the Bonus Screen!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
