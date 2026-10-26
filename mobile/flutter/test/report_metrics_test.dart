import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/utils/report_metrics.dart';

// These mirror web/test/department-performance.test.mjs so a figure reads the same on the phone and in the browser.
void main() {
  test('helpers word the trend, month and hours honestly', () {
    expect(
      reportTrendLabel({
        'direction': 'slower',
        'earlier_avg_hours': 10,
        'later_avg_hours': 30,
        'change_hours': 20,
      }),
      'Slower by 20 h (10 h → 30 h)',
    );
    expect(
      reportTrendLabel({
        'direction': 'faster',
        'earlier_avg_hours': 40,
        'later_avg_hours': 12.8,
        'change_hours': -27.2,
      }),
      'Faster by 27.2 h (40 h → 12.8 h)',
    );
    expect(
      reportTrendLabel({
        'direction': 'steady',
        'earlier_avg_hours': 100,
        'later_avg_hours': 105,
        'change_hours': 5,
      }),
      'Steady (100 h → 105 h)',
    );
    expect(
      reportTrendLabel({'direction': 'insufficient', 'change_hours': null}),
      'Not enough forwarded folders to show a trend',
    );
    expect(
      reportTrendLabel(null),
      'Not enough forwarded folders to show a trend',
    );
    expect(reportMonthLabel('2026-05'), 'May 2026');
    expect(reportMonthLabel('2026-05', short: true), 'May');
    expect(reportMonthLabel('not-a-month'), 'not-a-month');
    expect(reportMonthLabel(null), '');
  });

  test('hours read as whole numbers when whole, and in days from 48 hours', () {
    expect(formatHours(5), '5 h');
    expect(formatHours(5.0), '5 h');
    expect(formatHours(5.5), '5.5 h');
    expect(formatHours(47.9), '47.9 h');
    expect(formatHours(48), '48 h (2.0 days)');
    expect(formatHours(60), '60 h (2.5 days)');
    expect(formatHours('61.4'), '61.4 h (2.6 days)');
  });

  test(
    'offices are listed slowest first and offices without a forwarded folder last',
    () {
      final sorted = sortPerformanceOffices([
        {
          'office_code': 'HR',
          'totals': {'avg_hours': null},
        },
        {
          'office_code': 'ENG',
          'totals': {'avg_hours': 12.5},
        },
        {
          'office_code': 'TRE',
          'totals': {'avg_hours': 61.4},
        },
        {
          'office_code': 'ACC',
          'totals': {'avg_hours': 12.5},
        },
      ]);
      expect(sorted.map((o) => o['office_code']), ['TRE', 'ACC', 'ENG', 'HR']);
      expect(sortPerformanceOffices(null), isEmpty);
    },
  );

  test(
    'an office with a recurring bottleneck is listed first, then slowest first',
    () {
      final sorted = sortPerformanceOffices([
        {
          'office_code': 'BUD',
          'totals': {'avg_hours': 28.7},
          'bottleneck': {'recurring': false},
        },
        {
          'office_code': 'ACC',
          'totals': {'avg_hours': 21.1},
          'bottleneck': {'recurring': true},
        },
        {
          'office_code': 'TRE',
          'totals': {'avg_hours': 39.1},
          'bottleneck': {'recurring': true},
        },
        {
          'office_code': 'HR',
          'totals': {'avg_hours': null},
          'bottleneck': {'recurring': false},
        },
        {
          'office_code': 'MAY',
          'totals': {'avg_hours': null},
        },
      ]);
      expect(sorted.map((o) => o['office_code']), [
        'TRE',
        'ACC',
        'BUD',
        'HR',
        'MAY',
      ]);
    },
  );

  test(
    'bar numbers and heights are honest about small, empty and very tall months',
    () {
      expect(reportBarValueLabel(5.94), '5.9');
      expect(reportBarValueLabel(6), '6');
      expect(reportBarValueLabel(0), '0');
      expect(reportBarValueLabel(22.4), '22');
      expect(reportBarValueLabel(62.5), '63');
      expect(reportBarValueLabel(null), '');
      expect(reportBarFraction(null, 48), 0);
      expect(reportBarFraction(24, 48), 0.5);
      expect(reportBarFraction(0.5, 48), 0.06);
      expect(reportBarFraction(96, 48), 1);
      expect(reportBarFraction(10, 0), 0);
    },
  );

  test(
    'the visits line says what it measured, or that nothing was visited',
    () {
      expect(
        reportVisitsLine({
          'visits': 0,
          'avg_hours': null,
          'late': 0,
          'late_percent': null,
        }),
        'No office visits in this window',
      );
      expect(
        reportVisitsLine({
          'visits': 9,
          'avg_hours': null,
          'late': 0,
          'late_percent': 0,
        }),
        'No folder forwarded yet · 9 visits · 0 late (0%)',
      );
      expect(
        reportVisitsLine({
          'visits': 27,
          'avg_hours': 15.3,
          'late': 8,
          'late_percent': 29.6,
        }),
        '15.3 h on average before forwarding · 27 visits · 8 late (29.6%)',
      );
      expect(reportVisitsLine(null), 'No office visits in this window');
    },
  );
}
