import 'package:flutter_test/flutter_test.dart';
import 'package:smart_shop/utils/password_rules.dart';

void main() {
  test('money math stays deterministic', () {
    expect(100 + 20 - 5, 115);
  });

  test(
    'password validation requires alphabet number and special character',
    () {
      expect(validateStrongPassword('Admin@123'), isNull);
      expect(validateStrongPassword('Admin123'), isNotNull);
      expect(validateStrongPassword('Admin@@@'), isNotNull);
      expect(validateStrongPassword('12345678!'), isNotNull);
      expect(validateStrongPassword('Adm@123'), isNotNull);
    },
  );
}
