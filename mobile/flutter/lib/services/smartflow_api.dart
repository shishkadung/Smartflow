import '../config/api_config.dart';
import '../models/user.dart';
import 'api_client.dart';

class SmartflowApi {
  SmartflowApi(this._client);
  final ApiClient _client;

  Future<({String token, AppUser user})> login(
    String username,
    String password,
  ) async {
    final data = await _client.post(
      'auth-login.php',
      body: {'username': username, 'password': password},
      auth: false,
    );
    return (
      token: data['token'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> signup(Map<String, dynamic> body) async {
    return _client.post('auth-signup.php', body: body, auth: false);
  }

  Future<Map<String, dynamic>> forgotPassword(String username) async {
    return _client.post(
      'auth-forgot-password.php',
      body: {'username': username},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String username,
    required String code,
    required String newPassword,
  }) async {
    return _client.post(
      'auth-reset-password.php',
      body: {
        'username': username,
        'code': code,
        'new_password': newPassword,
      },
      auth: false,
    );
  }

  Future<Map<String, dynamic>> signupStatus({String? username, String? code}) {
    return _client.get(
      'signup-status.php',
      query: {
        if (username != null) 'username': username,
        if (code != null) 'request_code': code,
      },
      auth: false,
    );
  }

  Future<List<Map<String, dynamic>>> offices() async {
    final data = await _client.get('offices-list.php', auth: false);
    return List<Map<String, dynamic>>.from(data['offices'] as List);
  }

  Future<Map<String, dynamic>> dashboardStats(int officeId) => _client.get(
        'dashboard-stats.php',
        query: {'office_id': '$officeId'},
      );

  Future<Map<String, dynamic>> headDashboard(int officeId) => _client.get(
        'head-dashboard.php',
        query: {'office_id': '$officeId'},
      );

  Future<Map<String, dynamic>> headAnalytics(int officeId, String month) =>
      _client.get(
        'head-analytics.php',
        query: {'office_id': '$officeId', 'month': month},
      );

  Future<Map<String, dynamic>> accountantDashboard() =>
      _client.get('accountant-dashboard.php');

  Future<Map<String, dynamic>> alerts(int officeId) => _client.get(
        'alerts-list.php',
        query: {'office_id': '$officeId'},
      );

  Future<Map<String, dynamic>> accountantAlerts() =>
      _client.get('accountant-alerts.php');

  Future<Map<String, dynamic>> reportsSummary(int officeId, String month) =>
      _client.get(
        'reports-summary.php',
        query: {'office_id': '$officeId', 'month': month},
      );

  Future<Map<String, dynamic>> documentShow(String id) => _client.get(
        'documents-show.php',
        query: {'id': id},
      );

  /// Verifies signed SF1 QR payload server-side (signature + expiry).
  Future<Map<String, dynamic>> verifyQr(String qrPayload) => _client.post(
        'qr-verify.php',
        body: {'qr': qrPayload},
      );

  Future<Map<String, dynamic>> issueQrToken(String documentId) => _client.get(
        'qr-token-issue.php',
        query: {'id': documentId},
      );

  Future<Map<String, dynamic>> documentMovements(String id) => _client.get(
        'documents-movements.php',
        query: {'id': id},
      );

  Future<Map<String, dynamic>> findByReference(String reference) => _client.get(
        'documents-find-by-reference.php',
        query: {'reference': reference},
      );

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _client.post(
      'users-change-password.php',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    required String email,
  }) {
    return _client.post(
      'users-profile-update.php',
      body: {
        'name': name,
        'username': username,
        'email': email,
      },
    );
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) {
    return _client.postMultipart(
      'users-avatar-upload.php',
      fileField: 'avatar',
      filePath: filePath,
    );
  }

  Future<Map<String, dynamic>> removeAvatar() {
    return _client.postMultipart(
      'users-avatar-upload.php',
      fields: const {'remove': '1'},
    );
  }

  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String type,
    required int originOfficeId,
    String? description,
    String? dueAt,
    String? referenceNo,
    String? payee,
    String? fundSource,
  }) {
    return _client.post(
      'documents-create.php',
      body: {
        'title': title,
        'type': type,
        'origin_office_id': originOfficeId,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (dueAt != null && dueAt.isNotEmpty) 'due_at': dueAt,
        if (referenceNo != null && referenceNo.isNotEmpty)
          'reference_no': referenceNo,
        if (payee != null && payee.isNotEmpty) 'payee': payee,
        if (fundSource != null && fundSource.isNotEmpty)
          'fund_source': fundSource,
      },
    );
  }

