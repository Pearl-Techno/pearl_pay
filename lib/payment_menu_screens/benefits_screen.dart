import 'package:flutter/material.dart';

class BenefitsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Benefits'),
      ),
      body: Center(
        child: Text(
          'Welcome to the Benefits Screen!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}