import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/utils/user_directory.dart';

// The same cases as web/test/user-directory.test.mjs, so the phone filters accounts the way the browser does.
final _users = <Map<String, dynamic>>[
  {
    'id': 1,
    'name': 'Ana Reyes',
    'username': 'ana_acc',
    'email': 'ana@urbiztondo.gov.ph',
    'office_code': 'ACC',
    'role': 'staff',
    'is_active': true,
  },
  {
    'id': 2,
    'name': 'Ben Cruz',
    'username': 'ben_bud',
    'email': 'ben.cruz@example.com',
    'office_code': 'BUD',
    'role': 'staff',
    'is_active': false,
  },
  {
    'id': 3,
    'name': 'Carla Diaz',
    'username': 'carla_acc',
    'email': 'carla@example.com',
    'office_code': 'ACC',
    'role': 'head',
    'is_active': true,
  },
  {
    'id': 4,
    'name': 'System Admin',
    'username': 'admin',
    'email': 'admin@example.com',
    'office_code': 'MAY',
    'role': 'admin',
    'is_active': true,
  },
];

List<String> _names(Iterable<Map> list) => [
  for (final row in list) '${row['name']}',
];

void main() {
  test(
    'no filter lists everyone; search needs every typed word and ignores case',
    () {
      expect(filterAccounts(_users), hasLength(4));
      expect(
        _names(filterAccounts(_users, const AccountFilters(query: 'ANA'))),
        ['Ana Reyes'],
      );
      expect(
        _names(filterAccounts(_users, const AccountFilters(query: 'acc head'))),
        isEmpty,
      );
      expect(
        _names(
          filterAccounts(_users, const AccountFilters(query: 'carla acc')),
        ),
        ['Carla Diaz'],
      );
      expect(
        _names(
          filterAccounts(_users, const AccountFilters(query: 'example.com')),
        ),
        ['Ben Cruz', 'Carla Diaz', 'System Admin'],
      );
      expect(
        filterAccounts(_users, const AccountFilters(query: '   ')),
        hasLength(4),
      );
    },
  );

  test('the office name is searchable too, as it already was on the phone', () {
    final users = [
      {..._users.first, 'office_name': 'Accounting Office'},
      {..._users[1], 'office_name': 'Budget Office'},
    ];
    expect(
      _names(filterAccounts(users, const AccountFilters(query: 'accounting'))),
      ['Ana Reyes'],
    );
  });

  test('office, role and status narrow the list together', () {
    expect(
      _names(filterAccounts(_users, const AccountFilters(office: 'ACC'))),
      ['Ana Reyes', 'Carla Diaz'],
    );
    expect(
      _names(
        filterAccounts(
          _users,
          const AccountFilters(office: 'ACC', role: 'head'),
        ),
      ),
      ['Carla Diaz'],
    );
    expect(
      _names(filterAccounts(_users, const AccountFilters(status: 'inactive'))),
      ['Ben Cruz'],
    );
    expect(
      _names(
        filterAccounts(
          _users,
          const AccountFilters(status: 'active', role: 'staff'),
        ),
      ),
      ['Ana Reyes'],
    );
  });

  test('an account counts as active unless the server says it is not', () {
    final noValue = {'name': 'No flag', 'office_code': 'ACC', 'role': 'staff'};
    expect(
      matchesAccountFilters(noValue, const AccountFilters(status: 'active')),
      isTrue,
    );
    expect(
      matchesAccountFilters(noValue, const AccountFilters(status: 'inactive')),
      isFalse,
    );
  });

  test(
    'a sign-up request is matched on the role it asked for, and has no status',
    () {
      final request = {
        'username': 'new.head',
        'office_code': 'BUD',
        'requested_role': 'head',
      };
      const head = AccountFilters(role: 'head', status: 'inactive');
      expect(
        matchesAccountFilters(
          request,
          head,
          roleKey: 'requested_role',
          checkStatus: false,
        ),
        isTrue,
      );
      expect(
        matchesAccountFilters(
          request,
          const AccountFilters(role: 'staff'),
          roleKey: 'requested_role',
          checkStatus: false,
        ),
        isFalse,
      );
    },
  );

  test('office choices come from the accounts, sorted, without repeats', () {
    expect(officeCodes(_users), ['ACC', 'BUD', 'MAY']);
    expect(officeCodes(null), isEmpty);
  });

  test('filters count as active only when something is chosen', () {
    expect(emptyAccountFilters.active, isFalse);
    expect(const AccountFilters(query: '  ').active, isFalse);
    expect(const AccountFilters(status: 'active').active, isTrue);
    expect(emptyAccountFilters.copyWith(office: 'ACC').active, isTrue);
  });
}
