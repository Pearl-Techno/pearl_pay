import 'dart:core';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:pearl_pay/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

// Constants - Using same colors as other screens
class AppraisalConstants {
  static const Color primaryColor = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF00B0FF);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1A237E);
  static const Color subtitleColor = Color(0xFF546E7A);
  static const Color greyColor = Color(0xFF9E9E9E);
  static const Color errorColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFFF9800);
}

enum StarRating { none, one, two, three, four, five }

class SelfAppraisalProvider with ChangeNotifier {
  // A. Personal Details
  String designation = '';
  String periodUnderReview = '';

  // E. Performance Indicators
  String awards = '';
  String trainingAttended = '';
  int numberValidWarnings = 0;
  int absenteeDays = 0;
  int sickDays = 0;

  // F. Personal Attributes (Self-Ratings)
  Map<String, Map<String, dynamic>> personalAttributes = {
    'drive_and_enthusiasm': {'self': StarRating.none, 'comments': ''},
    'punctuality_attendance': {'self': StarRating.none, 'comments': ''},
    'self_presentation': {'self': StarRating.none, 'comments': ''},
    'adaptability': {'self': StarRating.none, 'comments': ''},
    'creativity': {'self': StarRating.none, 'comments': ''},
    'integrity': {'self': StarRating.none, 'comments': ''},
    'attitude_toward_work': {'self': StarRating.none, 'comments': ''},
    'attitude_toward_colleagues': {'self': StarRating.none, 'comments': ''},
    'ability_take_criticism': {'self': StarRating.none, 'comments': ''},
    'verbal_communication': {'self': StarRating.none, 'comments': ''},
    'written_communication': {'self': StarRating.none, 'comments': ''},
    'listening_responsiveness': {'self': StarRating.none, 'comments': ''},
  };

  // G. Operational Skills (Self-Ratings)
  Map<String, Map<String, dynamic>> operationalSkills = {
    'essential_function_3': {'self': StarRating.none, 'description': ''},
    'essential_function_4': {'self': StarRating.none, 'description': ''},
    'job_knowledge': {'self': StarRating.none, 'comments': ''},
    'problem_solving': {'self': StarRating.none, 'comments': ''},
    'service_excellence': {'self': StarRating.none, 'comments': ''},
    'communication': {'self': StarRating.none, 'comments': ''},
    'teamwork': {'self': StarRating.none, 'comments': ''},
    'initiative': {'self': StarRating.none, 'comments': ''},
    'productivity': {'self': StarRating.none, 'comments': ''},
    'planning': {'self': StarRating.none, 'comments': ''},
    'accuracy': {'self': StarRating.none, 'comments': ''},
  };

  // H. Compliance Questions
  bool complianceTraining = false;
  bool punctuality = false;
  bool internalControls = false;
  bool professionalism = false;

  // I. Improvement Plan
  List<Map<String, String>> improvementPlan = [
    {'area': '', 'action_plan': '', 'goal': '', 'timing': ''},
  ];

  // J. Career Development
  String careerObjectives = '';
  String longTermDevelopmentPlan = '';
  String jobTargets = '';
  String developmentNeeds = '';
  String trainingRequired = '';

  // K. Summary
  StarRating overallRatingSelf = StarRating.none;
  String appraiseeComments = '';
  bool isSubmitting = false;
  String? errorMessage;

  // Map star ratings to A-D for API compatibility
  String _mapStarToLetter(StarRating rating) {
    switch (rating) {
      case StarRating.five:
        return 'A';
      case StarRating.four:
        return 'B';
      case StarRating.three:
        return 'C';
      case StarRating.two:
      case StarRating.one:
        return 'D';
      case StarRating.none:
        return '';
    }
  }

