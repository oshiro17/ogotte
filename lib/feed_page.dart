import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ogore/profle_detail_page.dart';
// import 'package:ogore/profile_detail_page.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart'; // 日付フォーマット用に追加

// ========================= FeedPage =========================
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => FeedPageState();
}

/// HomePage からリロードするためクラス名を公開
class FeedPageState extends State<FeedPage> {
  final int _postsPerPage = 10;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<QueryDocumentSnapshot> _fetchedPosts = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    _lastDocument = null;
    _fetchedPosts.clear();
    _hasMore = true;
    await _fetchPosts();
    setState(() {});
  }

  Future<void> _fetchPosts() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;

    Query query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(_postsPerPage);
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }
    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _fetchedPosts.addAll(snapshot.docs);
    }
    if (snapshot.docs.length < _postsPerPage) {
      _hasMore = false;
    }
    _isLoadingMore = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('投稿'),
            bottom: const TabBar(tabs: [Tab(text: '投稿一覧'), Tab(text: '参加中')]),
          ),
          body: TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: refresh,
                child: FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('blocks')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .get(),
                  builder: (context, blockSnapshot) {
                    if (!blockSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final blockedData =
                        blockSnapshot.data!.data() as Map<String, dynamic>?;
                    final blockedList =
                        (blockedData?['blocked'] as List?)?.cast<String>() ??
                        [];

                    // 投稿一覧ページネーション
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _fetchedPosts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _fetchedPosts.length) {
                          return TextButton(
                            onPressed: _fetchPosts,
                            child: const Text("もっと読み込む"),
                          );
                        }
                        final doc = _fetchedPosts[index];
                        final data = doc.data() as Map<String, dynamic>;
                        // ブロック済みユーザーやblockedByに含まれる場合はスキップ
                        if (blockedList.contains(data['authorId']) ||
                            (data['blockedBy'] ?? []).contains(
                              FirebaseAuth.instance.currentUser!.uid,
                            )) {
                          return const SizedBox.shrink();
                        }
                        final postId = doc.id;
                        final authorId = data['authorId'];
                        final bool isOffering = data['isOffering'] ?? false;

                        return GestureDetector(
                          onLongPress: () async {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            if (currentUser == null) return;

                            if (currentUser.uid == authorId) {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('投稿を削除しますか？'),
                                      content: const Text('この操作は取り消せません。'),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('削除'),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(postId)
                                    .delete();
                                refresh();
                              }
                            } else {
                              final report = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('投稿を報告'),
                                      content: const Text('不適切な投稿は報告してください'),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('報告'),
                                        ),
                                      ],
                                    ),
                              );
                              if (report == true) {
                                await FirebaseFirestore.instance
                                    .collection('reports')
                                    .add({
                                      'reportedBy': currentUser.uid,
                                      'reportedPost': postId,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('投稿を報告しました')),
                                );
                              }
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => PostDetailPage(postId: postId),
                                    ),
                                  ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _UserAvatar(
                                          imageUrl:
                                              data['authorImageUrl'] ?? '',
                                          uid: authorId,
                                          isGirl: data['isGirl'] == true,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['title'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                isOffering ? '奢りたい！' : '奢られたい！',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      isOffering
                                                          ? Colors.blue
                                                          : Colors.orange,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      data['prefecture'] ?? '-',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      data['location'] ?? '-',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if ((data['dates'] as List).isNotEmpty)
                                      Text(
                                        DateFormat(
                                          'yyyy/MM/dd HH:mm 集合！',
                                        ).format(
                                          (data['dates'][0].toDate()
                                              as DateTime),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              _ParticipatingPostsList(),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile(BuildContext ctx, String uid) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => ProfileDetailPage(uid: uid)),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String imageUrl;
  final String uid;
  final bool isGirl;

  const _UserAvatar({
    required this.imageUrl,
    required this.uid,
    required this.isGirl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileDetailPage(uid: uid)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isGirl ? Colors.pink : Colors.blue,
            width: 3,
          ),
        ),
        child: CircleAvatar(
          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
          child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
      ),
    );
  }
}

