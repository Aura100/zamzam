import 'package:flutter_test/flutter_test.dart';
import 'package:zamzam/features/reports/domain/commission_utils.dart';

void main() {
  test('calculates commission using percentage', () {
    expect(calculateCommissionAmount(1000, 10), 100);
    expect(calculateCommissionAmount(1500, 15), 225);
  });
}
