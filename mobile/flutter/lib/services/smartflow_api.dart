import '../models/user.dart';
import 'api_client.dart';
import 'movement_recovery.dart';
import 'creation_recovery.dart';

class SmartflowApi {
  SmartflowApi(this._client, {String? movementScope})
    : _recovery = movementScope == null
          ? null
          : MovementRecovery(_client, movementScope),
      _creation = movementScope == null
          ? null
          : CreationRecovery(_client, movementScope);
  final ApiClient _client;
  final MovementRecovery? _recovery;
  final CreationRecovery? _creation;
  Future<Map<String, dynamic>?> pendingCreation(String kind) async =>
      _creation?.pending(kind);
  Future<Map<String, dynamic>?> checkCreation(String kind) async =>
      _creation?.check(kind);
  Future<Map<String, dynamic>?> retryCreation(String kind) async {
    final saved = await _creation?.pending(kind);
    return saved == null
        ? null
        : _creation!.submit(
            kind,
            Map<String, dynamic>.from(saved['body'] as Map),
          );
  }

  Future<Map<String, dynamic>> _create(
    String kind,
    Map<String, dynamic> body,
  ) => _creation != null
      ? _creation.submit(kind, body)
      : _client.post(
          kind == 'document'
              ? 'documents-create.php'
              : 'document-requests-create.php',
          body: body,
        );
  Future<Map<String, dynamic>?> pendingMovement() async => _recovery?.pending();
  Future<Map<String, dynamic>?> checkPendingMovement() async =>
      _recovery?.check();
  Future<Map<String, dynamic>?> cancelPendingMovement() async =>
      _recovery?.cancel();

  Future<Map<String, dynamic>> folderChecklists() =>
      _client.get('folder-checklists.php');
  Future<Map<String, dynamic>> saveFolderChecklist(Map<String, dynamic> body) =>
      _client.post('folder-checklists.php', body: body);

  Future<Map<String, dynamic>> validateSession() =>
      _client.get('auth-session.php');

  Future<void> logout() async {
    await _client.post('auth-logout.php');
  }

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
      body: {'username': username, 'code': code, 'new_password': newPassword},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> signupStatus({
    String? username,
    String? code,
    String? statusKey,
    String? password,
  }) {
    return _client.post(
      'signup-status.php',
      body: {
        'username': ?username,
        'request_code': ?code,
        'status_key': ?statusKey,
        'password': ?password,
      },
      auth: false,
    );
  }

  Future<List<Map<String, dynamic>>> offices() async {
    final data = await _client.get('offices-list.php', auth: false);
    return List<Map<String, dynamic>>.from(data['offices'] as List);
  }

  Future<Map<String, dynamic>> dashboardStats(int officeId) =>
      _client.get('dashboard-stats.php', query: {'office_id': '$officeId'});

  Future<Map<String, dynamic>> headDashboard(int officeId) =>
      _client.get('head-dashboard.php', query: {'office_id': '$officeId'});

  Future<Map<String, dynamic>> headAnalytics(int officeId, String month) =>
      _client.get(
        'head-analytics.php',
        query: {'office_id': '$officeId', 'month': month},
      );

  Future<Map<String, dynamic>> accountantDashboard() =>
      _client.get('accountant-dashboard.php');

  Future<Map<String, dynamic>> alerts(int officeId) =>
      _client.get('alerts-list.php', query: {'office_id': '$officeId'});

  Future<Map<String, dynamic>> accountantAlerts() =>
      _client.get('accountant-alerts.php');

  Future<Map<String, dynamic>> reportsSummary(int officeId, String month) =>
      _client.get(
        'reports-summary.php',
        query: {'office_id': '$officeId', 'month': month},
      );

  Future<Map<String, dynamic>> reportsSummaryQuarterly(
    int officeId,
    int year,
    int quarter,
  ) => _client.get(
    'reports-summary.php',
    query: {
      'office_id': '$officeId',
      'period': 'quarter',
      'year': '$year',
      'quarter': '$quarter',
    },
  );

