import 'package:local_auth/local_auth.dart';

class AuthService {
  AuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> canUseBiometrics() async {
    final canCheck = await _localAuthentication.canCheckBiometrics;
    final supported = await _localAuthentication.isDeviceSupported();
    return canCheck && supported;
  }

  Future<bool> authenticateBiometric() async {
    if (!await canUseBiometrics()) return false;
    return _localAuthentication.authenticate(
      localizedReason: 'Unlock Smart Shop',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
