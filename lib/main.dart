// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

// 앱 전체의 테마 상태를 관리하기 위한 변수
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  // main 함수에서 비동기 작업을 처리하기 위해 필요
  WidgetsFlutterBinding.ensureInitialized();

  // 스플래시 스크린이 하던 초기화 작업을 다시 main으로 가져옴
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting();

  // 저장된 테마 설정을 불러와 적용
  final prefs = await SharedPreferences.getInstance();
  final themeString = prefs.getString('themeMode') ?? 'system';
  if (themeString == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else if (themeString == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: '오롯이교회',
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.pink,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.pink,
            useMaterial3: true,
          ),
          themeMode: currentMode,
          // ⭐ 앱의 첫 화면을 AuthGate로 직접 지정
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
