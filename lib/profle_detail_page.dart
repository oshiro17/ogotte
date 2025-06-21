import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileDetailPage extends StatelessWidget {
  final String uid;
  const ProfileDetailPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール詳細')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ユーザー情報が見つかりません'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      (data['imageUrl'] ?? '').isNotEmpty
                          ? NetworkImage(data['imageUrl'])
                          : null,
                  backgroundColor: Colors.grey[300],
                  child:
                      (data['imageUrl'] ?? '').isEmpty
                          ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 24),
              _buildDisplayRow('名前', data['name']),
              _buildDisplayRow('性別', data['gender']),
              _buildDisplayRow(
                '年齢',
                data['age'] != null ? '${data['age']} 歳' : '-',
              ),
              _buildDisplayRow('ひとこと', data['bio']),
              _buildDisplayRow('Instagram', data['instagram']),
              _buildDisplayRow('Twitter', data['twitter']),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDisplayRow(String label, dynamic value) {
    final displayText =
        (value != null && value.toString().trim().isNotEmpty)
            ? value.toString()
            : '-';

    final isSocial =
        (label == 'Instagram' || label == 'Twitter') && displayText != '-';

    final url =
        label == 'Instagram'
            ? 'https://instagram.com/$displayText'
            : 'https://twitter.com/$displayText';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        isSocial
            ? InkWell(
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                url,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
            : Text(displayText, style: const TextStyle(fontSize: 16)),
        const Divider(height: 24),
      ],
    );
  }
}
