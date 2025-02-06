import 'package:flutter/material.dart';

class MedicalScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medical Screen'),
      ),
      body: Center(
        child: Text('Welcome to the Medical Screen!'),
      ),
    );
  }
}