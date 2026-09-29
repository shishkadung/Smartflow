import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/smartflow_theme.dart';
import '../utils/api_error.dart';
import '../utils/suggest_forward_office.dart';

/// Pilot office picked when forwarding (Mark OUT).
class MarkOutDestination {
  const MarkOutDestination({
    required this.officeId,
    required this.code,
    required this.name,
    this.isReturn = false,
    this.returnReason,
  });

  final int officeId;
  final String code;
  final String name;

  /// Sent back to an office that already held the folder (incomplete / needs correction).
  final bool isReturn;
  final String? returnReason;
}

/// Dialog: select receiving department; pre-selects LGU routing suggestion when known.
Future<MarkOutDestination?> showMarkOutDestinationDialog(
  BuildContext context, {
  required String documentId,
  required int myOfficeId,
  required String myOfficeName,
  required String myOfficeCode,
  String? documentType,
  int? suggestedOfficeId,
  String? suggestedOfficeCode,
  String? suggestedReason,
}) async {
  return showDialog<MarkOutDestination>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MarkOutDestinationDialog(
      documentId: documentId,
      myOfficeId: myOfficeId,
      myOfficeName: myOfficeName,
      myOfficeCode: myOfficeCode,
      documentType: documentType,
      suggestedOfficeId: suggestedOfficeId,
      suggestedOfficeCode: suggestedOfficeCode,
      suggestedReason: suggestedReason,
    ),
  );
}

class _MarkOutDestinationDialog extends StatefulWidget {
  const _MarkOutDestinationDialog({
    required this.documentId,
    required this.myOfficeId,
    required this.myOfficeName,
    required this.myOfficeCode,
    this.documentType,
    this.suggestedOfficeId,
    this.suggestedOfficeCode,
    this.suggestedReason,
  });

  final String documentId;
  final int myOfficeId;
  final String myOfficeName;
  final String myOfficeCode;
  final String? documentType;
  final int? suggestedOfficeId;
  final String? suggestedOfficeCode;
  final String? suggestedReason;

  @override
  State<_MarkOutDestinationDialog> createState() =>
      _MarkOutDestinationDialogState();
}

