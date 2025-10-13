import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';

class AllowancesScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const AllowancesScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<AllowancesScreen> createState() => _AllowancesScreenState();
}

class _AllowancesScreenState extends State<AllowancesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Allowances',
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
        child: Text('Allowances Screen Content'),
      ),
    );
  }
}
