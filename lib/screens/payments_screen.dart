import 'package:flutter/material.dart';

import '../payment_menu_screens/allowances_screen.dart';
import '../payment_menu_screens/benefits_screen.dart';
import '../payment_menu_screens/bonus_screen.dart';
import '../payment_menu_screens/deductions_screen.dart';
import '../payment_menu_screens/education_screen.dart';
import '../payment_menu_screens/insurance_relief_screen.dart'; // New import
import '../payment_menu_screens/insurance_screen.dart'; // New import
import '../payment_menu_screens/loans_screen.dart';
import '../payment_menu_screens/medical_screen.dart';
import '../payment_menu_screens/overtime_screen.dart';
import '../payment_menu_screens/paid_salaries_screen.dart';
import '../payment_menu_screens/pay_bills_screen.dart';
import '../payment_menu_screens/pay_salaries_screen.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  _buildMenuCard(
                    context,
                    icon: Icons.payment,
                    title: 'Pay Salaries',
                    subtitle: 'Process employee salaries',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PaySalariesScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.done_all,
                    title: 'Paid Salaries',
                    subtitle: 'View paid salaries',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PaidSalariesScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.receipt,
                    title: 'Pay Bills',
                    subtitle: 'Pay utility and other bills',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PayBillsScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.access_time,
                    title: 'Overtime',
                    subtitle: 'Manage overtime payments',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => OvertimeScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Loans',
                    subtitle: 'Manage employee loans',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoansScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.card_giftcard,
                    title: 'Benefits',
                    subtitle: 'Manage employee benefits',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BenefitsScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'Bonus',
                    subtitle: 'Manage bonus payments',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BonusScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.money,
                    title: 'Allowances',
                    subtitle: 'Manage allowances',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AllowancesScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.local_hospital,
                    title: 'Medical',
                    subtitle: 'Manage medical payments',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MedicalScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.school,
                    title: 'Education',
                    subtitle: 'Manage education payments',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EducationScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.remove_circle_outline,
                    title: 'Deductions',
                    subtitle: 'Manage deductions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => DeductionsScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.security,
                    title: 'Add Insurance',
                    subtitle: 'Manage insurance payments',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const InsuranceScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.savings,
                    title: 'Insurance Relief',
                    subtitle: 'Manage insurance relief',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const InsuranceReliefScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.teal, size: 40),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