  Future<Map<String, dynamic>> reportsSummaryAnnual(int officeId, int year) =>
      _client.get(
        'reports-summary.php',
        query: {'office_id': '$officeId', 'period': 'year', 'year': '$year'},
      );

  Future<String> reportExport(Map<String, String> query, String format) =>
      _client.getText(
        'reports-summary.php',
        query: {...query, 'format': format},
      );

  Future<Map<String, dynamic>> reportsRegister(Map<String, String> query) =>
      _client.get('reports-register.php', query: query);

  Future<Map<String, dynamic>> documentShow(String id) =>
      _client.get('documents-show.php', query: {'id': id});

  Future<Map<String, dynamic>> officeDocuments({String? id}) =>
      _client.get('office-documents.php', query: {'id': ?id});

  Future<Map<String, dynamic>> municipalDocuments({
    String? id,
    String? tray,
    String search = '',
    String sort = 'urgency',
    bool overdue = false,
    int? currentOfficeId,
    int? limit,
    int offset = 0,
  }) => _client.get(
    'office-documents.php',
    query: {
      'scope': 'municipal',
      'id': ?id,
      'tray': ?tray,
      'current_office_id': ?currentOfficeId?.toString(),
      'limit': ?limit?.toString(),
      'offset': '$offset',
      'search': search,
      'sort': sort,
      'overdue': overdue ? '1' : '0',
    },
  );

  Future<Map<String, dynamic>> officeDocumentPage({
    required String tray,
    String search = '',
    String sort = 'urgency',
    bool overdue = false,
    int limit = 50,
    int offset = 0,
  }) => _client.get(
    'office-documents.php',
    query: {
      'tray': tray,
      'search': search,
      'sort': sort,
      'overdue': overdue ? '1' : '0',
      'limit': '$limit',
      'offset': '$offset',
    },
  );

  /// Verifies signed SF1 QR payload server-side (signature + expiry).
  Future<Map<String, dynamic>> verifyQr(String qrPayload) =>
      _client.post('qr-verify.php', body: {'qr': qrPayload});

  Future<Map<String, dynamic>> issueQrToken(String documentId) =>
      _client.get('qr-token-issue.php', query: {'id': documentId});

