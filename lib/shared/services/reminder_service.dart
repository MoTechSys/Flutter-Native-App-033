import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/arabic_words.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../data/models/customer.dart';

/// WhatsApp / SMS reminders via the Android intent system (docs/06 phase 1).
/// Logs every send into `reminders` so the owner can see history (phase 2).
class ReminderService {
  final Database _db;
  final String? template;
  ReminderService(this._db, {this.template});

  static const _uuid = Uuid();

  static const defaultTemplate =
      'السلام عليكم {name}،\nتذكير من {shop}: المتبقي عليك {amount} ({words}).\nنشكر تعاونك.';

  /// Fills {name} {shop} {amount} {words} in [template] (settings-editable, D11 spirit).
  static String render(String template, {
    required String shopName,
    required String customerName,
    required Money balance,
  }) =>
      template
          .replaceAll('{name}', customerName)
          .replaceAll('{shop}', shopName)
          .replaceAll('{amount}', MoneyFormat.withName(balance.abs))
          .replaceAll('{words}', ArabicWords.money(balance.abs));

  static String defaultMessage({
    required String shopName,
    required String customerName,
    required Money balance,
  }) =>
      render(defaultTemplate, shopName: shopName, customerName: customerName, balance: balance);

  String _message(Customer c, Money balance, String shopName) =>
      render(template ?? defaultTemplate, shopName: shopName, customerName: c.name, balance: balance);

  Future<bool> sendWhatsApp({
    required Customer customer,
    required Money balance,
    required String shopName,
    required String byUserId,
    String? message,
  }) async {
    final phone = customer.phoneE164;
    if (phone == null) return false;
    final text = message ?? _message(customer, balance, shopName);
    final uri = Uri.parse(
        'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(text)}');
    final ok = await _launch(uri);
    if (ok) await _log(customer.id, 'wa', balance, byUserId);
    return ok;
  }

  Future<bool> sendSms({
    required Customer customer,
    required Money balance,
    required String shopName,
    required String byUserId,
    String? message,
  }) async {
    final phone = customer.phoneE164;
    if (phone == null) return false;
    final text = message ?? _message(customer, balance, shopName);
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': text});
    final ok = await _launch(uri);
    if (ok) await _log(customer.id, 'sms', balance, byUserId);
    return ok;
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('launch failed: $e');
      return false;
    }
  }

  Future<void> _log(String customerId, String channel, Money balance, String by) =>
      _db.insert('reminders', {
        'id': _uuid.v4(),
        'customer_id': customerId,
        'channel': channel,
        'balance_snap_minor': balance.minor,
        'currency_code': balance.currency.code,
        'sent_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'sent_by': by,
      });
}