// ---------------- 参加中タブ ----------------
class _ParticipatingPostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    // ❶ まず自分がブロックした UID 一覧を取得
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('blocks').doc(currentUid).get(),
      builder: (context, blockSnap) {
        if (!blockSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final blockedData =
            blockSnap.data!.data() as Map<String, dynamic>? ?? {};
        final blockedList =
            (blockedData['blocked'] as List?)?.cast<String>() ?? [];

        // ❷ 自分の投稿 & 参加中投稿をそれぞれストリームで取得
        final myPostsStream =
            FirebaseFirestore.instance
                .collection('posts')
                .where('authorId', isEqualTo: currentUid)
                .snapshots();

        final joinedPostsStream =
            FirebaseFirestore.instance
                .collection('posts')
                .where('participants', arrayContains: currentUid)
                .snapshots();

        // ❸ 2 つのストリームを結合
        return StreamBuilder<QuerySnapshot>(
          stream: myPostsStream,
          builder: (context, myPostsSnap) {
            if (!myPostsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<QuerySnapshot>(
              stream: joinedPostsStream,
              builder: (context, joinedSnap) {
                if (!joinedSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // --- 結合 & 重複排除 ---
                final Map<String, QueryDocumentSnapshot> map = {};
                for (final doc in myPostsSnap.data!.docs) {
                  map[doc.id] = doc;
                }
                for (final doc in joinedSnap.data!.docs) {
                  map[doc.id] = doc;
                }

                // ❹ ブロック済みユーザーの投稿を除外
                final posts =
                    map.values.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return !blockedList.contains(data['authorId']) &&
                            !(data['blockedBy'] ?? []).contains(
                              FirebaseAuth.instance.currentUser!.uid,
                            );
                      }).toList()
                      ..sort((a, b) {
                        final at = (a['createdAt'] as Timestamp?)?.toDate();
                        final bt = (b['createdAt'] as Timestamp?)?.toDate();
                        return (bt ?? DateTime(0)).compareTo(at ?? DateTime(0));
                      });

                if (posts.isEmpty) {
                  return const Center(child: Text('参加中の投稿はありません'));
                }

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    final postId = posts[index].id;
                    final bool isOffering = post['isOffering'] ?? false;
                    final authorId = post['authorId'];

                    return GestureDetector(
                      onLongPress: () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null &&
                            currentUser.uid == authorId) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('投稿を削除しますか？'),
                                  content: const Text('この操作は取り消せません。'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text('削除'),
                                    ),
                                  ],
                                ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(postId)
                                .delete();
                          }
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailPage(postId: postId),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _UserAvatar(
                                      imageUrl: post['authorImageUrl'] ?? '',
                                      uid: post['authorId'],
                                      isGirl: post['isGirl'] == true,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post['title'] ?? '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            isOffering ? '奢りたい！' : '奢られたい！',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isOffering
                                                      ? Colors.blue
                                                      : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post['prefecture'] ?? '-',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  post['location'] ?? '-',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if ((post['dates'] as List).isNotEmpty)
                                  Text(
                                    DateFormat('yyyy/MM/dd HH:mm').format(
                                      (post['dates'][0].toDate() as DateTime),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ======================= PostDetailPage ======================
class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});
  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController commentController = TextEditingController();
  String? replyingToUserName;
  String? replyingToCommentId;
  String? replyingToMessageText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final post = snap.data!.data() as Map<String, dynamic>;
        final authorId = post['authorId'];
        final createdAt = post['createdAt']?.toDate();

        return Scaffold(
          appBar: AppBar(
            title: Text(post['title'] ?? '-'),
            actions: [
              if (FirebaseAuth.instance.currentUser?.uid == authorId &&
                  !((post['participants'] as List?)?.contains(
                        FirebaseAuth.instance.currentUser?.uid,
                      ) ==
                      true))
                IconButton(
                  icon: Icon(
                    post['isClosed'] == true ? Icons.visibility : Icons.lock,
                    color: Colors.black,
                  ),
                  tooltip: post['isClosed'] == true ? '募集を公開する' : '募集を締め切る',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(
                              post['isClosed'] == true
                                  ? '募集を公開しますか？'
                                  : '募集を締め切りますか？',
                            ),
                            content: Text(
                              post['isClosed'] == true
                                  ? 'この投稿を再び募集状態にしますか？'
                                  : 'この投稿を締め切って非公開にしますか？',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('はい'),
                              ),
                            ],
                          ),
                    );
                    if (confirmed == true) {
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.postId)
                          .update({'isClosed': !(post['isClosed'] == true)});
                      setState(() {});
                    }
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _UserAvatar(
                                  imageUrl: post['authorImageUrl'] ?? '',
                                  uid: authorId,
                                  isGirl: post['isGirl'] == true,
                                ),
                                title: GestureDetector(
                                  onTap: () => _openProfile(context, authorId),
                                  child: Text(
                                    post['authorName'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  post['prefecture'] ?? '-',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              _buildLabelValue(
                                'タイトル',
                                post['title'],
                                valueStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildLabelValue(
                                '募集タイプ',
                                post['isOffering'] == true ? '奢りたい！' : '奢られたい！',
                                valueColor:
                                    post['isOffering'] == true
                                        ? Colors.blue
                                        : Colors.orange,
                                valueStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildLabelValue('場所', post['location']),
                              _buildLabelValue('条件', post['condition']),
                              _buildLabelValue('説明', post['description']),
                              _buildLabelValue('都道府県', post['prefecture']),
                              _buildLabelValue(
                                '参加人数',
                                '${post['minPeople']}人 ~ ${post['maxPeople']}人',
                              ),
                              if ((post['dates'] as List).isNotEmpty)
                                _buildLabelValue(
                                  '日程',
                                  (post['dates'] as List)
                                      .map(
                                        (d) => DateFormat(
                                          'yyyy/MM/dd HH:mm',
                                        ).format(d.toDate()),
                                      )
                                      .join('\n'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Text(
                        'コメント',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final comments = snapshot.data!.docs;
                        final post = snap.data!.data() as Map<String, dynamic>;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment =
                                comments[index].data() as Map<String, dynamic>;
                            return GestureDetector(
                              onLongPress: () {
                                setState(() {
                                  replyingToCommentId = comments[index].id;
                                  replyingToUserName =
                                      comment['userName'] ?? '匿名';
                                  replyingToMessageText = comment['text'];
                                  // Do not change commentController.text here.
                                });
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage:
                                            comment['userImageUrl'] != null &&
                                                    comment['userImageUrl']
                                                        .toString()
                                                        .isNotEmpty
                                                ? NetworkImage(
                                                  comment['userImageUrl'],
                                                )
                                                : null,
                                        child:
                                            (comment['userImageUrl'] == null ||
                                                    comment['userImageUrl']
                                                        .toString()
                                                        .isEmpty)
                                                ? const Icon(Icons.person)
                                                : null,
                                      ),
                                      title: Text(comment['userName'] ?? '匿名'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (comment['replyToMessageText'] !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2.0,
                                              ),
                                              child: Text(
                                                '→ ${comment['replyToMessageText'].toString().length > 20 ? comment['replyToMessageText'].toString().substring(0, 20) + '...' : comment['replyToMessageText']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          Text(comment['text'] ?? ''),
                                          if (comment['createdAt'] != null)
                                            Text(
                                              DateFormat('HH:mm').format(
                                                (comment['createdAt']
                                                        as Timestamp)
                                                    .toDate(),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      final currentUser =
                                          FirebaseAuth.instance.currentUser;
                                      final commentUserId = comment['userId'];
                                      final postOwnerId = post['authorId'];
                                      if (value == 'report') {
                                        // Handle reporting
                                        await FirebaseFirestore.instance
                                            .collection('reports')
                                            .add({
                                              'reportedBy': currentUser?.uid,
                                              'reportedComment':
                                                  comment['text'],
                                              'timestamp':
                                                  FieldValue.serverTimestamp(),
                                            });
                                      } else if (value == 'block' &&
                                          currentUser?.uid == postOwnerId) {
                                        // Handle blocking: add current user to blockedBy field of this post
                                        await FirebaseFirestore.instance
                                            .collection('posts')
                                            .doc(widget.postId)
                                            .update({
                                              'blockedBy':
                                                  FieldValue.arrayUnion([
                                                    currentUser!.uid,
                                                  ]),
                                            });
                                      }
                                    },
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('報告'),
                                          ),
                                          if (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ==
                                              post['authorId'])
                                            const PopupMenuItem(
                                              value: 'block',
                                              child: Text('ブロック'),
                                            ),
                                        ],
                                    icon: const Icon(Icons.more_vert, size: 20),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          labelText:
                              replyingToMessageText != null
                                  ? '→ ${replyingToMessageText!.length > 20 ? replyingToMessageText!.substring(0, 20) + '...' : replyingToMessageText!}'
                                  : 'コメントを入力',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabelValue(
    String label,
    String? value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  valueStyle ??
                  TextStyle(color: valueColor ?? Colors.black, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || commentController.text.trim().isEmpty) return;

    final userData =
        (await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get())
            .data();

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
          'text': commentController.text.trim(),
          'userId': user.uid,
          'userName': userData?['name'] ?? '匿名',
          'userImageUrl': userData?['imageUrl'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'replyTo': replyingToCommentId,
          'replyToUserName': replyingToUserName,
          'replyToMessageText': replyingToMessageText,
        });
    // 参加者リストに自身を追加
    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).set(
      {
        'participants': FieldValue.arrayUnion([user.uid]),
      },
      SetOptions(merge: true),
    );
    commentController.clear();
    replyingToCommentId = null;
    replyingToUserName = null;
    replyingToMessageText = null;
    setState(() {});
  }

  void _openProfile(BuildContext ctx, String uid) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => ProfileDetailPage(uid: uid)),
    );
  }
}
