/// LGU routing hints for Mark OUT (physical folder handoff).
class ForwardSuggestion {
  const ForwardSuggestion({
    required this.officeCode,
    required this.reason,
  });

  final String officeCode;
  final String reason;
}

/// Next office code to highlight, or null if no rule.
///
/// DV trail: ENG → BUD → ACC → TRE → MAY → TRE (check release).
ForwardSuggestion? suggestForwardOffice({
  required String documentType,
  required String fromOfficeCode,
  List<String> visitedOfficeCodes = const [],
}) {
  final type = documentType.trim().toLowerCase();
  final from = fromOfficeCode.trim().toUpperCase();
  final visited = visitedOfficeCodes.map((c) => c.trim().toUpperCase()).toList();

  if (type.contains('payroll')) {
    if (from == 'HR') {
      return const ForwardSuggestion(
        officeCode: 'ACC',
        reason: 'Payroll records typically go to Accounting for payment.',
      );
    }
    return const ForwardSuggestion(
      officeCode: 'ACC',
      reason: 'Payroll documents are usually routed to Accounting.',
    );
  }

  if (type.contains('approved budget') || type == 'budget') {
    if (from == 'BUD') {
      return const ForwardSuggestion(
        officeCode: 'ACC',
        reason: 'Approved budgets are forwarded to Accounting.',
      );
    }
    if (from == 'ENG') {
      return const ForwardSuggestion(
        officeCode: 'BUD',
        reason: 'Engineering often sends project files to Budget first.',
      );
    }
    return const ForwardSuggestion(
      officeCode: 'BUD',
      reason: 'Budget office usually handles budget documents.',
    );
  }

  if (type.contains('disbursement') || type.contains('voucher')) {
    if (from == 'ENG') {
      return const ForwardSuggestion(
        officeCode: 'BUD',
        reason: 'DV from Engineering often goes to Budget for fund check.',
      );
    }
    if (from == 'BUD') {
      return const ForwardSuggestion(
        officeCode: 'ACC',
        reason: 'After Budget review, DVs go to Accounting for supporting-doc check.',
      );
    }
    if (from == 'ACC') {
      if (visited.contains('TRE') && visited.contains('MAY')) {
        return null;
      }
      return const ForwardSuggestion(
        officeCode: 'TRE',
        reason: 'After Accounting, the folder goes to Treasury for payment processing.',
      );
    }
    if (from == 'TRE') {
      if (visited.contains('MAY')) {
        return const ForwardSuggestion(
          officeCode: 'ACC',
          reason: 'After Mayor and check release, return the folder to Accounting if needed.',
        );
      }
      return const ForwardSuggestion(
        officeCode: 'MAY',
        reason: 'Treasury forwards the DV to the Office of the Mayor for signature.',
      );
    }
    if (from == 'MAY') {
      return const ForwardSuggestion(
        officeCode: 'TRE',
        reason: 'After Mayor signature, return to Treasury for check release.',
      );
    }
    if (from == 'HR') {
      return const ForwardSuggestion(
        officeCode: 'ACC',
        reason: 'Disbursement vouchers are released through Accounting.',
      );
    }
    return const ForwardSuggestion(
      officeCode: 'ACC',
      reason: 'Disbursement documents typically go to Accounting, then Treasury and Mayor.',
    );
  }

  return null;
}
