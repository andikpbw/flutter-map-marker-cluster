import 'package:flutter_test/flutter_test.dart';
import 'package:map_marker_cluster_example/main.dart';

void main() {
  testWidgets('ClusterShowcaseApp renders and switches themes and filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ClusterShowcaseApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('map_marker_cluster'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Cafe'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });
}
