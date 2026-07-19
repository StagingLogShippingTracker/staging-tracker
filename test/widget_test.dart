import 'package:flutter_test/flutter_test.dart';

import 'package:slst/domain/models.dart';
import 'package:slst/domain/status.dart';

void main() {
  test('StatusRules maps Ship Today/Tomorrow to YMD', () {
    final today = StatusRules.todayYmd();
    final tomorrow = StatusRules.tomorrowYmd();
    expect(StatusRules.toDb('Ship Today'), today);
    expect(StatusRules.toDb('Ship Tomorrow'), tomorrow);
    expect(StatusRules.formatUi(today), 'Ship Today');
    expect(StatusRules.formatUi(tomorrow), 'Ship Tomorrow');
  });

  test('ContainerCounts builds type labels', () {
    const c = ContainerCounts(skids: 2, boxes: 1);
    expect(c.total, 3);
    expect(c.typeLabel, contains('2 Skids'));
    expect(c.typeLabel, contains('1 Box'));
  });

  test('Overdue detection', () {
    expect(StatusRules.isOverdue('2000-01-01'), isTrue);
    expect(StatusRules.isOverdue('Ready to Ship'), isFalse);
  });
}
