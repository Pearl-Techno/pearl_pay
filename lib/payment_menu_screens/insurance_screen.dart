import 'package:flutter/material.dart';

class InsuranceScreen extends StatelessWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Insurance'),
        backgroundColor: Colors.teal,
      ),
      body: const Center(
        child: Text('Insurance management screen will be implemented here.'),
      ),
    );
  }
}
