import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
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
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                final message = messageController.text;
                final user = FirebaseAuth.instance.currentUser;
                if (message.isNotEmpty && user != null) {
                  await FirebaseFirestore.instance
                      .collection('prayer_requests')
                      .add({
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
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('prayer_requests')
                    .doc(docId)
                    .delete();
                if (mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                final newText = messageController.text;
                if (newText.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('prayer_requests')
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
                })
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prayer_requests')
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
                    '$authorName · ${DateFormat('y. M. d. a h:mm', 'ko').format((data['createdAt'] as Timestamp).toDate())}'),
                trailing: isMine
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditMessageDialog(
                                document.id, data['text'])),
                        IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () =>
                                _showDeleteConfirmDialog(document.id))
                      ])
                    : null,
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: user != null
          ? FloatingActionButton(
              onPressed: _showAddMessageDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}
