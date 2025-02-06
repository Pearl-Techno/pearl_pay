import 'package:flutter/material.dart';

import '../forms_generator.dart';
//import '../services.dart';
import '../settings.dart';
import 'add_employee_screen.dart';
import 'employee_list_screen.dart';
import 'help_support_screen.dart';
import 'payments_screen.dart';
import 'printables_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final FormsGenerator formsGenerator = FormsGenerator();
  //final PayrollService payrollService = PayrollService();
  final Settings settings = Settings();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pearl Pay Dashboard'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.teal.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: Colors.teal),
                    title: Text('Add Employee',
                        style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddEmployeeScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.list, color: Colors.teal),
                    title: Text('Employee List',
                        style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EmployeeListScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.payment, color: Colors.teal),
                    title:
                        Text('Payments', style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PaymentsScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.print, color: Colors.teal),
                    title: Text('Printables',
                        style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PrintablesScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.report, color: Colors.teal),
                    title:
                        Text('Reports', style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReportsScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.settings, color: Colors.teal),
                    title:
                        Text('Settings', style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SettingsScreen()),
                      );
                    },
                  ),
                ),
                Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.help, color: Colors.teal),
                    title: Text('Help & Support',
                        style: TextStyle(color: Colors.teal)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HelpSupportScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
