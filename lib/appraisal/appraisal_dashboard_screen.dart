import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';

import 'appraisal_detail_screen.dart';
import 'employee_appraisal_screen.dart';
import 'self_appraisal_screen.dart';

// Premium Design Constants for Appraisal Dashboard
class AppraisalConstants {
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
  static const Color pendingColor = Color(0xFFFFA502);
  static const Color approvedColor = Color(0xFF00B894);
  static const Color rejectedColor = Color(0xFFFF4757);
  
  // Appraisal-specific colors
  static const Color selfAppraisalColor = Color(0xFF4CAF50);
  static const Color employeeAppraisalColor = Color(0xFF2196F3);
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient selfAppraisalGradient = LinearGradient(
    colors: [selfAppraisalColor, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient employeeAppraisalGradient = LinearGradient(
    colors: [employeeAppraisalColor, Color(0xFF64B5F6)],
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

class AppraisalDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const AppraisalDashboardScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  AppraisalDashboardScreenState createState() => AppraisalDashboardScreenState();
}

class AppraisalDashboardScreenState extends State<AppraisalDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  late User userModel;
  List<Map<String, dynamic>> _appraisals = [];
  bool _isLoading = true;
  bool _isLoadingEmployees = false;
  String? _errorMessage;
  String? _selectedFilter = 'All';
  List<Map<String, dynamic>> _employees = [];
  String _companyName = 'Unknown';
  bool _isAdmin = false;
  bool _isManager = false;
  bool _isEmployee = false;

  String? _safeParseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

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
    userModel = User.fromMap(widget.user);
    _companyName = _safeParseString(widget.user['company_name']) ?? 'Unknown';
    _isAdmin = userModel.role == 'admin';
    _isManager = userModel.role == 'manager';
    _isEmployee = userModel.role == 'employee';
    _fetchAppraisals();
    _fetchEmployees();
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

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoadingEmployees = true;
    });
    try {
      final employees = await widget.apiService.getEmployeeList(userModel.companyId);
      setState(() {
        _employees = employees;
        _isLoadingEmployees = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingEmployees = false;
      });
      _showErrorSnackBar('Failed to load employees: $e');
    }
  }

  Future<void> _fetchAppraisals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await widget.apiService.getAppraisals(
        companyId: userModel.companyId,
        role: userModel.role,
        employeeId: userModel.employeeId,
        filter: _selectedFilter,
      );
      setState(() {
        _appraisals = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAppraisalStatus(String appraisalId, String status) async {
    try {
      await widget.apiService.updateAppraisalStatus(
        appraisalId: appraisalId,
        status: status,
        companyId: userModel.companyId,
      );
      _showSuccessSnackBar('Appraisal status updated to $status');
      _fetchAppraisals();
    } catch (e) {
      _showErrorSnackBar('Failed to update appraisal status: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppraisalConstants.errorColor,
            borderRadius: AppraisalConstants.borderRadiusMedium,
            boxShadow: AppraisalConstants.mediumShadow,
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
            color: AppraisalConstants.successColor,
            borderRadius: AppraisalConstants.borderRadiusMedium,
            boxShadow: AppraisalConstants.mediumShadow,
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

  Future<void> _showEmployeeSelectionDialog() async {
    String? selectedUniqueValue;
    
    final uniqueEmployees = _getUniqueEmployees();
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppraisalConstants.surfaceColor,
            borderRadius: AppraisalConstants.borderRadiusLarge,
            boxShadow: AppraisalConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppraisalConstants.employeeAppraisalGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Employee to Appraise',
                style: TextStyle(
                  color: AppraisalConstants.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose an employee to start their performance appraisal process',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppraisalConstants.textTertiary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isLoadingEmployees)
                CircularProgressIndicator(color: AppraisalConstants.primaryColor),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  borderRadius: AppraisalConstants.borderRadiusMedium,
                  boxShadow: AppraisalConstants.subtleShadow,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedUniqueValue,
                  isExpanded: true,
                  selectedItemBuilder: (BuildContext context) {
                    return uniqueEmployees.map((employee) {
                      final fullName = _safeParseString(employee['fullname']) ?? 'Unknown';
                      return Text(
                        fullName,
                        style: TextStyle(
                          color: AppraisalConstants.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    }).toList();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search and select employee...',
                    hintStyle: TextStyle(
                      color: AppraisalConstants.textTertiary.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: AppraisalConstants.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: AppraisalConstants.borderRadiusMedium,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppraisalConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: AppraisalConstants.textTertiary.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppraisalConstants.borderRadiusMedium,
                      borderSide: BorderSide(
                        color: AppraisalConstants.primaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    prefixIcon: Icon(
                      Icons.person_search_rounded,
                      color: AppraisalConstants.primaryColor,
                      size: 20,
                    ),
                  ),
                  items: uniqueEmployees.map((employee) {
                    final employeeId = _safeParseString(employee['employee_id']);
                    final fullName = _safeParseString(employee['fullname']) ?? 'Unknown';
                    final position = _safeParseString(employee['position']) ?? 'Unknown';
                    
                    final uniqueValue = '$employeeId|$fullName|$position';
                    
                    return DropdownMenuItem<String>(
                      value: uniqueValue,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fullName,
                            style: TextStyle(
                              color: AppraisalConstants.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'ID: ${employeeId ?? 'N/A'} • $position',
                            style: TextStyle(
                              color: AppraisalConstants.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUniqueValue = value;
                    });
                  },
                  style: TextStyle(
                    color: AppraisalConstants.textPrimary,
                    fontSize: 14,
                  ),
                  dropdownColor: AppraisalConstants.cardColor,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppraisalConstants.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppraisalConstants.borderRadiusMedium,
                        ),
                        side: BorderSide(color: AppraisalConstants.textTertiary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppraisalConstants.textSecondary,
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
                      onPressed: selectedUniqueValue == null
                          ? null
                          : () {
                              final parts = selectedUniqueValue!.split('|');
                              final employeeId = parts[0];
                              final employeeName = parts.length > 1 ? parts[1] : 'Unknown';
                              final employeePosition = parts.length > 2 ? parts[2] : 'Unknown';
                              
                              Navigator.pop(context, {
                                'employeeId': employeeId,
                                'employeeName': employeeName,
                                'employeePosition': employeePosition,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppraisalConstants.borderRadiusMedium,
                        ),
                        backgroundColor: AppraisalConstants.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Continue',
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
    ).then((value) {
      if (value != null && mounted) {
        if (!mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => EmployeeAppraisalScreen(
              user: userModel,
              apiService: widget.apiService,
              onSubmit: _fetchAppraisals,
              employeeId: value['employeeId'],
              employeeName: value['employeeName'] ?? 'Unknown',
              employeePosition: value['employeePosition'] ?? 'Unknown',
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            transitionDuration: AppraisalConstants.animationDuration,
          ),
        );
      }
    });
  }

  List<Map<String, dynamic>> _getUniqueEmployees() {
    final seen = <String>{};
    final uniqueEmployees = <Map<String, dynamic>>[];
    
    for (final employee in _employees) {
      final employeeId = _safeParseString(employee['employee_id']);
      final fullName = _safeParseString(employee['fullname']) ?? 'Unknown';
      final position = _safeParseString(employee['position']) ?? 'Unknown';
      
      final uniqueKey = '$employeeId|$fullName|$position';
      
      if (!seen.contains(uniqueKey)) {
        seen.add(uniqueKey);
        uniqueEmployees.add(employee);
      }
    }
    
    return uniqueEmployees;
  }

  String _getEmployeeName(String employeeId) {
    final employee = _employees.firstWhere(
      (e) => _safeParseString(e['employee_id']) == employeeId,
      orElse: () => {'fullname': 'Unknown'},
    );
    return _safeParseString(employee['fullname']) ?? 'Unknown';
  }

  String _getEmployeePosition(String employeeId) {
    final employee = _employees.firstWhere(
      (e) => _safeParseString(e['employee_id']) == employeeId,
      orElse: () => {'position': 'Unknown'},
    );
    return _safeParseString(employee['position']) ?? 'Unknown';
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppraisalConstants.primaryGradient,
        boxShadow: AppraisalConstants.mediumShadow,
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
                        'Appraisal Dashboard',
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
                    _showSuccessSnackBar('No new notifications');
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Stats Row
            Row(
              children: [
                _buildStatCard(
                  title: 'Total',
                  value: _appraisals.length.toString(),
                  color: AppraisalConstants.primaryColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Pending',
                  value: _appraisals.where((a) => _safeParseString(a['status']) == 'Pending').length.toString(),
                  color: AppraisalConstants.pendingColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Approved',
                  value: _appraisals.where((a) => _safeParseString(a['status']) == 'Approved').length.toString(),
                  color: AppraisalConstants.approvedColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Rejected',
                  value: _appraisals.where((a) => _safeParseString(a['status']) == 'Rejected').length.toString(),
                  color: AppraisalConstants.rejectedColor,
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
          borderRadius: AppraisalConstants.borderRadiusMedium,
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

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppraisalConstants.surfaceColor,
        borderRadius: AppraisalConstants.borderRadiusLarge,
        boxShadow: AppraisalConstants.cardShadow,
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppraisalConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppraisalConstants.textTertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppraisalConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assessment_rounded,
                    color: AppraisalConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppraisalConstants.textPrimary,
                    ),
                  ),
                ),
                if (_isManager || _isAdmin) _buildFilterDropdown(),
              ],
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_isEmployee || _isAdmin) ...[
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.person_rounded,
                      title: 'Self Appraisal',
                      subtitle: 'Submit your own performance review',
                      gradient: AppraisalConstants.selfAppraisalGradient,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => SelfAppraisalScreen(
                              user: userModel,
                              apiService: widget.apiService,
                              onSubmit: _fetchAppraisals,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              );
                            },
                            transitionDuration: AppraisalConstants.animationDuration,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isAdmin) const SizedBox(width: 16),
                ],
                if (_isAdmin) ...[
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.group_rounded,
                      title: 'Employee Appraisal',
                      subtitle: 'Appraise team member performance',
                      gradient: AppraisalConstants.employeeAppraisalGradient,
                      onTap: _showEmployeeSelectionDialog,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: AppraisalConstants.borderRadiusLarge,
        boxShadow: AppraisalConstants.mediumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppraisalConstants.borderRadiusLarge,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppraisalConstants.borderRadiusLarge,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppraisalConstants.surfaceColor,
                  AppraisalConstants.surfaceColor,
                ],
              ),
              borderRadius: AppraisalConstants.borderRadiusLarge,
              border: Border.all(
                color: AppraisalConstants.textTertiary.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppraisalConstants.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppraisalConstants.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppraisalConstants.accentColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        borderRadius: AppraisalConstants.borderRadiusMedium,
        boxShadow: AppraisalConstants.subtleShadow,
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedFilter),
        initialValue: _selectedFilter,
        decoration: InputDecoration(
          hintText: 'Filter',
          hintStyle: TextStyle(
            color: AppraisalConstants.textTertiary.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: AppraisalConstants.cardColor,
          border: OutlineInputBorder(
            borderRadius: AppraisalConstants.borderRadiusMedium,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppraisalConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: AppraisalConstants.textTertiary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppraisalConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: AppraisalConstants.primaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        items: ['All', 'Pending', 'Approved', 'Rejected']
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(
                      color: AppraisalConstants.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedFilter = value;
            _fetchAppraisals();
          });
        },
        dropdownColor: AppraisalConstants.cardColor,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppraisalConstants.textTertiary,
        ),
        style: TextStyle(
          fontSize: 14,
          color: AppraisalConstants.textPrimary,
        ),
      ),
    );
  }

  Widget _buildAppraisalsList() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppraisalConstants.surfaceColor,
        borderRadius: AppraisalConstants.borderRadiusLarge,
        boxShadow: AppraisalConstants.cardShadow,
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppraisalConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppraisalConstants.textTertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppraisalConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.list_alt_rounded,
                    color: AppraisalConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Appraisal Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppraisalConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${_appraisals.length} records',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppraisalConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Appraisals List
          if (_appraisals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 60,
                    color: AppraisalConstants.textTertiary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Appraisals Found',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppraisalConstants.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEmployee 
                        ? 'You have no performance appraisals yet'
                        : 'No appraisals found for the current selection',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppraisalConstants.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _appraisals.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildAppraisalCard(_appraisals[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppraisalCard(Map<String, dynamic> appraisal) {
    final status = _safeParseString(appraisal['status']) ?? 'Pending';
    final isPending = status == 'Pending';
    final employeeName = _getEmployeeName(_safeParseString(appraisal['employee_id']) ?? '');
    final employeePosition = _getEmployeePosition(_safeParseString(appraisal['employee_id']) ?? '');
    final period = _safeParseString(appraisal['period']) ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppraisalConstants.borderRadiusMedium,
        boxShadow: AppraisalConstants.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppraisalConstants.borderRadiusMedium,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AppraisalDetailScreen(
                  appraisal: appraisal,
                  user: userModel,
                  apiService: widget.apiService,
                  employeeName: employeeName,
                  employeePosition: employeePosition,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
                transitionDuration: AppraisalConstants.animationDuration,
              ),
            );
          },
          borderRadius: AppraisalConstants.borderRadiusMedium,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppraisalConstants.cardColor,
              borderRadius: AppraisalConstants.borderRadiusMedium,
              border: Border.all(
                color: _getStatusColor(status).withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppraisalConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Period: $period',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppraisalConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Position: $employeePosition',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppraisalConstants.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(status).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if ((_isManager || _isAdmin) && isPending) ...[
                      _buildActionIconButton(
                        icon: Icons.check_rounded,
                        color: AppraisalConstants.approvedColor,
                        onPressed: () => _updateAppraisalStatus(
                          _safeParseString(appraisal['appraisal_id']) ?? '',
                          'Approved'
                        ),
                        tooltip: 'Approve',
                      ),
                      const SizedBox(height: 8),
                      _buildActionIconButton(
                        icon: Icons.close_rounded,
                        color: AppraisalConstants.rejectedColor,
                        onPressed: () => _updateAppraisalStatus(
                          _safeParseString(appraisal['appraisal_id']) ?? '',
                          'Rejected'
                        ),
                        tooltip: 'Reject',
                      ),
                      const SizedBox(height: 8),
                    ],
                    _buildActionIconButton(
                      icon: Icons.visibility_rounded,
                      color: AppraisalConstants.primaryColor,
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => AppraisalDetailScreen(
                              appraisal: appraisal,
                              user: userModel,
                              apiService: widget.apiService,
                              employeeName: employeeName,
                              employeePosition: employeePosition,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              );
                            },
                            transitionDuration: AppraisalConstants.animationDuration,
                          ),
                        );
                      },
                      tooltip: 'View Details',
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

  Widget _buildActionIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppraisalConstants.approvedColor;
      case 'pending':
        return AppraisalConstants.pendingColor;
      case 'rejected':
        return AppraisalConstants.rejectedColor;
      default:
        return AppraisalConstants.textTertiary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppraisalConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Appraisals...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppraisalConstants.textSecondary,
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
              color: AppraisalConstants.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppraisalConstants.errorColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Appraisals',
            style: TextStyle(
              fontSize: 18,
              color: AppraisalConstants.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 14,
              color: AppraisalConstants.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchAppraisals,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: AppraisalConstants.borderRadiusMedium,
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
      backgroundColor: AppraisalConstants.backgroundColor,
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
            if (_isLoading)
              Expanded(child: _buildLoadingState())
            else if (_errorMessage != null)
              Expanded(child: _buildErrorState())
            else
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 400,
                      child: _buildAppraisalsList(),
                    ),
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