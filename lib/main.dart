// lib/main.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// Firebase 관련 패키지 import
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 Firebase 인증
import 'package:google_sign_in/google_sign_in.dart'; // 👈 구글 사인인
import 'firebase_options.dart';

// 앱의 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

// 앱의 기본 구조
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '묵상 달력',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      // 앱의 첫 화면을 AuthGate로 변경
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ===================================================================
// ## (신규) AuthGate: 로그인 상태에 따라 화면을 결정하는 관문 ##
// ===================================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebase의 인증 상태 변경을 실시간으로 감지
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 로그인 상태가 아니면 로그인 화면을 보여줌
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        // 로그인 상태이면 메인 화면을 보여줌
        return const MainScreen();
      },
    );
  }
}

// ===================================================================
// ## (신규) 로그인 화면 ##
// ===================================================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // 구글 로그인 처리 함수
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
            // 구글 로그인 버튼
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

// (이하 기존 코드는 생략... 아래 전체 코드를 복사해서 사용하세요)
// (기존의 MainScreen, CalendarView, GuestbookScreen 등 모든 코드가 포함되어 있습니다)
// ===================================================================
// ## 하단 네비게이션 바와 화면 전체를 관리하는 메인 스크린 ##
// ===================================================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    CalendarView(),
    GuestbookScreen(),
    NotionLinkScreen(),
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '묵상달력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '기도제목', // '방명록'에서 '기도제목'으로 변경
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
// ## (수정) 2. 기도제목 화면 (삭제 기능 구현) ##
// ===================================================================
class GuestbookScreen extends StatefulWidget {
  const GuestbookScreen({super.key});

  @override
  State<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends State<GuestbookScreen> {
  // 글쓰기 팝업을 띄우는 함수 (기존과 동일)
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
                  await FirebaseFirestore.instance.collection('guestbook').add({
                    'text': message,
                    'createdAt': Timestamp.now(),
                    'authorName': user.displayName ?? '이름없음',
                    'authorUid': user.uid,
                  });
                  if (mounted) Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  // ================================================
  // ⭐ 1. (신규) 삭제 확인 팝업을 띄우는 함수
  // ================================================
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
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                // Firestore에서 해당 ID의 문서를 삭제
                await FirebaseFirestore.instance
                    .collection('guestbook')
                    .doc(docId)
                    .delete();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // ================================================
  // ⭐ 1. (신규) 수정 팝업을 띄우는 함수
  // ================================================
  void _showEditMessageDialog(String docId, String existingText) {
    // 텍스트 컨트롤러에 기존 내용을 미리 채워둠
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
                  // Firestore에서 해당 ID의 문서를 찾아 'text' 필드를 업데이트
                  await FirebaseFirestore.instance
                      .collection('guestbook')
                      .doc(docId)
                      .update({'text': newText});
                  if (mounted) Navigator.of(dialogContext).pop();
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
            ),
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
              final bool isMine = (user != null && user.uid == authorUid);

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
                            onPressed: () {
                              _showEditMessageDialog(document.id, data['text']);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            // ================================================
                            // ⭐ 2. 삭제 버튼에 새로운 함수 연결
                            // ================================================
                            onPressed: () {
                              // document.id는 Firestore의 각 문서가 가진 고유 ID입니다.
                              _showDeleteConfirmDialog(document.id);
                            },
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
// (이하 캘린더, 메모 목록, 교회소식 화면 코드는 이전과 거의 동일합니다)

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

class NotionLinkScreen extends StatelessWidget {
  const NotionLinkScreen({super.key});
  Future<void> _launchNotionUrl() async {
    final Uri url =
        Uri.parse('https://orosi.notion.site/1dc6f70e570c4a36bcf66dc7efb04318');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('교회 소식')),
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.article_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('교회 주보, 소식 등을 보려면\n아래 버튼을 눌러주세요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('교회 소식 페이지 열기'),
              onPressed: _launchNotionUrl,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16)))
        ])));
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
