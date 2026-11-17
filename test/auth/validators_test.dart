import 'package:flutter_test/flutter_test.dart';
import 'package:j_wallet/core/utils/validators.dart';

void main() {
  test('login email validation accepts trimmed addresses and rejects invalid input', () {
    expect(Validators.email('  demo@jstack.co  '), isNull);
    for (final email in [
      null,
      '',
      ' ',
      'demo',
      'demo@',
      'a b@test.co',
      '${'a' * 250}@b.co',
    ]) {
      expect(Validators.email(email), isNotNull);
    }
  });

  test(
    'login password validation preserves spaces and follows API length rules',
    () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('a' * 129), isNotNull);
      expect(Validators.password(' password '), isNull);
      expect(Validators.password('x'), isNull);
    },
  );
}
