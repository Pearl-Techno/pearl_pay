import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../appraisal/appraisal_dashboard_screen.dart';
import '../employee_management/add_employee_screen.dart';
import '../employee_management/employee_list_screen.dart';
import '../models/user.dart';
import '../services/services.dart';
import 'exports_screen.dart';
import 'help_support_screen.dart';
import 'leave_management_screen.dart';
import 'login_screen.dart';
import 'payments_screen.dart';
import 'payroll_summary_screen.dart';
import 'printables_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'time_and_attendance_screen.dart';

// Premium Design Constants
class HomeConstants {
  // Main color palette
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
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, Color(0xFF2EC4B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient goldGradient = LinearGradient(
    colors: [goldAccent, Color(0xFFFFB347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
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
  
  // Borders
  static BorderRadius borderRadiusLarge = BorderRadius.circular(24);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(16);
  static BorderRadius borderRadiusSmall = BorderRadius.circular(12);
  static BorderRadius borderRadiusExtraLarge = BorderRadius.circular(32);
}

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  late User _userModel;
  bool _isLoading = false;
  int _selectedCategory = 0;
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // Categories for better organization
  final List<DashboardCategory> _categories = [
    DashboardCategory(
      title: 'Employee Management',
      icon: Icons.people_alt_rounded,
      color: Colors.blue,
    ),
    DashboardCategory(
      title: 'Payroll & Finance',
      icon: Icons.account_balance_wallet_rounded,
      color: Colors.green,
    ),
    DashboardCategory(
      title: 'Operations',
      icon: Icons.business_center_rounded,
      color: Colors.orange,
    ),
    DashboardCategory(
      title: 'Reports & Analytics',
      icon: Icons.analytics_rounded,
      color: Colors.purple,
    ),
    DashboardCategory(
      title: 'System',
      icon: Icons.settings_rounded,
      color: Colors.grey,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    _initializeApiService();
    _initializeAnimations();
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
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _animationController.forward();
  }

  void _initializeUserData() {
    try {
      _userModel = User.fromMap(widget.user);
      if (_userModel.companyId == 0) {
        throw ArgumentError('Invalid or missing required user data');
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPremiumSnackBar('Invalid user data: $e', HomeConstants.errorColor);
        _logout();
      });
    }
  }

  void _initializeApiService() {
    _apiService = ApiService(client: http.Client(), user: _userModel);
  }

  Future<void> _logout() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar('Logout failed: $e', HomeConstants.errorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPremiumSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: HomeConstants.borderRadiusMedium,
            boxShadow: HomeConstants.mediumShadow,
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
                child: const Icon(Icons.info_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
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
  }

  // Role getters
  bool get _isAdmin => _userModel.role == 'admin';
  bool get _isManager => _userModel.role == 'manager';
  bool get _isOperator => _userModel.role == 'operator';
  bool get _isDirector => _userModel.role == 'director';
  bool get _canViewReports => _isAdmin || _isManager || _isDirector || _isOperator;

  // Get menu items by category
  List<DashboardItem> get _employeeManagementItems => [
    if (_isAdmin)
      DashboardItem(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add Employee',
        subtitle: 'Register new staff member',
        destination: AddEmployeeScreen(
          user: _userModel.toMap(),
          apiService: _apiService,
        ),
        color: Colors.blue,
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    DashboardItem(
      icon: Icons.people_alt_rounded,
      title: 'Employee List',
      subtitle: 'View and manage staff',
      destination: EmployeeListScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.green,
      gradient: LinearGradient(
        colors: [Colors.green.shade50, Colors.green.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  List<DashboardItem> get _payrollFinanceItems => [
    DashboardItem(
      icon: Icons.payment_rounded,
      title: 'Payments',
      subtitle: 'Salary processing & disbursement',
      destination: PaymentsScreen(user: _userModel, apiService: _apiService),
      color: Colors.purple,
      gradient: LinearGradient(
        colors: [Colors.purple.shade50, Colors.purple.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    DashboardItem(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Payroll',
      subtitle: 'Salary summaries & reports',
      destination: PayrollSummaryScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.indigo,
      gradient: LinearGradient(
        colors: [Colors.indigo.shade50, Colors.indigo.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  List<DashboardItem> get _operationsItems => [
    DashboardItem(
      icon: Icons.access_time_filled_rounded,
      title: 'Attendance',
      subtitle: 'Time tracking & management',
      destination: TimeAndAttendanceScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.orange,
      gradient: LinearGradient(
        colors: [Colors.orange.shade50, Colors.orange.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    DashboardItem(
      icon: Icons.calendar_today_rounded,
      title: 'Leave',
      subtitle: 'Leave requests & approvals',
      destination: LeaveManagementScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.teal,
      gradient: LinearGradient(
        colors: [Colors.teal.shade50, Colors.teal.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    DashboardItem(
      icon: Icons.assignment_ind_rounded,
      title: 'Appraisals',
      subtitle: 'Performance reviews',
      destination: AppraisalDashboardScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.amber,
      gradient: LinearGradient(
        colors: [Colors.amber.shade50, Colors.amber.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  List<DashboardItem> get _reportsAnalyticsItems => [
    if (_canViewReports)
      DashboardItem(
        icon: Icons.analytics_rounded,
        title: 'Reports',
        subtitle: 'Analytics & insights',
        destination: ReportsScreen(
          user: _userModel.toMap(),
          apiService: _apiService,
        ),
        color: Colors.red,
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    DashboardItem(
      icon: Icons.download_rounded,
      title: 'Exports',
      subtitle: 'Data export & backup',
      destination: ExportsScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.cyan,
      gradient: LinearGradient(
        colors: [Colors.cyan.shade50, Colors.cyan.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    DashboardItem(
      icon: Icons.print_rounded,
      title: 'Printables',
      subtitle: 'Documents & forms',
      destination: PrintablesScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.deepOrange,
      gradient: LinearGradient(
        colors: [Colors.deepOrange.shade50, Colors.deepOrange.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  List<DashboardItem> get _systemItems => [
    DashboardItem(
      icon: Icons.settings_rounded,
      title: 'Settings',
      subtitle: 'System configuration',
      destination: SettingsScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.grey,
      gradient: LinearGradient(
        colors: [Colors.grey.shade50, Colors.grey.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    DashboardItem(
      icon: Icons.help_center_rounded,
      title: 'Help & Support',
      subtitle: 'Guidance & assistance',
      destination: HelpSupportScreen(
        user: _userModel.toMap(),
        apiService: _apiService,
      ),
      color: Colors.pink,
      gradient: LinearGradient(
        colors: [Colors.pink.shade50, Colors.pink.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  List<DashboardItem> get _currentCategoryItems {
    switch (_selectedCategory) {
      case 0: return _employeeManagementItems;
      case 1: return _payrollFinanceItems;
      case 2: return _operationsItems;
      case 3: return _reportsAnalyticsItems;
      case 4: return _systemItems;
      default: return _employeeManagementItems;
    }
  }

  void _navigateToScreen(Widget destination) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HomeConstants.surfaceColor,
          borderRadius: HomeConstants.borderRadiusLarge,
          boxShadow: HomeConstants.strongShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: HomeConstants.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userModel.username ?? 'User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _userModel.role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userModel.companyName ?? 'Company',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // User Info
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.badge_rounded,
                    title: 'User ID',
                    value: _userModel.userId ?? 'N/A',
                  ),
                  const SizedBox(height: 12),
                  if (_userModel.employeeId != null)
                    _buildInfoRow(
                      icon: Icons.work_rounded,
                      title: 'Employee ID',
                      value: _userModel.employeeId!,
                    ),
                ],
              ),
            ),
            
            // Logout Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: HomeConstants.textTertiary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeConstants.errorColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: HomeConstants.borderRadiusMedium,
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
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

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeConstants.cardColor,
        borderRadius: HomeConstants.borderRadiusMedium,
        border: Border.all(
          color: HomeConstants.textTertiary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HomeConstants.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: HomeConstants.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: HomeConstants.textTertiary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: HomeConstants.textPrimary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeConstants.backgroundColor,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            // Custom App Bar
            _buildPremiumAppBar(),
            
            // Main Content
            Expanded(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // Welcome Header
                  SliverToBoxAdapter(
                    child: _buildWelcomeHeader(),
                  ),
                  
                  // Categories
                  SliverToBoxAdapter(
                    child: _buildCategoryTabs(),
                  ),
                  
                  // Dashboard Items Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 6,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _currentCategoryItems[index];
                          return _buildDashboardItem(item);
                        },
                        childCount: _currentCategoryItems.length,
                      ),
                    ),
                  ),
                  
                  // Bottom Padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: HomeConstants.primaryGradient,
        boxShadow: HomeConstants.mediumShadow,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Logo/Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pearl Pay',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Enterprise Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              
              // Notification Icon
              IconButton(
                onPressed: () {
                  _showPremiumSnackBar(
                    'Notifications feature coming soon!',
                    HomeConstants.successColor,
                  );
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              
              // Profile Icon
              IconButton(
                onPressed: _showProfileModal,
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HomeConstants.primaryColor,
              HomeConstants.secondaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: HomeConstants.borderRadiusLarge,
          boxShadow: HomeConstants.strongShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.business_center_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userModel.username ?? 'User',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Inter',
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Managing ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontFamily: 'Inter',
                            ),
                          ),
                          TextSpan(
                            text: _userModel.companyName ?? 'Company',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
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

  Widget _buildCategoryTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HomeConstants.cardColor,
          borderRadius: HomeConstants.borderRadiusMedium,
          border: Border.all(
            color: HomeConstants.textTertiary.withValues(alpha: 0.1),
          ),
          boxShadow: HomeConstants.subtleShadow,
        ),
        child: Row(
          children: List.generate(
            _categories.length,
            (index) => Expanded(
              child: _buildCategoryTab(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(int index) {
    final isSelected = _selectedCategory == index;
    final category = _categories[index];
    
    return Material(
      color: Colors.transparent,
      borderRadius: HomeConstants.borderRadiusSmall,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = index;
          });
        },
        borderRadius: HomeConstants.borderRadiusSmall,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? category.color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: HomeConstants.borderRadiusSmall,
            border: isSelected
                ? Border.all(
                    color: category.color.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Column(
            children: [
              Icon(
                category.icon,
                color: isSelected ? category.color : HomeConstants.textTertiary,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                category.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? category.color : HomeConstants.textTertiary,
                  fontFamily: 'Inter',
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardItem(DashboardItem item) {
    return Material(
      color: Colors.transparent,
      borderRadius: HomeConstants.borderRadiusLarge,
      child: InkWell(
        onTap: () => _navigateToScreen(item.destination),
        borderRadius: HomeConstants.borderRadiusLarge,
        child: Container(
          decoration: BoxDecoration(
            gradient: item.gradient,
            borderRadius: HomeConstants.borderRadiusLarge,
            boxShadow: HomeConstants.mediumShadow,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Background accent
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon with background
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        item.icon,
                        color: item.color,
                        size: 20,
                      ),
                    ),
                    
                    // Text content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HomeConstants.textPrimary,
                            fontFamily: 'Inter',
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeConstants.textTertiary,
                            fontFamily: 'Inter',
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    
                    // Arrow indicator
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: item.color,
                          size: 16,
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
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _apiService.dispose();
    super.dispose();
  }
}

// Supporting classes
class DashboardItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget destination;
  final Color color;
  final LinearGradient gradient;

  const DashboardItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
    required this.color,
    required this.gradient,
  });
}

class DashboardCategory {
  final String title;
  final IconData icon;
  final Color color;

  const DashboardCategory({
    required this.title,
    required this.icon,
    required this.color,
  });
}