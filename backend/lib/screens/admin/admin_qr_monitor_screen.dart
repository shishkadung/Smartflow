import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/format_time.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import 'admin_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Municipal admin — QR scan audit monitor (accepted vs rejected).
class AdminQrMonitorScreen extends StatefulWidget {
  const AdminQrMonitorScreen({super.key});

  @override
  State<AdminQrMonitorScreen> createState() => _AdminQrMonitorScreenState();
}

class _AdminQrMonitorScreenState extends State<AdminQrMonitorScreen> {
  static const _hourOptions = [24, 48, 168];

  int _hours = 48;
  String _outcome = 'all';
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _suspicious = const [];
  List<Map<String, dynamic>> _topReasons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.auditScans(
            hours: _hours,
            outcome: _outcome,
          );
      if (!mounted) return;
      setState(() {
        _summary = data['summary'] as Map<String, dynamic>?;
        _events = List<Map<String, dynamic>>.from(data['events'] as List? ?? []);
        _suspicious =
            List<Map<String, dynamic>>.from(data['suspicious'] as List? ?? []);
        _topReasons = List<Map<String, dynamic>>.from(
          data['top_reject_reasons'] as List? ?? [],
        );
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final csv = await context.read<AuthProvider>().api.auditScansCsv(
            hours: _hours,
            outcome: _outcome,
          );
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan audit CSV copied — paste into Excel or Sheets'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = (_summary?['accepted'] as int?) ?? 0;
    final rejected = (_summary?['rejected'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfAdminPageOverviewCard(screen: SfAdminScreen.qrMonitor),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _hourOptions)
                ChoiceChip(
                  label: Text(h == 168 ? '7 days' : '${h}h'),
                  selected: _hours == h,
                  onSelected: _loading
                      ? null
                      : (_) {
                          setState(() => _hours = h);
                          _load();
                        },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _outcomeChip('All', 'all'),
              _outcomeChip('Accepted', 'success'),
              _outcomeChip('Rejected', 'rejected'),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const SfLoadingCard()
          else ...[
            Row(
              children: [
                Expanded(
                  child: SfStatCard(
                    value: '$accepted',
                    label: 'Accepted',
                    color: SfColors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SfStatCard(
                    value: '$rejected',
                    label: 'Rejected',
                    color: SfColors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SfSecondaryOutlineButton(
              label: _exporting ? 'Exporting…' : 'Copy CSV for compliance',
              icon: Icons.table_chart_outlined,
              onPressed: _exporting ? null : _exportCsv,
            ),
            if (_suspicious.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Needs review',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Staff with 3+ rejected scans in this window — training or mis-scans.',
                style: TextStyle(fontSize: 11, color: SfColors.muted),
              ),
              const SizedBox(height: 8),
              ..._suspicious.map(_suspiciousTile),
            ],
            if (_topReasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Top reject reasons',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _topReasons
                    .map(
                      (r) => SfStatusPill(
                        label:
                            '${r['code']} · ${r['count']}',
                        tone: SfPillTone.warning,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Recent events (${_events.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              const SfEmptyState(
                icon: SfIcons.clerkScan,
                title: 'No scan events',
                subtitle:
                    'Try a longer window or run a demo scan as a clerk first.',
              )
            else
              ..._events.map(_eventTile),
          ],
        ],
      ),
    );
  }

  Widget _outcomeChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _outcome == value,
      onSelected: _loading
          ? null
          : (_) {
              setState(() => _outcome = value);
              _load();
            },
    );
  }

  Widget _suspiciousTile(Map<String, dynamic> s) {
    final name = s['user_name']?.toString() ?? s['username']?.toString() ?? '?';
    final office = s['office_code']?.toString() ?? '';
    final count = s['reject_count']?.toString() ?? '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SfListTile(
        title: name,
        subtitle: '$office · $count rejected scans',
        trailing: const Icon(Icons.warning_amber_rounded, color: SfColors.gold),
      ),
    );
  }

  Widget _eventTile(Map<String, dynamic> ev) {
    final ok = ev['outcome']?.toString() == 'success';
    final docId = ev['document_id']?.toString() ?? '—';
    final office = ev['office_code']?.toString() ?? '';
    final user = ev['user_name']?.toString() ?? ev['username']?.toString() ?? '';
    final status = ev['status']?.toString();
    final scanError = ev['scan_error']?.toString();
    final when = formatMovementListTime(ev['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SfFormCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SfStatusPill(
                  label: ok ? 'Accepted' : 'Rejected',
                  tone: ok ? SfPillTone.success : SfPillTone.warning,
                ),
                const Spacer(),
                Text(
                  when,
                  style: const TextStyle(fontSize: 10, color: SfColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              docId,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            if (status != null && status.isNotEmpty)
              Text(
                status,
                style: const TextStyle(fontSize: 11, color: SfColors.blue),
              ),
            const SizedBox(height: 4),
            Text(
              [if (office.isNotEmpty) office, if (user.isNotEmpty) user]
                  .join(' · '),
              style: const TextStyle(fontSize: 11, color: SfColors.muted),
            ),
            const SizedBox(height: 6),
            Text(
              ev['message']?.toString() ?? '',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            if (scanError != null && scanError.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Code: $scanError',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: SfColors.gold.withValues(alpha: 0.95),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
