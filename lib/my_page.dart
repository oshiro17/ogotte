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
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[300],
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child:
            imageUrl == null
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
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
        gender = isGirl ? '女性' : '男性'; // kept for display, no change needed here
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
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
        const Divider(),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
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
        const Divider(),
      ],
    );
  }

  Widget _buildAgeDropdown() {
    return Column(
      children: [
        DropdownButton<String>(
          value: selectedAge,
          hint: const Text('年齢を選択'),
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
        const Divider(),
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
            title: Text('$title を編集'),
            content: Column(
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
                                  autofocus: true,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  )
                else
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(hintText: '$title を入力'),
                    autofocus: true,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
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
