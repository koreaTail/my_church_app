// lib/main.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'firebase_options.dart';

// 앱 전체의 테마 상태를 관리하기 위한 전역 변수
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 앱 시작 시 저장된 테마 설정을 불러와 적용
  final prefs = await SharedPreferences.getInstance();
  final themeString = prefs.getString('themeMode') ?? 'system';
  if (themeString == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else if (themeString == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  }

  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder를 사용해 테마 변경을 실시간으로 감지
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
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ===================================================================
// ## 화면 위젯들 ##
// 아래는 각 화면을 구성하는 위젯들입니다.
// ===================================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        return const MainScreen();
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
      debugPrint('구글 로그인 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('오롯이교회 앱에 오신 것을 환영합니다!', style: TextStyle(fontSize: 20)),
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
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    VideoScreen(),
    CalendarView(),
    GuestbookScreen(),
    NotionWebViewScreen(),
  ];

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
              icon: Icon(Icons.play_circle_outline), label: '오늘의 영상'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: '묵상달력'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: '기도제목'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: '교회소식'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ===================================================================
// ## (수정) 오늘의 영상 화면 (오류 방지 코드 추가) ##
// ===================================================================
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  // 1. 컨트롤러를 나중에 초기화할 수 있도록 'late' 대신 'nullable'(?)로 변경
  YoutubePlayerController? _controller;

  // ⭐ 여기에 실제 유튜브 영상의 주소를 복사해서 붙여넣으세요! ⭐
  final String _videoUrl = 'https://www.youtube.com/watch?v=Ev7sNUK9stM';
  final String _videoTitle = '은혜를 대하는 자세 (사 12:1-6)';
  final String _videoPublishedDate = '2025년 7월 17일 목요일';

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(_videoUrl);

    // 2. videoId가 정상적으로 추출되었을 때만 컨트롤러를 초기화합니다.
    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId, // ! 연산자 제거
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          enableCaption: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    // 3. 컨트롤러가 생성되었을 때만 dispose를 호출
    _controller?.dispose();
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4. 컨트롤러가 정상적으로 생성되었을 때만 플레이어를 보여줌
              if (_controller != null)
                YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                )
              else
                // 영상 주소가 잘못되었을 때 안내 메시지 표시
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Text(
                      '유튜브 영상 주소가 올바르지 않습니다.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(_videoTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_videoPublishedDate,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// ## 캘린더 화면 (버튼 기능 복구) ##
// ===================================================================
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});
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
    final prefs = await SharedPreferences.getInstance();
    final dayString = DateFormat('yyyy-MM-dd').format(day);
    final savedMemo = prefs.getString('${dayString}_memo') ?? '';
    final memoController = TextEditingController(text: savedMemo);
    bool isMeditated = _meditatedDays.contains(dayString);

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

    if (result != null) {
      setState(() {
        if (result) {
          _meditatedDays.add(dayString);
        } else {
          _meditatedDays.remove(dayString);
        }
      });
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
            },
          ),
          // ⭐ '나의 묵상 기록' 버튼 기능 복구
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemoListPage()),
              );
            },
          ),
          // ⭐ '설정' 버튼 기능 복구
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final dayString = DateFormat('yyyy-MM-dd').format(day);
                  if (_meditatedDays.contains(dayString)) {
                    return const Center(
                        child: Icon(Icons.favorite, color: Colors.red));
                  }
                  return null;
                },
                todayBuilder: (context, day, focusedDay) {
                  final dayString = DateFormat('yyyy-MM-dd').format(day);
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: Colors.black26, shape: BoxShape.circle),
                    child: _meditatedDays.contains(dayString)
                        ? const Icon(Icons.favorite, color: Colors.red)
                        : Text(day.day.toString(),
                            style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+$_currentMonthCount',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuestbookScreen extends StatefulWidget {
  const GuestbookScreen({super.key});
  @override
  State<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends State<GuestbookScreen> {
  // 글쓰기 팝업을 띄우는 함수
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
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final message = messageController.text;
                final user = FirebaseAuth.instance.currentUser;
                if (message.isNotEmpty && user != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('guestbook')
                        .add({
                      'text': message,
                      'createdAt': Timestamp.now(),
                      'authorName': user.displayName ?? '이름없음',
                      'authorUid': user.uid,
                    });
                    if (mounted) Navigator.of(dialogContext).pop();
                  } catch (e) {
                    debugPrint('메시지 저장 중 에러 발생: $e');
                  }
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  // 삭제 확인 팝업을 띄우는 함수
  void _showDeleteConfirmDialog(String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('이 기도제목을 정말로 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('guestbook')
                      .doc(docId)
                      .delete();
                  if (mounted) Navigator.of(dialogContext).pop();
                } catch (e) {
                  debugPrint('메시지 삭제 중 에러 발생: $e');
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 수정 팝업을 띄우는 함수
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
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final newText = messageController.text;
                if (newText.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('guestbook')
                        .doc(docId)
                        .update({'text': newText});
                    if (mounted) Navigator.of(dialogContext).pop();
                  } catch (e) {
                    debugPrint('메시지 수정 중 에러 발생: $e');
                  }
                }
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('오롯이 기도제목'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
              },
            )
        ],
      ),
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
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              final authorName = data['authorName'] ?? '익명';
              final authorUid = data['authorUid'];
              final isMine = (user != null && user.uid == authorUid);

              return ListTile(
                title: Text(data['text']),
                subtitle: Text(
                  '$authorName · ${DateFormat('y. M. d. a h:mm', 'ko').format((data['createdAt'] as Timestamp).toDate())}',
                ),
                trailing: isMine
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditMessageDialog(
                                document.id, data['text']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () =>
                                _showDeleteConfirmDialog(document.id),
                          ),
                        ],
                      )
                    : null,
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: user != null
          ? FloatingActionButton(
              onPressed: _showAddMessageDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

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
        body: Stack(children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 현재 테마 설정을 저장하고 UI에 반영하기 위한 함수들
  void _onThemeChanged(ThemeMode? value) async {
    if (value == null) return;
    themeNotifier.value = value; // 전역 변수 값 변경해서 즉시 UI 반영
    final prefs = await SharedPreferences.getInstance();
    String themeString = 'system';
    if (value == ThemeMode.light)
      themeString = 'light';
    else if (value == ThemeMode.dark) themeString = 'dark';
    await prefs.setString('themeMode', themeString); // 변경사항 저장
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('라이트 모드'), value: ThemeMode.light,
            groupValue: themeNotifier.value, // 전역 변수 값으로 현재 상태 확인
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
      // 키가 '_memo'로 끝나는 메모 데이터만 골라냄
      if (key.endsWith('_memo')) {
        final memoContent = prefs.getString(key) ?? '';
        // 내용이 비어있지 않은 메모만 목록에 추가
        if (memoContent.isNotEmpty) {
          final dateString = key.replaceAll('_memo', '');
          tempMemos[dateString] = memoContent;
        }
      }
    }

    // 화면에 반영 (최신 날짜가 위로 오도록 정렬)
    if (mounted) {
      setState(() {
        _memos = Map.fromEntries(
          tempMemos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('나의 묵상 기록')),
      body: _memos.isEmpty
          ? const Center(child: Text('아직 작성된 메모가 없습니다.'))
          : ListView.builder(
              itemCount: _memos.length,
              itemBuilder: (context, index) {
                final dateString = _memos.keys.elementAt(index);
                final memoContent = _memos.values.elementAt(index);
                final displayDate =
                    DateFormat('y년 M월 d일').format(DateTime.parse(dateString));
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayDate,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(memoContent),
                        ]),
                  ),
                );
              },
            ),
    );
  }
}
