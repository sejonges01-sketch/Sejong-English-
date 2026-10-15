import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/login_storage.dart';
import 'admin_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<String> _grades = const ['1', '2', '3', '4', '5', '6'];
  final List<String> _classes = const ['믿음', '사랑'];
  final List<int> _levels = WordData.levels;

  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String? _grade;
  String? _classNum;
  int _level = 1;

  /// 로그인 정보 저장 여부 (기본: 저장)
  bool _remember = true;
  bool _loadingSaved = true;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final saved = await LoginStorage.load();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _grade = _grades.contains(saved.grade) ? saved.grade : null;
        _classNum = _classes.contains(saved.classNum) ? saved.classNum : null;
        _numberController.text = saved.number;
        _nameController.text = saved.name;
        _level = _levels.contains(saved.level) ? saved.level : 1;
        _remember = true;
      }
      _loadingSaved = false;
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final number = _numberController.text.trim();
    final name = _nameController.text.trim();
    if (_grade == null || _classNum == null || number.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    if (!firebaseReady && name != '교사용') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버(Firebase) 설정이 아직 안 되어 있습니다. 선생님께 알려 주세요.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_grade!, _classNum!, number, name, _level);
    if (!mounted) return;

    if (ok) {
      if (_remember) {
        await LoginStorage.save(SavedLogin(
          grade: _grade!,
          classNum: _classNum!,
          number: number,
          name: name,
          level: _level,
        ));
      } else {
        await LoginStorage.clear();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => auth.isTeacher ? const AdminScreen() : const MainScreen(),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: kPrimary),
      filled: true,
      fillColor: Colors.teal.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: _decoration(label, icon),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem<T>(value: e, child: Text(itemLabel(e))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = auth.isLoading || _loadingSaved;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimary, Color(0xFF26A69A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const AppTitle(),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '로그인',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: kPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _dropdown<String>(
                              label: '학년',
                              icon: Icons.school,
                              value: _grade,
                              items: _grades,
                              itemLabel: (g) => '$g학년',
                              onChanged: (v) => setState(() => _grade = v),
                            ),
                            const SizedBox(height: 12),
                            _dropdown<String>(
                              label: '반',
                              icon: Icons.groups,
                              value: _classNum,
                              items: _classes,
                              itemLabel: (c) => '$c반',
                              onChanged: (v) => setState(() => _classNum = v),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _numberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: _decoration('번호', Icons.tag),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameController,
                              decoration: _decoration('이름', Icons.person,
                                  hint: '한글 입력'),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => busy ? null : _handleLogin(),
                            ),
                            const SizedBox(height: 12),
                            _dropdown<int>(
                              label: '단계',
                              icon: Icons.workspace_premium,
                              value: _level,
                              items: _levels,
                              itemLabel: (l) => WordData.levelName(l),
                              onChanged: (v) =>
                                  setState(() => _level = v ?? _level),
                            ),
                            const SizedBox(height: 4),
                            CheckboxListTile(
                              value: _remember,
                              onChanged: (v) =>
                                  setState(() => _remember = v ?? false),
                              title: const Text('로그인 정보 저장'),
                              subtitle: const Text(
                                '다음에 앱을 열면 자동으로 채워집니다',
                                style: TextStyle(fontSize: 12),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: busy ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 3),
                                      )
                                    : const Text(
                                        '시작하기',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 앱 제목 (로그인·메인 화면 공용)
class AppTitle extends StatelessWidget {
  final Color color;
  const AppTitle({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.menu_book_rounded, size: 64, color: color),
        const SizedBox(height: 8),
        Text(
          '영어 단어 공부',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          'English Words',
          style: TextStyle(fontSize: 18, color: color.withValues(alpha: 0.85), letterSpacing: 2),
        ),
      ],
    );
  }
}
