// lib/main.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// 앱의 시작점
void main() {
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
      home: const CalendarView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 캘린더 화면 (메인 화면)
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  Set<String> _meditatedDays = {};

  @override
  void initState() {
    super.initState();
    _loadMeditatedDays();
  }

  Future<void> _loadMeditatedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getStringList('meditatedDays') ?? [];
    setState(() {
      _meditatedDays = Set.from(savedDays);
    });
  }

  void _showMeditationDialog(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final dayString = DateFormat('yyyy-MM-dd').format(day);
    final savedMemo = prefs.getString('${dayString}_memo') ?? '';
    final memoController = TextEditingController(text: savedMemo);
    bool isMeditated = _meditatedDays.contains(dayString);

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
                        hintText: "오늘의 깨달음을 메모하세요...",
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
                    Navigator.of(context).pop();
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
          // '오늘' 날짜로 이동하는 버튼
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
              });
            },
          ),
          // '메모 목록' 페이지로 이동하는 버튼 (새로 추가!)
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
      body: TableCalendar(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2022, 1, 1),
        lastDay: DateTime.utc(2032, 12, 31),
        focusedDay: _focusedDay,
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
    );
  }
}

// -------------------------------------------------------------------
// ## 메모 목록 페이지 (새로 추가된 부분) ##
// -------------------------------------------------------------------
class MemoListPage extends StatefulWidget {
  const MemoListPage({super.key});

  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  // 메모 데이터를 저장할 Map (예: '2025-07-15': '오늘의 메모 내용')
  Map<String, String> _memos = {};

  @override
  void initState() {
    super.initState();
    _loadAllMemos();
  }

  // 저장된 모든 메모를 불러오는 함수
  Future<void> _loadAllMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys(); // 스마트폰에 저장된 모든 키를 가져옴
    final Map<String, String> tempMemos = {};

    for (String key in allKeys) {
      // 키가 '_memo'로 끝나는 경우에만 (메모 데이터인 경우에만)
      if (key.endsWith('_memo')) {
        final memoContent = prefs.getString(key) ?? '';
        // 메모 내용이 비어있지 않은 경우에만 목록에 추가
        if (memoContent.isNotEmpty) {
          final dateString = key.replaceAll('_memo', '');
          tempMemos[dateString] = memoContent;
        }
      }
    }

    setState(() {
      // 날짜의 역순으로 정렬해서 최신 메모가 위로 오도록
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
      // 메모가 하나도 없을 경우와 있을 경우를 나눠서 보여줌
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
                // 날짜 형식을 '2025년 7월 15일' 처럼 예쁘게 변경
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
