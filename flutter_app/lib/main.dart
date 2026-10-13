import 'package:flutter/material.dart';
import 'screens/rates_screen.dart';

void main() {
  runApp(const ThaiHelperApp());
}

class ThaiHelperApp extends StatelessWidget {
  const ThaiHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ငွေလွှဲနှုန်း',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const RatesScreen(),
    );
  }
}
