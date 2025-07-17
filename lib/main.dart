// lib/main.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart'; // 웹뷰 import
import 'firebase_options.dart';

// 앱의 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

// ===================================================================
// ## 앱의 기본 구조 (테마 상태 관리) ##
// ===================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';
    if (mounted) {
      setState(() {
        if (themeString == 'light')
          _themeMode = ThemeMode.light;
        else if (themeString == 'dark')
          _themeMode = ThemeMode.dark;
        else
          _themeMode = ThemeMode.system;
      });
    }
  }

  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _saveTheme(themeMode);
  }

  Future<void> _saveTheme(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeString = 'system';
    if (themeMode == ThemeMode.light)
      themeString = 'light';
    else if (themeMode == ThemeMode.dark) themeString = 'dark';
    await prefs.setString('themeMode', themeString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '묵상 달력',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.pink,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.pink,
      ),
      themeMode: _themeMode,
      home: AuthGate(changeTheme: _changeTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ===================================================================
// ## AuthGate, LoginScreen (기존과 동일) ##
// ===================================================================
class AuthGate extends StatelessWidget {
  final Function(ThemeMode) changeTheme;
  const AuthGate({super.key, required this.changeTheme});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        return MainScreen(changeTheme: changeTheme);
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      print('구글 로그인 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('묵상 달력에 오신 것을 환영합니다!', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signInWithGoogle,
              child: const Text('Google 계정으로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ## 메인 스크린 (탭 4개로 구성) ##
// ===================================================================
class MainScreen extends StatefulWidget {
  final Function(ThemeMode) changeTheme;
  const MainScreen({super.key, required this.changeTheme});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const VideoScreen(),
      CalendarView(changeTheme: widget.changeTheme),
      const GuestbookScreen(),
      const NotionWebViewScreen(), // 👈 웹뷰 화면으로 복구
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            label: '오늘의 영상',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '묵상달력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '기도제목',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: '교회소식',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ===================================================================
// ## 오늘의 영상 화면 ##
// ===================================================================
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late YoutubePlayerController _controller;

  final String _videoUrl = 'https://www.youtube.com/watch?v=Ev7sNUK9stM';
  final String _videoTitle = '은혜를 대하는 자세 (사 12:1-6)';
  final String _videoPublishedDate = '2025년 7월 17일 목요일';

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(_videoUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        enableCaption: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 10분 메시지'),
        actions: [
          if (FirebaseAuth.instance.currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
            ),
            const SizedBox(height: 16),
            Text(_videoTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_videoPublishedDate,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ## (수정) 캘린더 화면 (묵상 완료 기능 복구) ##
// ===================================================================
class CalendarView extends StatefulWidget {
  final Function(ThemeMode) changeTheme;
  const CalendarView({super.key, required this.changeTheme});
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  Set<String> _meditatedDays = {};
  int _currentMonthCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMeditatedDays();
  }

  // 현재 달의 묵상 횟수를 계산하는 함수
  void _updateCurrentMonthCount(DateTime focusedDay) {
    int count = 0;
    for (String dayString in _meditatedDays) {
      DateTime date = DateTime.parse(dayString);
      if (date.year == focusedDay.year && date.month == focusedDay.month) {
        count++;
      }
    }
    if (mounted) setState(() => _currentMonthCount = count);
  }

  // 저장된 묵상 기록을 불러오는 함수
  Future<void> _loadMeditatedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getStringList('meditatedDays') ?? [];
    if (mounted) {
      setState(() {
        _meditatedDays = Set.from(savedDays);
      });
      _updateCurrentMonthCount(_focusedDay);
    }
  }

  // 묵상 기록 팝업을 띄우고 결과를 처리하는 함수
  void _showMeditationDialog(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final dayString = DateFormat('yyyy-MM-dd').format(day);
    final savedMemo = prefs.getString('${dayString}_memo') ?? '';
    final memoController = TextEditingController(text: savedMemo);
    bool isMeditated = _meditatedDays.contains(dayString);

    // 팝업이 닫힐 때의 결과(true/false)를 기다림
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(DateFormat('M월 d일').format(day)),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(
                        isMeditated ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 50),
                    onPressed: () =>
                        setDialogState(() => isMeditated = !isMeditated),
                  ),
                  const SizedBox(height: 10),
                  Text(isMeditated ? "묵상 완료!" : "묵상했나요?"),
                  const SizedBox(height: 20),
                  TextField(
                    controller: memoController,
                    decoration: const InputDecoration(
                        hintText: "깨달음이나 기도를 메모해보세요.",
                        border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    await prefs.setString(
                        '${dayString}_memo', memoController.text);
                    // '저장' 버튼은 하트의 현재 상태(isMeditated)를 결과로 반환
                    Navigator.of(context).pop(isMeditated);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    // 팝업이 닫힌 후에, '저장' 버튼을 눌렀을 때만 (결과가 null이 아닐 때만) 상태 업데이트
    if (result != null) {
      setState(() {
        if (result) {
          _meditatedDays.add(dayString);
        } else {
          _meditatedDays.remove(dayString);
        }
      });
      // 최종 결과를 스마트폰에 저장
      await prefs.setStringList('meditatedDays', _meditatedDays.toList());
      _updateCurrentMonthCount(_focusedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('묵상 달력'),
        actions: [
          IconButton(
              icon: const Icon(Icons.today),
              onPressed: () {
                setState(() => _focusedDay = DateTime.now());
                _updateCurrentMonthCount(DateTime.now());
              }),
          IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                // 이 부분은 나중에 파일 분리 후 MemoListPage()를 import 해야 합니다.
                // 지금은 오류가 날 수 있지만, 다음 단계에서 해결됩니다.
                // Navigator.push(context,
                //     MaterialPageRoute(builder: (context) => const MemoListPage()));
              }),
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // 이 부분도 나중에 SettingsScreen()을 import 해야 합니다.
                // Navigator.push(
                //     context,
                //     MaterialPageRoute(
                //         builder: (context) =>
                //             SettingsScreen(changeTheme: widget.changeTheme)));
              }),
        ],
      ),
      body: SingleChildScrollView(
          child: Column(children: [
        TableCalendar(
          locale: 'ko_KR',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.utc(2032, 12, 31),
          focusedDay: _focusedDay,
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            _updateCurrentMonthCount(focusedDay);
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() => _focusedDay = focusedDay);
            _showMeditationDialog(selectedDay);
          },
          calendarBuilders:
              CalendarBuilders(defaultBuilder: (context, day, focusedDay) {
            final dayString = DateFormat('yyyy-MM-dd').format(day);
            if (_meditatedDays.contains(dayString)) {
              return const Center(
                  child: Icon(Icons.favorite, color: Colors.red));
            }
            return null;
          }, todayBuilder: (context, day, focusedDay) {
            final dayString = DateFormat('yyyy-MM-dd').format(day);
            return Container(
                margin: const EdgeInsets.all(4.0),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Colors.black26, shape: BoxShape.circle),
                child: _meditatedDays.contains(dayString)
                    ? const Icon(Icons.favorite, color: Colors.red)
                    : Text(day.day.toString(),
                        style: const TextStyle(color: Colors.white)));
          }),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('+$_currentMonthCount',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))
            ]))
      ])),
    );
  }
}

