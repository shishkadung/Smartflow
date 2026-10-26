import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/smartflow_api.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/report_metrics.dart';
import '../../widgets/sf_motion.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart' show SfErrorBanner, SfLoadingCard;

/// How fast each office forwards folders, month by month, with the offices that are slow again and again. It is the
/// phone version of the web "Department performance" panel and reads the same administrator-only report.
class DepartmentPerformanceSection extends StatefulWidget {
  const DepartmentPerformanceSection({super.key, this.reloadKey = 0});

  /// A changed value reads the report again (the page's Refresh report).
  final int reloadKey;

  @override
  State<DepartmentPerformanceSection> createState() =>
      _DepartmentPerformanceSectionState();
}

class _DepartmentPerformanceSectionState
    extends State<DepartmentPerformanceSection>
    with AutomaticKeepAliveClientMixin<DepartmentPerformanceSection> {
  static const _windows = [3, 6, 12];

  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  int _months = 6;
  int _request = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  bool get _current => mounted && _auth.sessionIdentity == _identity;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _load();
  }

  @override
  void didUpdateWidget(DepartmentPerformanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _load();
  }

  Future<void> _load() async {
    if (!_current) return;
    final request = ++_request;
    final months = _months;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.departmentPerformance(months: months);
      if (!_current || request != _request) return;
      setState(() {
        _data = data;
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

  void _setWindow(int months) {
    if (!_current || months == _months) return;
    setState(() {
      _months = months;
      // A view of another window is never shown while this one loads.
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Department performance',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: SfColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final months in _windows)
                ChoiceChip(
                  label: Text('$months months'),
                  selected: _months == months,
                  onSelected: (_) => _setWindow(months),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(
              message: data != null
                  ? 'Department performance refresh failed. $_error Showing the previously loaded ${(data['window'] as Map?)?['months'] ?? _months} month view; it may be out of date.'
                  : 'Department performance unavailable. $_error The comparison between offices could not be verified.',
            ),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Retry department performance'),
            ),
          ],
          if (_loading && data == null) ...[
            const SizedBox(height: 12),
            const SfLoadingCard(),
          ] else if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (data != null) ..._content(data),
        ],
      ),
    );
  }

  List<Widget> _content(Map<String, dynamic> data) {
    final window = Map<String, dynamic>.from(data['window'] as Map? ?? {});
    final municipal = Map<String, dynamic>.from(
      data['municipal'] as Map? ?? {},
    );
    final totals = municipal['totals'] as Map?;
    final visits = (totals?['visits'] as num?) ?? 0;
    final rules = data['rules'] as Map? ?? const {};
    final configured = (rules['default_desk_limit_hours'] as num?) ?? 0;
    final limit = configured > 0 ? configured : null;
    final offices = sortPerformanceOffices(data['offices'] as List?);
    var scale = math.max<num>(1, limit ?? 0);
    for (final office in offices) {
      for (final month in office['months'] as List? ?? const []) {
        scale = math.max(scale, (month['avg_hours'] as num?) ?? 0);
      }
    }
    final bottlenecks = (data['bottlenecks'] as List? ?? const []).cast<Map>();
    return [
      const SizedBox(height: 12),
      Text(
        '${reportMonthLabel(window['start_month'])} to ${reportMonthLabel(window['end_month'])} · each month is measured at its own end · ${reportNumber(visits)} office visits in total',
        style: const TextStyle(
          fontSize: 13,
          color: SfColors.muted,
          height: 1.4,
        ),
      ),
      if (visits == 0) ...[
        const SizedBox(height: 12),
        const SfEmptyState(
          icon: Icons.assessment_outlined,
          title: 'No office visits',
          subtitle: 'No office visits were recorded in this window.',
        ),
      ] else ...[
        const SizedBox(height: 12),
        if (bottlenecks.isNotEmpty)
          Container(
            key: const Key('department-bottlenecks'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0B36A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bottlenecks.length == 1
                      ? 'Recurring bottleneck'
                      : 'Recurring bottlenecks',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final item in bottlenecks)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${item['office_name']} (${item['office_code']}): slow in ${item['slow_months']} of ${item['active_months']} months · ${item['late_percent']}% of visits late',
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
              ],
            ),
          )
        else
          Text(
            'No office was slow in ${rules['recurring_slow_months']} or more months in this window.',
            style: const TextStyle(fontSize: 13, color: SfColors.muted),
          ),
        const SizedBox(height: 10),
        Text(
          "Each bar is a month's average hours before forwarding, with the number on it; orange marks a slow month, meaning at least ${rules['slow_month_late_percent'] ?? 25}% of its visits ran past their limit.${limit != null ? ' The dashed line is the ${reportNumber(limit)} h default desk limit; some folder types have their own limit.' : ''}",
          style: const TextStyle(
            fontSize: 12,
            color: SfColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        SfListTile(title: 'All offices', subtitle: reportVisitsLine(totals)),
        for (final office in offices)
          _OfficeBlock(office: office, scale: scale, limit: limit),
      ],
      if ('${data['basis'] ?? ''}'.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'How these are counted',
            style: TextStyle(fontSize: 13),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data['basis']}',
              style: const TextStyle(
                fontSize: 12.5,
                color: SfColors.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
    ];
  }
}

class _OfficeBlock extends StatelessWidget {
  const _OfficeBlock({
    required this.office,
    required this.scale,
    required this.limit,
  });

  final Map<String, dynamic> office;
  final num scale;
  final num? limit;

  @override
  Widget build(BuildContext context) {
    final months = (office['months'] as List? ?? const []).cast<Map>();
    final types = (office['types'] as List? ?? const []).cast<Map>();
    final lateTypes = types
        .where((type) => ((type['late'] as num?) ?? 0) > 0)
        .take(3)
        .map(
          (type) =>
              '${type['type']} (${type['late']} late of ${type['visits']})',
        )
        .join('; ');
    final recurring = (office['bottleneck'] as Map?)?['recurring'] == true;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SfColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${office['office_name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                '${office['office_code']}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SfColors.navy,
                  letterSpacing: 0.4,
                ),
              ),
              if (recurring)
                const SfStatusPill(
                  label: 'Recurring bottleneck',
                  tone: SfPillTone.warning,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reportVisitsLine(office['totals'] as Map?),
            style: const TextStyle(
              fontSize: 13,
              color: SfColors.muted,
              height: 1.35,
            ),
          ),
          Text(
            reportTrendLabel(office['trend'] as Map?),
            style: const TextStyle(
              fontSize: 13,
              color: SfColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          MonthBars(months: months, scale: scale, limit: limit),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Month by month', style: TextStyle(fontSize: 13)),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final month in months)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${reportMonthLabel(month['month'])}${month['slow'] == true ? ' · slow' : ''}\n',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text:
                              'Visits ${month['visits']} · Forwarded ${month['forwarded']} · Average hours ${month['avg_hours'] ?? '—'} · Late ${month['late']} · Late share ${month['late_percent'] == null ? '—' : '${month['late_percent']}%'}',
                          style: const TextStyle(color: SfColors.muted),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              if (types.isNotEmpty)
                Text(
                  'Folder types with the most late visits: ${lateTypes.isEmpty ? 'none late' : lateTypes}.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SfColors.muted,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Average hours per month as bars with the number on each; the dashed line marks the default desk limit when the
/// report provides it.
class MonthBars extends StatelessWidget {
  const MonthBars({
    super.key,
    required this.months,
    required this.scale,
    this.limit,
  });

  final List<Map> months;
  final num scale;
  final num? limit;

  static const _height = 112.0;
  static const _labelHeight = 18.0;
  static const _topPad = 16.0;
  static const _normal = Color(0xFF8AA0BD);
  static const _slow = Color(0xFFB45309);

  String get _description {
    final parts = months
        .map((month) {
          final average = month['avg_hours'] == null
              ? 'no forwarded folders'
              : formatHours(month['avg_hours']);
          return '${reportMonthLabel(month['month'])}: $average${month['slow'] == true ? ', slow' : ''}';
        })
        .join('; ');
    return 'Average hours per month. $parts.${limit != null ? ' The dashed line is the ${reportNumber(limit!)} h default desk limit.' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    const plot = _height - _labelHeight - _topPad;
    return Semantics(
      label: _description,
      excludeSemantics: true,
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(right: limit != null ? 38 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < months.length; i++)
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 64),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _bar(months[i], i, plot),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (limit != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: _labelHeight + plot * (limit! / scale).clamp(0, 1),
                child: Row(
                  children: [
                    const Expanded(child: _DashedLine()),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${reportNumber(limit!)} h',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: SfColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Map month, int index, double plot) {
    final hours = month['avg_hours'];
    final fraction = reportBarFraction(hours, scale);
    final slow = month['slow'] == true;
    final color = slow ? _slow : _normal;
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              if (fraction > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: plot * fraction,
                  child: SfGrowUp(
                    index: index,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hours != null)
                Positioned(
                  left: -4,
                  right: -4,
                  bottom: plot * fraction + 2,
                  child: Text(
                    reportBarValueLabel(hours),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: slow ? const Color(0xFF92400E) : SfColors.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: _labelHeight,
          child: Center(
            child: Text(
              reportMonthLabel(month['month'], short: true),
              maxLines: 1,
              style: const TextStyle(fontSize: 11, color: SfColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.fromHeight(1), painter: _DashedPainter());
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SfColors.muted
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 3, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
