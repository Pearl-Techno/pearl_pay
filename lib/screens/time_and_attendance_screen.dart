import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/services.dart';
import 'login_screen.dart';

// Premium Design Constants for Time & Attendance Screen
class AttendanceConstants {
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
  static const Color clockInColor = Color(0xFF4CAF50);
  static const Color clockOutColor = Color(0xFFF44336);
  static const Color presentColor = Color(0xFF00B894);
  static const Color absentColor = Color(0xFFFF4757);
  
  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF3A506B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient clockInGradient = LinearGradient(
    colors: [clockInColor, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient clockOutGradient = LinearGradient(
    colors: [clockOutColor, Color(0xFFEF5350)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient exportGradient = LinearGradient(
    colors: [accentColor, Color(0xFF2EC4B6)],
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

class TimeAndAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService apiService;

  const TimeAndAttendanceScreen({
    super.key,
    required this.user,
    required this.apiService,
  });

  @override
  State<TimeAndAttendanceScreen> createState() => _TimeAndAttendanceScreenState();
}

class _TimeAndAttendanceScreenState extends State<TimeAndAttendanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _isLoading = false;
  bool _isExporting = false;
  List<Map<String, dynamic>> _attendanceRecords = [];
  DateTime _selectedDate = DateTime.now();
  int? _selectedCompanyId;
  List<int> _companyIds = [];
  Map<int, String> _companyIdToName = {};
  String _companyName = 'Unknown';
  bool _isAdmin = false;

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
    _companyName = widget.user['company_name']?.toString() ?? 'Unknown';
    _isAdmin = widget.user['role'] == 'admin';
    _fetchCompanies();
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
            color: AttendanceConstants.surfaceColor,
            borderRadius: AttendanceConstants.borderRadiusLarge,
            boxShadow: AttendanceConstants.strongShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AttendanceConstants.errorColor, Colors.red[800]!],
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
                  color: AttendanceConstants.textPrimary,
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
                  color: AttendanceConstants.textTertiary,
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
                          borderRadius: AttendanceConstants.borderRadiusMedium,
                        ),
                        side: BorderSide(color: AttendanceConstants.textTertiary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AttendanceConstants.textSecondary,
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
                          borderRadius: AttendanceConstants.borderRadiusMedium,
                        ),
                        backgroundColor: AttendanceConstants.errorColor,
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
          color: AttendanceConstants.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: AttendanceConstants.strongShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                gradient: AttendanceConstants.primaryGradient,
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
                    color: AttendanceConstants.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    icon: Icons.badge,
                    title: 'User Role',
                    value: role,
                    color: AttendanceConstants.secondaryColor,
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
                        backgroundColor: AttendanceConstants.errorColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AttendanceConstants.borderRadiusMedium,
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
        color: AttendanceConstants.cardColor,
        borderRadius: AttendanceConstants.borderRadiusMedium,
        border: Border.all(
          color: AttendanceConstants.textTertiary.withValues(alpha: 0.1),
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
                    color: AttendanceConstants.textTertiary,
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
                    color: AttendanceConstants.textPrimary,
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

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await widget.apiService.getCompanies();
      final userCompanyId = widget.user['company_id'] != null
          ? int.tryParse(widget.user['company_id'].toString())
          : null;

      setState(() {
        if (_isAdmin) {
          _companyIds = companies
              .map((c) => int.tryParse(c['id'].toString()))
              .where((id) => id != null)
              .cast<int>()
              .toSet()
              .toList();
          _companyIdToName = {};
          for (var c in companies) {
            final id = int.tryParse(c['id'].toString());
            if (id != null) {
              _companyIdToName[id] = c['company_name']?.toString() ?? 'Unknown';
            }
          }
          _companyIds.insert(0, 0); // 0 for 'All Companies'
          _companyIdToName[0] = 'All Companies';
        } else if (userCompanyId != null) {
          final userCompany = companies.firstWhere(
            (c) => int.tryParse(c['id'].toString()) == userCompanyId,
            orElse: () => {
              'id': userCompanyId,
              'company_name': _companyName
            },
          );
          _companyIds = [userCompanyId];
          _companyIdToName = {
            userCompanyId: userCompany['company_name']?.toString() ?? 'Unknown'
          };
        }
        _selectedCompanyId = _companyIds.isNotEmpty ? _companyIds[0] : null;
      });

      if (_selectedCompanyId != null) {
        await _fetchAttendanceRecords();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching companies: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load companies: $e');
    }
  }

  Future<void> _fetchAttendanceRecords() async {
    if (_selectedCompanyId == null) {
      setState(() {
        _attendanceRecords = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> records = [];
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (_selectedCompanyId == 0 && _isAdmin) {
        // Fetch attendance for all companies
        final futures = _companyIds.where((id) => id != 0).map((companyId) async {
          return await widget.apiService.getAttendanceRecords(
            companyId: companyId,
            date: dateStr,
            employeeId: null,
          );
        });
        final results = await Future.wait(futures);
        records = results.expand((r) => r).toList();
      } else {
        // Fetch attendance for a single company
        records = await widget.apiService.getAttendanceRecords(
          companyId: _selectedCompanyId!,
          date: dateStr,
          employeeId: _isAdmin ? null : widget.user['employee_id'],
        );
      }

      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching attendance records: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load attendance records: $e');
    }
  }

  Future<void> _recordAttendance(bool isClockIn) async {
    if (widget.user['employee_id'] == null) {
      _showErrorSnackBar('Employee ID not found');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.apiService.recordAttendance(
        companyId: widget.user['company_id'],
        employeeId: widget.user['employee_id'],
        isClockIn: isClockIn,
      );
      
      _showSuccessSnackBar('Successfully ${isClockIn ? 'clocked in' : 'clocked out'}');
      await _fetchAttendanceRecords();
    } catch (e) {
      if (kDebugMode) {
        print('Error recording attendance: $e');
      }
      _showErrorSnackBar('Failed to record attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToCsv() async {
    if (_attendanceRecords.isEmpty) {
      _showErrorSnackBar('No attendance data available to export');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final companyName = _selectedCompanyId == 0
          ? 'All Companies'
          : _companyIdToName[_selectedCompanyId] ?? 'Unknown';
      final dateStr = DateFormat('MMM dd yyyy').format(_selectedDate);

      final csvData = [
        ['Attendance Report for', companyName, dateStr],
        ['Employee ID', 'Employee Name', 'Clock In', 'Clock Out', 'Hours Worked', 'Status'],
        ..._attendanceRecords.map((data) {
          final hoursWorked = data['hours_worked']?.toString() ?? 'N/A';
          final status = data['status']?.toString() ?? 'N/A';
          return [
            data['employee_id']?.toString() ?? 'N/A',
            data['employee_name']?.toString() ?? 'Unknown',
            data['clock_in']?.toString() ?? 'N/A',
            data['clock_out']?.toString() ?? 'N/A',
            hoursWorked,
            status,
          ];
        }),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);

      String baseDir = Platform.isWindows
          ? r'C:\reports'
          : '${(await getApplicationDocumentsDirectory()).path}/reports';

      final directory = Directory(baseDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filename =
          'attendance_report_${companyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateFormat('MMM_dd_yyyy').format(_selectedDate)}.csv';
      final filePath = '$baseDir/$filename';

      final file = File(filePath);
      await file.writeAsString(csvString);

      _showSuccessSnackBar('CSV exported successfully to $filePath');
    } catch (e) {
      _showErrorSnackBar('Failed to export CSV: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AttendanceConstants.errorColor,
            borderRadius: AttendanceConstants.borderRadiusMedium,
            boxShadow: AttendanceConstants.mediumShadow,
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
            color: AttendanceConstants.successColor,
            borderRadius: AttendanceConstants.borderRadiusMedium,
            boxShadow: AttendanceConstants.mediumShadow,
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
        gradient: AttendanceConstants.primaryGradient,
        boxShadow: AttendanceConstants.mediumShadow,
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
                        'Time & Attendance',
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
                  title: 'Records Today',
                  value: _attendanceRecords.length.toString(),
                  color: AttendanceConstants.primaryColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Present',
                  value: _attendanceRecords.where((r) => r['status'] == 'Present').length.toString(),
                  color: AttendanceConstants.presentColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Absent',
                  value: _attendanceRecords.where((r) => r['status'] == 'Absent').length.toString(),
                  color: AttendanceConstants.absentColor,
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
          borderRadius: AttendanceConstants.borderRadiusMedium,
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

  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AttendanceConstants.surfaceColor,
        borderRadius: AttendanceConstants.borderRadiusLarge,
        boxShadow: AttendanceConstants.cardShadow,
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AttendanceConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AttendanceConstants.textTertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AttendanceConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: AttendanceConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Attendance Control Panel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AttendanceConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: AttendanceConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Controls
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Clock In/Out Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.login_rounded,
                        title: 'Clock In',
                        subtitle: 'Record your arrival',
                        gradient: AttendanceConstants.clockInGradient,
                        onPressed: _isLoading ? null : () => _recordAttendance(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.logout_rounded,
                        title: 'Clock Out',
                        subtitle: 'Record your departure',
                        gradient: AttendanceConstants.clockOutGradient,
                        onPressed: _isLoading ? null : () => _recordAttendance(false),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Date Picker and Company Selector
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCompanySelector(),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Export Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting || _attendanceRecords.isEmpty ? null : _exportToCsv,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AttendanceConstants.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AttendanceConstants.borderRadiusMedium,
                      ),
                      elevation: 0,
                    ),
                    icon: _isExporting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _isExporting ? 'Exporting...' : 'Export to CSV',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: AttendanceConstants.borderRadiusLarge,
        boxShadow: AttendanceConstants.mediumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AttendanceConstants.borderRadiusLarge,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AttendanceConstants.borderRadiusLarge,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AttendanceConstants.surfaceColor,
                  AttendanceConstants.surfaceColor,
                ],
              ),
              borderRadius: AttendanceConstants.borderRadiusLarge,
              border: Border.all(
                color: onPressed != null 
                    ? AttendanceConstants.textTertiary.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: onPressed != null ? gradient : LinearGradient(
                      colors: [Colors.grey[400]!, Colors.grey[500]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
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
                          color: onPressed != null 
                              ? AttendanceConstants.textPrimary 
                              : AttendanceConstants.textTertiary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: onPressed != null 
                              ? AttendanceConstants.textTertiary 
                              : Colors.grey[500]!,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AttendanceConstants.borderRadiusMedium,
        boxShadow: AttendanceConstants.subtleShadow,
      ),
      child: InkWell(
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AttendanceConstants.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AttendanceConstants.textPrimary,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (pickedDate != null) {
            setState(() {
              _selectedDate = pickedDate;
              _fetchAttendanceRecords();
            });
          }
        },
        borderRadius: AttendanceConstants.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AttendanceConstants.cardColor,
            borderRadius: AttendanceConstants.borderRadiusMedium,
            border: Border.all(
              color: AttendanceConstants.textTertiary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AttendanceConstants.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AttendanceConstants.textPrimary,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.calendar_today_rounded,
                color: AttendanceConstants.primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanySelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AttendanceConstants.borderRadiusMedium,
        boxShadow: AttendanceConstants.subtleShadow,
      ),
      child: DropdownButtonFormField<int>(
        key: ValueKey(_selectedCompanyId),
        initialValue: _selectedCompanyId,
        decoration: InputDecoration(
          hintText: 'Select Company',
          hintStyle: TextStyle(
            color: AttendanceConstants.textTertiary.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: AttendanceConstants.cardColor,
          border: OutlineInputBorder(
            borderRadius: AttendanceConstants.borderRadiusMedium,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AttendanceConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: AttendanceConstants.textTertiary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AttendanceConstants.borderRadiusMedium,
            borderSide: BorderSide(
              color: AttendanceConstants.primaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          prefixIcon: Icon(
            Icons.business_rounded,
            color: AttendanceConstants.primaryColor,
            size: 20,
          ),
        ),
        items: _companyIds.map((id) {
          return DropdownMenuItem(
            value: id,
            child: Text(
              _companyIdToName[id] ?? 'Unknown',
              style: TextStyle(
                fontSize: 14,
                color: AttendanceConstants.textPrimary,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCompanyId = value;
            _fetchAttendanceRecords();
          });
        },
        dropdownColor: AttendanceConstants.cardColor,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AttendanceConstants.textTertiary,
        ),
        style: TextStyle(
          fontSize: 14,
          color: AttendanceConstants.textPrimary,
        ),
      ),
    );
  }

  Widget _buildAttendanceRecords() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AttendanceConstants.surfaceColor,
        borderRadius: AttendanceConstants.borderRadiusLarge,
        boxShadow: AttendanceConstants.cardShadow,
      ),
      child: Column(
        children: [
          // Records Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AttendanceConstants.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AttendanceConstants.textTertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AttendanceConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.list_alt_rounded,
                    color: AttendanceConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Attendance Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AttendanceConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${_attendanceRecords.length} records',
                  style: TextStyle(
                    fontSize: 14,
                    color: AttendanceConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Records List
          if (_attendanceRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 60,
                    color: AttendanceConstants.textTertiary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No attendance records',
                    style: TextStyle(
                      fontSize: 16,
                      color: AttendanceConstants.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No attendance data available for the selected date',
                    style: TextStyle(
                      fontSize: 14,
                      color: AttendanceConstants.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: _attendanceRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildAttendanceCard(_attendanceRecords[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> data) {
    final hoursWorked = data['hours_worked']?.toString() ?? 'N/A';
    final status = data['status']?.toString() ?? 'N/A';
    final isPresent = status == 'Present';
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: AttendanceConstants.borderRadiusMedium,
        boxShadow: AttendanceConstants.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AttendanceConstants.borderRadiusMedium,
        child: InkWell(
          borderRadius: AttendanceConstants.borderRadiusMedium,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AttendanceConstants.cardColor,
              borderRadius: AttendanceConstants.borderRadiusMedium,
              border: Border.all(
                color: isPresent
                    ? AttendanceConstants.presentColor.withValues(alpha: 0.2)
                    : AttendanceConstants.absentColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPresent
                        ? AttendanceConstants.presentColor.withValues(alpha: 0.1)
                        : AttendanceConstants.absentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isPresent ? AttendanceConstants.presentColor : AttendanceConstants.absentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['employee_name']?.toString() ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AttendanceConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${data['employee_id']?.toString() ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AttendanceConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildDetailBadge(
                            label: 'Clock In',
                            value: data['clock_in']?.toString() ?? 'N/A',
                            color: AttendanceConstants.clockInColor,
                          ),
                          _buildDetailBadge(
                            label: 'Clock Out',
                            value: data['clock_out']?.toString() ?? 'N/A',
                            color: AttendanceConstants.clockOutColor,
                          ),
                          _buildDetailBadge(
                            label: 'Hours',
                            value: hoursWorked,
                            color: AttendanceConstants.secondaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPresent
                        ? AttendanceConstants.presentColor.withValues(alpha: 0.1)
                        : AttendanceConstants.absentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPresent
                          ? AttendanceConstants.presentColor.withValues(alpha: 0.3)
                          : AttendanceConstants.absentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPresent
                          ? AttendanceConstants.presentColor
                          : AttendanceConstants.absentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AttendanceConstants.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
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
              valueColor: AlwaysStoppedAnimation<Color>(AttendanceConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Attendance...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AttendanceConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AttendanceConstants.backgroundColor,
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
            else
              Expanded(
                child: ListView(
                  children: [
                    _buildControlPanel(),
                    const SizedBox(height: 24),
                    _buildAttendanceRecords(),
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