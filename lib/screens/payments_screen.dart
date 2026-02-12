import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'login_screen.dart';

// Premium Design Constants for Payments Screen
class PaymentsConstants {
  // Main color palette (aligned with LoginConstants but specialized)
  static const Color primaryColor = Color(0xFF0A2463);
  static const Color secondaryColor = Color(0xFF3E92CC);
  static const Color accentColor = Color(0xFF1DD3B0);
  static const Color goldAccent = Color(0xFFFFD166);
  static const Color platinumColor = Color(0xFFE8E8E8);
  
  // Background & Surface colors
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFAFCFF);
  static const Color darkBackground = Color(0xFF0F1B3A);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Status colors
  static const Color successColor = Color(0xFF00B894);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color warningColor = Color(0xFFFFA502);
  static const Color infoColor = Color(0xFF2D3436);
  
  // Payment-specific colors
  static const Color salaryColor = Color(0xFF4CAF50);
  static const Color billColor = Color(0xFFFF9800);
  static const Color loanColor = Color(0xFF2196F3);
  static const Color benefitColor = Color(0xFF9C27B0);
  static const Color deductionColor = Color(0xFFF44336);
  static const Color allowanceColor = Color(0xFF00BCD4);
  static const Color medicalColor = Color(0xFF4CAF50);
  static const Color educationColor = Color(0xFFFFC107);
  static const Color insuranceColor = Color(0xFF3F51B5);
  static const Color pensionColor = Color(0xFF607D8B);
  static const Color overtimeColor = Color(0xFF795548);
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient salaryGradient = LinearGradient(
    colors: [salaryColor, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient billGradient = LinearGradient(
    colors: [billColor, Color(0xFFFFB74D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient loanGradient = LinearGradient(
    colors: [loanColor, Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient premiumGradient = LinearGradient(
    colors: [backgroundColor, Color(0xFFF0F5FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static LinearGradient overtimeGradient = LinearGradient(
    colors: [overtimeColor, Color(0xFF8D6E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, Color(0xFF2EC4B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows - FIXED: Changed .withValues() to .withOpacity()
  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 30,
      offset: Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> strongShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 40,
      offset: Offset(0, 12),
    ),
  ];
  
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: Offset(0, 6),
      spreadRadius: 1,
    ),
  ];
  
  // Borders
  static BorderRadius borderRadiusLarge = BorderRadius.circular(24);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(16);
  static BorderRadius borderRadiusSmall = BorderRadius.circular(12);
  static BorderRadius borderRadiusExtraLarge = BorderRadius.circular(32);
  
  // Animations
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Curve animationCurve = Curves.easeOutCubic;
}

class PaymentsScreen extends StatefulWidget {
  final User user;
  final ApiService apiService;

  const PaymentsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  final ScrollController _firstRowScrollController = ScrollController();
  final ScrollController _secondRowScrollController = ScrollController();
  final ScrollController _thirdRowScrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _showWelcomeSnackBar();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    _animationController.forward();
  }

  void _showWelcomeSnackBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: PaymentsConstants.successColor,
              borderRadius: PaymentsConstants.borderRadiusMedium,
              boxShadow: PaymentsConstants.mediumShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Managing payments for ${widget.user.companyName ?? 'Company'}, ${widget.user.username ?? 'User'}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(24),
          duration: const Duration(seconds: 3),
          padding: EdgeInsets.zero,
        ),
      );
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: PaymentsConstants.surfaceColor,
            borderRadius: PaymentsConstants.borderRadiusLarge,
            boxShadow: PaymentsConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [PaymentsConstants.errorColor, Colors.red[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                'Logout Confirmation',
                style: TextStyle(
                  color: PaymentsConstants.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to log out? You\'ll need to sign in again to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PaymentsConstants.textTertiary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: PaymentsConstants.borderRadiusMedium,
                        ),
                        side: BorderSide(color: PaymentsConstants.textTertiary.withValues(alpha: 0.3)), // FIXED
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: PaymentsConstants.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: PaymentsConstants.borderRadiusMedium,
                        ),
                        backgroundColor: PaymentsConstants.errorColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        if (!context.mounted) return;
        
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: BoxDecoration(
          color: PaymentsConstants.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: PaymentsConstants.strongShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                gradient: PaymentsConstants.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2), // FIXED
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.username ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.user.role} • ${widget.user.companyName ?? 'Company'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9), // FIXED
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                children: [
                  _buildProfileItem(
                    icon: Icons.business,
                    title: 'Company ID',
                    value: widget.user.companyId.toString(),
                    color: PaymentsConstants.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    icon: Icons.badge,
                    title: 'Employee ID',
                    value: widget.user.employeeId ?? 'N/A',
                    color: PaymentsConstants.secondaryColor,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaymentsConstants.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: PaymentsConstants.borderRadiusMedium,
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.logout, size: 20),
                      label: Text(
                        _isLoading ? 'Logging out...' : 'Logout',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaymentsConstants.cardColor,
        borderRadius: PaymentsConstants.borderRadiusMedium,
        border: Border.all(
          color: PaymentsConstants.textTertiary.withValues(alpha: 0.1), // FIXED
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), // FIXED
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: PaymentsConstants.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: PaymentsConstants.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstRowScrollController.dispose();
    _secondRowScrollController.dispose();
    _thirdRowScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == 'admin';

    return Scaffold(
      backgroundColor: PaymentsConstants.backgroundColor,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: PaymentsConstants.primaryGradient,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {
                    developer.log('Notifications tapped', name: 'PaymentsScreen');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: PaymentsConstants.infoColor,
                            borderRadius: PaymentsConstants.borderRadiusMedium,
                          ),
                          child: const Text(
                            'No new notifications',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(24),
                      ),
                    );
                  },
                  tooltip: 'Notifications',
                ),
                IconButton(
                  icon: Icon(Icons.person_outline, color: Colors.white),
                  onPressed: _showProfileSheet,
                  tooltip: 'Profile',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: PaymentsConstants.surfaceColor,
                        borderRadius: PaymentsConstants.borderRadiusLarge,
                        boxShadow: PaymentsConstants.cardShadow,
                        border: Border.all(
                          color: PaymentsConstants.primaryColor.withValues(alpha: 0.1), // FIXED
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: PaymentsConstants.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.business, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Management System',
                                  style: TextStyle(
                                    color: PaymentsConstants.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Managing payments for ${widget.user.companyName ?? 'Company'}',
                                  style: TextStyle(
                                    color: PaymentsConstants.textTertiary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Inter',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: PaymentsConstants.accentColor.withValues(alpha: 0.1), // FIXED
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PaymentsConstants.accentColor.withValues(alpha: 0.3), // FIXED
                              ),
                            ),
                            child: Text(
                              widget.user.role.toUpperCase(),
                              style: TextStyle(
                                color: PaymentsConstants.accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Payment Categories Section
                    _buildSectionHeader(
                      title: 'Payment Operations',
                      subtitle: 'Select a category to manage payments',
                    ),
                    const SizedBox(height: 20),
                    
                    // First Row - Primary Operations
                    _buildScrollableRow(
                      controller: _firstRowScrollController,
                      tiles: [
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.payment,
                            title: 'Pay Salaries',
                            subtitle: 'Process employee salaries',
                            destination: PaySalariesScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: PaymentsConstants.salaryGradient,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        _buildPremiumMenuTile(
                          context: context,
                          icon: Icons.done_all,
                          title: 'Paid Salaries',
                          subtitle: 'View paid salaries',
                          destination: PaidSalariesScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                          gradient: PaymentsConstants.salaryGradient,
                          tileCount: isAdmin ? 7 : 6,
                        ),
                        _buildPremiumMenuTile(
                          context: context,
                          icon: Icons.receipt_long,
                          title: 'Pay Bills',
                          subtitle: 'Pay utility bills',
                          destination: PayBillsScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                          gradient: PaymentsConstants.billGradient,
                          tileCount: isAdmin ? 7 : 6,
                        ),
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.access_time_filled,
                            title: 'Overtime',
                            subtitle: 'Manage overtime',
                            destination: OvertimeScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: PaymentsConstants.overtimeGradient,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.account_balance_wallet,
                            title: 'Loans',
                            subtitle: 'Manage loans',
                            destination: LoansScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: PaymentsConstants.loanGradient,
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.card_giftcard,
                            title: 'Benefits',
                            subtitle: 'Manage benefits',
                            destination: BenefitsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: LinearGradient(
                              colors: [PaymentsConstants.benefitColor, Color(0xFFBA68C8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.attach_money,
                            title: 'Bonus',
                            subtitle: 'Manage bonuses',
                            destination: BonusScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: LinearGradient(
                              colors: [PaymentsConstants.goldAccent, Color(0xFFFFB347)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            tileCount: isAdmin ? 7 : 6,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Second Row - Deductions & Benefits
                    _buildScrollableRow(
                      controller: _secondRowScrollController,
                      tiles: [
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.money,
                            title: 'Allowances',
                            subtitle: 'Manage allowances',
                            destination: AllowancesScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: LinearGradient(
                              colors: [PaymentsConstants.allowanceColor, Color(0xFF26C6DA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        _buildPremiumMenuTile(
                          context: context,
                          icon: Icons.local_hospital,
                          title: 'Medical',
                          subtitle: 'Manage medical',
                          destination: MedicalScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                          gradient: LinearGradient(
                            colors: [PaymentsConstants.medicalColor, Color(0xFF66BB6A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          tileCount: isAdmin ? 7 : 6,
                        ),
                        _buildPremiumMenuTile(
                          context: context,
                          icon: Icons.school,
                          title: 'Education',
                          subtitle: 'Manage education',
                          destination: EducationScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                          gradient: LinearGradient(
                            colors: [PaymentsConstants.educationColor, Color(0xFFFFD54F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          tileCount: isAdmin ? 7 : 6,
                        ),
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.remove_circle,
                            title: 'Deductions',
                            subtitle: 'Manage deductions',
                            destination: DeductionsScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: LinearGradient(
                              colors: [PaymentsConstants.deductionColor, Color(0xFFEF5350)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        _buildPremiumMenuTile(
                          context: context,
                          icon: Icons.security,
                          title: 'Insurance',
                          subtitle: 'Manage insurance',
                          destination: InsuranceScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                          gradient: LinearGradient(
                            colors: [PaymentsConstants.insuranceColor, Color(0xFF5C6BC0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          tileCount: isAdmin ? 7 : 6,
                        ),
                        _buildPremiumMenuTile(
                          context: context,
                          icon: Icons.monetization_on,
                          title: 'Loan Repayment',
                          subtitle: 'Manage loan repayments',
                          destination: LoanRepaymentScreen(
                            user: widget.user,
                            apiService: widget.apiService,
                          ),
                          gradient: PaymentsConstants.loanGradient,
                          tileCount: isAdmin ? 7 : 6,
                        ),
                        if (isAdmin)
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.savings,
                            title: 'Insurance Relief',
                            subtitle: 'Manage relief',
                            destination: InsuranceReliefScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: LinearGradient(
                              colors: [Colors.brown, Color(0xFF8D6E63)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            tileCount: isAdmin ? 7 : 6,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Third Row - Additional Options
                    if (isAdmin)
                      _buildScrollableRow(
                        controller: _thirdRowScrollController,
                        tiles: [
                          _buildPremiumMenuTile(
                            context: context,
                            icon: Icons.account_balance,
                            title: 'Pension',
                            subtitle: 'Manage pension contributions',
                            destination: PensionScreen(
                              user: widget.user,
                              apiService: widget.apiService,
                            ),
                            gradient: LinearGradient(
                              colors: [PaymentsConstants.pensionColor, Color(0xFF90A4AE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            tileCount: isAdmin ? 7 : 6,
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 40),
                    
                    // Footer Note
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PaymentsConstants.cardColor,
                        borderRadius: PaymentsConstants.borderRadiusMedium,
                        border: Border.all(
                          color: PaymentsConstants.textTertiary.withValues(alpha: 0.1), // FIXED
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: PaymentsConstants.secondaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All payment operations are secured and encrypted. '
                              'Your data is protected with bank-level security.',
                              style: TextStyle(
                                color: PaymentsConstants.textTertiary,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Inter',
                                height: 1.5,
                              ),
                            ),
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

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: PaymentsConstants.accentGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: PaymentsConstants.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            subtitle,
            style: TextStyle(
              color: PaymentsConstants.textTertiary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableRow({
    required ScrollController controller,
    required List<Widget> tiles,
  }) {
    return SizedBox(
      height: 240,
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        thickness: 6.0,
        radius: const Radius.circular(3),
        trackVisibility: true,
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tiles.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) => tiles[index],
        ),
      ),
    );
  }

  Widget _buildPremiumMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
    required Gradient gradient,
    required int tileCount,
  }) {
    const minTileWidth = 160.0;
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 48.0;
    final spacingBetweenTiles = 16.0 * (tileCount - 1);
    final tileWidth =
        (screenWidth - horizontalPadding - spacingBetweenTiles) / tileCount;
    final finalTileWidth = tileWidth < minTileWidth ? minTileWidth : tileWidth;

    return Container(
      width: finalTileWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: PaymentsConstants.borderRadiusLarge,
        boxShadow: PaymentsConstants.mediumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: PaymentsConstants.borderRadiusLarge,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => destination,
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
                transitionDuration: PaymentsConstants.animationDuration,
              ),
            );
          },
          borderRadius: PaymentsConstants.borderRadiusLarge,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PaymentsConstants.surfaceColor,
                  PaymentsConstants.surfaceColor,
                ],
              ),
              borderRadius: PaymentsConstants.borderRadiusLarge,
              border: Border.all(
                color: PaymentsConstants.textTertiary.withValues(alpha: 0.1), // FIXED
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: PaymentsConstants.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: PaymentsConstants.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: PaymentsConstants.accentColor.withValues(alpha: 0.1), // FIXED
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: PaymentsConstants.accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}