import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  final String? editingField;
  const ProfileSetupPage({super.key, this.editingField});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final nameController = TextEditingController();
  final bioController = TextEditingController();
  final instagramController = TextEditingController();
  final twitterController = TextEditingController();
  String gender = '未選択';
  String? selectedAge;

  File? _imageFile;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadProfileImage(File file) async {
    try {
      final fileName = path.basename(file.path);
      final storageRef = FirebaseStorage.instance.ref(
        'profile_images/${FirebaseAuth.instance.currentUser!.uid}/$fileName',
      );

      // ① putFile から直接 TaskSnapshot を取得
      final TaskSnapshot snapshot = await storageRef.putFile(file);

      // ② アップロード済のリファレンスから URL を取得
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Uploaded to: ${snapshot.metadata?.fullPath}');
      debugPrint('Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('画像アップロードエラー: $e');
      return null;
    }
  }

  void setGender(String newGender) {
    setState(() {
      gender = newGender;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.editingField == null ||
                widget.editingField == 'image') ...[
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      _imageFile != null ? FileImage(_imageFile!) : null,
                  child:
                      _imageFile == null
                          ? const Icon(Icons.camera_alt, color: Colors.white)
                          : null,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.editingField == null ||
                widget.editingField == 'name') ...[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.editingField == null ||
                widget.editingField == 'gender') ...[
              Row(
                children: [
                  const Text('性別:'),
                  Radio<String>(
                    value: '男性',
                    groupValue: gender,
                    onChanged: (v) => setGender(v!),
                  ),
                  const Text('男性'),
                  Radio<String>(
                    value: '女性',
                    groupValue: gender,
                    onChanged: (v) => setGender(v!),
                  ),
                  const Text('女性'),
                ],
              ),
            ],
            if (widget.editingField == null ||
                widget.editingField == 'age') ...[
              DropdownButton<String>(
                value: selectedAge,
                hint: const Text('年齢を選択'),
                items: List.generate(90, (index) {
                  final age = (index + 10).toString();
                  return DropdownMenuItem(value: age, child: Text('$age 歳'));
                }),
                onChanged: (value) => setState(() => selectedAge = value),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.editingField == null ||
                widget.editingField == 'bio') ...[
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'ひとこと（任意）'),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.editingField == null ||
                widget.editingField == 'instagram') ...[
              TextField(
                controller: instagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagramアカウント（任意）',
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.editingField == null ||
                widget.editingField == 'twitter') ...[
              TextField(
                controller: twitterController,
                decoration: const InputDecoration(
                  labelText: 'Twitterアカウント（任意）',
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: () async {
                String name = nameController.text.trim();
                String age = selectedAge ?? '';

                if (name.isEmpty || gender == '未選択' || age.isEmpty) {
                  name = '花子';
                  gender = '女性';
                  age = '72';
                }

                try {
                  final user = FirebaseAuth.instance.currentUser!;
                  final docRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid);

                  String? imageUrl;
                  if (_imageFile != null) {
                    imageUrl = await _uploadProfileImage(_imageFile!);
                  }
                  final data = {
                    if (widget.editingField == null ||
                        widget.editingField == 'name')
                      'name': name,
                    if (widget.editingField == null ||
                        widget.editingField == 'gender')
                      'gender': gender,
                    if (widget.editingField == null ||
                        widget.editingField == 'gender')
                      'isGirl': gender == '女性',
                    if (widget.editingField == null ||
                        widget.editingField == 'age')
                      'age': int.parse(age),
                    if (widget.editingField == null ||
                        widget.editingField == 'bio')
                      'bio': bioController.text.trim(),
                    if (widget.editingField == null ||
                        widget.editingField == 'instagram')
                      'instagram': instagramController.text.trim(),
                    if (widget.editingField == null ||
                        widget.editingField == 'twitter')
                      'twitter': twitterController.text.trim(),
                    if (widget.editingField == null ||
                        widget.editingField == 'image')
                      'imageUrl': imageUrl,
                  };
                  await docRef.set(data, SetOptions(merge: true));

                  final prefs = await SharedPreferences.getInstance();
                  if (widget.editingField == null ||
                      widget.editingField == 'name') {
                    await prefs.setString('name', name);
                  }
                  if (widget.editingField == null ||
                      widget.editingField == 'gender') {
                    await prefs.setBool('isGirl', gender == '女性');
                  }
                  if (widget.editingField == null ||
                      widget.editingField == 'age') {
                    await prefs.setInt('age', int.parse(age));
                  }
                  if (widget.editingField == null ||
                      widget.editingField == 'bio') {
                    await prefs.setString('bio', bioController.text.trim());
                  }
                  if (widget.editingField == null ||
                      widget.editingField == 'instagram') {
                    await prefs.setString(
                      'instagram',
                      instagramController.text.trim(),
                    );
                  }
                  if (widget.editingField == null ||
                      widget.editingField == 'twitter') {
                    await prefs.setString(
                      'twitter',
                      twitterController.text.trim(),
                    );
                  }
                  if ((widget.editingField == null ||
                          widget.editingField == 'image') &&
                      imageUrl != null) {
                    await prefs.setString('imageUrl', imageUrl);
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _loadProfile() {
    // This method should be implemented to reload the profile data after editing.
    // Placeholder implementation:
    print('Profile reloaded');
  }
}
