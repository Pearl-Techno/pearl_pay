import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pearl_pay/models/user.dart';
import 'package:pearl_pay/services/services.dart';
import 'package:provider/provider.dart';

import '../widgets/custom_app_bar.dart';

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
      designation =
          employeePosition; // Initialize designation with employeePosition
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
      default:
        return '';
    }
  }

  void updateField<T>(String field, T value) {
    if (field == 'designation')
      designation = value as String;
    else if (field == 'periodUnderReview')
      periodUnderReview = value as String;
    else if (field == 'lastAppraisalDate')
      lastAppraisalDate = value as String;
    else if (field == 'dateOfJoining')
      dateOfJoining = value as String;
    else if (field == 'dateOfAppointment')
      dateOfAppointment = value as String;
    else if (field == 'appraiserName')
      appraiserName = value as String;
    else if (field == 'appraiserPosition')
      appraiserPosition = value as String;
    else if (field == 'awards')
      awards = value as String;
    else if (field == 'recommendations')
      recommendations = value as String;
    else if (field == 'trainingAttended')
      trainingAttended = value as String;
    else if (field == 'numberValidWarnings')
      numberValidWarnings = value as int;
    else if (field == 'absenteeDays')
      absenteeDays = value as int;
    else if (field == 'sickOffs')
      sickOffs = value as int;
    else if (field == 'complianceTraining')
      complianceTraining = value as bool;
    else if (field == 'internalControls')
      internalControls = value as bool;
    else if (field == 'careerObjectives')
      careerObjectives = value as String;
    else if (field == 'longTermObjectives')
      longTermObjectives = value as String;
    else if (field == 'jobTargets')
      jobTargets = value as String;
    else if (field == 'developmentNeeds')
      developmentNeeds = value as String;
    else if (field == 'workExposure')
      workExposure = value as String;
    else if (field == 'trainingRequired')
      trainingRequired = value as String;
    else if (field == 'promotionPossibilities')
      promotionPossibilities = value as String;
    else if (field == 'additionalResponsibilities')
      additionalResponsibilities = value as String;
    else if (field == 'overallRatingSelf')
      overallRatingSelf = value as StarRating;
    else if (field == 'overallRatingAppraiser')
      overallRatingAppraiser = value as StarRating;
    else if (field == 'appraiseeComments')
      appraiseeComments = value as String;
    else if (field == 'appraiserComments')
      appraiserComments = value as String;
    else if (field == 'generalManagerComments')
      generalManagerComments = value as String;
    else if (field == 'appraiseeSignature')
      appraiseeSignature = value as String;
    else if (field == 'appraiserSignature')
      appraiserSignature = value as String;
    else if (field == 'generalManagerSignature')
      generalManagerSignature = value as String;
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
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Success'),
          content: const Text('Employee appraisal submitted successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.teal)),
            ),
          ],
        ),
      );
      onSubmit();
      Navigator.pop(context);
    } catch (e) {
      errorMessage =
          e is Exception ? e.toString() : 'Failed to submit appraisal.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorMessage!), backgroundColor: Colors.red[700]),
      );
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}

class EmployeeAppraisalScreen extends StatelessWidget {
  final User user;
  final ApiService apiService;
  final VoidCallback onSubmit;
  final String employeeId;
  final String employeeName;
  final String employeePosition; // Added

