// lib/main.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart'; // 👈 이 줄을 추가
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
// ## (수정) 앱의 기본 구조 (테마 상태 관리를 위해 StatefulWidget으로 변경) ##
// ===================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system; // 기본 테마는 시스템 설정 따름

  @override
  void initState() {
    super.initState();
    _loadTheme(); // 앱 시작 시 저장된 테마 불러오기
  }

  // 저장된 테마 설정을 불러오는 함수
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';
    setState(() {
      if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  // 테마를 변경하고 앱을 재시작하라는 안내를 보여주는 함수
  void _changeTheme(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeString = 'system';
    if (themeMode == ThemeMode.light) {
      themeString = 'light';
    } else if (themeMode == ThemeMode.dark) {
      themeString = 'dark';
    }

    await prefs.setString('themeMode', themeString);

    // UI를 즉시 업데이트하고 사용자에게 재시작 안내
    setState(() {
      _themeMode = themeMode;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테마가 변경되었습니다. 앱을 다시 시작하면 완벽하게 적용됩니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '묵상 달력',
      // ⭐ 1. 라이트/다크 테마 정의
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.pink,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.pink,
        // 다크 모드에 어울리는 다른 색상들을 여기에 추가할 수 있습니다.
      ),
      // ⭐ 2. 현재 설정된 테마 모드를 적용
      themeMode: _themeMode,
      // 앱의 첫 화면을 AuthGate로 설정
      home: AuthGate(changeTheme: _changeTheme), // 👈 테마 변경 함수 전달
      debugShowCheckedModeBanner: false,
    );
  }
}

// ===================================================================
// ## AuthGate (테마 변경 함수를 전달받도록 수정) ##
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
        return MainScreen(changeTheme: changeTheme); // 👈 MainScreen에 함수 전달
      },
    );
  }
}

// 이하 생략된 코드는 이전과 동일합니다.
// (기존의 LoginScreen, MainScreen, CalendarView 등 모든 코드가 포함되어 있습니다)
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
      CalendarView(changeTheme: widget.changeTheme), // 👈 CalendarView에 함수 전달
      GuestbookScreen(),
      NotionLinkScreen(),
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
        items: const <BottomNavigationBarItem>[
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
// ## 캘린더 화면 (설정 버튼 추가 및 테마 변경 함수 전달받기) ##
// ===================================================================
class CalendarView extends StatefulWidget {
  final Function(ThemeMode) changeTheme;
  const CalendarView({super.key, required this.changeTheme});
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  // ...(이하 캘린더 화면의 기존 코드는 생략)...
  DateTime _focusedDay = DateTime.now();
  Set<String> _meditatedDays = {};
  int _currentMonthCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMeditatedDays();
  }

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

  void _showMeditationDialog(DateTime day) async {
    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    final dayString = DateFormat('yyyy-MM-dd').format(day);
    final savedMemo = prefs.getString('${dayString}_memo') ?? '';
    final memoController = TextEditingController(text: savedMemo);
    bool isMeditated = _meditatedDays.contains(dayString);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(DateFormat('M월 d일').format(day)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isMeditated ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 50,
                      ),
                      onPressed: () {
                        setDialogState(() => isMeditated = !isMeditated);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(isMeditated ? "묵상 완료!" : "묵상했나요?"),
                    const SizedBox(height: 20),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        hintText: "깨달음이나 기도를 메모해보세요.",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    if (mounted) {
                      setState(() {
                        if (isMeditated) {
                          _meditatedDays.add(dayString);
                        } else {
                          _meditatedDays.remove(dayString);
                        }
                      });
                    }
                    await prefs.setStringList(
                        'meditatedDays', _meditatedDays.toList());
                    await prefs.setString(
                        '${dayString}_memo', memoController.text);
                    _updateCurrentMonthCount(_focusedDay);
                    if (mounted) navigator.pop();
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
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
              },
            ),
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MemoListPage()),
                );
              },
            ),
            // ⭐ 3. 설정 페이지로 이동하는 아이콘 버튼 추가
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SettingsScreen(changeTheme: widget.changeTheme)),
                );
              },
            ),
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
              })),
          Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.favorite, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('+$_currentMonthCount',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))
              ]))
        ])));
  }
}

