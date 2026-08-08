import 'package:flutter/material.dart';

/// Placeholder home/lobby screen (STEP7「画面構成」). Real content —
/// マッチング待機, CPU戦フォールバック, 友人戦ルーム作成/参加 — lands in a later
/// slice; this only proves the app shell renders.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('6華6北5等三麻')),
      body: const Center(child: Text('準備中')),
    );
  }
}