class _MarkOutDestinationDialogState extends State<_MarkOutDestinationDialog> {
  List<Map<String, dynamic>> _offices = [];
  int? _selectedId;
  bool _loading = true;
  String? _error;
  String? _suggestReason;
  int? _suggestId;
  Set<String> _previousHolderCodes = {};
  bool _isReturn = false;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reasonCtrl.addListener(() => setState(() {}));
    _loadOffices();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    final api = context.read<AuthProvider>().api;
    try {
      var docType = widget.documentType;
      var suggestId = widget.suggestedOfficeId;
      var suggestReason = widget.suggestedReason;
      var previousHolders = <String>{};

      try {
        final show = await api.documentShow(widget.documentId);
        final doc = show['document'] as Map<String, dynamic>?;
        docType ??= doc?['type']?.toString();
        final sf = doc?['suggested_forward'] as Map<String, dynamic>?;
        if (sf != null) {
          suggestId ??= sf['office_id'] as int?;
          suggestReason ??= sf['reason']?.toString();
        }
        previousHolders = {
          for (final c in doc?['visited_office_codes'] as List<dynamic>? ?? [])
            c.toString().toUpperCase(),
        }..remove(widget.myOfficeCode.toUpperCase());
      } catch (_) {
        // Offices list still works without document detail (returns unavailable).
      }

      final list = await api.offices();
      if (!mounted) return;

      final filtered = list
          .where((o) => (o['id'] as int) != widget.myOfficeId)
          .toList();

      var sid = suggestId;
      var sreason = suggestReason;
      final dtype = docType ?? widget.documentType;
      if (sid == null && dtype != null && dtype.isNotEmpty) {
        final hint = suggestForwardOffice(
          documentType: dtype,
          fromOfficeCode: widget.myOfficeCode,
        );
        if (hint != null) {
          sreason = hint.reason;
          for (final o in filtered) {
            if (o['code'] == hint.officeCode) {
              sid = o['id'] as int;
              break;
            }
          }
        }
      }

      final sorted = List<Map<String, dynamic>>.from(filtered)
        ..sort((a, b) {
          final aSuggest = a['id'] == sid;
          final bSuggest = b['id'] == sid;
          if (aSuggest != bSuggest) return aSuggest ? -1 : 1;
          return (a['code'] as String).compareTo(b['code'] as String);
        });

      setState(() {
        _offices = sorted;
        _previousHolderCodes = previousHolders;
        _suggestId = sid;
        _suggestReason = sreason;
        if (sid != null && sorted.any((o) => o['id'] == sid)) {
          _selectedId = sid;
        }
        _loading = false;
        _error = _offices.isEmpty ? 'No other offices configured' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleOffices => _isReturn
      ? _offices
          .where((o) => _previousHolderCodes.contains(o['code'] as String))
          .toList()
      : _offices;

  bool get _canConfirm =>
      !_loading &&
      _selectedId != null &&
      _visibleOffices.any((o) => o['id'] == _selectedId) &&
      (!_isReturn || _reasonCtrl.text.trim().length >= 5);

  void _setReturn(bool value) {
    setState(() {
      _isReturn = value;
      if (value) {
        final holders = _visibleOffices;
        _selectedId = holders.length == 1 ? holders.first['id'] as int : null;
      } else {
        _selectedId = _suggestId;
      }
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
    final id = _selectedId!;
    final office = _offices.firstWhere((o) => o['id'] == id);
    Navigator.pop(
      context,
      MarkOutDestination(
        officeId: id,
        code: office['code'] as String,
        name: office['name'] as String,
        isReturn: _isReturn,
        returnReason: _isReturn ? _reasonCtrl.text.trim() : null,
      ),
    );
  }

  Color _deptColor(String code) => SfColors.dept(code);

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? suggestOffice;
    if (_suggestId != null) {
      for (final o in _offices) {
        if (o['id'] == _suggestId) {
          suggestOffice = o;
          break;
        }
      }
    }

    return AlertDialog(
      scrollable: true,
      title: Text(_isReturn ? 'Return to which office?' : 'Forward to which office?'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Text(_error!, style: const TextStyle(color: SfColors.red))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mark ${widget.documentId} as OUT from ${widget.myOfficeName}.',
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                      if (_previousHolderCodes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _isReturn,
                          onChanged: _setReturn,
                          title: const Text(
                            'Return to a previous office',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Incomplete or needs correction — a reason is required.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                      if (_isReturn) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: _reasonCtrl,
                          maxLines: 2,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Reason for return',
                            hintText: 'e.g. Missing obligation request (ObR)',
                            helperText: 'At least 5 characters',
                          ),
                        ),
                      ],
                      if (!_isReturn &&
                          widget.myOfficeCode.toUpperCase() == 'ACC' &&
                          (widget.documentType ?? '')
                              .toLowerCase()
                              .contains('disbursement')) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: SfColors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: SfColors.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Text(
                            'Usual next stop is Treasury (TRE), then Mayor (MAY), '
                            'then Treasury again for check release. SmartFlow tracks '
                            'the folder — it does not approve payment.',
                            style: TextStyle(
                              fontSize: 11,
                              color: SfColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      if (!_isReturn &&
                          suggestOffice != null &&
                          _suggestReason != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SfColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SfColors.gold.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: SfColors.gold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Suggested: ${suggestOffice['code']} — ${suggestOffice['name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _suggestReason!,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: SfColors.muted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ..._visibleOffices.map((o) {
                        final id = o['id'] as int;
                        final code = o['code'] as String;
                        final name = o['name'] as String;
                        final selected = _selectedId == id;
                        final isSuggested = !_isReturn && id == _suggestId;
                        final dept = _deptColor(code);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? SfColors.blue.withValues(alpha: 0.12)
                                : SfColors.paper,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => setState(() => _selectedId = id),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? SfColors.blue
                                        : isSuggested
                                            ? SfColors.gold
                                                .withValues(alpha: 0.6)
                                            : const Color(0x140F172A),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: selected
                                          ? SfColors.blue
                                          : SfColors.muted,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                code,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: dept,
                                                ),
                                              ),
                                              if (isSuggested) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: SfColors.gold
                                                        .withValues(
                                                            alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Text(
                                                    'Suggested',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: SfColors.gold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: SfColors.muted,
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
                      }),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: Text(_isReturn ? 'Return (OUT)' : 'Mark OUT'),
        ),
      ],
    );
  }
}
