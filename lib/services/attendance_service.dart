import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'api_endpoints.dart';
import 'base_api_service.dart';

class AttendanceService extends BaseApiService {
  AttendanceService({required http.Client client, required User user})
      : super(client: client, user: user);

  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    required int companyId,
    required String date,
    String? employeeId,
  }) async {
    validateCompanyId(companyId);

    final data = await postRequest(ApiEndpoints.getAttendanceRecords, {
      'company_id': companyId,
      'date': date,
      if (employeeId != null) 'employee_id': employeeId,
    });

    if (data['status'] == 'success') {
      return List<Map<String, dynamic>>.from(data['attendance_records'] ?? []);
    }
    throw Exception(
        'Failed to fetch attendance records: ${data['message'] ?? 'Unknown error'}');
  }

  Future<Map<String, dynamic>> recordAttendance({
    required int companyId,
    required String employeeId,
    required bool isClockIn,
  }) async {
    validateCompanyId(companyId);

    final data = await postRequest(ApiEndpoints.recordAttendance, {
      'company_id': companyId,
      'employee_id': employeeId,
      'is_clock_in': isClockIn,
    });

    if (data['status'] == 'success') {
      return data;
    }
    throw Exception(
        'Failed to record attendance: ${data['message'] ?? 'Unknown error'}');
  }
}
