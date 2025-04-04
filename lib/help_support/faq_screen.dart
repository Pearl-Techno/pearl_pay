import 'package:flutter/material.dart';

import '../widgets/custom_app_bar.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Frequently Asked Questions',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          print('Profile tapped');
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[50]!, Colors.teal[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[900],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildFAQItem(
                      question: 'How do I add an employee to the payroll?',
                      answer:
                          'Navigate to the Employees section, click "Add Employee", and fill in the required details such as name, ID number, and company. Then assign their salary and tax details.',
                    ),
                    _buildFAQItem(
                      question: 'How can I track employee attendance?',
                      answer:
                          'Go to the Time & Attendance module, where you can view clock-in and clock-out times recorded via biometric devices or manual entries. Generate reports from the Reports section.',
                    ),
                    _buildFAQItem(
                      question:
                          'How do I process payroll for a specific month?',
                      answer:
                          'In the Payroll section, select the desired month and year, review employee hours, deductions, and benefits, then click "Process Payroll" to generate payslips compliant with Kenyan tax laws.',
                    ),
                    _buildFAQItem(
                      question: 'Can I calculate PAYE automatically?',
                      answer:
                          'Yes, the software integrates KRA PAYE rates. Enter an employee’s gross salary in the Payroll setup, and it will automatically compute PAYE, NHIF, and NSSF deductions.',
                    ),
                    _buildFAQItem(
                      question: 'How do I handle overtime payments?',
                      answer:
                          'In the Overtime section, input the employee’s overtime hours and rate. The system will calculate the payment and include it in the next payroll run.',
                    ),
                    _buildFAQItem(
                      question: 'How do I generate a P9 form for tax filing?',
                      answer:
                          'Go to Reports > Tax Reports, select the employee and year, and click "Generate P9". The form will be prepared according to KRA requirements.',
                    ),
                    _buildFAQItem(
                      question: 'What if an employee forgets to clock in?',
                      answer:
                          'Admins can manually add attendance records in the Time & Attendance module under "Edit Attendance" with the correct date and time.',
                    ),
                    _buildFAQItem(
                      question: 'How do I contact support for assistance?',
                      answer:
                          'Reach out via the Help & Support section in the app, or email us at support@payrollkenya.co.ke. We’re available 24/7 to assist with payroll and attendance queries.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.teal[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
