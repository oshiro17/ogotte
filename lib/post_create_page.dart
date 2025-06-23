import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostCreatePage extends StatefulWidget {
  final VoidCallback onPostSuccess;
  const PostCreatePage({super.key, required this.onPostSuccess});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  bool isOffering = true;
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final conditionController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedPrefecture = '東京都';
  List<DateTime> selectedDateTimes = [];
  int minPeople = 2;
  int maxPeople = 3;
  bool isSubmitting = false;

  // 都道府県一覧（必要に応じて省略可）
  final List<String> prefectures = [
    '北海道',
    '青森県',
    '岩手県',
    '宮城県',
    '秋田県',
    '山形県',
    '福島県',
    '茨城県',
    '栃木県',
    '群馬県',
    '埼玉県',
    '千葉県',
    '東京都',
    '神奈川県',
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
    '岐阜県',
    '静岡県',
    '愛知県',
    '三重県',
    '滋賀県',
    '京都府',
    '大阪府',
    '兵庫県',
    '奈良県',
    '和歌山県',
    '鳥取県',
    '島根県',
    '岡山県',
    '広島県',
    '山口県',
    '徳島県',
    '香川県',
    '愛媛県',
    '高知県',
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県',
  ];

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null) return;

    setState(() {
      selectedDateTimes.add(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    });
  }

  Future<void> submitPost() async {
    if (!_formKey.currentState!.validate() || selectedDateTimes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('必須項目が未入力です')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSubmitting = true);

    final userData =
        (await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get())
            .data();

    await FirebaseFirestore.instance.collection('posts').add({
      'title': titleController.text,
      'dates': selectedDateTimes.map((d) => Timestamp.fromDate(d)).toList(),
      'prefecture': selectedPrefecture,
      'location': locationController.text,
      'minPeople': minPeople,
      'maxPeople': maxPeople,
      'condition': conditionController.text,
      'description': descriptionController.text,
      'createdAt': FieldValue.serverTimestamp(),
      'authorId': user.uid,
      'authorName': userData?['name'] ?? '',
      'authorImageUrl': userData?['imageUrl'] ?? '',
      'isGirl': userData?['isGirl'] == true,
      'isOffering': isOffering,
    });

    setState(() {
      isSubmitting = false;
      titleController.clear();
      locationController.clear();
      conditionController.clear();
      descriptionController.clear();
      selectedDateTimes.clear();
      minPeople = 2;
      maxPeople = 3;
      selectedPrefecture = '東京都';
    });

    widget.onPostSuccess(); // 一覧をリロード & タブ戻し
    ScaffoldMessenger.of(context).showSnackBar(
      // 投稿完了通知
      const SnackBar(content: Text('投稿が完了しました！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('投稿作成')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    hintText: '焼肉奢るので、女子会しましょう',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (v) => (v == null || v.isEmpty) ? '募集タイトルは必須です' : null,
                ),
                const SizedBox(height: 16),

                // 日程
                Row(
                  children: [
                    const Text(
                      '日程',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.add),
                      label: const Text('追加'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      selectedDateTimes.map((dt) {
                        final label =
                            '${dt.month}/${dt.day}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        return Chip(
                          label: Text(label),
                          onDeleted:
                              () =>
                                  setState(() => selectedDateTimes.remove(dt)),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // 都道府県
                DropdownButtonFormField<String>(
                  value: selectedPrefecture,
                  items:
                      prefectures
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                  onChanged:
                      (v) => setState(() => selectedPrefecture = v ?? '東京都'),
                  decoration: const InputDecoration(labelText: '都道府県'),
                ),

                // 集合場所
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: '集合場所',
                    hintText: '例）渋谷駅 ハチ公前',
                  ),
                  validator:
                      (v) => (v == null || v.isEmpty) ? '集合場所は必須です' : null,
                ),
                const SizedBox(height: 16),

                // 募集人数
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: minPeople,
                        items:
                            List.generate(10, (i) => i + 1)
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n人'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => minPeople = v ?? 2),
                        decoration: const InputDecoration(labelText: '最小人数'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: maxPeople,
                        items:
                            List.generate(10, (i) => i + 1)
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n人'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => maxPeople = v ?? 3),
                        decoration: const InputDecoration(labelText: '最大人数'),
                      ),
                    ),
                  ],
                ),

                // 奢り or 奢られたい（boolで送信）
                const Text(
                  'あなたはどちら？',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ToggleButtons(
                  isSelected: [isOffering, !isOffering],
                  onPressed: (index) {
                    setState(() {
                      isOffering = index == 0;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('奢ります！'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('奢られたい！'),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // 条件・詳細（任意）
                TextField(
                  controller: conditionController,
                  decoration: const InputDecoration(labelText: '参加条件'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '詳細説明'),
                ),
                const SizedBox(height: 24),

                // 投稿ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submitPost,
                    child:
                        isSubmitting
                            ? const CircularProgressIndicator()
                            : const Text('投稿する'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
