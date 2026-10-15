import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  static const Color _teal = Color(0xFF00695C);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    final auth = context.read<AuthProvider>();
    final s = auth.student;
    if (s == null) return;
    setState(() => _loading = true);
    try {
      final fresh = await auth.firebaseService.getOrCreateStudent(
          s.grade, s.classNum, s.number, s.name, s.currentLevel);
      auth.updateStudent(fresh);
    } catch (e) {
      debugPrint('점수 새로고침 실패: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AuthProvider>().student;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('내 점수 보기')),
        body: const Center(child: Text('로그인 정보가 없습니다.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text('내 점수 보기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStudentInfoCard(s),
                      const SizedBox(height: 12),
                      _buildTotalPointsCard(s),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('영역별 진행 상황',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _teal)),
                      ),
                      const SizedBox(height: 8),
                      for (final c in WordData.categories) _buildProgressCard(s, c),
                      const SizedBox(height: 12),
                      _buildKingScoresCard(s),
                      const SizedBox(height: 12),
                      _buildStatusCard(s),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStudentInfoCard(Student s) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: _teal,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(s.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Text('${s.grade}학년 ${s.classNum}반 ${s.number}번'),
        trailing: Text('Level ${s.currentLevel}',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: _teal)),
      ),
    );
  }

  Widget _buildTotalPointsCard(Student s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF26A69A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('누적 활동 점수',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 6),
          Text('${s.totalPoints}점',
              style: const TextStyle(
                  color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressCard(Student s, String category) {
    final total = WordData.getTotalStages(s.currentLevel);
    final passed = s.scores[category] ?? 0;
    final done = total > 0 && passed >= total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(category,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (done)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('완료',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                const SizedBox(width: 8),
                Text('$passed / $total 단계'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: total == 0 ? 0 : passed / total,
              minHeight: 8,
              color: done ? Colors.green : _teal,
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKingScoresCard(Student s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('영단어왕 점수',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final lv in ['1', '2', '3', '4'])
                  Expanded(
                    child: _buildKingScoreItem('Level $lv', s.kingScores[lv] ?? 0),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKingScoreItem(String label, int score) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text('$score점',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF8F00))),
      ],
    );
  }

  Widget _buildStatusCard(Student s) {
    final passed = s.status == '통과';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: passed ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(color: passed ? Colors.green : Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(passed ? Icons.verified : Icons.hourglass_bottom,
              color: passed ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Text(passed ? '전체 통과' : '전체 상태: ${s.status}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.green : Colors.black87)),
        ],
      ),
    );
  }
}