  const EmployeeAppraisalScreen({
    super.key,
    required this.user,
    required this.apiService,
    required this.onSubmit,
    required this.employeeId,
    required this.employeeName,
    required this.employeePosition, // Added
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppraisalFormProvider(
          employeePosition: employeePosition), // Pass employeePosition
      child: _EmployeeAppraisalView(
        user: user,
        apiService: apiService,
        onSubmit: onSubmit,
        employeeId: employeeId,
        employeeName: employeeName,
        employeePosition: employeePosition, // Added
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
  final String employeePosition; // Added

  const _EmployeeAppraisalView({
    required this.user,
    required this.apiService,
    required this.onSubmit,
    required this.employeeId,
    required this.employeeName,
    required this.employeePosition, // Added
  });

  @override
  _EmployeeAppraisalViewState createState() => _EmployeeAppraisalViewState();
}

class _EmployeeAppraisalViewState extends State<_EmployeeAppraisalView>
    with SingleTickerProviderStateMixin {
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
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppraisalFormProvider>(context);

    return Scaffold(
      appBar: CustomAppBar(
        title:
            'Appraise ${widget.employeeName} (${widget.employeePosition})', // Updated to include position
        backgroundColor: Colors.teal[700],
        titleStyle: GoogleFonts.roboto(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.teal[50]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee: ${widget.employeeName}',
                        style: GoogleFonts.roboto(
                            fontSize: 18,
                            color: Colors.teal[900],
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Position: ${widget.employeePosition}',
                        style: GoogleFonts.roboto(
                            fontSize: 16, color: Colors.teal[700]),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Personal Details',
                        icon: Icons.person,
                        children: [
                          _buildTextField(
                              label: 'Designation',
                              value: provider.designation,
                              onChanged: (v) =>
                                  provider.updateField('designation', v)),
                          _buildTextField(
                              label: 'Period Under Review',
                              value: provider.periodUnderReview,
                              onChanged: (v) =>
                                  provider.updateField('periodUnderReview', v)),
                          _buildTextField(
                              label: 'Last Appraisal Date',
                              value: provider.lastAppraisalDate,
                              onChanged: (v) =>
                                  provider.updateField('lastAppraisalDate', v)),
                          _buildTextField(
                              label: 'Date of Joining',
                              value: provider.dateOfJoining,
                              onChanged: (v) =>
                                  provider.updateField('dateOfJoining', v)),
                          _buildTextField(
                              label: 'Date of Appointment',
                              value: provider.dateOfAppointment,
                              onChanged: (v) =>
                                  provider.updateField('dateOfAppointment', v)),
                          _buildTextField(
                              label: 'Appraiser Name',
                              value: provider.appraiserName,
                              onChanged: (v) =>
                                  provider.updateField('appraiserName', v)),
                          _buildTextField(
                              label: 'Appraiser Position',
                              value: provider.appraiserPosition,
                              onChanged: (v) =>
                                  provider.updateField('appraiserPosition', v)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Performance Record',
                        icon: Icons.assessment,
                        children: [
                          _buildTextField(
                              label: 'Awards',
                              value: provider.awards,
                              onChanged: (v) =>
                                  provider.updateField('awards', v)),
                          _buildTextField(
                              label: 'Recommendations',
                              value: provider.recommendations,
                              onChanged: (v) =>
                                  provider.updateField('recommendations', v)),
                          _buildTextField(
                              label: 'Training Attended',
                              value: provider.trainingAttended,
                              onChanged: (v) =>
                                  provider.updateField('trainingAttended', v)),
                          _buildNumberField(
                              label: 'Valid Warnings',
                              value: provider.numberValidWarnings,
                              onChanged: (v) => provider.updateField(
                                  'numberValidWarnings', v)),
                          _buildNumberField(
                              label: 'Absentee Days',
                              value: provider.absenteeDays,
                              onChanged: (v) =>
                                  provider.updateField('absenteeDays', v)),
                          _buildNumberField(
                              label: 'Sick Days',
                              value: provider.sickOffs,
                              onChanged: (v) =>
                                  provider.updateField('sickOffs', v)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Personal Attributes',
                        icon: Icons.person_outline,
                        children: provider.personalAttributes.entries
                            .map((entry) => _buildAttributeField(
                                  label: entry.key
                                      .replaceAll('_', ' ')
                                      .toTitleCase(),
                                  selfRating: entry.value['self'],
                                  appraiserRating: entry.value['appraiser'],
                                  comments: entry.value['comments'],
                                  onSelfRatingChanged: (v) => provider
                                      .updateAttribute(entry.key, 'self', v),
                                  onAppraiserRatingChanged: (v) =>
                                      provider.updateAttribute(
                                          entry.key, 'appraiser', v),
                                  onCommentsChanged: (v) =>
                                      provider.updateAttribute(
                                          entry.key, 'comments', v),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Operational Skills',
                        icon: Icons.work,
                        children: provider.operationalSkills.entries
                            .map((entry) => _buildAttributeField(
                                  label: entry.key
                                      .replaceAll('_', ' ')
                                      .toTitleCase(),
                                  selfRating: entry.value['self'],
                                  appraiserRating: entry.value['appraiser'],
                                  description: entry.value['description'],
                                  comments: entry.value['comments'],
                                  onSelfRatingChanged: (v) => provider
                                      .updateAttribute(entry.key, 'self', v,
                                          isPersonal: false),
                                  onAppraiserRatingChanged: (v) =>
                                      provider.updateAttribute(
                                          entry.key, 'appraiser', v,
                                          isPersonal: false),
                                  onDescriptionChanged:
                                      entry.key.startsWith('essential_function')
                                          ? (v) => provider.updateAttribute(
                                              entry.key, 'description', v,
                                              isPersonal: false)
                                          : null,
                                  onCommentsChanged: (v) => provider
                                      .updateAttribute(entry.key, 'comments', v,
                                          isPersonal: false),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Compliance',
                        icon: Icons.verified,
                        children: [
                          _buildSwitchField(
                            label: 'Current with Trainings',
                            value: provider.complianceTraining,
                            onChanged: (v) =>
                                provider.updateField('complianceTraining', v),
                          ),
                          _buildSwitchField(
                            label: 'Safeguards Assets',
                            value: provider.internalControls,
                            onChanged: (v) =>
                                provider.updateField('internalControls', v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Improvement Plan',
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
                                    onAreaChanged: (v) =>
                                        provider.updateImprovementPlan(
                                            entry.key, 'area', v),
                                    onActionChanged: (v) =>
                                        provider.updateImprovementPlan(
                                            entry.key, 'action', v),
                                    onGoalChanged: (v) =>
                                        provider.updateImprovementPlan(
                                            entry.key, 'goal', v),
                                    onTimingChanged: (v) =>
                                        provider.updateImprovementPlan(
                                            entry.key, 'timing', v),
                                  )),
                          TextButton.icon(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            label: const Text('Add Entry',
                                style: TextStyle(color: Colors.teal)),
                            onPressed: provider.addImprovementPlanEntry,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Career Development',
                        icon: Icons.school,
                        children: [
                          _buildTextField(
                              label: 'Career Objectives',
                              value: provider.careerObjectives,
                              onChanged: (v) =>
                                  provider.updateField('careerObjectives', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'Long-Term Objectives',
                              value: provider.longTermObjectives,
                              onChanged: (v) =>
                                  provider.updateField('longTermObjectives', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'Job Targets',
                              value: provider.jobTargets,
                              onChanged: (v) =>
                                  provider.updateField('jobTargets', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'Development Needs',
                              value: provider.developmentNeeds,
                              onChanged: (v) =>
                                  provider.updateField('developmentNeeds', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'Work Exposure',
                              value: provider.workExposure,
                              onChanged: (v) =>
                                  provider.updateField('workExposure', v),
                              maxLines: 3),
                          _buildTextField(
                              label: 'Training Required',
                              value: provider.trainingRequired,
                              onChanged: (v) =>
                                  provider.updateField('trainingRequired', v),
                              maxLines: 3),
                          _buildTextField(
                              label: 'Promotion Possibilities',
                              value: provider.promotionPossibilities,
                              onChanged: (v) => provider.updateField(
                                  'promotionPossibilities', v),
                              maxLines: 3),
                          _buildTextField(
                              label: 'Additional Responsibilities',
                              value: provider.additionalResponsibilities,
                              onChanged: (v) => provider.updateField(
                                  'additionalResponsibilities', v),
                              maxLines: 3),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Summary',
                        icon: Icons.summarize,
                        children: [
                          _buildStarRatingField(
                              label: 'Overall Rating (Self)',
                              value: provider.overallRatingSelf,
                              onChanged: (v) =>
                                  provider.updateField('overallRatingSelf', v)),
                          _buildStarRatingField(
                              label: 'Overall Rating (Appraiser)',
                              value: provider.overallRatingAppraiser,
                              onChanged: (v) => provider.updateField(
                                  'overallRatingAppraiser', v)),
                          _buildTextField(
                              label: 'Appraisee Comments',
                              value: provider.appraiseeComments,
                              onChanged: (v) =>
                                  provider.updateField('appraiseeComments', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'Appraiser Comments',
                              value: provider.appraiserComments,
                              onChanged: (v) =>
                                  provider.updateField('appraiserComments', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'General Manager Comments',
                              value: provider.generalManagerComments,
                              onChanged: (v) => provider.updateField(
                                  'generalManagerComments', v),
                              maxLines: 5),
                          _buildTextField(
                              label: 'Appraisee Signature',
                              value: provider.appraiseeSignature,
                              onChanged: (v) => provider.updateField(
                                  'appraiseeSignature', v)),
                          _buildTextField(
                              label: 'Appraiser Signature',
                              value: provider.appraiserSignature,
                              onChanged: (v) => provider.updateField(
                                  'appraiserSignature', v)),
                          _buildTextField(
                              label: 'General Manager Signature',
                              value: provider.generalManagerSignature,
                              onChanged: (v) => provider.updateField(
                                  'generalManagerSignature', v)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildActionButtons(context, provider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.teal.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.teal[700], size: 28),
        title: Text(
          title,
          style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.teal[800]),
        ),
        iconColor: Colors.teal[700],
        childrenPadding: const EdgeInsets.all(16),
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
          prefixIcon: Icon(Icons.edit, color: Colors.teal[700]),
          labelText: label,
          hintText: 'Enter $label',
          filled: true,
          fillColor: Colors.teal[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal[700]!, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red)),
          suffixIcon: value.isNotEmpty
              ? const Icon(Icons.check_circle, color: Colors.green)
              : null,
        ),
        validator: (v) => v == null || v.isEmpty ? '$label is required' : null,
        onChanged: onChanged,
        maxLines: maxLines,
        style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
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
          prefixIcon: Icon(Icons.numbers, color: Colors.teal[700]),
          labelText: label,
          hintText: 'Enter $label',
          filled: true,
          fillColor: Colors.teal[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal[700]!, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red)),
          suffixIcon: value > 0
              ? const Icon(Icons.check_circle, color: Colors.green)
              : null,
        ),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || int.tryParse(v) == null
            ? '$label must be a number'
            : null,
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
        style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
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
            style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.teal[800],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < value.index ? Icons.star : Icons.star_border,
                  color: Colors.amber[700],
                  size: 32,
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
              style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[900]),
            ),
            const SizedBox(height: 12),
            _buildStarRatingField(
                label: 'Self Rating',
                value: selfRating,
                onChanged: onSelfRatingChanged),
            _buildStarRatingField(
                label: 'Appraiser Rating',
                value: appraiserRating,
                onChanged: onAppraiserRatingChanged),
            if (onDescriptionChanged != null)
              _buildTextField(
                  label: 'Description',
                  value: description ?? '',
                  onChanged: onDescriptionChanged),
            if (onCommentsChanged != null)
              _buildTextField(
                  label: 'Comments',
                  value: comments ?? '',
                  onChanged: onCommentsChanged),
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
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[900]),
            ),
            const SizedBox(height: 8),
            _buildTextField(
                label: 'Area for Improvement',
                value: area,
                onChanged: onAreaChanged),
            _buildTextField(
                label: 'Action Plan',
                value: action,
                onChanged: onActionChanged),
            _buildTextField(
                label: 'Goal', value: goal, onChanged: onGoalChanged),
            _buildTextField(
                label: 'Timing', value: timing, onChanged: onTimingChanged),
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
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.teal[700], size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style:
                    GoogleFonts.roboto(fontSize: 16, color: Colors.teal[800]),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.teal[700],
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, AppraisalFormProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ScaleTransitionButton(
            onPressed: provider.isSubmitting
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      _buildPreviewDialog(context, provider);
                    }
                  },
            child: ElevatedButton(
              onPressed: provider.isSubmitting
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _buildPreviewDialog(context, provider);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.preview, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Preview',
                      style: GoogleFonts.roboto(
                          fontSize: 16, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ScaleTransitionButton(
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Submit',
                            style: GoogleFonts.roboto(
                                fontSize: 16, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ScaleTransitionButton(
            onPressed: provider.isSubmitting ? null : provider.clearForm,
            child: OutlinedButton(
              onPressed: provider.isSubmitting ? null : provider.clearForm,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red[700]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.clear, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Text('Clear',
                      style: GoogleFonts.roboto(
                          fontSize: 16, color: Colors.red[700])),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _buildPreviewDialog(
      BuildContext context, AppraisalFormProvider provider) {
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 5,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Text('Appraisal Preview',
                  style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal[900])),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  isScrollable: true,
                  indicatorColor: Colors.teal[700],
                  labelColor: Colors.teal[800],
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: GoogleFonts.roboto(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  tabs: [
                    const Tab(text: 'Personal'),
                    Tab(text: 'Performance'),
                    Tab(text: 'Attributes'),
                    Tab(text: 'Plans'),
                    Tab(text: 'Summary'),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: 400,
            child: TabBarView(
              children: [
                _buildPreviewSection('Personal Details', [
                  _buildPreviewItem('Designation', provider.designation),
                  _buildPreviewItem(
                      'Period Under Review', provider.periodUnderReview),
                  _buildPreviewItem(
                      'Last Appraisal', provider.lastAppraisalDate),
                  _buildPreviewItem('Date of Joining', provider.dateOfJoining),
                  _buildPreviewItem(
                      'Date of Appointment', provider.dateOfAppointment),
                  _buildPreviewItem('Appraiser Name', provider.appraiserName),
                  _buildPreviewItem(
                      'Appraiser Position', provider.appraiserPosition),
                ]),
                _buildPreviewSection('Performance Record', [
                  _buildPreviewItem('Awards', provider.awards),
                  _buildPreviewItem(
                      'Recommendations', provider.recommendations),
                  _buildPreviewItem(
                      'Training Attended', provider.trainingAttended),
                  _buildPreviewItem('Valid Warnings',
                      provider.numberValidWarnings.toString()),
                  _buildPreviewItem(
                      'Absentee Days', provider.absenteeDays.toString()),
                  _buildPreviewItem('Sick Days', provider.sickOffs.toString()),
                ]),
                _buildPreviewSection('Attributes', [
                  ...provider.personalAttributes.entries
                      .map((entry) => [
                            _buildPreviewItem(
                                '${entry.key.replaceAll('_', ' ').toTitleCase()} (Self)',
                                '${entry.value['self'].index} Stars'),
                            _buildPreviewItem(
                                '${entry.key.replaceAll('_', ' ').toTitleCase()} (Appraiser)',
                                '${entry.value['appraiser'].index} Stars'),
                            _buildPreviewItem(
                                '${entry.key.replaceAll('_', ' ').toTitleCase()} Comments',
                                entry.value['comments']),
                          ])
                      .expand((e) => e),
                  ...provider.operationalSkills.entries
                      .map((entry) => [
                            _buildPreviewItem(
                                '${entry.key.replaceAll('_', ' ').toTitleCase()} (Self)',
                                '${entry.value['self'].index} Stars'),
                            _buildPreviewItem(
                                '${entry.key.replaceAll('_', ' ').toTitleCase()} (Appraiser)',
                                '${entry.value['appraiser'].index} Stars'),
                            if (entry.key.startsWith('essential_function'))
                              _buildPreviewItem(
                                  '${entry.key.replaceAll('_', ' ').toTitleCase()} Description',
                                  entry.value['description']),
                            _buildPreviewItem(
                                '${entry.key.replaceAll('_', ' ').toTitleCase()} Comments',
                                entry.value['comments']),
                          ])
                      .expand((e) => e),
                  _buildPreviewItem('Compliance Training',
                      provider.complianceTraining ? 'Yes' : 'No'),
                  _buildPreviewItem('Internal Controls',
                      provider.internalControls ? 'Yes' : 'No'),
                ]),
                _buildPreviewSection('Plans', [
                  ...provider.improvementPlan
                      .asMap()
                      .entries
                      .map((entry) => [
                            _buildPreviewItem('Entry ${entry.key + 1}: Area',
                                entry.value['area']!),
                            _buildPreviewItem('Entry ${entry.key + 1}: Action',
                                entry.value['action']!),
                            _buildPreviewItem('Entry ${entry.key + 1}: Goal',
                                entry.value['goal']!),
                            _buildPreviewItem('Entry ${entry.key + 1}: Timing',
                                entry.value['timing']!),
                          ])
                      .expand((e) => e),
                  _buildPreviewItem(
                      'Career Objectives', provider.careerObjectives),
                  _buildPreviewItem(
                      'Long-Term Objectives', provider.longTermObjectives),
                  _buildPreviewItem('Job Targets', provider.jobTargets),
                  _buildPreviewItem(
                      'Development Needs', provider.developmentNeeds),
                  _buildPreviewItem('Work Exposure', provider.workExposure),
                  _buildPreviewItem(
                      'Training Required', provider.trainingRequired),
                  _buildPreviewItem('Promotion Possibilities',
                      provider.promotionPossibilities),
                  _buildPreviewItem('Additional Responsibilities',
                      provider.additionalResponsibilities),
                ]),
                _buildPreviewSection('Summary', [
                  _buildPreviewItem('Overall Rating (Self)',
                      '${provider.overallRatingSelf.index} Stars'),
                  _buildPreviewItem('Overall Rating (Appraiser)',
                      '${provider.overallRatingAppraiser.index} Stars'),
                  _buildPreviewItem(
                      'Appraisee Comments', provider.appraiseeComments),
                  _buildPreviewItem(
                      'Appraiser Comments', provider.appraiserComments),
                  _buildPreviewItem('General Manager Comments',
                      provider.generalManagerComments),
                  _buildPreviewItem(
                      'Appraisee Signature', provider.appraiseeSignature),
                  _buildPreviewItem(
                      'Appraiser Signature', provider.appraiserSignature),
                  _buildPreviewItem('General Manager Signature',
                      provider.generalManagerSignature),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.roboto(color: Colors.grey[600])),
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
                backgroundColor: Colors.teal[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Submit',
                  style: GoogleFonts.roboto(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(String title, List<Widget> items) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              title,
              style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[800]),
            ),
          ),
          ...items,
          const Divider(),
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
                  color: Colors.teal[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom widget for scale transition button
class ScaleTransitionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const ScaleTransitionButton(
      {super.key, required this.onPressed, required this.child});

  @override
  _ScaleTransitionButtonState createState() => _ScaleTransitionButtonState();
}

class _ScaleTransitionButtonState extends State<ScaleTransitionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.onPressed != null) widget.onPressed!();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
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
