import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../payment_menu_screens/allowances_screen.dart';
import '../payment_menu_screens/benefits_screen.dart';
import '../payment_menu_screens/bonus_screen.dart';
import '../payment_menu_screens/deductions_screen.dart';
import '../payment_menu_screens/education_screen.dart';
import '../payment_menu_screens/insurance_relief_screen.dart';
import '../payment_menu_screens/insurance_screen.dart';
import '../payment_menu_screens/loan_repayment_screen.dart';
import '../payment_menu_screens/loans_screen.dart';
import '../payment_menu_screens/medical_screen.dart';
import '../payment_menu_screens/overtime_screen.dart';
import '../payment_menu_screens/paid_salaries_screen.dart';
import '../payment_menu_screens/pay_bills_screen.dart';
import '../payment_menu_screens/pay_salaries_screen.dart';
import '../payment_menu_screens/pension_screen.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const PaymentsScreen({
    Key? key,
    required this.user,
    required this.apiService,
  }) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final ScrollController _firstRowScrollController = ScrollController();
  final ScrollController _secondRowScrollController = ScrollController();
  final ScrollController _thirdRowScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Managing payments for ${widget.user.companyName ?? 'Company'}, ${widget.user.username ?? 'User'}!'),
          backgroundColor: Colors.teal[700],
        ),
      );
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _firstRowScrollController.dispose();
    _secondRowScrollController.dispose();
    _thirdRowScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';

    return Scaffold(
      appBar: CustomAppBar(
        title:
            'Payments - ${widget.user.username ?? 'User'} (${widget.user.companyName ?? 'Company'})',
        backgroundColor: Colors.teal[800],
        onNotificationTap: () {
          print('Notifications tapped');
        },
        onProfileTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.teal[700]),
                    title: Text('Profile: ${widget.user.username ?? 'User'}'),
                    subtitle: Text(
                        'Role: ${widget.user.role} | Company: ${widget.user.companyName ?? 'Company'}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red[700]),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout(context);
                    },
                  ),
                ],
              ),
            ),
          );
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
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      shadowColor: Colors.grey.withOpacity(0.3),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal[50]!, Colors.teal[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.business,
                                size: 32, color: Colors.teal[700]),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Managing Payments for ${widget.user.companyName ?? 'Company'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[900],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: Scrollbar(
                        controller: _firstRowScrollController,
                        thumbVisibility: true,
                        thickness: 8.0,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          controller: _firstRowScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.payment,
                                  title: 'Pay Salaries',
                                  subtitle: 'Process employee salaries',
                                  destination: PaySalariesScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.blue[50]!,
                                  iconColor: Colors.blue[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              _buildMenuTile(
                                context,
                                icon: Icons.done_all,
                                title: 'Paid Salaries',
                                subtitle: 'View paid salaries',
                                destination: PaidSalariesScreen(
                                  user: widget.user,
                                  apiService: widget.apiService,
                                ),
                                backgroundColor: Colors.green[50]!,
                                iconColor: Colors.green[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildMenuTile(
                                context,
                                icon: Icons.receipt,
                                title: 'Pay Bills',
                                subtitle: 'Pay utility bills',
                                destination: PayBillsScreen(
                                  user: widget.user,
                                  apiService: widget.apiService,
                                ),
                                backgroundColor: Colors.yellow[50]!,
                                iconColor: Colors.yellow[700]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.access_time,
                                  title: 'Overtime',
                                  subtitle: 'Manage overtime',
                                  destination: OvertimeScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.purple[50]!,
                                  iconColor: Colors.purple[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.account_balance_wallet,
                                  title: 'Loans',
                                  subtitle: 'Manage loans',
                                  destination: LoansScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.indigo[50]!,
                                  iconColor: Colors.indigo[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.card_giftcard,
                                  title: 'Benefits',
                                  subtitle: 'Manage benefits',
                                  destination: BenefitsScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.teal[50]!,
                                  iconColor: Colors.teal[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.attach_money,
                                  title: 'Bonus',
                                  subtitle: 'Manage bonuses',
                                  destination: BonusScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.orange[50]!,
                                  iconColor: Colors.orange[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: Scrollbar(
                        controller: _secondRowScrollController,
                        thumbVisibility: true,
                        thickness: 8.0,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          controller: _secondRowScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.money,
                                  title: 'Allowances',
                                  subtitle: 'Manage allowances',
                                  destination: AllowancesScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.blue[50]!,
                                  iconColor: Colors.blue[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              _buildMenuTile(
                                context,
                                icon: Icons.local_hospital,
                                title: 'Medical',
                                subtitle: 'Manage medical',
                                destination: MedicalScreen(
                                  user: widget.user,
                                  apiService: widget.apiService,
                                ),
                                backgroundColor: Colors.green[50]!,
                                iconColor: Colors.green[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildMenuTile(
                                context,
                                icon: Icons.school,
                                title: 'Education',
                                subtitle: 'Manage education',
                                destination: EducationScreen(
                                  user: widget.user,
                                  apiService: widget.apiService,
                                ),
                                backgroundColor: Colors.yellow[50]!,
                                iconColor: Colors.yellow[700]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.remove_circle_outline,
                                  title: 'Deductions',
                                  subtitle: 'Manage deductions',
                                  destination: DeductionsScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.red[50]!,
                                  iconColor: Colors.red[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                              _buildMenuTile(
                                context,
                                icon: Icons.security,
                                title: 'Insurance',
                                subtitle: 'Manage insurance',
                                destination: InsuranceScreen(
                                  user: widget.user,
                                  apiService: widget.apiService,
                                ),
                                backgroundColor: Colors.purple[50]!,
                                iconColor: Colors.purple[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              _buildMenuTile(
                                context,
                                icon: Icons.monetization_on,
                                title: 'Loan Repayment',
                                subtitle: 'Manage loan repayments',
                                destination: LoanRepaymentScreen(
                                  user: widget.user,
                                  apiService: widget.apiService,
                                ),
                                backgroundColor: Colors.teal[50]!,
                                iconColor: Colors.teal[500]!,
                                tileCount: isAdmin ? 7 : 6,
                              ),
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.savings,
                                  title: 'Insurance Relief',
                                  subtitle: 'Manage relief',
                                  destination: InsuranceReliefScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.brown[50]!,
                                  iconColor: Colors.brown[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: Scrollbar(
                        controller: _thirdRowScrollController,
                        thumbVisibility: true,
                        thickness: 8.0,
                        radius: const Radius.circular(4),
                        child: SingleChildScrollView(
                          controller: _thirdRowScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (isAdmin)
                                _buildMenuTile(
                                  context,
                                  icon: Icons.account_balance,
                                  title: 'Pension',
                                  subtitle: 'Manage pension contributions',
                                  destination: PensionScreen(
                                    user: widget.user,
                                    apiService: widget.apiService,
                                  ),
                                  backgroundColor: Colors.cyan[50]!,
                                  iconColor: Colors.cyan[500]!,
                                  tileCount: isAdmin ? 7 : 6,
                                ),
                            ],
                          ),
                        ),
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
    const minTileWidth = 100.0;
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 32.0;
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;
    final finalTileWidth = tileWidth < minTileWidth ? minTileWidth : tileWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
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
            width: finalTileWidth,
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
      ),
    );
  }
}
