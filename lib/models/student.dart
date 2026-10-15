import 'word_data.dart';

/// Level별 학습 기록 (Firestore: eng_students/{학년}/{반}/{번호_이름}/levels/{Level})
class LevelData {
  /// 영역별 단계 통과 여부. 예) {'철자쓰기': [true, true, false]}
  final Map<String, List<bool>> stageResults;
  int totalPoints;
  String status;

  LevelData({
    Map<String, List<bool>>? stageResults,
    this.totalPoints = 0,
    this.status = '미통과',
  }) : stageResults =
            stageResults ?? {for (final c in WordData.categories) c: <bool>[]};

  factory LevelData.fromMap(Map<String, dynamic> map) {
    final raw = map['stageResults'];
    final results = <String, List<bool>>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) {
          results[key.toString()] = value.map((e) => e == true).toList();
        }
      });
    }
    for (final c in WordData.categories) {
      results.putIfAbsent(c, () => <bool>[]);
    }
    final tp = map['totalPoints'];
    return LevelData(
      stageResults: results,
      totalPoints: tp is num ? tp.toInt() : 0,
      status: (map['status'] as String?) ?? '미통과',
    );
  }

  Map<String, dynamic> toMap() => {
        'stageResults':
            stageResults.map((k, v) => MapEntry(k, List<bool>.from(v))),
        'totalPoints': totalPoints,
        'status': status,
      };

  /// 해당 영역에서 통과한 단계 수
  int passedStages(String category) =>
      (stageResults[category] ?? const <bool>[]).where((b) => b).length;

  Map<String, int> get scores =>
      {for (final c in WordData.categories) c: passedStages(c)};

  bool isStagePassed(String category, int stage) {
    final list = stageResults[category] ?? const <bool>[];
    return stage >= 1 && stage <= list.length && list[stage - 1];
  }
}

class Student {
  final String grade;
  final String classNum;
  final String number;
  final String name;
  final int currentLevel;
  final Map<int, LevelData> levels;
  final Map<String, int> kingScores;

  Student(
    this.grade,
    this.classNum,
    this.number,
    this.name, {
    this.currentLevel = 1,
    Map<int, LevelData>? levels,
    Map<String, int>? kingScores,
  })  : levels = levels ?? {for (final lv in WordData.levels) lv: LevelData()},
        kingScores = kingScores ?? {'1': 0, '2': 0, '3': 0, '4': 0};

  factory Student.fromMap(
    Map<String, dynamic> map, {
    required int currentLevel,
    Map<int, LevelData>? levels,
  }) {
    return Student(
      (map['grade'] ?? '').toString(),
      (map['classNum'] ?? '').toString(),
      (map['number'] ?? '').toString(),
      (map['name'] ?? '').toString(),
      currentLevel: currentLevel,
      levels: levels,
      kingScores: parseKingScores(map['kingScores']),
    );
  }

  static Map<String, int> parseKingScores(dynamic raw) {
    final result = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0};
    if (raw is Map) {
      for (final k in ['1', '2', '3', '4']) {
        final v = raw[k];
        if (v is num) {
          result[k] = v.toInt();
        } else if (v != null) {
          result[k] = int.tryParse(v.toString()) ?? 0;
        }
      }
    }
    return result;
  }

  Map<String, dynamic> toMap() => {
        'grade': grade,
        'classNum': classNum,
        'number': number,
        'name': name,
        'kingScores': Map<String, int>.from(kingScores),
      };

  /// Firestore 문서 ID: "번호_이름"
  String get docId => '${number}_$name';

  LevelData get currentLevelData =>
      levels.putIfAbsent(currentLevel, () => LevelData());

  Map<String, int> get scores => currentLevelData.scores;
  Map<String, List<bool>> get stageResults => currentLevelData.stageResults;

  int get totalPoints => currentLevelData.totalPoints;
  set totalPoints(int v) => currentLevelData.totalPoints = v;

  String get status => currentLevelData.status;
  set status(String v) => currentLevelData.status = v;
}
