import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/smartflow_api.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/api_error.dart';
import '../staff/clerk_widgets.dart' show SfErrorBanner;
import '../../widgets/sf_widgets.dart';

/// A summary tile on the report asks the register to show one classification. A new [token] applies it once, the way the
/// web register opens from a tile: period activity, all offices, no search.
class ReportClassificationRequest {
  const ReportClassificationRequest(this.classification, this.token);

  final String classification;
  final int token;
}

/// A server-paged report snapshot. Opening a record uses the existing live,
/// authenticated detail/history routes; it does not grant a custody action.
class CustodyReportRegister extends StatefulWidget {
  const CustodyReportRegister({
    super.key,
    required this.period,
    required this.periodLabel,
    required this.reloadKey,
    this.offices = const [],
    this.asOf,
    this.movementWatermark,
    this.correctionWatermark,
    this.ready = true,
    this.classificationRequest,
  });

  final Map<String, String> period;
  final String periodLabel;
  final int reloadKey;
  final List<dynamic> offices;
  final String? asOf;
  final String? movementWatermark;
  final String? correctionWatermark;
  final bool ready;
  final ReportClassificationRequest? classificationRequest;

  @override
  State<CustodyReportRegister> createState() => _CustodyReportRegisterState();
}

class _CustodyReportRegisterState extends State<CustodyReportRegister>
    with AutomaticKeepAliveClientMixin<CustodyReportRegister> {
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  final _search = TextEditingController();
  String _scope = 'activity';
  String _classification = 'all';
  String _office = '';
  String _query = '';
  int _page = 1;
  int _request = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String? _loadedQuery;

  bool get _current => mounted && _auth.sessionIdentity == _identity;

  @override
  bool get wantKeepAlive => true;

  static const _classifications = {
    'all': 'All classifications',
    'on_time': 'On time / in process',
    'unforwarded': 'Awaiting receipt',
    'delayed': 'Late receipt',
  };

  Map<String, String> get _params => {
    ...widget.period,
    if (widget.asOf != null) 'as_of': widget.asOf!,
    if (widget.movementWatermark != null)
      'movement_watermark': widget.movementWatermark!,
    if (widget.correctionWatermark != null)
      'correction_watermark': widget.correctionWatermark!,
    'scope': _scope,
    'classification': _classification,
    if (_office.isNotEmpty) 'office_id': _office,
    if (_query.isNotEmpty) 'q': _query,
    'page': '$_page',
    'page_size': '25',
  };

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _load();
  }

  @override
  void didUpdateWidget(CustodyReportRegister oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.classificationRequest;
    if (request != null &&
        request.token != oldWidget.classificationRequest?.token) {
      _scope = 'activity';
      _classification = request.classification;
      _office = '';
      _query = '';
      _search.clear();
      _page = 1;
      _load();
      return;
    }
    final changedPeriod =
        jsonEncode(oldWidget.period) != jsonEncode(widget.period);
    if (changedPeriod ||
        oldWidget.reloadKey != widget.reloadKey ||
        oldWidget.asOf != widget.asOf ||
        oldWidget.movementWatermark != widget.movementWatermark ||
        oldWidget.correctionWatermark != widget.correctionWatermark ||
        oldWidget.ready != widget.ready) {
      if (changedPeriod) _page = 1;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    final request = ++_request;
    if (!widget.ready) {
      setState(() {
        _data = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    final params = _params;
    final query = jsonEncode(params);
    setState(() {
      _loading = true;
      _error = null;
      if (_loadedQuery != query) _data = null;
    });
    try {
      final data = await _api.reportsRegister(params);
      if (!_current || request != _request) return;
      final pages = (data['total_pages'] as num?)?.toInt() ?? 0;
      if (_page > 1 && _page > (pages > 0 ? pages : 1)) {
        setState(() => _page = 1);
        await _load();
        return;
      }
      setState(() {
        _data = data;
        _loadedQuery = query;
        _loading = false;
      });
    } catch (error) {
      if (!_current || request != _request) return;
      setState(() {
        _error = apiErrorMessage(error);
        _loading = false;
      });
    }
  }

  void _filter(VoidCallback change) {
    if (!_current) return;
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  void _submitSearch() => _filter(() => _query = _search.text.trim());

  void _open(String id, {bool history = false}) {
    if (!_current || _auth.loggingOut || id.isEmpty) return;
    if (history) {
      context.push('/admin/history', extra: {'documentId': id});
    } else {
      context.push(
        '/admin/documents?${Uri(queryParameters: {'id': id}).query}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = (_data?['documents'] as List? ?? []).cast<Map>();
    final total = (_data?['total'] as num?)?.toInt() ?? 0;
    final page = (_data?['page'] as num?)?.toInt() ?? _page;
    final pages = (_data?['total_pages'] as num?)?.toInt() ?? 0;
    final officeOptions = <String, String>{'': 'All offices'};
    for (final raw in widget.offices) {
      final office = raw as Map;
      final id = office['office_id']?.toString();
      if (id != null) {
        officeOptions[id] =
            office['office_name']?.toString() ??
            office['office_code']?.toString() ??
            'Office $id';
      }
    }
    if (!officeOptions.containsKey(_office)) {
      officeOptions[_office] = 'Office $_office';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Folder register',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: SfColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _scope == 'outstanding'
              ? 'Transfers still awaiting a recorded receipt at the reporting cutoff, including sends from earlier periods. These folders can also appear in Period activity.'
              : 'Folders with a recorded handoff or registration in this period. Custody below is shown as of the reporting cutoff; open tracking for the latest status.',
          style: const TextStyle(
            color: SfColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('report-register-view'),
          initialValue: _scope,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Register view'),
          items: const [
            DropdownMenuItem(value: 'activity', child: Text('Period activity')),
            DropdownMenuItem(
              value: 'outstanding',
              child: Text('Outstanding transfers'),
            ),
          ],
          onChanged: (value) {
            if (value != null && value != _scope) {
              _filter(() {
                _scope = value;
                if (value == 'outstanding') _classification = 'all';
              });
            }
          },
        ),
        if (_scope == 'activity') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('report-register-classification-$_classification'),
            initialValue: _classification,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Transfer classification',
            ),
            items: _classifications.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null && value != _classification) {
                _filter(() => _classification = value);
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('report-register-office'),
          initialValue: _office,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Custody / sending office',
          ),
          items: officeOptions.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null && value != _office) {
              _filter(() => _office = value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('report-register-search'),
          controller: _search,
          maxLength: 200,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search folders',
            hintText: 'ID, title or type',
            counterText: '',
          ),
          onSubmitted: (_) => _submitSearch(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _submitSearch,
              icon: const Icon(Icons.search),
              label: const Text('Search register'),
            ),
            if (_query.isNotEmpty)
              TextButton(
                onPressed: () {
                  _search.clear();
                  _filter(() => _query = '');
                },
                child: const Text('Clear search'),
              ),
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh register'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          SfErrorBanner(
            message: _data == null
                ? 'Folder register unavailable. $_error'
                : 'Refresh failed. Previously loaded register may be stale. $_error',
          ),
          TextButton(onPressed: _load, child: const Text('Retry register')),
        ],
        if (_data != null) ...[
          Text(
            '${_data?['period_label'] ?? widget.periodLabel} · $total ${total == 1 ? 'folder' : 'folders'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Evidence through ${_data?['as_of'] ?? _data?['period_end'] ?? 'the period cutoff'} '
            '(${_data?['timezone'] ?? 'Asia/Manila'}). '
            'Folder titles and names use current records. '
            'Open folder and Full history show the current record.',
            style: const TextStyle(
              color: SfColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty && !_loading && _error == null)
            const SfEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No matching folders',
              subtitle:
                  'Try another period, register view, classification, office or search.',
            ),
          for (final row in rows) _folder(row),
          if (pages > 1)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Page $page of $pages'),
                OutlinedButton(
                  onPressed: _loading || page <= 1
                      ? null
                      : () {
                          setState(() => _page = page - 1);
                          _load();
                        },
                  child: const Text('Previous page'),
                ),
                OutlinedButton(
                  onPressed: _loading || page >= pages
                      ? null
                      : () {
                          setState(() => _page = page + 1);
                          _load();
                        },
                  child: const Text('Next page'),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _folder(Map row) {
    final id = row['document_id']?.toString() ?? '';
    final office =
        row['current_office_name'] ??
        row['current_office_code'] ??
        'Unknown office';
    final destination =
        row['destination_office_name'] ??
        row['destination_office_code'] ??
        'Unrecorded destination';
    final outgoing = row['current_status'] == 'OUT';
    final classification =
        _classifications[row['classification']] ?? 'Unclassified';
    String evidence(String timestampKey, String personKey) {
      final time = row[timestampKey]?.toString();
      if (time == null || time.isEmpty) return 'Not recorded';
      final person = row[personKey]?.toString();
      return '$time · ${person == null || person.isEmpty ? 'Name not recorded' : person}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SfFormCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row['title']?.toString() ?? id,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: SfColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$id · ${row['type'] ?? 'Type not recorded'}',
              style: const TextStyle(color: SfColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '$classification · ${outgoing ? 'OUT' : row['current_status'] ?? 'Status not recorded'}',
            ),
            Text(outgoing ? 'Sent from $office → $destination' : 'At $office'),
            if (row['carried_forward'] == true)
              const Text(
                'Carried forward from before this period',
                style: TextStyle(color: SfColors.muted, fontSize: 12),
              ),
            if (outgoing && row['receipt_wait_hours'] != null)
              Text(
                '${row['receipt_wait_hours']} hours awaiting receipt at cutoff',
              ),
            const SizedBox(height: 8),
            Text(
              'Last activity: ${evidence('last_scanned_at', 'recorded_by')}',
            ),
            Text(
              'Last receipt: ${evidence('last_received_at', 'received_by')}',
            ),
            Text('Last send: ${evidence('last_sent_at', 'sent_by')}'),
            Text(
              '${row['movement_count'] ?? 0} movements through cutoff',
              style: const TextStyle(color: SfColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: id.isEmpty ? null : () => _open(id),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Semantics(
                    label: 'Open folder $id',
                    excludeSemantics: true,
                    child: const Text('Open folder'),
                  ),
                ),
                TextButton.icon(
                  onPressed: id.isEmpty ? null : () => _open(id, history: true),
                  icon: const Icon(Icons.history),
                  label: Semantics(
                    label: 'Full history for $id',
                    excludeSemantics: true,
                    child: const Text('Full history'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
