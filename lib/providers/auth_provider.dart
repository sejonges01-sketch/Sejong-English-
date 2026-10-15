import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService firebaseService = FirebaseService();

  Student? student;
  bool isTeacher = false;
  bool isLoading = false;

  Future<bool> login(
    String grade,
    String classNum,
    String number,
    String name,
    int level,
  ) async {
    isLoading = true;
    notifyListeners();

    if (name == '교사용') {
      isTeacher = true;
      student = Student(grade, classNum, '0', '교사용', currentLevel: level);
      isLoading = false;
      notifyListeners();
      return true;
    }

    try {
      student = await firebaseService.getOrCreateStudent(
          grade, classNum, number, name, level);
      isTeacher = false;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('로그인 실패: $e');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void updateStudent(Student s) {
    student = s;
    notifyListeners();
  }

  void logout() {
    student = null;
    isTeacher = false;
    notifyListeners();
  }
}
