import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

/// 교사용: 학급 학생들의 Level별 통과 여부·점수·영단어왕 점수 표
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const List<int> _levels = [1, 2, 3, 4];

  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudents());
  }

  Future<void> _loadStudents() async {
    final auth = context.read<AuthProvider>();
    final t = auth.student;
    if (t == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await auth.firebaseService.getClassStudents(t.grade, t.classNum);
      if (!mounted) return;
      setState(() {
        _students = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('교사용 데이터 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '데이터를 불러오지 못했습니다.';
      });
    }
  }

  Map<String, dynamic> _getLevelData(Map<String, dynamic> s, int level) {
    final levels = s['levels'];
    if (levels is Map) {
      final d = levels[level.toString()];
      if (d is Map) return Map<String, dynamic>.from(d);
    }
    return {};
  }

  String _statusText(Map<String, dynamic> s, int level) =>
      (_getLevelData(s, level)['status'] ?? '미통과') == '통과' ? '통과' : 'X';

  String _pointsText(Map<String, dynamic> s, int level) =>
      '${_getLevelData(s, level)['totalPoints'] ?? 0}';

  String _kingText(Map<String, dynamic> s, int level) {
    final k = s['kingScores'];
    if (k is Map && k[level.toString()] != null) return '${k[level.toString()]}';
    return '';
  }

  String _dateText() {
    final now = DateTime.now();
    return '${now.year}년 ${now.month}월 ${now.day}일 현재';
  }

  Future<void> _copyToClipboard() async {
    final t = context.read<AuthProvider>().student;
    if (t == null) return;
    final sb = StringBuffer()
      ..writeln('${t.grade}학년 ${t.classNum}반 - 영어 단어 - 활동 결과표')
      ..writeln(_dateText())
      ..writeln()
      ..write('번호\t이름\t');
    for (final lv in _levels) {
      sb.write('L$lv\t점수\t');
    }
    sb.writeln('왕L1\t왕L2\t왕L3\t왕L4');
    for (final s in _students) {
      sb.write('${s['number'] ?? ''}\t${s['name'] ?? ''}\t');
      for (final lv in _levels) {
        sb.write('${_statusText(s, lv)}\t${_pointsText(s, lv)}\t');
      }
      sb.write(_levels.map((lv) => _kingText(s, lv)).join('\t'));
      sb.write('\n');
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('텍스트가 클립보드에 복사되었습니다')),
    );
  }

  Future<void> _onWillPop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('로그인 화면으로 나갑니다', textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white),
            child: const Text('예'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _cell(String text, double width, {bool bold = false, Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AuthProvider>().student;

    final header = Container(
      color: kPrimary,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _cell('번호', 44, bold: true, color: Colors.white),
          _cell('이름', 70, bold: true, color: Colors.white),
          for (final lv in _levels) ...[
            _cell('L$lv', 44, bold: true, color: Colors.white),
            _cell('점수', 44, bold: true, color: Colors.white),
          ],
          for (final lv in _levels) _cell('왕L$lv', 48, bold: true, color: Colors.white),
        ],
      ),
    );

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (_students.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            const Text('아직 등록된 학생이 없습니다.'),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadStudents,
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 44 + 70 + 4 * 88 + 4 * 48,
            child: Column(
              children: [
                header,
                Expanded(
                  child: ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, i) {
                      final s = _students[i];
                      return Container(
                        color: i.isEven ? Colors.white : Colors.teal.shade50,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            _cell('${s['number'] ?? ''}', 44),
                            _cell('${s['name'] ?? ''}', 70, bold: true),
                            for (final lv in _levels) ...[
                              _cell(_statusText(s, lv), 44,
                                  bold: true,
                                  color: _statusText(s, lv) == '통과'
                                      ? Colors.green
                                      : Colors.redAccent),
                              _cell(_pointsText(s, lv), 44),
                            ],
                            for (final lv in _levels)
                              _cell(_kingText(s, lv), 48, color: Colors.orange.shade800),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _onWillPop,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t == null ? '교사용' : '${t.grade}학년 ${t.classNum}반 - 영어 단어 - 활동 결과표',
                style: const TextStyle(fontSize: 15),
              ),
              Text(_dateText(), style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '텍스트로 복사',
              icon: const Icon(Icons.copy),
              onPressed: _students.isEmpty ? null : _copyToClipboard,
            ),
            IconButton(
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh),
              onPressed: _loadStudents,
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
