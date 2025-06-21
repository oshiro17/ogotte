import 'package:flutter/material.dart';
import 'package:ogore/feed_page.dart';
import 'package:ogore/post_create_page.dart';
import 'my_page.dart'; // MyPage を別ファイルからインポート

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final feedKey = GlobalKey<FeedPageState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedPage(key: feedKey),
      PostCreatePage(
        onPostSuccess: () {
          feedKey.currentState?.refresh(); // 一覧再読込
          setState(() => _selectedIndex = 0); // 一覧タブへ戻る
        },
      ),
      const MyPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: '投稿'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}
