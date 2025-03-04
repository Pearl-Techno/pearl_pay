import 'package:flutter/material.dart';

import 'p10_screen.dart';
import 'p9_screen.dart';
import 'payslip_screen.dart';
import 'reports_screen.dart';

class PrintablesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printables Menu'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Payslips'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PayslipScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('P9 Forms'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => P9Screen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('P10 Forms'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => P10Screen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Other Reports'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
