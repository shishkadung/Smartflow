// Alert time limits worded the way the web words them (Offices and Thresholds pages).

/// Hours to record a receipt after sending. A rule saved before receipt limits existed has none, so this is used.
const defaultReceiptHours = 24;

/// Hours the office has to process a folder when no rule is saved for its type.
const defaultProcessingHours = 48;

int? _hours(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

/// The receipt limit of a saved rule, falling back to the default when the rule has none.
int ruleReceiptHours(Map rule) =>
    _hours(rule['out_unconfirmed_hours']) ?? defaultReceiptHours;

/// `48 hours at the office · 24 hours to record receipt after sending`.
String ruleSummary(Map rule) =>
    '${rule['max_hours']} hours at the office · ${ruleReceiptHours(rule)} hours to record receipt after sending';
