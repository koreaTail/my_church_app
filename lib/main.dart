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
import 'firebase_options.dart';

// 앱의 시작점 (Firebase 초기화 추가)
void main() async {
  // main 함수에서 비동기 작업을 처리하기 위해 필요
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 앱 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 한국어 달력 설정을 위해 필요
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
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

  // 하단 탭에 연결될 화면 목록 (방명록 추가!)
  static const List<Widget> _widgetOptions = <Widget>[
    CalendarView(),
    GuestbookScreen(), // 👈 방명록 화면 추가
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
        // 👈 화면 상태를 유지하기 위해 IndexedStack으로 변경
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
            icon: Icon(Icons.chat_bubble_outline), // 👈 방명록 아이콘
            label: '방명록',
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
// ## (신규) 2. 방명록 화면 ##
// ===================================================================
class GuestbookScreen extends StatefulWidget {
  const GuestbookScreen({super.key});

  @override
  State<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends State<GuestbookScreen> {
  final TextEditingController _messageController = TextEditingController();

  // 방명록 메시지를 Firestore에 추가하는 함수
  void _addMessage(BuildContext dialogContext) {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      FirebaseFirestore.instance.collection('guestbook').add({
        'text': message,
        'createdAt': Timestamp.now(), // 현재 시간을 기록
      });
      _messageController.clear(); // 입력창 비우기
      Navigator.of(dialogContext).pop(); // 팝업 닫기
    }
  }

  // 글쓰기 팝업을 띄우는 함수
  void _showAddMessageDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('방명록 작성'),
          content: TextField(
            controller: _messageController,
            decoration: const InputDecoration(hintText: "메시지를 입력하세요"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _messageController.clear();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => _addMessage(dialogContext),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온라인 방명록'),
      ),
      // StreamBuilder: Firestore 데이터를 실시간으로 감지하고 화면을 업데이트
      body: StreamBuilder<QuerySnapshot>(
        // 'guestbook' 컬렉션의 데이터를 'createdAt' 필드 기준으로 내림차순(최신순) 정렬
        stream: FirebaseFirestore.instance
            .collection('guestbook')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 데이터 로딩 중일 때
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 데이터가 없을 때
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('아직 등록된 메시지가 없습니다.'));
          }
          // 데이터가 있을 때 목록을 보여줌
          return ListView(
            padding: const EdgeInsets.only(bottom: 80), // FAB에 가려지지 않도록 패딩 추가
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              return ListTile(
                title: Text(data['text']),
                subtitle: Text(
                  // 타임스탬프 데이터를 날짜/시간 형식으로 변환
                  DateFormat('y년 M월 d일 a h:mm', 'ko')
                      .format((data['createdAt'] as Timestamp).toDate()),
                ),
              );
            }).toList(),
          );
        },
      ),
      // 글쓰기 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMessageDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ===================================================================
// ## 1. 캘린더 화면 (기존 코드와 동일) ##
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
    setState(() {
      _currentMonthCount = count;
    });
  }

  Future<void> _loadMeditatedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getStringList('meditatedDays') ?? [];
    setState(() {
      _meditatedDays = Set.from(savedDays);
    });
    _updateCurrentMonthCount(_focusedDay);
  }

  void _showMeditationDialog(DateTime day) async {
    // mounted 속성 확인을 위해 context를 미리 저장
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final prefs = await SharedPreferences.getInstance();
    final dayString = DateFormat('yyyy-MM-dd').format(day);
    final savedMemo = prefs.getString('${dayString}_memo') ?? '';
    final memoController = TextEditingController(text: savedMemo);
    bool isMeditated = _meditatedDays.contains(dayString);

    if (!mounted) return; // 비동기 작업 후 위젯이 사라졌으면 아무것도 하지 않음

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
                        setDialogState(() {
                          isMeditated = !isMeditated;
                        });
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      if (isMeditated) {
                        _meditatedDays.add(dayString);
                      } else {
                        _meditatedDays.remove(dayString);
                      }
                    });
                    await prefs.setStringList(
                        'meditatedDays', _meditatedDays.toList());
                    await prefs.setString(
                        '${dayString}_memo', memoController.text);
                    _updateCurrentMonthCount(_focusedDay);
                    navigator.pop();
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
              setState(() {
                _focusedDay = DateTime.now();
              });
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
                setState(() {
                  _focusedDay = focusedDay;
                });
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
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
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

// ===================================================================
// ## 3. 교회 소식 화면 (링크 연결 버튼) ##
// ===================================================================
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
      appBar: AppBar(
        title: const Text('교회 소식'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              '교회 주보, 소식 등을 보려면\n아래 버튼을 눌러주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('교회 소식 페이지 열기'),
              onPressed: _launchNotionUrl,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ## 4. 메모 목록 페이지 (기존 코드와 동일) ##
// ===================================================================
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
        tempMemos.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 묵상 기록'),
      ),
      body: _memos.isEmpty
          ? const Center(
              child: Text(
                '아직 작성된 메모가 없습니다.',
                style: TextStyle(fontSize: 16),
              ),
            )
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
                        Text(
                          displayDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          memoContent,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
