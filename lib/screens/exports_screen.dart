import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exports/housing_levy_export.dart';
import '../exports/nssf_export.dart';
import '../exports/paye_export.dart';
import '../exports/shif_export.dart';
import '../services/services.dart';
import 'login_screen.dart';

// Premium Design Constants for Exports Screen (Updated to match pattern)
class ExportsConstants {
  // Main color palette
  static const Color primaryColor = Color(0xFF0A2463);
  static const Color secondaryColor = Color(0xFF3E92CC);
  static const Color accentColor = Color(0xFF1DD3B0);
  
  // Background & Surface colors
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFAFCFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Status colors
  static const Color successColor = Color(0xFF00B894);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color warningColor = Color(0xFFFFA502);
  
  // Export-specific colors
  static const Color nssfColor = Color(0xFF4CAF50);
  static const Color shifColor = Color(0xFF2196F3);
  static const Color housingColor = Color(0xFFFF9800);
  static const Color payeColor = Color(0xFF9C27B0);
  static const Color adminOnlyColor = Color(0xFFF44336);
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient nssfGradient = LinearGradient(
    colors: [nssfColor, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient shifGradient = LinearGradient(
    colors: [shifColor, Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient housingGradient = LinearGradient(
    colors: [housingColor, Color(0xFFFFB74D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient payeGradient = LinearGradient(
    colors: [payeColor, Color(0xFFBA68C8)],
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

class ExportsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const ExportsScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends State<ExportsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _isLoading = false;
  String? _errorMessage;
  String _companyName = 'Unknown';
  bool _isAdmin = false;
  int? _companyId;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAnimations();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initializeData() {
    final userCompanyId = widget.user['company_id'] != null
        ? int.tryParse(widget.user['company_id'].toString())
        : null;
    _companyName = widget.user['company_name']?.toString() ?? 'Unknown';
    _isAdmin = widget.user['role'] == 'admin';
    _companyId = userCompanyId;

    if (userCompanyId == null || widget.user['role'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorSnackBar('User data is incomplete (missing company ID or role)');
      });
    }
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
            color: ExportsConstants.surfaceColor,
            borderRadius: ExportsConstants.borderRadiusLarge,
            boxShadow: ExportsConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ExportsConstants.errorColor, Colors.red[800]!],
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
                  color: ExportsConstants.textPrimary,
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
                  color: ExportsConstants.textTertiary,
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
                          borderRadius: ExportsConstants.borderRadiusMedium,
                        ),
                        side: BorderSide(color: ExportsConstants.textTertiary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: ExportsConstants.textSecondary,
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
                          borderRadius: ExportsConstants.borderRadiusMedium,
                        ),
                        backgroundColor: ExportsConstants.errorColor,
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
    final username = widget.user['username']?.toString() ?? 'Unknown';
    final role = widget.user['role']?.toString() ?? 'Unknown';
    final companyId = widget.user['company_id']?.toString() ?? 'N/A';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: BoxDecoration(
          color: ExportsConstants.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: ExportsConstants.strongShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                gradient: ExportsConstants.primaryGradient,
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
                      color: Colors.white.withValues(alpha: 0.2),
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
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$role • $_companyName',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
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
                    value: companyId,
                    color: ExportsConstants.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    icon: Icons.badge,
                    title: 'User Role',
                    value: role,
                    color: ExportsConstants.secondaryColor,
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
                        backgroundColor: ExportsConstants.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: ExportsConstants.borderRadiusMedium,
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
        color: ExportsConstants.cardColor,
        borderRadius: ExportsConstants.borderRadiusMedium,
        border: Border.all(
          color: ExportsConstants.textTertiary.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
                    color: ExportsConstants.textTertiary,
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
                    color: ExportsConstants.textPrimary,
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

  void _showAdminRestrictedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ExportsConstants.adminOnlyColor,
            borderRadius: ExportsConstants.borderRadiusMedium,
            boxShadow: ExportsConstants.mediumShadow,
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
                child: Icon(Icons.admin_panel_settings, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Admin access required or invalid company ID',
                  style: TextStyle(
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ExportsConstants.errorColor,
            borderRadius: ExportsConstants.borderRadiusMedium,
            boxShadow: ExportsConstants.mediumShadow,
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
                child: const Icon(Icons.error_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ExportsConstants.successColor,
            borderRadius: ExportsConstants.borderRadiusMedium,
            boxShadow: ExportsConstants.mediumShadow,
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
                child: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: ExportsConstants.primaryGradient,
        boxShadow: ExportsConstants.mediumShadow,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button and Title
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _companyName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Notification Icon
                IconButton(
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
                  onPressed: () {
                    if (kDebugMode) {
                      print('Notifications tapped');
                    }
                    _showSuccessSnackBar('No new notifications');
                  },
                ),
                
                // Profile Icon
                IconButton(
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
                  onPressed: _showProfileSheet,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Stats Row
            Row(
              children: [
                _buildStatCard(
                  title: 'Export Types',
                  value: '4',
                  color: ExportsConstants.primaryColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Access',
                  value: _isAdmin ? 'Admin' : 'Restricted',
                  color: _isAdmin ? ExportsConstants.successColor : ExportsConstants.warningColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Status',
                  value: _isAdmin ? 'Ready' : 'Limited',
                  color: _isAdmin ? ExportsConstants.successColor : ExportsConstants.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: ExportsConstants.borderRadiusMedium,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptions() {
    // Initialize export classes
    final nssfExport = NSSFExport(
      user: widget.user,
      apiService: widget.apiService,
      companyId: _companyId,
    );
    
    final shifExport = SHIFExport(
      user: widget.user,
      apiService: widget.apiService,
      companyId: _companyId,
    );
    
    final housingLevyExport = HousingLevyExport(
      user: widget.user,
      apiService: widget.apiService,
      companyId: _companyId,
    );
    
    final payeExport = PAYEExport(
      user: widget.user,
      apiService: widget.apiService,
      companyId: _companyId,
    );

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ExportsConstants.surfaceColor,
        borderRadius: ExportsConstants.borderRadiusLarge,
        boxShadow: ExportsConstants.mediumShadow,
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ExportsConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: ExportsConstants.textTertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ExportsConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_download_rounded,
                    color: ExportsConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ExportsConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Select an export type',
                  style: TextStyle(
                    fontSize: 14,
                    color: ExportsConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Export Tiles Grid
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // First Row - NSSF & SHIF
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildExportTile(
                      icon: Icons.description,
                      title: 'NSSF Export',
                      subtitle: 'Export NSSF contributions',
                      exportInstance: nssfExport,
                      gradient: ExportsConstants.nssfGradient,
                      enabled: _isAdmin && _companyId != null,
                    ),
                    const SizedBox(width: 24),
                    _buildExportTile(
                      icon: Icons.health_and_safety,
                      title: 'SHIF Export',
                      subtitle: 'Export SHIF contributions',
                      exportInstance: shifExport,
                      gradient: ExportsConstants.shifGradient,
                      enabled: _isAdmin && _companyId != null,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Second Row - Housing Levy & PAYE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildExportTile(
                      icon: Icons.home_work,
                      title: 'Housing Levy',
                      subtitle: 'Export housing levy data',
                      exportInstance: housingLevyExport,
                      gradient: ExportsConstants.housingGradient,
                      enabled: _isAdmin && _companyId != null,
                    ),
                    const SizedBox(width: 24),
                    _buildExportTile(
                      icon: Icons.account_balance,
                      title: 'PAYE Export',
                      subtitle: 'Export PAYE data',
                      exportInstance: payeExport,
                      gradient: ExportsConstants.payeGradient,
                      enabled: _isAdmin && _companyId != null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required dynamic exportInstance,
    required Gradient gradient,
    required bool enabled,
  }) {
    return Expanded(
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          borderRadius: ExportsConstants.borderRadiusLarge,
          boxShadow: enabled 
              ? ExportsConstants.mediumShadow 
              : ExportsConstants.subtleShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: ExportsConstants.borderRadiusLarge,
          child: InkWell(
            onTap: enabled
                ? () {
                    if (kDebugMode) {
                      print('Navigating to $title details page');
                    }
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                            exportInstance.buildDetailsPage(context),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          );
                        },
                        transitionDuration: ExportsConstants.animationDuration,
                      ),
                    );
                  }
                : _showAdminRestrictedSnackBar,
            borderRadius: ExportsConstants.borderRadiusLarge,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ExportsConstants.surfaceColor,
                    enabled ? ExportsConstants.surfaceColor : ExportsConstants.surfaceColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: ExportsConstants.borderRadiusLarge,
                border: Border.all(
                  color: enabled 
                      ? ExportsConstants.textTertiary.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: enabled ? gradient : LinearGradient(
                        colors: [Colors.grey[400]!, Colors.grey[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: enabled ? [
                        BoxShadow(
                          color: gradient.colors.first.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled 
                          ? ExportsConstants.textPrimary 
                          : ExportsConstants.textTertiary,
                      fontSize: 18,
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
                      color: enabled 
                          ? ExportsConstants.textTertiary 
                          : Colors.grey[500]!,
                      fontSize: 14,
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
                          color: enabled 
                              ? ExportsConstants.accentColor.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          enabled ? Icons.arrow_forward_ios : Icons.lock,
                          size: 14,
                          color: enabled 
                              ? ExportsConstants.accentColor 
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ExportsConstants.cardColor,
        borderRadius: ExportsConstants.borderRadiusMedium,
        border: Border.all(
          color: ExportsConstants.textTertiary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: ExportsConstants.secondaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Export operations are secured and logged. All exports require administrative privileges.',
              style: TextStyle(
                color: ExportsConstants.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNotice() {
    if (_isAdmin) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ExportsConstants.adminOnlyColor.withValues(alpha: 0.1),
        borderRadius: ExportsConstants.borderRadiusMedium,
        border: Border.all(
          color: ExportsConstants.adminOnlyColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: ExportsConstants.adminOnlyColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Export functionality requires administrator privileges.',
              style: TextStyle(
                color: ExportsConstants.adminOnlyColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: ExportsConstants.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: ExportsConstants.errorColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: ExportsConstants.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _initializeData();
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ExportsConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: ExportsConstants.borderRadiusMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExportsConstants.backgroundColor,
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
        child: Column(
          children: [
            _buildHeaderSection(),
            if (_errorMessage != null)
              Expanded(child: _buildErrorState())
            else
              Expanded(
                child: ListView(
                  children: [
                    _buildExportOptions(),
                    const SizedBox(height: 16),
                    _buildSecurityFooter(),
                    _buildAdminNotice(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}