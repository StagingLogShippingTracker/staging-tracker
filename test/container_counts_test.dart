import 'package:flutter_test/flutter_test.dart';
import 'package:slst/domain/models.dart';

void main() {
  test('split parts must conserve original typed counts', () {
    final original = ContainerCounts.parse('3 Skids, 2 Boxes');
    final a = const ContainerCounts(skids: 2, boxes: 1);
    final b = const ContainerCounts(skids: 1, boxes: 1);
    expect((a + b).sameCounts(original), isTrue);
    expect(
      (a + const ContainerCounts(skids: 2, boxes: 1)).sameCounts(original),
      isFalse,
    );
  });
}
