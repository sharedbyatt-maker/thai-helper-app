import 'package:flutter/material.dart';
import 'screens/rates_screen.dart';

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() {
  runApp(const ThaiHelperApp());
}

class ThaiHelperApp extends StatelessWidget {
  const ThaiHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'ဘတ်ဈေး',
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark),
          useMaterial3: true,
        ),
        themeMode: mode,
        home: const RatesScreen(),
      ),
    );
  }
}