  Future<Map<String, dynamic>> documentMovements(String id) =>
      _client.get('documents-movements.php', query: {'id': id});

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
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    required String email,
  }) {
    return _client.post(
      'users-profile-update.php',
      body: {'name': name, 'username': username, 'email': email},
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
    int? receivedFromOfficeId,
    Map<String, dynamic>? folderInventory,
    int? requestId,
  }) {
    return _create('document', {
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
      'received_from_office_id': ?receivedFromOfficeId,
      'folder_inventory': ?folderInventory,
      'request_id': ?requestId,
    });
  }

  Future<String> printableLabel(String documentId) =>
      _client.getText('qr-label.php', query: {'id': documentId});

  Future<Map<String, dynamic>> correctMovementDestination(
    Map<String, dynamic> body,
  ) => _recovery != null
      ? _recovery.record(body, destinationCorrection: true)
      : _client.post('movements-correct-destination.php', body: body);

  Future<Map<String, dynamic>> fileDocument(
    String documentId, {
    required int expectedMovementId,
  }) => _client.post(
    'documents-file.php',
    body: {
      'document_id': documentId,
      'expected_movement_id': expectedMovementId,
    },
  );

  Future<Map<String, dynamic>> recordMovement({
    required String documentId,
    required int officeId,
    required String status,
    String? remarks,
    int? destinationOfficeId,
    DateTime? scanStartedAt,
    String? qrPayload,
    bool isReturn = false,
    String? movementSource,
    required int expectedMovementId,
    bool receiptConfirmed = false,
    Map<String, dynamic>? contentsReceipt,
  }) {
    final body = <String, dynamic>{
      'document_id': documentId,
      'contents_receipt': ?contentsReceipt,
      'office_id': officeId,
      'status': status,
      'movement_source': ?movementSource,
      'expected_movement_id': expectedMovementId,
      if (movementSource == 'system' || receiptConfirmed)
        'receipt_confirmed': receiptConfirmed,
      if (isReturn) 'is_return': true,
      'remarks': ?remarks,
      if (scanStartedAt != null)
        'scan_started_at': scanStartedAt.toUtc().toIso8601String(),
      if (destinationOfficeId != null && destinationOfficeId > 0)
        'destination_office_id': destinationOfficeId,
      if (qrPayload != null && qrPayload.isNotEmpty) 'qr_payload': qrPayload,
    };
    return _recovery?.record(body) ??
        _client.post('movements-create.php', body: body);
  }

  Future<Map<String, dynamic>> usersList() => _client.get('users-list.php');

  Future<Map<String, dynamic>> setUserActive(int userId, bool active) =>
      _client.post(
        'users-set-active.php',
        body: {'user_id': userId, 'active': active},
      );

  /// Administrator correction of a staff or head user's password-reset email.
  Future<Map<String, dynamic>> adminSetUserEmail(int userId, String email) =>
      _client.post(
        'users-admin-set-email.php',
        body: {'user_id': userId, 'email': email},
      );

  /// Issues a temporary password (shown once) when the emailed reset code does not reach the user.
  Future<Map<String, dynamic>> adminResetPassword(int userId) =>
      _client.post('users-admin-reset-password.php', body: {'user_id': userId});

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
    return _create('request', {
      'request_kind': requestKind,
      'document_category': requestKind == 'pull' ? 'general' : documentCategory,
      'purpose': purpose,
      'required_by': requiredBy,
      'target_office_id': ?targetOfficeId,
    });
  }

  /// [period] uses the same keys as the COA summary (`period`, `month`, `quarter`, `year`).
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String> period = const {},
  }) => _client.get(
    'audit-exceptions.php',
    query: {'hours': '$hours', ...period},
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

  /// Admin/account actions: sign-up review, user changes, thresholds, request decisions.
  Future<Map<String, dynamic>> auditActivity({
    int hours = 168,
    String type = 'all',
    int limit = 100,
  }) {
    return _client.get(
      'audit-activity.php',
      query: {'hours': '$hours', 'type': type, 'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> documentRequestsList({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 25,
    bool overdue = false,
    String? search,
    int? requestId,
  }) {
    return _client.get(
      'document-requests-list.php',
      query: {
        'view': view,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': '$page',
        'page_size': '$pageSize',
        if (overdue) 'overdue': '1',
        if (search != null && search.isNotEmpty) 'q': search,
        if (requestId != null) 'id': '$requestId',
      },
    );
  }

  Future<Map<String, dynamic>> documentRequestsSummary() =>
      _client.get('document-requests-summary.php');

  Future<Map<String, dynamic>> officeMovements(
    int officeId, {
    String? date,
    String? status,
    int page = 1,
    int pageSize = 25,
  }) => _client.get(
    'office-movements-list.php',
    query: {
      'office_id': '$officeId',
      'date': ?date,
      if (status != null && status.isNotEmpty) 'status': status,
      'page': '$page',
      'page_size': '$pageSize',
    },
  );

  Future<Map<String, dynamic>> documentRequestUpdate({
    required int requestId,
    required String action,
    String? reviewNotes,
    String? relatedDocumentId,
    String? expectedStatus,
    String? expectedRevision,
  }) {
    return _client.post(
      'document-requests-update.php',
      body: {
        'request_id': requestId,
        'action': action,
        'expected_status': ?expectedStatus,
        'expected_revision': ?expectedRevision,
        'review_notes': ?reviewNotes,
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
