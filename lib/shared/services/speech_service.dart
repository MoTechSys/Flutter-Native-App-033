import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/ledger/tx_type.dart';
import '../../core/money/arabic_words.dart';
import '../../core/money/money.dart';

/// Arabic TTS (docs/03 §7). Fails silently — speech is a helper, never a
/// blocker. Can be disabled from settings (phase 2).
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool enabled = true;
  double _rate = 0.45;

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (e) {
      debugPrint('tts init failed: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('tts speak failed: $e');
    }
  }

  /// Speaks and completes when the utterance ends (or after an estimate if
  /// the engine gives no completion — e.g. some web browsers).
  Future<void> speakAndWait(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    try {
      await _init();
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      final est = Duration(milliseconds: 350 + text.length * 75);
      await Future.any([
        _tts.speak(text),
        Future<void>.delayed(est + const Duration(seconds: 4)),
      ]);
    } catch (e) {
      debugPrint('tts speakAndWait failed: $e');
      await Future<void>.delayed(Duration(milliseconds: 350 + text.length * 60));
    }
  }

  Future<void> setRate(double r) async {
    _rate = r;
    try {
      await _tts.setSpeechRate(r);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// "أحمد أخذ ثلاثة آلاف ريال، يصير عليه ثمانية آلاف ريال"
  static String transactionSentence({
    required String customerName,
    required TxType type,
    required Money amount,
    required Money newBalance,
  }) {
    final verb = switch (type) {
      TxType.debit => 'أخذ',
      TxType.credit => 'دفع',
      TxType.adjustDown => 'خُصم له',
      TxType.adjustUp => 'أُضيف عليه',
      TxType.opening => 'رصيد سابق',
    };
    final tail = newBalance.isZero
        ? 'وصار حسابه مسدَّداً'
        : newBalance.isNegative
            ? 'يصير له ${ArabicWords.money(newBalance.abs)}'
            : 'يصير عليه ${ArabicWords.money(newBalance)}';
    return '$customerName $verb ${ArabicWords.money(amount)}، $tail';
  }

  static String balanceSentence(String customerName, Money balance) {
    if (balance.isZero) return '$customerName، حسابه مسدَّد';
    if (balance.isNegative) return '$customerName، له ${ArabicWords.money(balance.abs)}';
    return '$customerName، عليه ${ArabicWords.money(balance)}';
  }
}
