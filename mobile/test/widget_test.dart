// App 最小 smoke test:未登入(無 session)時 app 能建構出 MaterialApp。
// 原範本測試引用不存在的 MyApp 計數器頁,已改為對應實際的 ProjectDappApp。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_dapp/main.dart';

void main() {
  testWidgets('App builds without a session', (WidgetTester tester) async {
    await tester.pumpWidget(const ProjectDappApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
