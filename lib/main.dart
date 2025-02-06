import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(PearlPayApp());
}

class PearlPayApp extends StatelessWidget {
  const PearlPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pearl Pay',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}
