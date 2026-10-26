import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/theme/sf_icons.dart';

void main() {
  test('Home is the same house icon for staff, head and admin', () {
    expect(SfIcons.clerkHome, Icons.home_outlined);
    expect(SfIcons.clerkHomeActive, Icons.home_rounded);
    expect(SfIcons.headHome, SfIcons.clerkHome);
    expect(SfIcons.headHomeActive, SfIcons.clerkHomeActive);
    expect(SfIcons.adminHome, SfIcons.clerkHome);
    expect(SfIcons.adminHomeActive, SfIcons.clerkHomeActive);
  });
}
