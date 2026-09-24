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
  });

  final int officeId;
  final String code;
  final String name;
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

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    try {
      var docType = widget.documentType;
      var suggestId = widget.suggestedOfficeId;
      var suggestReason = widget.suggestedReason;

      if ((docType == null || docType.isEmpty) || suggestId == null) {
        try {
          final show = await context.read<AuthProvider>().api.documentShow(
                widget.documentId,
              );
          final doc = show['document'] as Map<String, dynamic>?;
          docType ??= doc?['type']?.toString();
          final sf = doc?['suggested_forward'] as Map<String, dynamic>?;
          if (sf != null) {
            suggestId ??= sf['office_id'] as int?;
            suggestReason ??= sf['reason']?.toString();
          }
        } catch (_) {
          // Offices list still works without document detail.
        }
      }

      final list = await context.read<AuthProvider>().api.offices();
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

  void _confirm() {
    final id = _selectedId;
    if (id == null) return;
    final office = _offices.firstWhere((o) => o['id'] == id);
    Navigator.pop(
      context,
      MarkOutDestination(
        officeId: id,
        code: office['code'] as String,
        name: office['name'] as String,
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
      title: const Text('Forward to which office?'),
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
                      if (widget.myOfficeCode.toUpperCase() == 'ACC' &&
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
                      if (suggestOffice != null &&
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
                      ..._offices.map((o) {
                        final id = o['id'] as int;
                        final code = o['code'] as String;
                        final name = o['name'] as String;
                        final selected = _selectedId == id;
                        final isSuggested = id == _suggestId;
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
          onPressed: _selectedId == null || _loading ? null : _confirm,
          child: const Text('Mark OUT'),
        ),
      ],
    );
  }
}
