import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ogore/home_page.dart';
import 'package:ogore/profile_setup_page.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ogotte App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/profile-setup': (context) => const ProfileSetupPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
