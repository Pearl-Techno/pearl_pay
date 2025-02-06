import 'package:flutter/material.dart';

class PaidSalariesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paid Salaries'),
      ),
      body: Center(
        child: Text('List of paid salaries will be displayed here.'),
      ),
    );
  }
}