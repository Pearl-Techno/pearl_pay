import 'package:flutter/material.dart';
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:provider/provider.dart';

import '../widgets/custom_app_bar.dart';

// Constants - Using same colors as other screens
class AppraisalFormConstants {
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

class AppraisalFormProvider with ChangeNotifier {
  // A. Personal Details
  String designation = '';
  String periodUnderReview = '';
  String lastAppraisalDate = '';
  String dateOfJoining = '';
  String dateOfAppointment = '';
  String appraiserName = '';
  String appraiserPosition = '';

  // E. Employee Performance Record
  String awards = '';
  String recommendations = '';
  String trainingAttended = '';
  int numberValidWarnings = 0;
  int absenteeDays = 0;
  int sickOffs = 0;

  // F. Personal Attributes (Self and Appraiser Ratings)
  Map<String, Map<String, dynamic>> personalAttributes = {
    'drive_and_enthusiasm': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'punctuality_attendance': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'self_presentation_grooming': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'adaptability': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'creativity': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'integrity': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'attitude_towards_work': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'attitude_towards_colleagues': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'ability_to_take_criticism': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'verbal_communication': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'written_communication': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'listening_responsiveness': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
  };

  // G. Operational Skills Attributes (Self and Appraiser Ratings)
  Map<String, Map<String, dynamic>> operationalSkills = {
    'essential_function_3': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'description': ''
    },
    'essential_function_4': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'description': ''
    },
    'thoroughness': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'initiative': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'productivity': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'job_knowledge': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'job_interest': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'care_of_equipment': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'consistency': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'sales_awareness': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'cost_awareness': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'customer_care': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'planning': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'teamwork': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
    'accuracy': {
      'self': StarRating.none,
      'appraiser': StarRating.none,
      'comments': ''
    },
  };

  // H. Performance Improvement Plan
  List<Map<String, String>> improvementPlan = [
    {'area': '', 'action': '', 'goal': '', 'timing': ''},
  ];

  // I. Career Development Plan
  String careerObjectives = '';
  String longTermObjectives = '';
  String jobTargets = '';
  String developmentNeeds = '';
  String workExposure = '';
  String trainingRequired = '';
  String promotionPossibilities = '';
  String additionalResponsibilities = '';

  // J. Summary
  StarRating overallRatingSelf = StarRating.none;
  StarRating overallRatingAppraiser = StarRating.none;
  String appraiseeComments = '';
  String appraiserComments = '';
  String generalManagerComments = '';
  String appraiseeSignature = '';
  String appraiserSignature = '';
  String generalManagerSignature = '';

  // Compliance Questions
  bool complianceTraining = false;
  bool internalControls = false;

  bool isSubmitting = false;
  String? errorMessage;

  AppraisalFormProvider({String? employeePosition}) {
    if (employeePosition != null && employeePosition.isNotEmpty) {
      designation = employeePosition;
    }
  }

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
    if (field == 'designation') {
      designation = value as String;
    } else if (field == 'periodUnderReview') {
      periodUnderReview = value as String;
    } else if (field == 'lastAppraisalDate') {
      lastAppraisalDate = value as String;
    } else if (field == 'dateOfJoining') {
      dateOfJoining = value as String;
    } else if (field == 'dateOfAppointment') {
      dateOfAppointment = value as String;
    } else if (field == 'appraiserName') {
      appraiserName = value as String;
    } else if (field == 'appraiserPosition') {
      appraiserPosition = value as String;
    } else if (field == 'awards') {
      awards = value as String;
    } else if (field == 'recommendations') {
      recommendations = value as String;
    } else if (field == 'trainingAttended') {
      trainingAttended = value as String;
    } else if (field == 'numberValidWarnings') {
      numberValidWarnings = value as int;
    } else if (field == 'absenteeDays') {
      absenteeDays = value as int;
    } else if (field == 'sickOffs') {
      sickOffs = value as int;
    } else if (field == 'complianceTraining') {
      complianceTraining = value as bool;
    } else if (field == 'internalControls') {
      internalControls = value as bool;
    } else if (field == 'careerObjectives') {
      careerObjectives = value as String;
    } else if (field == 'longTermObjectives') {
      longTermObjectives = value as String;
    } else if (field == 'jobTargets') {
      jobTargets = value as String;
    } else if (field == 'developmentNeeds') {
      developmentNeeds = value as String;
    } else if (field == 'workExposure') {
      workExposure = value as String;
    } else if (field == 'trainingRequired') {
      trainingRequired = value as String;
    } else if (field == 'promotionPossibilities') {
      promotionPossibilities = value as String;
    } else if (field == 'additionalResponsibilities') {
      additionalResponsibilities = value as String;
    } else if (field == 'overallRatingSelf') {
      overallRatingSelf = value as StarRating;
    } else if (field == 'overallRatingAppraiser') {
      overallRatingAppraiser = value as StarRating;
    } else if (field == 'appraiseeComments') {
      appraiseeComments = value as String;
    } else if (field == 'appraiserComments') {
      appraiserComments = value as String;
    } else if (field == 'generalManagerComments') {
      generalManagerComments = value as String;
    } else if (field == 'appraiseeSignature') {
      appraiseeSignature = value as String;
    } else if (field == 'appraiserSignature') {
      appraiserSignature = value as String;
    } else if (field == 'generalManagerSignature') {
      generalManagerSignature = value as String;
    }
    notifyListeners();
  }

  void updateAttribute(String attribute, String key, dynamic value,
      {bool isPersonal = true}) {
    final target = isPersonal ? personalAttributes : operationalSkills;
    if (target.containsKey(attribute)) {
      target[attribute]![key] = value;
      notifyListeners();
    }
  }

  void addImprovementPlanEntry() {
    improvementPlan.add({'area': '', 'action': '', 'goal': '', 'timing': ''});
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
    lastAppraisalDate = '';
    dateOfJoining = '';
    dateOfAppointment = '';
    appraiserName = '';
    appraiserPosition = '';
    awards = '';
    recommendations = '';
    trainingAttended = '';
    numberValidWarnings = 0;
    absenteeDays = 0;
    sickOffs = 0;
    personalAttributes.forEach((_, attr) {
      attr['self'] = StarRating.none;
      attr['appraiser'] = StarRating.none;
      attr['comments'] = '';
    });
    operationalSkills.forEach((_, attr) {
      attr['self'] = StarRating.none;
      attr['appraiser'] = StarRating.none;
      attr['description'] = '';
      attr['comments'] = '';
    });
    improvementPlan = [
      {'area': '', 'action': '', 'goal': '', 'timing': ''}
    ];
    careerObjectives = '';
    longTermObjectives = '';
    jobTargets = '';
    developmentNeeds = '';
    workExposure = '';
    trainingRequired = '';
    promotionPossibilities = '';
    additionalResponsibilities = '';
    overallRatingSelf = StarRating.none;
    overallRatingAppraiser = StarRating.none;
    appraiseeComments = '';
    appraiserComments = '';
    generalManagerComments = '';
    appraiseeSignature = '';
    appraiserSignature = '';
    generalManagerSignature = '';
    complianceTraining = false;
    internalControls = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> submitAppraisal({
    required ApiService apiService,
    required String employeeId,
    required String companyId,
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
        'last_appraisal_date': lastAppraisalDate,
        'date_of_joining': dateOfJoining,
        'date_of_appointment': dateOfAppointment,
        'appraiser_name': appraiserName,
        'appraiser_position': appraiserPosition,
        'awards': awards,
        'recommendations': recommendations,
        'training_attended': trainingAttended,
        'number_valid_warnings': numberValidWarnings,
        'absentee_days': absenteeDays,
        'sick_offs': sickOffs,
        'personal_attributes':
            personalAttributes.map((key, value) => MapEntry(key, {
                  'self_rating': _mapStarToLetter(value['self']),
                  'appraiser_rating': _mapStarToLetter(value['appraiser']),
                  'comments': value['comments'],
                })),
        'operational_skills':
            operationalSkills.map((key, value) => MapEntry(key, {
                  'self_rating': _mapStarToLetter(value['self']),
                  'appraiser_rating': _mapStarToLetter(value['appraiser']),
                  'description': value['description'] ?? '',
                  'comments': value['comments'] ?? '',
                })),
        'improvement_plan': improvementPlan,
        'career_objectives': careerObjectives,
        'long_term_objectives': longTermObjectives,
        'job_targets': jobTargets,
        'development_needs': developmentNeeds,
        'work_exposure': workExposure,
        'training_required': trainingRequired,
        'promotion_possibilities': promotionPossibilities,
        'additional_responsibilities': additionalResponsibilities,
        'overall_rating_self': _mapStarToLetter(overallRatingSelf),
        'overall_rating_appraiser': _mapStarToLetter(overallRatingAppraiser),
        'appraisee_comments': appraiseeComments,
        'appraiser_comments': appraiserComments,
        'general_manager_comments': generalManagerComments,
        'appraisee_signature': appraiseeSignature,
        'appraiser_signature': appraiserSignature,
        'general_manager_signature': generalManagerSignature,
        'compliance_training': complianceTraining ? '1' : '0',
        'internal_controls': internalControls ? '1' : '0',
      };
      await apiService.submitEmployeeAppraisal(
        employeeId: employeeId,
        companyId: int.parse(companyId),
        data: data,
      );
      if (!context.mounted) return;
      _showSuccessSnackBar(context, 'Employee appraisal submitted successfully!');
      onSubmit();
      Navigator.pop(context);
    } catch (e) {
      errorMessage = e is Exception ? e.toString() : 'Failed to submit appraisal.';
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage!);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppraisalFormConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppraisalFormConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class EmployeeAppraisalScreen extends StatelessWidget {
  final User user;
  final ApiService apiService;
  final VoidCallback onSubmit;
  final String employeeId;
  final String employeeName;
  final String employeePosition;

  const EmployeeAppraisalScreen({
    super.key,
    required this.user,
    required this.apiService,
    required this.onSubmit,
    required this.employeeId,
    required this.employeeName,
    required this.employeePosition,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppraisalFormProvider(employeePosition: employeePosition),
      child: _EmployeeAppraisalView(
        user: user,
        apiService: apiService,
        onSubmit: onSubmit,
        employeeId: employeeId,
        employeeName: employeeName,
        employeePosition: employeePosition,
      ),
    );
  }
}

class _EmployeeAppraisalView extends StatefulWidget {
  final User user;
  final ApiService apiService;
  final VoidCallback onSubmit;
  final String employeeId;
  final String employeeName;
  final String employeePosition;

  const _EmployeeAppraisalView({
    required this.user,
    required this.apiService,
    required this.onSubmit,
    required this.employeeId,
    required this.employeeName,
    required this.employeePosition,
  });

  @override
  _EmployeeAppraisalViewState createState() => _EmployeeAppraisalViewState();
}

class _EmployeeAppraisalViewState extends State<_EmployeeAppraisalView> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, bool> _sectionExpanded = {
    'personal': true,
    'performance': true,
    'attributes': true,
    'skills': true,
    'compliance': true,
    'improvement': true,
    'career': true,
    'summary': true,
  };

  void _toggleSection(String section) {
    setState(() {
      _sectionExpanded[section] = !_sectionExpanded[section]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppraisalFormProvider>(context);

    return Scaffold(
      backgroundColor: AppraisalFormConstants.backgroundColor,
      appBar: CustomAppBar(
        title: 'Appraise ${widget.employeeName}',
        backgroundColor: AppraisalFormConstants.primaryColor,
      ),
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),
          
          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Personal Details',
                        sectionKey: 'personal',
                        icon: Icons.person,
                        children: [
                          _buildTextField(
                            label: 'Designation',
                            value: provider.designation,
                            onChanged: (v) => provider.updateField('designation', v),
                          ),
                          _buildTextField(
                            label: 'Period Under Review',
                            value: provider.periodUnderReview,
                            onChanged: (v) => provider.updateField('periodUnderReview', v),
                          ),
                          _buildTextField(
                            label: 'Last Appraisal Date',
                            value: provider.lastAppraisalDate,
                            onChanged: (v) => provider.updateField('lastAppraisalDate', v),
                          ),
                          _buildTextField(
                            label: 'Date of Joining',
                            value: provider.dateOfJoining,
                            onChanged: (v) => provider.updateField('dateOfJoining', v),
                          ),
                          _buildTextField(
                            label: 'Date of Appointment',
                            value: provider.dateOfAppointment,
                            onChanged: (v) => provider.updateField('dateOfAppointment', v),
                          ),
                          _buildTextField(
                            label: 'Appraiser Name',
                            value: provider.appraiserName,
                            onChanged: (v) => provider.updateField('appraiserName', v),
                          ),
                          _buildTextField(
                            label: 'Appraiser Position',
                            value: provider.appraiserPosition,
                            onChanged: (v) => provider.updateField('appraiserPosition', v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Performance Record',
                        sectionKey: 'performance',
                        icon: Icons.assessment,
                        children: [
                          _buildTextField(
                            label: 'Awards',
                            value: provider.awards,
                            onChanged: (v) => provider.updateField('awards', v),
                          ),
                          _buildTextField(
                            label: 'Recommendations',
                            value: provider.recommendations,
                            onChanged: (v) => provider.updateField('recommendations', v),
                          ),
                          _buildTextField(
                            label: 'Training Attended',
                            value: provider.trainingAttended,
                            onChanged: (v) => provider.updateField('trainingAttended', v),
                          ),
                          _buildNumberField(
                            label: 'Valid Warnings',
                            value: provider.numberValidWarnings,
                            onChanged: (v) => provider.updateField('numberValidWarnings', v),
                          ),
                          _buildNumberField(
                            label: 'Absentee Days',
                            value: provider.absenteeDays,
                            onChanged: (v) => provider.updateField('absenteeDays', v),
                          ),
                          _buildNumberField(
                            label: 'Sick Days',
                            value: provider.sickOffs,
                            onChanged: (v) => provider.updateField('sickOffs', v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Personal Attributes',
                        sectionKey: 'attributes',
                        icon: Icons.person_outline,
                        children: provider.personalAttributes.entries
                            .map((entry) => _buildAttributeField(
                                  label: entry.key.replaceAll('_', ' ').toTitleCase(),
                                  selfRating: entry.value['self'],
                                  appraiserRating: entry.value['appraiser'],
                                  comments: entry.value['comments'],
                                  onSelfRatingChanged: (v) => provider.updateAttribute(entry.key, 'self', v),
                                  onAppraiserRatingChanged: (v) => provider.updateAttribute(entry.key, 'appraiser', v),
                                  onCommentsChanged: (v) => provider.updateAttribute(entry.key, 'comments', v),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Operational Skills',
                        sectionKey: 'skills',
                        icon: Icons.work,
                        children: provider.operationalSkills.entries
                            .map((entry) => _buildAttributeField(
                                  label: entry.key.replaceAll('_', ' ').toTitleCase(),
                                  selfRating: entry.value['self'],
                                  appraiserRating: entry.value['appraiser'],
                                  description: entry.value['description'],
                                  comments: entry.value['comments'],
                                  onSelfRatingChanged: (v) => provider.updateAttribute(entry.key, 'self', v, isPersonal: false),
                                  onAppraiserRatingChanged: (v) => provider.updateAttribute(entry.key, 'appraiser', v, isPersonal: false),
                                  onDescriptionChanged: entry.key.startsWith('essential_function')
                                      ? (v) => provider.updateAttribute(entry.key, 'description', v, isPersonal: false)
                                      : null,
                                  onCommentsChanged: (v) => provider.updateAttribute(entry.key, 'comments', v, isPersonal: false),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Compliance',
                        sectionKey: 'compliance',
                        icon: Icons.verified,
                        children: [
                          _buildSwitchField(
                            label: 'Current with Trainings',
                            value: provider.complianceTraining,
                            onChanged: (v) => provider.updateField('complianceTraining', v),
                          ),
                          _buildSwitchField(
                            label: 'Safeguards Assets',
                            value: provider.internalControls,
                            onChanged: (v) => provider.updateField('internalControls', v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Improvement Plan',
                        sectionKey: 'improvement',
                        icon: Icons.trending_up,
                        children: [
                          ...provider.improvementPlan
                              .asMap()
                              .entries
                              .map((entry) => _buildImprovementPlanEntry(
                                    index: entry.key,
                                    area: entry.value['area']!,
                                    action: entry.value['action']!,
                                    goal: entry.value['goal']!,
                                    timing: entry.value['timing']!,
                                    onAreaChanged: (v) => provider.updateImprovementPlan(entry.key, 'area', v),
                                    onActionChanged: (v) => provider.updateImprovementPlan(entry.key, 'action', v),
                                    onGoalChanged: (v) => provider.updateImprovementPlan(entry.key, 'goal', v),
                                    onTimingChanged: (v) => provider.updateImprovementPlan(entry.key, 'timing', v),
                                  )),
                          _buildAddButton(
                            onPressed: provider.addImprovementPlanEntry,
                            label: 'Add Improvement Entry',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Career Development',
                        sectionKey: 'career',
                        icon: Icons.school,
                        children: [
                          _buildTextField(
                            label: 'Career Objectives',
                            value: provider.careerObjectives,
                            onChanged: (v) => provider.updateField('careerObjectives', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'Long-Term Objectives',
                            value: provider.longTermObjectives,
                            onChanged: (v) => provider.updateField('longTermObjectives', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'Job Targets',
                            value: provider.jobTargets,
                            onChanged: (v) => provider.updateField('jobTargets', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'Development Needs',
                            value: provider.developmentNeeds,
                            onChanged: (v) => provider.updateField('developmentNeeds', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'Work Exposure',
                            value: provider.workExposure,
                            onChanged: (v) => provider.updateField('workExposure', v),
                            maxLines: 3,
                          ),
                          _buildTextField(
                            label: 'Training Required',
                            value: provider.trainingRequired,
                            onChanged: (v) => provider.updateField('trainingRequired', v),
                            maxLines: 3,
                          ),
                          _buildTextField(
                            label: 'Promotion Possibilities',
                            value: provider.promotionPossibilities,
                            onChanged: (v) => provider.updateField('promotionPossibilities', v),
                            maxLines: 3,
                          ),
                          _buildTextField(
                            label: 'Additional Responsibilities',
                            value: provider.additionalResponsibilities,
                            onChanged: (v) => provider.updateField('additionalResponsibilities', v),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Summary',
                        sectionKey: 'summary',
                        icon: Icons.summarize,
                        children: [
                          _buildStarRatingField(
                            label: 'Overall Rating (Self)',
                            value: provider.overallRatingSelf,
                            onChanged: (v) => provider.updateField('overallRatingSelf', v),
                          ),
                          _buildStarRatingField(
                            label: 'Overall Rating (Appraiser)',
                            value: provider.overallRatingAppraiser,
                            onChanged: (v) => provider.updateField('overallRatingAppraiser', v),
                          ),
                          _buildTextField(
                            label: 'Appraisee Comments',
                            value: provider.appraiseeComments,
                            onChanged: (v) => provider.updateField('appraiseeComments', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'Appraiser Comments',
                            value: provider.appraiserComments,
                            onChanged: (v) => provider.updateField('appraiserComments', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'General Manager Comments',
                            value: provider.generalManagerComments,
                            onChanged: (v) => provider.updateField('generalManagerComments', v),
                            maxLines: 5,
                          ),
                          _buildTextField(
                            label: 'Appraisee Signature',
                            value: provider.appraiseeSignature,
                            onChanged: (v) => provider.updateField('appraiseeSignature', v),
                          ),
                          _buildTextField(
                            label: 'Appraiser Signature',
                            value: provider.appraiserSignature,
                            onChanged: (v) => provider.updateField('appraiserSignature', v),
                          ),
                          _buildTextField(
                            label: 'General Manager Signature',
                            value: provider.generalManagerSignature,
                            onChanged: (v) => provider.updateField('generalManagerSignature', v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildActionButtons(context, provider),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppraisalFormConstants.primaryColor, AppraisalFormConstants.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
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
                  child: Icon(
                    Icons.assessment,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Appraisal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Appraising ${widget.employeeName} - ${widget.employeePosition}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String sectionKey,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: AppraisalFormConstants.primaryColor, size: 24),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppraisalFormConstants.textColor,
          ),
        ),
        iconColor: AppraisalFormConstants.primaryColor,
        collapsedIconColor: AppraisalFormConstants.primaryColor,
        childrenPadding: const EdgeInsets.all(16),
        initiallyExpanded: _sectionExpanded[sectionKey]!,
        onExpansionChanged: (expanded) => _toggleSection(sectionKey),
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          filled: true,
          fillColor: AppraisalFormConstants.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppraisalFormConstants.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          suffixIcon: value.isNotEmpty
              ? Icon(Icons.check_circle, color: AppraisalFormConstants.successColor)
              : null,
        ),
        validator: (v) => v == null || v.isEmpty ? '$label is required' : null,
        onChanged: onChanged,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 14,
          color: AppraisalFormConstants.textColor,
        ),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          filled: true,
          fillColor: AppraisalFormConstants.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppraisalFormConstants.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          suffixIcon: value > 0
              ? Icon(Icons.check_circle, color: AppraisalFormConstants.successColor)
              : null,
        ),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || int.tryParse(v) == null
            ? '$label must be a number'
            : null,
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
        style: TextStyle(
          fontSize: 14,
          color: AppraisalFormConstants.textColor,
        ),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildStarRatingField({
    required String label,
    required StarRating value,
    required Function(StarRating) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppraisalFormConstants.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < value.index ? Icons.star : Icons.star_border,
                  color: Colors.amber[700],
                  size: 28,
                ),
                onPressed: () => onChanged(StarRating.values[index + 1]),
                tooltip: '${index + 1} Star${index == 0 ? '' : 's'}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeField({
    required String label,
    required StarRating selfRating,
    required StarRating appraiserRating,
    String? description,
    String? comments,
    required Function(StarRating) onSelfRatingChanged,
    required Function(StarRating) onAppraiserRatingChanged,
    Function(String)? onDescriptionChanged,
    Function(String)? onCommentsChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppraisalFormConstants.textColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildStarRatingField(
              label: 'Self Rating',
              value: selfRating,
              onChanged: onSelfRatingChanged,
            ),
            _buildStarRatingField(
              label: 'Appraiser Rating',
              value: appraiserRating,
              onChanged: onAppraiserRatingChanged,
            ),
            if (onDescriptionChanged != null)
              _buildTextField(
                label: 'Description',
                value: description ?? '',
                onChanged: onDescriptionChanged,
              ),
            if (onCommentsChanged != null)
              _buildTextField(
                label: 'Comments',
                value: comments ?? '',
                onChanged: onCommentsChanged,
              ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entry ${index + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppraisalFormConstants.textColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              label: 'Area for Improvement',
              value: area,
              onChanged: onAreaChanged,
            ),
            _buildTextField(
              label: 'Action Plan',
              value: action,
              onChanged: onActionChanged,
            ),
            _buildTextField(
              label: 'Goal',
              value: goal,
              onChanged: onGoalChanged,
            ),
            _buildTextField(
              label: 'Timing',
              value: timing,
              onChanged: onTimingChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppraisalFormConstants.textColor,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppraisalFormConstants.primaryColor,
            activeTrackColor: AppraisalFormConstants.primaryColor.withAlpha(128),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppraisalFormConstants.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppraisalFormConstants.primaryColor.withAlpha(77)),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add, color: AppraisalFormConstants.primaryColor),
        label: Text(
          label,
          style: TextStyle(color: AppraisalFormConstants.primaryColor),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppraisalFormProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: provider.isSubmitting
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      _showPreviewDialog(context, provider);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalFormConstants.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.preview, size: 20),
                const SizedBox(width: 8),
                Text('Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalFormConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: provider.isSubmitting
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      provider.submitAppraisal(
                        apiService: widget.apiService,
                        employeeId: widget.employeeId,
                        companyId: widget.user.companyId.toString(),
                        onSubmit: widget.onSubmit,
                        context: context,
                      );
                    }
                  },
            child: provider.isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, size: 20),
                      const SizedBox(width: 8),
                      Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: provider.isSubmitting ? null : provider.clearForm,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppraisalFormConstants.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.clear, color: AppraisalFormConstants.errorColor),
                const SizedBox(width: 8),
                Text('Clear', style: TextStyle(fontSize: 16, color: AppraisalFormConstants.errorColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPreviewDialog(BuildContext context, AppraisalFormProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppraisalFormConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Appraisal Preview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppraisalFormConstants.textColor,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee: ${widget.employeeName}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppraisalFormConstants.textColor),
                ),
                Text(
                  'Position: ${widget.employeePosition}',
                  style: TextStyle(fontSize: 14, color: AppraisalFormConstants.subtitleColor),
                ),
                const SizedBox(height: 16),
                _buildPreviewItem('Designation', provider.designation),
                _buildPreviewItem('Period Under Review', provider.periodUnderReview),
                _buildPreviewItem('Overall Rating', '${provider.overallRatingSelf.index} Stars'),
                _buildPreviewItem('Career Objectives', provider.careerObjectives),
                _buildPreviewItem('Appraiser Comments', provider.appraiserComments),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppraisalFormConstants.subtitleColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.submitAppraisal(
                apiService: widget.apiService,
                employeeId: widget.employeeId,
                companyId: widget.user.companyId.toString(),
                onSubmit: widget.onSubmit,
                context: context,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppraisalFormConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Submit',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppraisalFormConstants.textColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: TextStyle(fontSize: 14, color: AppraisalFormConstants.subtitleColor),
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
    return split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}