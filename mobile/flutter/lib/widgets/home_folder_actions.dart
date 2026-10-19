import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/live_refresh.dart';
import '../theme/smartflow_theme.dart';
import 'sf_widgets.dart';

/// Keep the daily physical-folder workflow and pending requests in sight.
class HomeFolderActions extends StatefulWidget {
  const HomeFolderActions({super.key, this.overview});

  final Widget? overview;
  @override
  State<HomeFolderActions> createState() => _HomeFolderActionsState();
}

class _HomeFolderActionsState extends State<HomeFolderActions>
    with LiveRefresh<HomeFolderActions> {
  int? _pending;
  int _overdue = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    refreshLiveData();
  }

  @override
  Future<void> refreshLiveData() async {
    try {
      final data = await context
          .read<AuthProvider>()
          .api
          .documentRequestsSummary();
      if (mounted) {
        setState(() {
          _pending = (data['pending_inbox_count'] as num?)?.toInt() ?? 0;
          _overdue = (data['overdue_inbox_count'] as num?)?.toInt() ?? 0;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Request count unavailable · open inbox to retry',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user!.role;
    final home = '/$role';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.overview != null) ...[
          widget.overview!,
          const SizedBox(height: 12),
        ],
        SfNavigationRow(
          icon: Icons.inbox_outlined,
          title: 'Requests',
          subtitle:
              _error ??
              (_pending == null
                  ? 'Checking request inbox…'
                  : '$_pending pending · $_overdue overdue'),
          subtitleColor: _error != null || _overdue > 0
              ? SfColors.red
              : SfColors.muted,
          onTap: () => context.push('$home/requests'),
        ),
        if (role == 'staff') ...[
          const SizedBox(height: 12),
          SfNavigationRow(
            icon: Icons.create_new_folder_outlined,
            title: 'Register folder',
            onTap: () => context.push('$home/register'),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}
