import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rice_weight_manager/main.dart';
import 'package:rice_weight_manager/services/app_settings_service.dart';

void main() {
  testWidgets('RiceWeightManagerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RiceWeightManagerApp());
    expect(find.byType(Image), findsWidgets);
    expect(find.text(AppSettingsService.instance.tr('app_title')), findsOneWidget);
  });
}
