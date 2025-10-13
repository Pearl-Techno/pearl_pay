class User {
  final int companyId;
  final String? employeeId;
  final String role;
  final String? position;
  final String? department;
  final String? token;
  final String? userId;
  final String? username;
  final String? companyName;

  User({
    required this.companyId,
    this.employeeId,
    required this.role,
    this.position,
    this.department,
    this.token,
    this.userId,
    this.username,
    this.companyName,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    // Validate and parse companyId with fallback
    final companyIdStr = map['company_id']?.toString();
    final companyId = companyIdStr != null && companyIdStr.isNotEmpty
        ? int.tryParse(companyIdStr) ?? 0 // Fallback to 0 if parsing fails
        : 0; // Default to 0 if null or empty

    return User(
      companyId: companyId,
      employeeId: map['employee_id']?.toString(),
      role: map['role']?.toString() ?? 'unknown',
      position: map['position']?.toString(),
      department: map['department']?.toString(),
      token: map['token'] as String?,
      userId: map['user_id']?.toString() ??
          map['id']?.toString(), // Prioritize user_id
      username: map['username']?.toString(),
      companyName: map['company_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'role': role,
      'position': position,
      'department': department,
      'company_id': companyId.toString(),
      'company_name': companyName,
      'employee_id': employeeId,
    };
  }
}
