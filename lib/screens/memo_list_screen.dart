import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
                          Text(memoContent,
                              style: const TextStyle(fontSize: 14))
                        ]),
                  ),
                );
              },
            ),
    );
  }
}
