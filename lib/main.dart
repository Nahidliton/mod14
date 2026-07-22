import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
export 'package:provider/provider.dart';
import 'services/sqflite_init.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/main/home_screen.dart'; // Assuming you have this from the previous answer
import 'providers/task_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop = !kIsWeb && (
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS
  );

  if (isDesktop) {
    initSqfliteFfi();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TaskProvider())],
      child: MaterialApp(
        title: 'Task Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF00C853),
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00C853),
            primary: const Color(0xFF00C853),
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/set_password': (context) => const SetPasswordScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
