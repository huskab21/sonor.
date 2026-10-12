import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';

/// Нэвтрэлтийн алдаа. [message] нь хэрэглэгчид харуулах монгол бичвэр.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

/// Нууц үггүй нэвтрэлт: и-мэйл рүү нэг удаагийн код илгээж, кодоор баталгаажуулна.
/// Бүртгэлгүй и-мэйл бол код баталгаажих үед бүртгэл автоматаар үүснэ.
abstract class AuthBackend {
  String? get email;
  Future<void> sendCode(String email);
  Future<void> verify(String email, String code);
  Future<void> signOut();
}

class AuthService extends ChangeNotifier {
  AuthService([this._backend]);
  AuthBackend? _backend;

  /// Нэвтрэх үйлчилгээ холбогдсон эсэх.
  bool get available => _backend != null;

  /// Нэвтэрсэн хэрэглэгчийн и-мэйл, нэвтрээгүй бол null.
  String? get email => _backend?.email;

  Future<void> init() async {
    if (_backend != null) return;
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
      _backend = _SupabaseBackend();
    } else if (kIsWeb) {
      _backend = DemoAuthBackend(); // хөтчийн демо: дизайн харахад зориулсан
    }
    notifyListeners();
  }

  static String cleanEmail(String input) => input.trim().toLowerCase();

  static bool validEmail(String input) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(cleanEmail(input));

  /// Код илгээнэ. Алдаа гарвал бичвэрийг нь, амжилттай бол null буцаана.
  Future<String?> sendCode(String email) async {
    if (!validEmail(email)) return 'И-мэйл хаягаа зөв бичнэ үү.';
    return _run(() => _backend!.sendCode(cleanEmail(email)));
  }

  /// Кодыг шалгаж нэвтэрнэ. Алдаа гарвал бичвэрийг нь, амжилттай бол null буцаана.
  Future<String?> verify(String email, String code) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return 'И-мэйлээр ирсэн кодыг бүтнээр нь бичнэ үү.';
    return _run(() => _backend!.verify(cleanEmail(email), digits));
  }

  Future<void> signOut() async {
    await _run(() => _backend!.signOut());
  }

  Future<String?> _run(Future<void> Function() action) async {
    if (_backend == null) {
      return 'Нэвтрэх үйлчилгээ хараахан холбогдоогүй байна.';
    }
    try {
      await action();
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Холбогдож чадсангүй. Интернэтээ шалгаад дахин оролдоно уу.';
    } finally {
      notifyListeners();
    }
  }
}

class _SupabaseBackend implements AuthBackend {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Future<void> sendCode(String email) => _guard(
    () => _auth.signInWithOtp(email: email, shouldCreateUser: true),
    'Код илгээж чадсангүй. Хаягаа шалгаад дахин оролдоно уу.',
  );

  @override
  Future<void> verify(String email, String code) => _guard(
    () => _auth.verifyOTP(email: email, token: code, type: OtpType.email),
    'Код буруу эсвэл хугацаа нь дууссан байна.',
  );

  @override
  Future<void> signOut() => _guard(_auth.signOut, 'Гарч чадсангүй.');

  Future<void> _guard(Future<void> Function() action, String fallback) async {
    try {
      await action();
    } on AuthException catch (e) {
      if (e.statusCode == '429') {
        throw const AuthFailure(
          'Хэт олон удаа оролдлоо. Хэдэн минут хүлээгээд дахин оролдоно уу.',
        );
      }
      // Сүлжээний алдааг ерөнхий "холбогдож чадсангүй" бичвэрээр харуулна
      if (e is AuthRetryableFetchException) rethrow;
      throw AuthFailure(fallback);
    }
  }
}

/// Сервергүй хуурамч нэвтрэлт. Код нь үргэлж [code].
class DemoAuthBackend implements AuthBackend {
  static const String code = '123456';

  @override
  String? email;

  @override
  Future<void> sendCode(String email) async {}

  @override
  Future<void> verify(String email, String code) async {
    if (code != DemoAuthBackend.code) {
      throw const AuthFailure('Код буруу эсвэл хугацаа нь дууссан байна.');
    }
    this.email = email;
  }

  @override
  Future<void> signOut() async => email = null;
}