// ===================================================================
// ## 기도제목 화면 (기존과 동일) ##
// ===================================================================
class GuestbookScreen extends StatefulWidget {
  const GuestbookScreen({super.key});
  @override
  State<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends State<GuestbookScreen> {
  // (기도제목 관련 로직은 이전과 동일)
  void _showAddMessageDialog() {/* ... */}
  void _showDeleteConfirmDialog(String docId) {/* ... */}
  void _showEditMessageDialog(String docId, String existingText) {/* ... */}

  @override
  Widget build(BuildContext context) {
    // (UI 부분은 이전과 동일)
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
        appBar: AppBar(title: const Text('오롯이 기도제목'), actions: [
          if (user != null)
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                })
        ]),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guestbook')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('아직 등록된 기도제목이 없습니다.'));
              }
              return ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children:
                      snapshot.data!.docs.map((DocumentSnapshot document) {
                    Map<String, dynamic> data =
                        document.data()! as Map<String, dynamic>;
                    final authorName = data['authorName'] ?? '익명';
                    final authorUid = data['authorUid'];
                    final bool isMine = (user != null && user.uid == authorUid);
                    return ListTile(
                        title: Text(data['text']),
                        subtitle: Text(
                            '$authorName · ${DateFormat('y. M. d. a h:mm', 'ko').format((data['createdAt'] as Timestamp).toDate())}'),
                        trailing: isMine
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () {
                                      _showEditMessageDialog(
                                          document.id, data['text']);
                                    }),
                                IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () {
                                      _showDeleteConfirmDialog(document.id);
                                    })
                              ])
                            : null);
                  }).toList());
            }),
        floatingActionButton: user != null
            ? FloatingActionButton(
                onPressed: _showAddMessageDialog, child: const Icon(Icons.add))
            : null);
  }
}

