import 'package:flutter/material.dart';
import 'ui/studio_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InfiniteStateApp());
}

class InfiniteStateApp extends StatelessWidget {
  const InfiniteStateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infinite State',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF161922),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'sans-serif',
              bodyColor: const Color(0xFFE2E8F0),
              displayColor: Colors.white,
            ),
      ),
      home: const StudioPage(),
    );
  }
}