// ===================================================================
// ## (신규) 설정 화면 ##
// ===================================================================
class SettingsScreen extends StatefulWidget {
  // 테마 변경 함수를 상위 위젯으로부터 전달받음
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

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';
    setState(() {
      if (themeString == 'light') {
        _currentTheme = ThemeMode.light;
      } else if (themeString == 'dark') {
        _currentTheme = ThemeMode.dark;
      } else {
        _currentTheme = ThemeMode.system;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('라이트 모드'),
            value: ThemeMode.light,
            groupValue: _currentTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                setState(() => _currentTheme = value);
                widget.changeTheme(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('다크 모드'),
            value: ThemeMode.dark,
            groupValue: _currentTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                setState(() => _currentTheme = value);
                widget.changeTheme(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('시스템 설정 따름'),
            value: ThemeMode.system,
            groupValue: _currentTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                setState(() => _currentTheme = value);
                widget.changeTheme(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

// (기도제목, 교회소식, 메모 목록 페이지 코드는 이전과 동일합니다.)
class GuestbookScreen extends StatefulWidget {
  const GuestbookScreen({super.key});
  @override
  State<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends State<GuestbookScreen> {
  void _showAddMessageDialog() {
    final messageController = TextEditingController();
    showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
              title: const Text('기도제목 작성'),
              content: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(hintText: "기도제목을 입력하세요"),
                  autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () async {
                      final message = messageController.text;
                      final user = FirebaseAuth.instance.currentUser;
                      if (message.isNotEmpty && user != null) {
                        await FirebaseFirestore.instance
                            .collection('guestbook')
                            .add({
                          'text': message,
                          'createdAt': Timestamp.now(),
                          'authorName': user.displayName ?? '이름없음',
                          'authorUid': user.uid
                        });
                        if (mounted) Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('저장'))
              ]);
        });
  }

  void _showDeleteConfirmDialog(String docId) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              title: const Text('삭제 확인'),
              content: const Text('이 기도제목을 정말로 삭제하시겠습니까?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('guestbook')
                          .doc(docId)
                          .delete();
                      if (mounted) Navigator.of(context).pop();
                    },
                    child:
                        const Text('삭제', style: TextStyle(color: Colors.red)))
              ]);
        });
  }

  void _showEditMessageDialog(String docId, String existingText) {
    final messageController = TextEditingController(text: existingText);
    showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
              title: const Text('기도제목 수정'),
              content: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(hintText: "수정할 내용을 입력하세요"),
                  autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () async {
                      final newText = messageController.text;
                      if (newText.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('guestbook')
                            .doc(docId)
                            .update({'text': newText});
                        if (mounted) Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('수정'))
              ]);
        });
  }

  @override
  Widget build(BuildContext context) {
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
// ## (재수정) 2. 교회 소식 화면 (WebView 방식) ##
// ===================================================================
class NotionLinkScreen extends StatefulWidget {
  const NotionLinkScreen({super.key});

  @override
  State<NotionLinkScreen> createState() => _NotionLinkScreenState();
}

class _NotionLinkScreenState extends State<NotionLinkScreen> {
  // 웹뷰를 제어하기 위한 컨트롤러
  late final WebViewController _controller;
  // 로딩 상태를 표시하기 위한 변수
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 웹뷰 컨트롤러 초기화 및 노션 링크 로드
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // 페이지 로딩이 끝나면 로딩 표시를 없앰
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(
          'https://orosi.notion.site/1dc6f70e570c4a36bcf66dc7efb04318'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교회 소식'),
      ),
      // Stack을 사용해 로딩 인디케이터와 웹뷰를 겹쳐서 보여줌
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // 로딩 중일 때만 로딩 인디케이터를 보여줌
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class MemoListPage extends StatefulWidget {
  const MemoListPage({super.key});
  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  Map<String, String> _memos = {};
  @override
  void initState() {
    super.initState();
    _loadAllMemos();
  }

  Future<void> _loadAllMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, String> tempMemos = {};
    for (String key in allKeys) {
      if (key.endsWith('_memo')) {
        final memoContent = prefs.getString(key) ?? '';
        if (memoContent.isNotEmpty) {
          final dateString = key.replaceAll('_memo', '');
          tempMemos[dateString] = memoContent;
        }
      }
    }
    setState(() {
      _memos = Map.fromEntries(
          tempMemos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
    });
  }

  @override
  Widget build(BuildContext context) {
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
