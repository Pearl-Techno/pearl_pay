import 'package:flutter/material.dart';

class BonusScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonus Screen'),
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