import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mahjong_engine/mahjong_engine.dart';

import 'game_screen.dart';

/// Placeholder home/lobby screen (STEP7「画面構成」). Real content —
/// マッチング待機, CPU戦フォールバック, 友人戦ルーム作成/参加 — lands in a later
/// slice; for now the only action deals a fresh local round so the game
/// board (game_screen.dart) has something real to display.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('6華6北5等三麻')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _startLocalRound(context),
          child: const Text('対局開始（動作確認用）'),
        ),
      ),
    );
  }

  void _startLocalRound(BuildContext context) {
    final ruleset = RulesetRegistry.resolve('sanma.six_ka_six_pei');
    final match = MatchState(ruleset: ruleset);
    final state = match.dealCurrentRound(random: Random(), config: const {});
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(state: state, match: match)),
    );
  }
}
