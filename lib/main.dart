import 'package:flutter/material.dart';
import 'core/app_colors.dart';
import 'features/auth/screens/login_option_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/login_info_screen.dart';
import 'features/home/screens/home_screen.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EpicPadelApp());
}
class EpicPadelApp extends StatelessWidget {
  const EpicPadelApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epic Padel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginOptionScreen(),
        '/login': (_) => const LoginScreen(),
        '/login-info': (_) => const LoginInfoScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
