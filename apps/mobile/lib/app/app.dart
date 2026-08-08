import 'package:flutter/material.dart';

import '../presentation/screens/home_screen.dart';

/// App root: routing/theme/DI setup (STEP6「app/」). Routing itself is a
/// single static home screen for now — a router lands with the rest of the
/// screen flow.
class SanmaMahjongApp extends StatelessWidget {
  const SanmaMahjongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '6華6北5等三麻',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
