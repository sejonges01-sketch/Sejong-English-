import 'package:shared_preferences/shared_preferences.dart';

/// 이 기기에 저장해 두는 로그인 정보 (학년·반·번호·이름·Level)
class SavedLogin {
  final String grade;
  final String classNum;
  final String number;
  final String name;
  final int level;

  const SavedLogin({
    required this.grade,
    required this.classNum,
    required this.number,
    required this.name,
    required this.level,
  });
}

class LoginStorage {
  static const _kRemember = 'login_remember';
  static const _kGrade = 'login_grade';
  static const _kClass = 'login_class';
  static const _kNumber = 'login_number';
  static const _kName = 'login_name';
  static const _kLevel = 'login_level';

  /// 저장된 로그인 정보. 저장하지 않았으면 null.
  static Future<SavedLogin?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool(_kRemember) ?? false)) return null;
      return SavedLogin(
        grade: p.getString(_kGrade) ?? '',
        classNum: p.getString(_kClass) ?? '',
        number: p.getString(_kNumber) ?? '',
        name: p.getString(_kName) ?? '',
        level: p.getInt(_kLevel) ?? 1,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SavedLogin info) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kRemember, true);
      await p.setString(_kGrade, info.grade);
      await p.setString(_kClass, info.classNum);
      await p.setString(_kNumber, info.number);
      await p.setString(_kName, info.name);
      await p.setInt(_kLevel, info.level);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in [_kRemember, _kGrade, _kClass, _kNumber, _kName, _kLevel]) {
        await p.remove(k);
      }
    } catch (_) {}
  }
}
