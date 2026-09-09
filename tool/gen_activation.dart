// Seller tool: generate offline activation codes for Sijil.
//
//   dart run tool/gen_activation.dart <deviceId> <plan: Y1|Y3|LIFE> [count]
//
// The device id is shown on the customer's Activation screen. Codes are bound
// to that device. Keep `secret` identical to lib/core/activation/activation.dart.
//
// Example:
//   dart run tool/gen_activation.dart 3f9c2c1e-...-b1 Y1
//   → SJL-Y1---0N7Q-K3M9PX   (valid 1 year from today)
import 'dart:io';

import 'package:sijil/core/activation/activation.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/gen_activation.dart <deviceId> <Y1|Y3|LIFE> [count]');
    exit(2);
  }
  final deviceId = args[0];
  final plan = args[1].toUpperCase();
  final count = args.length > 2 ? int.parse(args[2]) : 1;
  final now = DateTime.now().toUtc();
  final DateTime? expires = switch (plan) {
    'Y1' => DateTime.utc(now.year + 1, now.month, now.day),
    'Y3' => DateTime.utc(now.year + 3, now.month, now.day),
    'LIFE' => null,
    _ => throw ArgumentError('plan must be Y1, Y3 or LIFE'),
  };
  for (var i = 0; i < count; i++) {
    // Same device+plan+expiry always yields the same code (deterministic HMAC);
    // count > 1 is only useful with different expiry days.
    final e = expires?.add(Duration(days: i));
    stdout.writeln(Activation.generate(plan: plan, expires: e, deviceId: deviceId));
  }
}
