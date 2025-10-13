class Appraisal {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? managerId;
  final String? operatorId;
  final String? directorId;
  final String period;
  final String status;
  final String? essentialFunction3;
  final int? essentialFunction3Rating;
  final String? essentialFunction4;
  final int? essentialFunction4Rating;
  final String? jobKnowledge;
  final int? jobKnowledgeRating;
  final String? problemSolving;
  final int? problemSolvingRating;
  final String? serviceExcellence;
  final int? serviceExcellenceRating;
  final String? communication;
  final int? communicationRating;
  final String? teamwork;
  final int? teamworkRating;
  final bool? complianceTraining;
  final bool? punctuality;
  final bool? internalControls;
  final bool? professionalism;
  final String? developmentPlan;
  final String? additionalComments;

  Appraisal({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.managerId,
    this.operatorId,
    this.directorId,
    required this.period,
    required this.status,
    this.essentialFunction3,
    this.essentialFunction3Rating,
    this.essentialFunction4,
    this.essentialFunction4Rating,
    this.jobKnowledge,
    this.jobKnowledgeRating,
    this.problemSolving,
    this.problemSolvingRating,
    this.serviceExcellence,
    this.serviceExcellenceRating,
    this.communication,
    this.communicationRating,
    this.teamwork,
    this.teamworkRating,
    this.complianceTraining,
    this.punctuality,
    this.internalControls,
    this.professionalism,
    this.developmentPlan,
    this.additionalComments,
  });

  factory Appraisal.fromMap(Map<String, dynamic> map) {
    return Appraisal(
      id: map['appraisal_id'] ?? map['id'],
      employeeId: map['employee_id'],
      employeeName: map['employee_name'],
      managerId: map['manager_id'],
      operatorId: map['operator_id'],
      directorId: map['director_id'],
      period: map['period'],
      status: map['status'],
      essentialFunction3: map['essential_function_3'],
      essentialFunction3Rating: map['essential_function_3_rating'] != null
          ? int.parse(map['essential_function_3_rating'].toString())
          : null,
      essentialFunction4: map['essential_function_4'],
      essentialFunction4Rating: map['essential_function_4_rating'] != null
          ? int.parse(map['essential_function_4_rating'].toString())
          : null,
      jobKnowledge: map['job_knowledge'],
      jobKnowledgeRating: map['job_knowledge_rating'] != null
          ? int.parse(map['job_knowledge_rating'].toString())
          : null,
      problemSolving: map['problem_solving'],
      problemSolvingRating: map['problem_solving_rating'] != null
          ? int.parse(map['problem_solving_rating'].toString())
          : null,
      serviceExcellence: map['service_excellence'],
      serviceExcellenceRating: map['service_excellence_rating'] != null
          ? int.parse(map['service_excellence_rating'].toString())
          : null,
      communication: map['communication'],
      communicationRating: map['communication_rating'] != null
          ? int.parse(map['communication_rating'].toString())
          : null,
      teamwork: map['teamwork'],
      teamworkRating: map['teamwork_rating'] != null
          ? int.parse(map['teamwork_rating'].toString())
          : null,
      complianceTraining: map['compliance_training'] == '1' ||
          map['compliance_training'] == true,
      punctuality: map['punctuality'] == '1' || map['punctuality'] == true,
      internalControls:
          map['internal_controls'] == '1' || map['internal_controls'] == true,
      professionalism:
          map['professionalism'] == '1' || map['professionalism'] == true,
      developmentPlan: map['development_plan'],
      additionalComments: map['additional_comments'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appraisal_id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'manager_id': managerId,
      'operator_id': operatorId,
      'director_id': directorId,
      'period': period,
      'status': status,
      'essential_function_3': essentialFunction3,
      'essential_function_3_rating': essentialFunction3Rating,
      'essential_function_4': essentialFunction4,
      'essential_function_4_rating': essentialFunction4Rating,
      'job_knowledge': jobKnowledge,
      'job_knowledge_rating': jobKnowledgeRating,
      'problem_solving': problemSolving,
      'problem_solving_rating': problemSolvingRating,
      'service_excellence': serviceExcellence,
      'service_excellence_rating': serviceExcellenceRating,
      'communication': communication,
      'communication_rating': communicationRating,
      'teamwork': teamwork,
      'teamwork_rating': teamworkRating,
      'compliance_training': complianceTraining,
      'punctuality': punctuality,
      'internal_controls': internalControls,
      'professionalism': professionalism,
      'development_plan': developmentPlan,
      'additional_comments': additionalComments,
    };
  }
}
