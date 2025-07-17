import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // main.dart 파일의 themeNotifier를 가져오기 위함

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 테마 변경을 처리하는 함수
  void _onThemeChanged(ThemeMode? value) async {
    if (value == null) return;

    // setState로 UI를 새로고침하도록 감싸줍니다.
    setState(() {
      // 1. 즉시 UI에 반영
      themeNotifier.value = value;
    });

    // 2. 다음에 앱을 켤 때를 위해 선택사항 저장
    final prefs = await SharedPreferences.getInstance();
    String themeString = 'system';
    if (value == ThemeMode.light)
      themeString = 'light';
    else if (value == ThemeMode.dark) themeString = 'dark';
    await prefs.setString('themeMode', themeString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('라이트 모드'),
            value: ThemeMode.light,
            groupValue: themeNotifier.value,
            onChanged: _onThemeChanged,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('다크 모드'),
            value: ThemeMode.dark,
            groupValue: themeNotifier.value,
            onChanged: _onThemeChanged,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('시스템 설정 따름'),
            value: ThemeMode.system,
            groupValue: themeNotifier.value,
            onChanged: _onThemeChanged,
          ),
        ],
      ),
    );
  }
}
