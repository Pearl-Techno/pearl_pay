import 'package:flutter/material.dart';

import '../widgets/custom_app_bar.dart';

class P10Screen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: CustomAppBar(
        title: 'P10 Screen',
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
        child: Text('Welcome to P10 Screen!'),
      ),
    );
  }
}