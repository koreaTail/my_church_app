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
  // ⭐ 1. 현재 달의 묵상 횟수를 저장할 변수 추가
  int _currentMonthCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMeditatedDays();
  }

  // ⭐ 2. 현재 달의 묵상 횟수를 계산하고 화면을 업데이트하는 함수 추가
  void _updateCurrentMonthCount(DateTime focusedDay) {
    int count = 0;
    // 저장된 모든 묵상 기록을 확인
    for (String dayString in _meditatedDays) {
      DateTime date = DateTime.parse(dayString);
      // 현재 보고 있는 달력의 '년'과 '월'이 같은 기록만 셈
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
    // 앱이 처음 켜질 때 횟수 계산
    _updateCurrentMonthCount(_focusedDay);
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
                    // 저장이 완료된 후 횟수 다시 계산
                    _updateCurrentMonthCount(_focusedDay);
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
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
              });
              // '오늘' 버튼을 눌렀을 때도 횟수 다시 계산
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
      body: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2022, 1, 1),
            lastDay: DateTime.utc(2032, 12, 31),
            focusedDay: _focusedDay,
            // ⭐ 3. 달력을 넘길 때마다 횟수를 다시 계산하도록 추가
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // 포커스된 날짜를 업데이트하는 것이 중요
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
          // ⭐ 4. 묵상 횟수를 보여주는 UI 위젯 추가
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
    );
  }
}

// (메모 목록 페이지 코드는 이전과 동일하여 생략... 아래에 그대로 붙여넣습니다)
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
