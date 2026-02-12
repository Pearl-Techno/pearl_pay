import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pearl_pay/services/base_api_service.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/base_api_service.dart' as base_api;
import '../services/services.dart' as services;
import 'home_screen.dart';
import 'recaptcha_screen.dart';

// Premium Design Constants
class LoginConstants {
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
  static const Color infoColor = Color(0xFF2D3436);
  
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late ApiService _apiService;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _useLocalhost = false;
  bool _hasAttemptedAutoLogin = false;
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  // Particle system
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeApiService();
    _loadStoredPreferences();
    _initializeAnimations();
    _initializeParticles();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );
    
    _animationController.forward();
  }

  void _initializeParticles() {
    for (int i = 0; i < 15; i++) {
      _particles.add(Particle());
    }
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.update();
    }
  }

  void _initializeApiService() {
    _apiService = ApiService(
      client: http.Client(),
      user: User(
        companyId: 0,
        role: 'unknown',
      ),
    );
  }

  Future<void> _loadStoredPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useLocalhost = prefs.getBool('use_localhost') ?? false;
    });
    _updateEnvironment();
    
    if (!_hasAttemptedAutoLogin) {
      await _checkExistingSession();
      _hasAttemptedAutoLogin = true;
    }
  }

  void _updateEnvironment() {
    ApiConfig.environment = _useLocalhost 
        ? Environment.localhost 
        : Environment.production;
    
    _apiService = ApiService(
      client: http.Client(),
      user: User(
        companyId: 0,
        role: 'unknown',
      ),
    );
    
    if (kDebugMode) {
      print('Environment set to: ${_useLocalhost ? 'Localhost' : 'Production'}');
      print('Base URL: ${ApiConfig.baseUrl}');
    }
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('user_id');
    
    if (token != null && userId != null && mounted) {
      final isValid = await _validateStoredToken(token);
      
      if (isValid) {
        final user = User(
          userId: userId,
          username: prefs.getString('username'),
          role: prefs.getString('role') ?? 'unknown',
          companyId: _safeParseInt(prefs.getString('company_id')) ?? 0,
          companyName: prefs.getString('company_name'),
          employeeId: prefs.getString('employee_id'),
          token: token,
        );
        
        _navigateToHome(user);
      } else {
        await _clearStoredUserData();
      }
    }
  }

  Future<bool> _validateStoredToken(String token) async {
    return token.length > 10;
  }

  Future<void> _clearStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('role');
    await prefs.remove('company_id');
    await prefs.remove('company_name');
    await prefs.remove('employee_id');
  }

  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _safeParseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  Future<void> _toggleEnvironment() async {
    if (!kDebugMode) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _buildEnvironmentDialog(),
      );
      
      if (confirmed != true) return;
    }

    setState(() {
      _useLocalhost = !_useLocalhost;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_localhost', _useLocalhost);
    
    _updateEnvironment();
    
    setState(() {
      _errorMessage = null;
    });
    _passwordController.clear();
    
    if (mounted) {
      _showPremiumSnackBar(
        'Switched to ${_useLocalhost ? 'Localhost' : 'Production'} environment',
        LoginConstants.successColor,
        Icons.swap_horiz,
      );
    }
  }

  Widget _buildEnvironmentDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: LoginConstants.surfaceColor,
          borderRadius: LoginConstants.borderRadiusLarge,
          boxShadow: LoginConstants.strongShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LoginConstants.accentGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.developer_mode, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 24),
            Text(
              'Switch Environment?',
              style: TextStyle(
                color: LoginConstants.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This feature is for development purposes only. '
              'Are you sure you want to continue?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LoginConstants.textTertiary,
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
                        borderRadius: LoginConstants.borderRadiusMedium,
                      ),
                      side: BorderSide(color: LoginConstants.textTertiary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: LoginConstants.textSecondary,
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
                        borderRadius: LoginConstants.borderRadiusMedium,
                      ),
                      backgroundColor: LoginConstants.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Switch',
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
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _apiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      _validateUserData(user);
      await _saveUserData(user);
      _navigateToHome(user);
      
    } catch (e) {
      await _handleLoginError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _validateUserData(User user) {
    final errors = <String>[];
    
    if (_safeParseString(user.userId) == null) errors.add('User ID');
    if (_safeParseString(user.username) == null) errors.add('Username');
    if (_safeParseString(user.role) == null) errors.add('User role');
    if (_safeParseInt(user.companyId) == null) errors.add('Company ID');
    
    if (errors.isNotEmpty) {
      throw Exception('Invalid user data: ${errors.join(', ')} missing from server response');
    }
  }

  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('user_id', _safeParseString(user.userId) ?? '');
    await prefs.setString('username', _safeParseString(user.username) ?? '');
    await prefs.setString('role', _safeParseString(user.role) ?? 'unknown');
    await prefs.setString('company_id', _safeParseString(user.companyId) ?? '0');
    await prefs.setString('company_name', _safeParseString(user.companyName) ?? 'N/A');
    await prefs.setString('employee_id', _safeParseString(user.employeeId) ?? 'N/A');
    
    if (user.token != null) {
      await prefs.setString('token', user.token!);
    }
    await prefs.setBool('use_localhost', _useLocalhost);
  }

  void _navigateToHome(User user) {
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            HomeScreen(user: user.toMap()),
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
  }

  Future<void> _handleLoginError(dynamic e) async {
    String errorMessage;
    bool requiresRecaptcha = false;
    
    if (e is base_api.UnauthorizedAccessException) {
      errorMessage = e.message;
    } else if (e is services.ServerException) {
      errorMessage = 'Server error: ${e.message}';
    } else if (e is base_api.NetworkException) {
      errorMessage = 'Network error: Please check your internet connection and try again.';
    } else if (e.toString().contains('reCAPTCHA')) {
      errorMessage = 'Security verification required';
      requiresRecaptcha = true;
    } else {
      errorMessage = 'Login failed: ${e.toString().replaceFirst('Exception: ', '')}';
    }

    if (requiresRecaptcha && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RecaptchaScreen(),
          fullscreenDialog: true,
        ),
      );
      if (result == 'success' && mounted) {
        _login();
        return;
      }
    }

    if (mounted) {
      setState(() {
        _errorMessage = errorMessage;
      });

      _showPremiumSnackBar(
        errorMessage,
        LoginConstants.errorColor,
        Icons.error_outline,
      );
    }
  }

  void _showPremiumSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: LoginConstants.borderRadiusMedium,
            boxShadow: LoginConstants.mediumShadow,
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
                child: Icon(icon, size: 18, color: Colors.white),
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
              if (!message.contains('Security verification'))
                TextButton(
                  onPressed: _login,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      decoration: TextDecoration.underline,
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

  void _clearForm() {
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _errorMessage = null;
      _obscurePassword = true;
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoginConstants.backgroundColor,
      body: Stack(
        children: [
          // Background Particles
          CustomPaint(
            painter: ParticlePainter(particles: _particles),
            willChange: true,
          ),
          
          // Animated Gradient Background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              _updateParticles();
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LoginConstants.backgroundColor,
                      LoginConstants.backgroundColor.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: child,
              );
            },
          ),
          
          // Main Content
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // App Bar
              _buildPremiumAppBar(),
              
              // Main Content
              SliverToBoxAdapter(
                child: AnimatedBuilder(
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
                      const SizedBox(height: 20),
                      _buildHeroSection(),
                      const SizedBox(height: 40),
                      _buildLoginCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildPremiumAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: kDebugMode ? null : Container(),
      actions: kDebugMode ? [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              _buildEnvironmentChip(),
              const SizedBox(width: 12),
              _buildClearButton(),
            ],
          ),
        ),
      ] : null,
      expandedHeight: 0,
      floating: false,
      pinned: false,
    );
  }

  Widget _buildEnvironmentChip() {
    return Material(
      color: Colors.transparent,
      borderRadius: LoginConstants.borderRadiusSmall,
      child: InkWell(
        onTap: _toggleEnvironment,
        borderRadius: LoginConstants.borderRadiusSmall,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _useLocalhost ? Colors.orange.withValues(alpha: 0.1) : 
                  Colors.green.withValues(alpha: 0.1),
            borderRadius: LoginConstants.borderRadiusSmall,
            border: Border.all(
              color: _useLocalhost ? Colors.orange : Colors.green,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _useLocalhost ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _useLocalhost ? 'DEV' : 'PROD',
                style: TextStyle(
                  color: _useLocalhost ? Colors.orange : Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(Icons.refresh, color: LoginConstants.textSecondary),
        onPressed: _clearForm,
        tooltip: 'Clear form',
        splashRadius: 20,
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo/Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LoginConstants.primaryGradient,
              borderRadius: LoginConstants.borderRadiusExtraLarge,
              boxShadow: LoginConstants.mediumShadow,
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          
          // Welcome Text
          Text(
            'Welcome Back',
            style: TextStyle(
              color: LoginConstants.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Sign in to continue to Pearl Pay',
            style: TextStyle(
              color: LoginConstants.textTertiary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: LoginConstants.surfaceColor,
          borderRadius: LoginConstants.borderRadiusLarge,
          boxShadow: LoginConstants.strongShadow,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Form Title
              _buildFormTitle(),
              const SizedBox(height: 32),
              
              // Username Field
              _buildPremiumTextField(
                controller: _usernameController,
                label: 'Username',
                hintText: 'Enter your username',
                prefixIcon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your username';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Password Field
              _buildPremiumTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: LoginConstants.textTertiary,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  splashRadius: 20,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              
              // Forgot Password
              _buildForgotPassword(),
              const SizedBox(height: 32),
              
              // Login Button
              _buildPremiumLoginButton(),
              const SizedBox(height: 20),
              
              // Error Message
              if (_errorMessage != null) _buildPremiumErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: LoginConstants.accentGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Login Credentials',
              style: TextStyle(
                color: LoginConstants.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your details to access your account',
          style: TextStyle(
            color: LoginConstants.textTertiary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LoginConstants.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: LoginConstants.borderRadiusMedium,
            boxShadow: LoginConstants.subtleShadow,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(
              color: LoginConstants.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: LoginConstants.textTertiary.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
              filled: true,
              fillColor: LoginConstants.cardColor,
              border: OutlineInputBorder(
                borderRadius: LoginConstants.borderRadiusMedium,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: LoginConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: LoginConstants.textTertiary.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: LoginConstants.borderRadiusMedium,
                borderSide: BorderSide(
                  color: LoginConstants.primaryColor,
                  width: 2,
                ),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  prefixIcon,
                  color: LoginConstants.primaryColor,
                  size: 22,
                ),
              ),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffixIcon,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            textInputAction: TextInputAction.next,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        borderRadius: LoginConstants.borderRadiusSmall,
        child: InkWell(
          onTap: () {
            _showPremiumSnackBar(
              'Password recovery feature is coming soon',
              LoginConstants.infoColor,
              Icons.info_outline,
            );
          },
          borderRadius: LoginConstants.borderRadiusSmall,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: LoginConstants.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                decoration: TextDecoration.underline,
                decorationThickness: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLoginButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: LoginConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: LoginConstants.borderRadiusMedium,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildPremiumErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LoginConstants.errorColor.withValues(alpha: 0.1),
        borderRadius: LoginConstants.borderRadiusMedium,
        border: Border.all(
          color: LoginConstants.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: LoginConstants.errorColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: LoginConstants.errorColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: LoginConstants.errorColor,
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

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.clear();
    _usernameController.clear();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}

// Particle System for Background Animation
class Particle {
  double x, y;
  double vx, vy;
  double radius;
  Color color;
  
  Particle()
      : x = Random().nextDouble() * 400,
        y = Random().nextDouble() * 800,
        vx = Random().nextDouble() * 0.5 - 0.25,
        vy = Random().nextDouble() * 0.5 - 0.25,
        radius = Random().nextDouble() * 2 + 1,
        color = LoginConstants.primaryColor.withValues(alpha: Random().nextDouble() * 0.1 + 0.05);
  
  void update() {
    x += vx;
    y += vy;
    
    if (x < 0 || x > 400) vx = -vx;
    if (y < 0 || y > 800) vy = -vy;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  
  ParticlePainter({required this.particles});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    
    for (var particle in particles) {
      paint.color = particle.color;
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.radius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}