// ===================================================================
// ## 교회 소식 화면 (WebView 방식으로 복구) ##
// ===================================================================
class NotionWebViewScreen extends StatefulWidget {
  const NotionWebViewScreen({super.key});
  @override
  State<NotionWebViewScreen> createState() => _NotionWebViewScreenState();
}

class _NotionWebViewScreenState extends State<NotionWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(
          'https://orosi.notion.site/1dc6f70e570c4a36bcf66dc7efb04318'));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('교회 소식')),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ## 설정 화면 ##
// ===================================================================
class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) changeTheme;
  const SettingsScreen({super.key, required this.changeTheme});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _currentTheme = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  void _loadCurrentTheme() async {/* ... */}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
              title: const Text('라이트 모드'),
              value: ThemeMode.light,
              groupValue: _currentTheme,
              onChanged: (v) => _onThemeChanged(v)),
          RadioListTile<ThemeMode>(
              title: const Text('다크 모드'),
              value: ThemeMode.dark,
              groupValue: _currentTheme,
              onChanged: (v) => _onThemeChanged(v)),
          RadioListTile<ThemeMode>(
              title: const Text('시스템 설정 따름'),
              value: ThemeMode.system,
              groupValue: _currentTheme,
              onChanged: (v) => _onThemeChanged(v)),
        ],
      ),
    );
  }

  void _onThemeChanged(ThemeMode? value) {
    if (value != null) {
      setState(() => _currentTheme = value);
      widget.changeTheme(value);
    }
  }
}

// ===================================================================
// ## 메모 목록 페이지 ##
// ===================================================================
class MemoListPage extends StatefulWidget {
  const MemoListPage({super.key});
  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  // (메모 목록 관련 로직은 이전과 동일)
  Map<String, String> _memos = {};
  @override
  void initState() {
    super.initState();
    _loadAllMemos();
  }

  Future<void> _loadAllMemos() async {/* ... */}

  @override
  Widget build(BuildContext context) {
    // (UI 부분은 이전과 동일)
    return Scaffold(
        appBar: AppBar(title: const Text('나의 묵상 기록')),
        body: _memos.isEmpty
            ? const Center(
                child: Text('아직 작성된 메모가 없습니다.', style: TextStyle(fontSize: 16)))
            : ListView.builder(
                itemCount: _memos.length,
                itemBuilder: (context, index) {
                  final dateString = _memos.keys.elementAt(index);
                  final memoContent = _memos.values.elementAt(index);
                  final displayDate =
                      DateFormat('y년 M월 d일').format(DateTime.parse(dateString));
                  return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayDate,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 8),
                                Text(memoContent,
                                    style: const TextStyle(fontSize: 14))
                              ])));
                }));
  }
}