  void updateField<T>(String field, T value) {
    switch (field) {
      case 'designation':
        designation = value as String;
      case 'periodUnderReview':
        periodUnderReview = value as String;
      case 'awards':
        awards = value as String;
      case 'trainingAttended':
      case 'training':
        trainingAttended = value as String;
      case 'numberValidWarnings':
        numberValidWarnings = value as int;
      case 'absenteeDays':
        absenteeDays = value as int;
      case 'sickDays':
        sickDays = value as int;
      case 'complianceTraining':
        complianceTraining = value as bool;
      case 'punctuality':
        punctuality = value as bool;
      case 'internalControls':
        internalControls = value as bool;
      case 'professionalism':
        professionalism = value as bool;
      case 'careerObjectives':
      case 'careerDevelopment':
        careerObjectives = value as String;
      case 'longTermDevelopmentPlan':
        longTermDevelopmentPlan = value as String;
      case 'jobTargets':
        jobTargets = value as String;
      case 'developmentNeeds':
        developmentNeeds = value as String;
      case 'trainingRequired':
        trainingRequired = value as String;
      case 'overallRatingSelf':
        overallRatingSelf = value as StarRating;
      case 'appraiseeComments':
        appraiseeComments = value as String;
    }
    notifyListeners();
  }

  void updateAttribute(String attribute, String key, dynamic value, {bool isPersonal = true}) {
    final target = isPersonal ? personalAttributes : operationalSkills;
    if (target.containsKey(attribute)) {
      target[attribute]![key] = value;
      notifyListeners();
    }
  }

  void addImprovementPlanEntry() {
    improvementPlan.add({'area': '', 'action_plan': '', 'goal': '', 'timing': ''});
    notifyListeners();
  }

  void updateImprovementPlan(int index, String key, String value) {
    if (index < improvementPlan.length) {
      improvementPlan[index][key] = value;
      notifyListeners();
    }
  }

  void clearForm() {
    designation = '';
    periodUnderReview = '';
    awards = '';
    trainingAttended = '';
    numberValidWarnings = 0;
    absenteeDays = 0;
    sickDays = 0;
    
    personalAttributes.forEach((_, attr) {
      attr['self'] = StarRating.none;
      attr['comments'] = '';
    });
    
    operationalSkills.forEach((_, attr) {
      attr['self'] = StarRating.none;
      attr['description'] = '';
      attr['comments'] = '';
    });
    
    complianceTraining = false;
    punctuality = false;
    internalControls = false;
    professionalism = false;
    improvementPlan = [{'area': '', 'action_plan': '', 'goal': '', 'timing': ''}];
    careerObjectives = '';
    longTermDevelopmentPlan = '';
    jobTargets = '';
    developmentNeeds = '';
    trainingRequired = '';
    overallRatingSelf = StarRating.none;
    appraiseeComments = '';
    errorMessage = null;
    notifyListeners();
  }

  Future<void> submitAppraisal({
    required ApiService apiService,
    required String employeeId,
    required int companyId,
    required VoidCallback onSubmit,
    required BuildContext context,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      final data = {
        'designation': designation,
        'period_under_review': periodUnderReview,
        'awards': awards,
        'training_attended': trainingAttended,
        'number_valid_warnings': numberValidWarnings,
        'absentee_days': absenteeDays,
        'sick_days': sickDays,
        'personal_attributes': personalAttributes.map((key, value) => MapEntry(key, {
              'self_rating': _mapStarToLetter(value['self']),
              'comments': value['comments'],
            })),
        'operational_skills': operationalSkills.map((key, value) => MapEntry(key, {
              'self_rating': _mapStarToLetter(value['self']),
              'description': value['description'] ?? '',
              'comments': value['comments'] ?? '',
            })),
        'compliance_training': complianceTraining ? '1' : '0',
        'punctuality': punctuality ? '1' : '0',
        'internal_controls': internalControls ? '1' : '0',
        'professionalism': professionalism ? '1' : '0',
        'improvement_plan': improvementPlan,
        'career_development': {
          'career_objectives': careerObjectives,
          'long_term_development_plan': longTermDevelopmentPlan,
          'job_targets': jobTargets,
          'development_needs': developmentNeeds,
          'training_required': trainingRequired,
        },
        'overall_rating_self': _mapStarToLetter(overallRatingSelf),
        'appraisee_comments': appraiseeComments,
        'status': 'pending',
        'submitted_by': employeeId,
      };
      
      await apiService.submitSelfAppraisal(
        employeeId: employeeId,
        companyId: companyId,
        data: data,
      );
      
      if (!context.mounted) return;
      _showSuccessDialog(context);
      onSubmit();
      Navigator.pop(context);
    } catch (e) {
      errorMessage = e.toString();
      if (!context.mounted) return;
      _showErrorSnackBar(context, e.toString());
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void _showSuccessDialog(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppraisalConstants.cardColor,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppraisalConstants.successColor, size: 24),
            const SizedBox(width: 8),
            Text('Success', style: GoogleFonts.roboto(
              fontSize: 20, 
              fontWeight: FontWeight.w600, 
              color: AppraisalConstants.textColor
            )),
          ],
        ),
        content: Text('Self-appraisal submitted successfully!', 
          style: GoogleFonts.roboto(fontSize: 16, color: AppraisalConstants.subtitleColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.roboto(
              color: AppraisalConstants.primaryColor,
              fontWeight: FontWeight.w600
            )),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Error: $error', style: GoogleFonts.roboto(color: Colors.white))),
          ],
        ),
        backgroundColor: AppraisalConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class SelfAppraisalScreen extends StatelessWidget {
  final User user;
  final ApiService apiService;
  final VoidCallback onSubmit;

  const SelfAppraisalScreen({
    super.key,
    required this.user,
    required this.apiService,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SelfAppraisalProvider(),
      child: _SelfAppraisalView(
        user: user,
        apiService: apiService,
        onSubmit: onSubmit,
      ),
    );
  }
}

