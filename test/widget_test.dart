
import 'package:flutter_test/flutter_test.dart';
import 'package:case2_khmt2411001_tranthitutrinh/main.dart';

void main() {
  testWidgets('Task Manager app starts successfully',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TaskManagerApp());

        expect(find.byType(TaskManagerApp), findsOneWidget);
      });
}
