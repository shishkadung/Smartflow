import 'package:flutter/material.dart';

/// SmartFlow icons aligned to Figma / HTML mockups.
///
/// Bottom nav (clerk mockup): ⌂ Home · ▣ Scan · ☰ History · ◔ Alerts
/// Module tiles: QR · RG · HS · AL · PR
abstract final class SfIcons {
  // ─── Clerk bottom navigation ───────────────────────────────────────────
  static const clerkHome = Icons.home_outlined;
  static const clerkHomeActive = Icons.home_rounded;

  /// Mockup ▣ — QR scanner tab
  static const clerkScan = Icons.qr_code_scanner_outlined;
  static const clerkScanActive = Icons.qr_code_scanner_rounded;

  /// Register document (grid RG); center nav "New"
  static const clerkRegister = Icons.edit_note_outlined;
  static const clerkRegisterActive = Icons.edit_note_rounded;

  /// Mockup ☰ — audit trail / movement list
  static const clerkHistory = Icons.view_list_outlined;
  static const clerkHistoryActive = Icons.view_list_rounded;

  /// Alerts tab — bell (user-facing; mockup ◔ was reports-style)
  static const clerkAlerts = Icons.notifications_outlined;
  static const clerkAlertsActive = Icons.notifications_rounded;

  // ─── Clerk module grid (2×2 + profile) ─────────────────────────────────
  static const moduleScan = Icons.qr_code_2_rounded;
  static const moduleRegister = Icons.post_add_rounded;
  static const moduleHistory = Icons.history_rounded;
  static const moduleAlerts = Icons.notifications_active_outlined;
  static const moduleProfile = Icons.person_rounded;

  // ─── Head bottom navigation ────────────────────────────────────────────
  static const headHome = Icons.home_outlined;
  static const headHomeActive = Icons.home_rounded;

  static const headRegister = Icons.edit_note_outlined;
  static const headRegisterActive = Icons.edit_note_rounded;

  static const headQueue = Icons.inbox_outlined;
  static const headQueueActive = Icons.inbox_rounded;

  static const headAlerts = Icons.notifications_outlined;
  static const headAlertsActive = Icons.notifications_rounded;

  static const headAnalytics = Icons.insights_outlined;
  static const headAnalyticsActive = Icons.insights_rounded;

  // ─── Admin bottom navigation ───────────────────────────────────────────
  static const adminHome = Icons.dashboard_outlined;
  static const adminHomeActive = Icons.dashboard_rounded;

  static const adminUsers = Icons.groups_outlined;
  static const adminUsersActive = Icons.groups_rounded;

  static const adminOffices = Icons.account_balance_outlined;
  static const adminOfficesActive = Icons.account_balance_rounded;

  static const adminSystem = Icons.dns_outlined;
  static const adminSystemActive = Icons.dns_rounded;

  static const adminCoaSummary = Icons.assessment_outlined;
  static const adminCoaSummaryActive = Icons.assessment_rounded;

  static const adminProfile = Icons.admin_panel_settings_outlined;
  static const adminProfileActive = Icons.admin_panel_settings_rounded;

  // ─── Shared actions ──────────────────────────────────────────────────────
  static const scanner = Icons.qr_code_scanner_rounded;
  static const printLabel = Icons.print_outlined;
  static const copyId = Icons.content_copy_rounded;
  static const timeline = Icons.timeline_rounded;
  static const warning = Icons.warning_amber_rounded;
  static const info = Icons.info_outline_rounded;
  static const logout = Icons.logout_rounded;
  static const back = Icons.arrow_back_ios_new_rounded;
}