  String qrLabelUrl(String documentId, {String? token}) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final q = token != null && token.isNotEmpty
        ? '?id=${Uri.encodeComponent(documentId)}&token=${Uri.encodeComponent(token)}'
        : '?id=${Uri.encodeComponent(documentId)}';
    return '$base/qr-label.php$q';
  }

  Future<Map<String, dynamic>> recordMovement({
    required String documentId,
    required int officeId,
    required String status,
    String? remarks,
    int? destinationOfficeId,
    DateTime? scanStartedAt,
    String? qrPayload,
  }) {
    return _client.post(
      'movements-create.php',
      body: {
        'document_id': documentId,
        'office_id': officeId,
        'status': status,
        if (remarks != null) 'remarks': remarks,
        if (scanStartedAt != null) 'scan_started_at': scanStartedAt.toIso8601String(),
        if (destinationOfficeId != null && destinationOfficeId > 0)
          'destination_office_id': destinationOfficeId,
        if (qrPayload != null && qrPayload.isNotEmpty) 'qr_payload': qrPayload,
      },
    );
  }

  Future<Map<String, dynamic>> usersList() => _client.get('users-list.php');

  Future<Map<String, dynamic>> signupPending() =>
      _client.get('signup-pending-list.php');

  Future<void> signupApprove(int requestId, String action) async {
    await _client.post(
      'signup-approve.php',
      body: {'request_id': requestId, 'action': action},
    );
  }

  Future<Map<String, dynamic>> systemStatus() =>
      _client.get('system-status.php');

  Future<Map<String, dynamic>> adminOffices() =>
      _client.get('admin-offices.php');

  Future<Map<String, dynamic>> documentRequestCreate({
    required String requestKind,
    required String documentCategory,
    required String purpose,
    required String requiredBy,
    int? targetOfficeId,
  }) {
    return _client.post(
      'document-requests-create.php',
      body: {
        'request_kind': requestKind,
        'document_category': documentCategory,
        'purpose': purpose,
        'required_by': requiredBy,
        if (targetOfficeId != null) 'target_office_id': targetOfficeId,
      },
    );
  }

  Future<Map<String, dynamic>> auditExceptions({int hours = 24}) => _client.get(
        'audit-exceptions.php',
        query: {'hours': '$hours'},
      );

  Future<Map<String, dynamic>> auditScans({
    int hours = 48,
    String outcome = 'all',
    int? officeId,
    int? userId,
    int limit = 200,
  }) {
    return _client.get(
      'audit-scans.php',
      query: {
        'hours': '$hours',
        'outcome': outcome,
        'limit': '$limit',
        if (officeId != null && officeId > 0) 'office_id': '$officeId',
        if (userId != null && userId > 0) 'user_id': '$userId',
      },
    );
  }

  Future<String> auditScansCsv({
    int hours = 48,
    String outcome = 'all',
    int? officeId,
  }) {
    return _client.getText(
      'audit-scans.php',
      query: {
        'hours': '$hours',
        'outcome': outcome,
        'format': 'csv',
        'limit': '500',
        if (officeId != null && officeId > 0) 'office_id': '$officeId',
      },
    );
  }

  Future<Map<String, dynamic>> documentRequestsList({
    required String view,
    String? status,
  }) {
    return _client.get(
      'document-requests-list.php',
      query: {
        'view': view,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<Map<String, dynamic>> documentRequestsSummary() =>
      _client.get('document-requests-summary.php');

  Future<Map<String, dynamic>> documentRequestUpdate({
    required int requestId,
    required String action,
    String? reviewNotes,
    String? relatedDocumentId,
  }) {
    return _client.post(
      'document-requests-update.php',
      body: {
        'request_id': requestId,
        'action': action,
        if (reviewNotes != null) 'review_notes': reviewNotes,
        if (relatedDocumentId != null && relatedDocumentId.isNotEmpty)
          'related_document_id': relatedDocumentId,
      },
    );
  }

  Future<void> updateThreshold({
    required int officeId,
    required String documentType,
    required int maxHours,
    int outHours = 24,
  }) async {
    await _client.post(
      'admin-thresholds-update.php',
      body: {
        'office_id': officeId,
        'document_type': documentType,
        'max_hours': maxHours,
        'out_unconfirmed_hours': outHours,
      },
    );
  }
}
