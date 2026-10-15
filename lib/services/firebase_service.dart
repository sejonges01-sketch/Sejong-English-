import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/word_data.dart';
import '../models/student.dart';

/// 세종 한자공부 앱과 같은 구조로 학생 기록을 저장합니다.
/// eng_students/{학년}/{반}/{번호_이름}               : 학생 기본 정보 + kingScores(영단어왕)
/// eng_students/{학년}/{반}/{번호_이름}/levels/{Level} : Level별 stageResults, totalPoints, status
class FirebaseService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _studentRef(
          String grade, String classNum, String docId) =>
      _db.collection('eng_students').doc(grade).collection(classNum).doc(docId);

  DocumentReference<Map<String, dynamic>> _studentDoc(Student s) =>
      _studentRef(s.grade, s.classNum, s.docId);

  DocumentReference<Map<String, dynamic>> _levelDoc(Student s, int level) =>
      _studentDoc(s).collection('levels').doc(level.toString());

  Future<Student> getOrCreateStudent(
    String grade,
    String classNum,
    String number,
    String name,
    int level,
  ) async {
    final docRef = _studentRef(grade, classNum, '${number}_$name');
    final snap = await docRef.get();

    if (!snap.exists) {
      final student = Student(grade, classNum, number, name, currentLevel: level);
      await docRef.set(student.toMap());
      for (final lv in WordData.levels) {
        await docRef
            .collection('levels')
            .doc(lv.toString())
            .set(LevelData().toMap());
      }
      return student;
    }

    final levelRef = docRef.collection('levels').doc(level.toString());
    final levelSnap = await levelRef.get();
    if (!levelSnap.exists) {
      await levelRef.set(LevelData().toMap());
    }

    final levels = await _readAllLevels(docRef);
    return Student.fromMap(snap.data() ?? {}, currentLevel: level, levels: levels);
  }

  Future<Map<int, LevelData>> _readAllLevels(
      DocumentReference<Map<String, dynamic>> docRef) async {
    final qs = await docRef.collection('levels').get();
    final result = <int, LevelData>{};
    for (final d in qs.docs) {
      final lv = int.tryParse(d.id);
      if (lv == null) continue;
      result[lv] = LevelData.fromMap(d.data());
    }
    for (final lv in WordData.levels) {
      result.putIfAbsent(lv, () => LevelData());
    }
    return result;
  }

  /// 단계 통과 기록. 이미 통과한 단계면 점수를 다시 더하지 않습니다.
  Future<void> updateScore(
      Student student, String category, int stage, int points) async {
    final ref = _levelDoc(student, student.currentLevel);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};

    final rawResults = data['stageResults'];
    List<bool> list = <bool>[];
    if (rawResults is Map && rawResults[category] is List) {
      list = (rawResults[category] as List).map((e) => e == true).toList();
    }
    while (list.length < stage) {
      list.add(false);
    }
    if (list[stage - 1]) return;
    list[stage - 1] = true;

    final tp = data['totalPoints'];
    final newTotal = (tp is num ? tp.toInt() : 0) + points;

    await ref.update({
      'stageResults.$category': list,
      'totalPoints': newTotal,
    });

    student.stageResults[category] = list;
    student.totalPoints = newTotal;
  }

  Future<void> updateStatus(Student student) async {
    await _levelDoc(student, student.currentLevel).update({'status': '통과'});
    student.status = '통과';
  }

  Future<void> updateKingScore(Student student, int level, int score) async {
    await _studentDoc(student).set({
      'kingScores': {level.toString(): score},
    }, SetOptions(merge: true));
  }

  /// 교사용: 학급 학생 목록 (번호순)
  Future<List<Map<String, dynamic>>> getClassStudents(
      String grade, String classNum) async {
    final qs = await _db.collection('eng_students').doc(grade).collection(classNum).get();
    final result = <Map<String, dynamic>>[];
    for (final doc in qs.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      if (data['name'] == '교사용') continue;
      final levelsSnap = await doc.reference.collection('levels').get();
      final levels = <String, dynamic>{};
      for (final l in levelsSnap.docs) {
        levels[l.id] = l.data();
      }
      data['levels'] = levels;
      result.add(data);
    }
    result.sort((a, b) {
      final na = int.tryParse((a['number'] ?? '0').toString()) ?? 0;
      final nb = int.tryParse((b['number'] ?? '0').toString()) ?? 0;
      return na.compareTo(nb);
    });
    return result;
  }
}

/// 모든 영역을 끝냈는지 확인
bool allCategoriesComplete(Student s) {
  final lv = s.currentLevel;
  final scores = s.scores;
  for (final c in WordData.categories) {
    if ((scores[c] ?? 0) < WordData.getTotalStages(lv)) return false;
  }
  return true;
}
