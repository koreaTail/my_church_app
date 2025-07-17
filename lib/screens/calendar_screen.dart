import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'memo_list_screen.dart';
import 'settings_screen.dart';

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
      if (date.year == focusedDay.year && date.month == focusedDay.month)
        count++;
    }
    if (mounted) setState(() => _currentMonthCount = count);
  }

  Future<void> _loadMeditatedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getStringList('meditatedDays') ?? [];
    if (mounted) {
      setState(() => _meditatedDays = Set.from(savedDays));
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
                    child: const Text('취소')),
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
        if (result)
          _meditatedDays.add(dayString);
        else
          _meditatedDays.remove(dayString);
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
              }),
          IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MemoListPage()))),
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()))),
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
            setState(() => _focusedDay = selectedDay);
            _showMeditationDialog(selectedDay);
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final dayString = DateFormat('yyyy-MM-dd').format(day);
              if (_meditatedDays.contains(dayString))
                return const Center(
                    child: Icon(Icons.favorite, color: Colors.red));
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
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.favorite, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text('+$_currentMonthCount',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
          ]),
        ),
      ])),
    );
  }
}
