import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<void> refresh() async {
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
                    return StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('posts')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final posts =
                            snapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return !blockedList.contains(data['authorId']);
                            }).toList();

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post =
                                posts[index].data() as Map<String, dynamic>;
                            final postId = posts[index].id;
                            final authorId = post['authorId'];
                            final titleColor = Colors.black;
                            final bool isOffering = post['isOffering'] ?? false;

                            return Card(
                              // color: Colors.white,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: _UserAvatar(
                                  imageUrl: post['authorImageUrl'] ?? '',
                                  uid: authorId,
                                  isGirl: post['isGirl'] == true,
                                ),
                                title: GestureDetector(
                                  onTap: () => _openProfile(context, authorId),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post['title'] ?? '-',
                                        style: TextStyle(
                                          color: titleColor,
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
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
                                          (post['dates'][0].toDate()
                                              as DateTime),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                PostDetailPage(postId: postId),
                                      ),
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('posts').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final posts = snapshot.data!.docs;
                  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                  // フィルタリング：自分が投稿 or コメントした投稿
                  final userPosts =
                      posts.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['authorId'] == currentUserId;
                      }).toList();

                  return StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collectionGroup('comments')
                            .where('userId', isEqualTo: currentUserId)
                            .snapshots(),
                    builder: (context, commentSnapshot) {
                      if (!commentSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final commentedPostIds =
                          commentSnapshot.data!.docs
                              .map((doc) => doc.reference.parent.parent?.id)
                              .whereType<String>()
                              .toSet();

                      final allPostIds = {
                        ...userPosts.map((doc) => doc.id),
                        ...commentedPostIds,
                      };

                      final participatingPosts =
                          posts
                              .where((doc) => allPostIds.contains(doc.id))
                              .toList();

                      if (participatingPosts.isEmpty) {
                        return const Center(child: Text('参加中の投稿はありません'));
                      }

                      return ListView.builder(
                        itemCount: participatingPosts.length,
                        itemBuilder: (context, index) {
                          final post =
                              participatingPosts[index].data()
                                  as Map<String, dynamic>;
                          final postId = participatingPosts[index].id;
                          final authorId = post['authorId'];
                          final titleColor = Colors.black;
                          final bool isOffering = post['isOffering'] ?? false;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: _UserAvatar(
                                imageUrl: post['authorImageUrl'] ?? '',
                                uid: authorId,
                                isGirl: post['isGirl'] == true,
                              ),
                              title: GestureDetector(
                                onTap: () => _openProfile(context, authorId),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['title'] ?? '-',
                                      style: TextStyle(
                                        color: titleColor,
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
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
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => PostDetailPage(postId: postId),
                                    ),
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('投稿詳細')),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snap.data!.data() as Map<String, dynamic>;
          final authorId = post['authorId'];
          final createdAt = post['createdAt']?.toDate();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: _UserAvatar(
                        imageUrl: post['authorImageUrl'] ?? '',
                        uid: authorId,
                        isGirl: post['isGirl'] == true,
                      ),
                      title: GestureDetector(
                        onTap: () => _openProfile(context, authorId),
                        child: Text(
                          post['authorName'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      subtitle: Text(post['prefecture'] ?? '-'),
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 4),
                        child: Text(
                          DateFormat('yyyy/MM/dd HH:mm').format(createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          _buildLabelValue('タイトル', post['title']),
                          _buildLabelValue(
                            '募集タイプ',
                            post['isOffering'] == true ? '奢りたい！' : '奢られたい！',
                            valueColor:
                                post['isOffering'] == true
                                    ? Colors.blue
                                    : Colors.orange,
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Text(
                        'コメント',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                                        // Handle blocking
                                        await FirebaseFirestore.instance
                                            .collection('blocks')
                                            .doc(currentUser!.uid)
                                            .set({
                                              'blocked': FieldValue.arrayUnion([
                                                commentUserId,
                                              ]),
                                            }, SetOptions(merge: true));
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
          );
        },
      ),
    );
  }

  Widget _buildLabelValue(String label, String? value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value ?? '-',
              style: TextStyle(color: valueColor ?? Colors.black),
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
