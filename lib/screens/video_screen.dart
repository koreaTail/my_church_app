// lib/screens/video_screen.dart

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  YoutubePlayerController? _controller;
  String? _currentVideoId;

  // 영상 정보 수정을 위한 팝업창
  void _showEditVideoDialog(Map<String, dynamic> currentData) {
    final urlController = TextEditingController(text: currentData['url'] ?? '');
    final titleController =
        TextEditingController(text: currentData['title'] ?? '');
    final dateController =
        TextEditingController(text: currentData['date'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('오늘의 영상 정보 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: '유튜브 영상 주소'),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '영상 제목'),
                ),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                      labelText: '게시 날짜 (예: 2025년 7월 18일)'),
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
                // Firestore에 데이터 업데이트
                await FirebaseFirestore.instance
                    .collection('daily_video')
                    .doc('latest')
                    .set({
                  'url': urlController.text,
                  'title': titleController.text,
                  'date': dateController.text,
                });
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // StreamBuilder를 사용해 Firestore 데이터를 실시간으로 감지
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('daily_video')
            .doc('latest')
            .snapshots(),
        builder: (context, snapshot) {
          // 데이터 로딩 중이거나 없을 때
          if (!snapshot.hasData || !snapshot.data!.exists) {
            final videoData = {'url': '', 'title': '등록된 영상이 없습니다.', 'date': ''};
            return _buildContent(context, videoData);
          }

          // 데이터가 있을 때
          final videoData = snapshot.data!.data() as Map<String, dynamic>;
          final newVideoUrl = videoData['url'] as String? ?? '';
          final newVideoId = YoutubePlayer.convertUrlToId(newVideoUrl);

          // 영상 ID가 바뀌었을 때만 컨트롤러를 새로 만듦
          if (newVideoId != null && newVideoId != _currentVideoId) {
            _controller?.dispose(); // 기존 컨트롤러 정리
            _controller = YoutubePlayerController(
              initialVideoId: newVideoId,
              flags: const YoutubePlayerFlags(
                  autoPlay: false, enableCaption: false),
            );
            _currentVideoId = newVideoId;
          }

          return _buildContent(context, videoData);
        },
      ),
    );
  }

  // 화면의 실제 내용을 그리는 위젯
  Widget _buildContent(BuildContext context, Map<String, dynamic> videoData) {
    final videoTitle = videoData['title'] ?? '제목 없음';
    final videoDate = videoData['date'] ?? '날짜 없음';

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 10분 메시지'),
        actions: [
          // 로그인한 사용자에게만 수정 버튼 표시
          if (FirebaseAuth.instance.currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditVideoDialog(videoData),
            ),
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
              if (_controller != null)
                YoutubePlayer(controller: _controller!)
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Text('영상을 불러올 수 없거나 등록되지 않았습니다.',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              const SizedBox(height: 16),
              Text(videoTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(videoDate,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
