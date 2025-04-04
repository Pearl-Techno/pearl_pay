import 'package:flutter/material.dart';

import '../payment_menu_screens/allowances_screen.dart';
import '../payment_menu_screens/benefits_screen.dart';
import '../payment_menu_screens/bonus_screen.dart';
import '../payment_menu_screens/deductions_screen.dart';
import '../payment_menu_screens/education_screen.dart';
import '../payment_menu_screens/insurance_relief_screen.dart';
import '../payment_menu_screens/insurance_screen.dart';
import '../payment_menu_screens/loan_repayment_screen.dart'; // Import LoanRepaymentScreen
import '../payment_menu_screens/loans_screen.dart';
import '../payment_menu_screens/medical_screen.dart';
import '../payment_menu_screens/overtime_screen.dart';
import '../payment_menu_screens/paid_salaries_screen.dart';
import '../payment_menu_screens/pay_bills_screen.dart';
import '../payment_menu_screens/pay_salaries_screen.dart';
import '../widgets/custom_app_bar.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Payments',
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First row with 7 tiles
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMenuTile(
                            context,
                            icon: Icons.payment,
                            title: 'Pay Salaries',
                            subtitle: 'Process employee salaries',
                            destination: PaySalariesScreen(),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.done_all,
                            title: 'Paid Salaries',
                            subtitle: 'View paid salaries',
                            destination: PaidSalariesScreen(),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.receipt,
                            title: 'Pay Bills',
                            subtitle: 'Pay utility bills',
                            destination: PayBillsScreen(),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.access_time,
                            title: 'Overtime',
                            subtitle: 'Manage overtime',
                            destination: OvertimeScreen(),
                            backgroundColor: Colors.purple[50]!,
                            iconColor: Colors.purple[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.account_balance_wallet,
                            title: 'Loans',
                            subtitle: 'Manage loans',
                            destination: LoansScreen(),
                            backgroundColor: Colors.indigo[50]!,
                            iconColor: Colors.indigo[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.card_giftcard,
                            title: 'Benefits',
                            subtitle: 'Manage benefits',
                            destination: BenefitsScreen(),
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.attach_money,
                            title: 'Bonus',
                            subtitle: 'Manage bonuses',
                            destination: BonusScreen(),
                            backgroundColor: Colors.orange[50]!,
                            iconColor: Colors.orange[500]!,
                            tileCount: 7,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Second row with 7 tiles (including Loan Repayment)
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMenuTile(
                            context,
                            icon: Icons.money,
                            title: 'Allowances',
                            subtitle: 'Manage allowances',
                            destination: AllowancesScreen(),
                            backgroundColor: Colors.blue[50]!,
                            iconColor: Colors.blue[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.local_hospital,
                            title: 'Medical',
                            subtitle: 'Manage medical',
                            destination: MedicalScreen(),
                            backgroundColor: Colors.green[50]!,
                            iconColor: Colors.green[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.school,
                            title: 'Education',
                            subtitle: 'Manage education',
                            destination: EducationScreen(),
                            backgroundColor: Colors.yellow[50]!,
                            iconColor: Colors.yellow[700]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.remove_circle_outline,
                            title: 'Deductions',
                            subtitle: 'Manage deductions',
                            destination: DeductionsScreen(),
                            backgroundColor: Colors.red[50]!,
                            iconColor: Colors.red[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.security,
                            title: 'Insurance',
                            subtitle: 'Manage insurance',
                            destination: const InsuranceScreen(),
                            backgroundColor: Colors.purple[50]!,
                            iconColor: Colors.purple[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.monetization_on,
                            title: 'Loan Repayment',
                            subtitle: 'Manage loan repayments',
                            destination: LoanRepaymentScreen(), // Pass an empty list or fetch dynamically
                           
                            backgroundColor: Colors.teal[50]!,
                            iconColor: Colors.teal[500]!,
                            tileCount: 7,
                          ),
                          _buildMenuTile(
                            context,
                            icon: Icons.savings,
                            title: 'Insurance Relief',
                            subtitle: 'Manage relief',
                            destination: const InsuranceReliefScreen(),
                            backgroundColor: Colors.brown[50]!,
                            iconColor: Colors.brown[500]!,
                            tileCount: 7,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
    required Color backgroundColor,
    required Color iconColor,
    required int tileCount,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0; // 16 on each side
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.grey.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: tileWidth,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, backgroundColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.teal[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