class _SelfAppraisalView extends StatefulWidget {
  final User user;
  final ApiService apiService;
  final VoidCallback onSubmit;

  const _SelfAppraisalView({
    required this.user,
    required this.apiService,
    required this.onSubmit,
  });

  @override
  _SelfAppraisalViewState createState() => _SelfAppraisalViewState();
}

class _SelfAppraisalViewState extends State<_SelfAppraisalView> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), 
      end: Offset.zero
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SelfAppraisalProvider>(context);
    final employeeName = widget.user.username ?? 'Self';

    return Scaffold(
      backgroundColor: AppraisalConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Self Appraisal',
        backgroundColor: AppraisalConstants.primaryColor,
        titleStyle: GoogleFonts.roboto(
          fontSize: 20, 
          fontWeight: FontWeight.w600, 
          color: Colors.white
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  _buildHeaderCard(employeeName),
                  const SizedBox(height: 20),
                  
                  // Form Sections
                  _buildSection(
                    title: 'Personal Details',
                    icon: Icons.person_outline,
                    children: _buildPersonalDetails(provider),
                  ),
                  
                  _buildSection(
                    title: 'Performance Indicators',
                    icon: Icons.assessment_outlined,
                    children: _buildPerformanceIndicators(provider),
                  ),
                  
                  _buildSection(
                    title: 'Personal Attributes',
                    icon: Icons.psychology_outlined,
                    children: _buildPersonalAttributes(provider),
                  ),
                  
                  _buildSection(
                    title: 'Operational Skills',
                    icon: Icons.work_outline,
                    children: _buildOperationalSkills(provider),
                  ),
                  
                  _buildSection(
                    title: 'Compliance Questions',
                    icon: Icons.verified_outlined,
                    children: _buildComplianceQuestions(provider),
                  ),
                  
                  _buildSection(
                    title: 'Improvement Plan',
                    icon: Icons.trending_up_outlined,
                    children: _buildImprovementPlan(provider),
                  ),
                  
                  _buildSection(
                    title: 'Career Development',
                    icon: Icons.school_outlined,
                    children: _buildCareerDevelopment(provider),
                  ),
                  
                  _buildSection(
                    title: 'Summary',
                    icon: Icons.summarize_outlined,
                    children: _buildSummary(provider),
                  ),
                  
                  const SizedBox(height: 24),
                  _buildActionButtons(context, provider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String employeeName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppraisalConstants.primaryColor, AppraisalConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppraisalConstants.primaryColor.withAlpha(77),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assessment, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Self Appraisal Form',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete your performance evaluation for $employeeName',
                      style: GoogleFonts.roboto(
                        color: Colors.white.withAlpha(230),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Employee ID: ${widget.user.employeeId ?? 'N/A'}',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppraisalConstants.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppraisalConstants.primaryColor.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppraisalConstants.primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppraisalConstants.textColor,
          ),
        ),
        iconColor: AppraisalConstants.primaryColor,
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }

  List<Widget> _buildPersonalDetails(SelfAppraisalProvider provider) {
    return [
      _buildTextField(
        label: 'Designation',
        value: provider.designation,
        onChanged: (v) => provider.updateField('designation', v),
        icon: Icons.work_outline,
      ),
      _buildTextField(
        label: 'Period Under Review',
        value: provider.periodUnderReview,
        onChanged: (v) => provider.updateField('periodUnderReview', v),
        icon: Icons.calendar_today_outlined,
      ),
    ];
  }

  List<Widget> _buildPerformanceIndicators(SelfAppraisalProvider provider) {
    return [
      _buildTextField(
        label: 'Awards & Recognition',
        value: provider.awards,
        onChanged: (v) => provider.updateField('awards', v),
        icon: Icons.emoji_events_outlined,
      ),
      _buildTextField(
        label: 'Training Attended',
        value: provider.trainingAttended,
        onChanged: (v) => provider.updateField('trainingAttended', v),
        icon: Icons.school_outlined,
      ),
      _buildNumberField(
        label: 'Number of Valid Warnings',
        value: provider.numberValidWarnings,
        onChanged: (v) => provider.updateField('numberValidWarnings', v),
        icon: Icons.warning_outlined,
      ),
      _buildNumberField(
        label: 'Absentee Days',
        value: provider.absenteeDays,
        onChanged: (v) => provider.updateField('absenteeDays', v),
        icon: Icons.event_busy_outlined,
      ),
      _buildNumberField(
        label: 'Sick Days',
        value: provider.sickDays,
        onChanged: (v) => provider.updateField('sickDays', v),
        icon: Icons.medical_services_outlined,
      ),
    ];
  }

  List<Widget> _buildPersonalAttributes(SelfAppraisalProvider provider) {
    return provider.personalAttributes.entries.map((entry) => 
      _buildAttributeField(
        label: entry.key.replaceAll('_', ' ').toTitleCase(),
        selfRating: entry.value['self'],
        comments: entry.value['comments'],
        onSelfRatingChanged: (v) => provider.updateAttribute(entry.key, 'self', v),
        onCommentsChanged: (v) => provider.updateAttribute(entry.key, 'comments', v),
      )
    ).toList();
  }

  List<Widget> _buildOperationalSkills(SelfAppraisalProvider provider) {
    return provider.operationalSkills.entries.map((entry) => 
      _buildAttributeField(
        label: entry.key.replaceAll('_', ' ').toTitleCase(),
        selfRating: entry.value['self'],
        description: entry.value['description'],
        comments: entry.value['comments'],
        onSelfRatingChanged: (v) => provider.updateAttribute(entry.key, 'self', v, isPersonal: false),
        onDescriptionChanged: entry.key.startsWith('essential_function')
            ? (v) => provider.updateAttribute(entry.key, 'description', v, isPersonal: false)
            : null,
        onCommentsChanged: (v) => provider.updateAttribute(entry.key, 'comments', v, isPersonal: false),
      )
    ).toList();
  }

  List<Widget> _buildComplianceQuestions(SelfAppraisalProvider provider) {
    return [
      _buildSwitchField(
        label: 'Current with mandatory trainings',
        value: provider.complianceTraining,
        onChanged: (v) => provider.updateField('complianceTraining', v),
      ),
      _buildSwitchField(
        label: 'Maintains punctuality standards',
        value: provider.punctuality,
        onChanged: (v) => provider.updateField('punctuality', v),
      ),
      _buildSwitchField(
        label: 'Follows internal controls and safeguards company assets',
        value: provider.internalControls,
        onChanged: (v) => provider.updateField('internalControls', v),
      ),
      _buildSwitchField(
        label: 'Maintains professional appearance and hygiene',
        value: provider.professionalism,
        onChanged: (v) => provider.updateField('professionalism', v),
      ),
    ];
  }

  List<Widget> _buildImprovementPlan(SelfAppraisalProvider provider) {
    return [
      ...provider.improvementPlan.asMap().entries.map((entry) => 
        _buildImprovementPlanEntry(
          index: entry.key,
          area: entry.value['area']!,
          action: entry.value['action_plan']!,
          goal: entry.value['goal']!,
          timing: entry.value['timing']!,
          onAreaChanged: (v) => provider.updateImprovementPlan(entry.key, 'area', v),
          onActionChanged: (v) => provider.updateImprovementPlan(entry.key, 'action_plan', v),
          onGoalChanged: (v) => provider.updateImprovementPlan(entry.key, 'goal', v),
          onTimingChanged: (v) => provider.updateImprovementPlan(entry.key, 'timing', v),
        )
      ),
      Container(
        margin: const EdgeInsets.only(top: 8),
        child: ElevatedButton.icon(
          onPressed: provider.addImprovementPlanEntry,
          icon: Icon(Icons.add, color: Colors.white, size: 20),
          label: Text('Add Improvement Area', style: GoogleFonts.roboto(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppraisalConstants.accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildCareerDevelopment(SelfAppraisalProvider provider) {
    return [
      _buildTextField(
        label: 'Career Objectives',
        value: provider.careerObjectives,
        onChanged: (v) => provider.updateField('careerObjectives', v),
        icon: Icons.flag_outlined,
        maxLines: 4,
      ),
      _buildTextField(
        label: 'Long-Term Development Plan',
        value: provider.longTermDevelopmentPlan,
        onChanged: (v) => provider.updateField('longTermDevelopmentPlan', v),
        icon: Icons.timeline_outlined,
        maxLines: 4,
      ),
      _buildTextField(
        label: 'Job Targets',
        value: provider.jobTargets,
        onChanged: (v) => provider.updateField('jobTargets', v),
        icon: Icons.flag_outlined,
        maxLines: 4,
      ),
      _buildTextField(
        label: 'Development Needs',
        value: provider.developmentNeeds,
        onChanged: (v) => provider.updateField('developmentNeeds', v),
        icon: Icons.lightbulb_outline,
        maxLines: 4,
      ),
      _buildTextField(
        label: 'Training Required',
        value: provider.trainingRequired,
        onChanged: (v) => provider.updateField('trainingRequired', v),
        icon: Icons.school_outlined,
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildSummary(SelfAppraisalProvider provider) {
    return [
      _buildStarRatingField(
        label: 'Overall Self Rating',
        value: provider.overallRatingSelf,
        onChanged: (v) => provider.updateField('overallRatingSelf', v),
      ),
      const SizedBox(height: 16),
      _buildTextField(
        label: 'Additional Comments',
        value: provider.appraiseeComments,
        onChanged: (v) => provider.updateField('appraiseeComments', v),
        icon: Icons.comment_outlined,
        maxLines: 5,
      ),
    ];
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    required IconData icon,
    int maxLines = 3,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppraisalConstants.primaryColor),
          labelText: label,
          hintText: 'Enter $label',
          filled: true,
          fillColor: AppraisalConstants.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppraisalConstants.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          suffixIcon: value.isNotEmpty 
              ? Icon(Icons.check_circle, color: AppraisalConstants.successColor)
              : null,
        ),
        validator: (v) => v == null || v.isEmpty ? '$label is required' : null,
        onChanged: onChanged,
        maxLines: maxLines,
        style: GoogleFonts.roboto(fontSize: 14, color: AppraisalConstants.textColor),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppraisalConstants.primaryColor),
          labelText: label,
          hintText: 'Enter $label',
          filled: true,
          fillColor: AppraisalConstants.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppraisalConstants.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          suffixIcon: value > 0 
              ? Icon(Icons.check_circle, color: AppraisalConstants.successColor)
              : null,
        ),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || int.tryParse(v) == null ? '$label must be a number' : null,
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
        style: GoogleFonts.roboto(fontSize: 14, color: AppraisalConstants.textColor),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildStarRatingField({
    required String label,
    required StarRating value,
    required Function(StarRating) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: AppraisalConstants.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppraisalConstants.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final rating = StarRating.values[index + 1];
                final isSelected = value.index >= rating.index;
                return GestureDetector(
                  onTap: () => onChanged(rating),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppraisalConstants.accentColor.withAlpha(26)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? AppraisalConstants.accentColor
                            : AppraisalConstants.greyColor.withAlpha(77),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: isSelected ? AppraisalConstants.accentColor : AppraisalConstants.greyColor,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${index + 1}',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppraisalConstants.accentColor : AppraisalConstants.greyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeField({
    required String label,
    required StarRating selfRating,
    String? description,
    String? comments,
    required Function(StarRating) onSelfRatingChanged,
    Function(String)? onDescriptionChanged,
    Function(String)? onCommentsChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppraisalConstants.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppraisalConstants.primaryColor.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppraisalConstants.textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildStarRatingField(
            label: 'Self Rating',
            value: selfRating,
            onChanged: onSelfRatingChanged,
          ),
          if (onDescriptionChanged != null) ...[
            const SizedBox(height: 8),
            _buildTextField(
              label: 'Description',
              value: description ?? '',
              onChanged: onDescriptionChanged,
              icon: Icons.description_outlined,
            ),
          ],
          if (onCommentsChanged != null) ...[
            const SizedBox(height: 8),
            _buildTextField(
              label: 'Comments',
              value: comments ?? '',
              onChanged: onCommentsChanged,
              icon: Icons.comment_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImprovementPlanEntry({
    required int index,
    required String area,
    required String action,
    required String goal,
    required String timing,
    required Function(String) onAreaChanged,
    required Function(String) onActionChanged,
    required Function(String) onGoalChanged,
    required Function(String) onTimingChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppraisalConstants.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppraisalConstants.primaryColor.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppraisalConstants.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Improvement Area ${index + 1}',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppraisalConstants.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Area for Improvement',
            value: area,
            onChanged: onAreaChanged,
            icon: Icons.area_chart_outlined,
          ),
          _buildTextField(
            label: 'Action Plan',
            value: action,
            onChanged: onActionChanged,
            icon: Icons.assignment_outlined,
          ),
          _buildTextField(
            label: 'Goal',
            value: goal,
            onChanged: onGoalChanged,
            icon: Icons.flag_outlined,
          ),
          _buildTextField(
            label: 'Timeline',
            value: timing,
            onChanged: onTimingChanged,
            icon: Icons.schedule_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppraisalConstants.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  value ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: value ? AppraisalConstants.successColor : AppraisalConstants.greyColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppraisalConstants.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppraisalConstants.successColor,
            inactiveTrackColor: AppraisalConstants.greyColor.withAlpha(77),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SelfAppraisalProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            onPressed: provider.isSubmitting ? null : provider.clearForm,
            text: 'Clear Form',
            icon: Icons.clear_outlined,
            backgroundColor: AppraisalConstants.errorColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            onPressed: provider.isSubmitting
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      _showPreviewDialog(context, provider);
                    }
                  },
            text: 'Preview',
            icon: Icons.preview_outlined,
            backgroundColor: AppraisalConstants.warningColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            onPressed: provider.isSubmitting
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      provider.submitAppraisal(
                        apiService: widget.apiService,
                        employeeId: widget.user.employeeId ?? '',
                        companyId: widget.user.companyId,
                        onSubmit: widget.onSubmit,
                        context: context,
                      );
                    }
                  },
            text: provider.isSubmitting ? 'Submitting...' : 'Submit',
            icon: provider.isSubmitting ? Icons.hourglass_empty : Icons.send_outlined,
            backgroundColor: AppraisalConstants.primaryColor,
            isLoading: provider.isSubmitting,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required Color backgroundColor,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  void _showPreviewDialog(BuildContext context, SelfAppraisalProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppraisalConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.preview, color: AppraisalConstants.primaryColor, size: 24),
            const SizedBox(width: 8),
            Text('Appraisal Preview', style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppraisalConstants.textColor,
            )),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please review your appraisal before submitting:',
                  style: GoogleFonts.roboto(
                    color: AppraisalConstants.subtitleColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPreviewItem('Designation', provider.designation),
                _buildPreviewItem('Period Under Review', provider.periodUnderReview),
                _buildPreviewItem('Overall Rating', '${provider.overallRatingSelf.index} Stars'),
                const Divider(),
                Text(
                  'Note: All sections will be submitted for review.',
                  style: GoogleFonts.roboto(
                    color: AppraisalConstants.warningColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.roboto(
              color: AppraisalConstants.subtitleColor,
            )),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.submitAppraisal(
                apiService: widget.apiService,
                employeeId: widget.user.employeeId ?? '',
                companyId: widget.user.companyId,
                onSubmit: widget.onSubmit,
                context: context,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm Submit', style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppraisalConstants.textColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppraisalConstants.subtitleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for string formatting
extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }
}