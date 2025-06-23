import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
// 編集画面

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String name = '-';
  String gender = '-';
  int age = 0;
  String bio = '-';
  String instagram = '-';
  String twitter = '-';
  String? imageUrl;
  String? selectedAge;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_images')
        .child('${user.uid}.jpg');
    await storageRef.putFile(File(pickedFile.path));
    final downloadUrl = await storageRef.getDownloadURL();

    setState(() => imageUrl = downloadUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('imageUrl', downloadUrl);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'imageUrl': downloadUrl,
    });
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickAndUploadImage,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: gender == '女性' ? Colors.pinkAccent : Colors.blueAccent,
            width: 3,
          ),
        ),
        child: CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[300],
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child:
              imageUrl == null
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedName = prefs.getString('name') ?? '-';
    final cachedGender = prefs.getString('gender') ?? '-';
    final cachedAge = prefs.getInt('age') ?? 0;
    final cachedBio = prefs.getString('bio') ?? '-';
    final cachedInstagram = prefs.getString('instagram') ?? '-';
    final cachedTwitter = prefs.getString('twitter') ?? '-';
    final cachedImageUrl = prefs.getString('imageUrl');

    setState(() {
      name = cachedName;
      gender = cachedGender;
      age = cachedAge;
      bio = cachedBio;
      instagram = cachedInstagram;
      twitter = cachedTwitter;
      imageUrl = cachedImageUrl;
      selectedAge = age > 0 ? '$age' : null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final isGirl = data['isGirl'] as bool? ?? false;
      setState(() {
        name = data['name'] as String? ?? '-';
        gender =
            isGirl ? '女性' : '男性'; // kept for display, no change needed here
        age = (data['age'] as int?) ?? 0;
        bio = data['bio'] as String? ?? '-';
        instagram = data['instagram'] as String? ?? '-';
        twitter = data['twitter'] as String? ?? '-';
        imageUrl = data['imageUrl'] as String?;
        selectedAge = age > 0 ? '$age' : null;
      });

      await prefs.setString('name', name);
      await prefs.setBool('isGirl', isGirl);
      await prefs.setInt('age', age);
      await prefs.setString('bio', bio);
      await prefs.setString('instagram', instagram);
      await prefs.setString('twitter', twitter);
      if (imageUrl != null) {
        await prefs.setString('imageUrl', imageUrl!);
      } else {
        await prefs.remove('imageUrl');
      }
    } catch (e) {
      // silent
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text(
            '奢り、奢られ。',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.black87,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 16),
                    _buildEditableRow(context, '名前', name),
                    _buildGenderSelector(),
                    _buildAgeDropdown(),
                    _buildEditableRow(context, 'ひとこと', bio),
                    _buildEditableRow(context, 'Instagram', instagram),
                    _buildEditableRow(context, 'Twitter', twitter),
                  ],
                ),
              ),
            ),
            const Divider(thickness: 1.2),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('アカウント削除'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('アカウントを削除しますか？'),
                        content: const Text('この操作は取り消せません。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除する'),
                          ),
                        ],
                      ),
                );
                if (confirmed == true) {
                  try {
                    await FirebaseAuth.instance.currentUser?.delete();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.mail),
              label: const Text('お問い合わせ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('相談窓口'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('「奢ると書いていたが奢られなかった」'),
                            Text('「待ち合わせに来なかった」'),
                            SizedBox(height: 8),
                            Text('不快・不安なことがあったら、'),
                            Text('運営までご連絡ください'),
                            SizedBox(height: 12),
                            SelectableText('nonokuwapiano@gmail.com'),
                            SelectableText('https://x.com/ora_nonoka'),
                            SelectableText('TEL:080-9852-7749'),
                            SizedBox(height: 12),
                            Text('対応目安：3営業日以内'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('閉じる'),
                          ),
                        ],
                      ),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.description),
              label: const Text('利用規約とプライバシーポリシー'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                final uri = Uri.parse(
                  'https://note.com/nonokapiano/n/n7ccfc73fabac',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRow(BuildContext context, String title, String value) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          subtitle:
              title == 'Instagram' && value.isNotEmpty
                  ? InkWell(
                    child: Text(
                      'https://instagram.com/$value',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    onTap:
                        () => launchUrl(
                          Uri.parse('https://instagram.com/$value'),
                        ),
                  )
                  : title == 'Twitter' && value.isNotEmpty
                  ? InkWell(
                    child: Text(
                      'https://twitter.com/$value',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    onTap:
                        () =>
                            launchUrl(Uri.parse('https://twitter.com/$value')),
                  )
                  : Text(value.isNotEmpty ? value : '-'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed:
                () => _editField(
                  title,
                  value,
                  (v) => setState(() {
                    switch (title) {
                      case '名前':
                        name = v;
                        break;
                      case 'ひとこと':
                        bio = v;
                        break;
                      case 'Instagram':
                        instagram = v;
                        break;
                      case 'Twitter':
                        twitter = v;
                        break;
                    }
                  }),
                ),
          ),
        ),
        const Divider(thickness: 1.2),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Text('性別: '),
              Radio<String>(
                value: '男性',
                groupValue: gender,
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => gender = value);
                  final isGirl = value == '女性' ? true : false;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isGirl', isGirl);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .set({'isGirl': isGirl}, SetOptions(merge: true));
                },
              ),
              const Text('男性'),
              Radio<String>(
                value: '女性',
                groupValue: gender,
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => gender = value);
                  final isGirl = value == '女性';
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isGirl', isGirl);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .set({'isGirl': isGirl}, SetOptions(merge: true));
                },
              ),
              const Text('女性'),
            ],
          ),
        ),
        const Divider(thickness: 1.2),
      ],
    );
  }

  Widget _buildAgeDropdown() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Text('年齢: '),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedAge,
                  hint: const Text('年齢を選択'),
                  isExpanded: true,
                  items: List.generate(90, (index) {
                    final age = (index + 10).toString();
                    return DropdownMenuItem(value: age, child: Text('$age 歳'));
                  }),
                  onChanged: (value) async {
                    setState(() {
                      selectedAge = value;
                      age = int.parse(value!);
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('age', age);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .set({'age': age}, SetOptions(merge: true));
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(thickness: 1.2),
      ],
    );
  }

  Future<void> _editField(
    String title,
    String initialValue,
    Function(String) onSave,
  ) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '$title を編集',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title == 'Instagram' || title == 'Twitter')
                    Builder(
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            controller.addListener(() {
                              setState(() {});
                            });
                            return Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      hintText: 'ユーザーIDを入力',
                                    ),
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.text,
                                    autofocus: true,
                                    onEditingComplete:
                                        () => FocusScope.of(context).unfocus(),
                                    onSubmitted:
                                        (_) => FocusScope.of(context).unfocus(),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(hintText: '$title を入力'),
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.text,
                        autofocus: true,
                        onEditingComplete:
                            () => FocusScope.of(context).unfocus(),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (title == 'Instagram')
                    const Text(
                      '例: nonoka_17',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (title == 'Twitter')
                    const Text(
                      '例: @nonoka',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context, controller.text.trim());
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );

    if (result != null) {
      String cleaned = result;
      if (title == 'Instagram' || title == 'Twitter') {
        cleaned = result.replaceAll(
          RegExp(r'^https?://(www\.)?(instagram|twitter)\.com/'),
          '',
        );
        cleaned = cleaned.replaceAll('@', '').trim();
      }
      onSave(cleaned);

      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final updateData = <String, dynamic>{};
        switch (title) {
          case '名前':
            await prefs.setString('name', cleaned);
            updateData['name'] = cleaned;
            break;
          case 'ひとこと':
            await prefs.setString('bio', cleaned);
            updateData['bio'] = cleaned;
            break;
          case 'Instagram':
            await prefs.setString('instagram', cleaned);
            updateData['instagram'] = cleaned;
            break;
          case 'Twitter':
            await prefs.setString('twitter', cleaned);
            updateData['twitter'] = cleaned;
            break;
        }
        await docRef.set(updateData, SetOptions(merge: true));
      }
    }
  }
}
