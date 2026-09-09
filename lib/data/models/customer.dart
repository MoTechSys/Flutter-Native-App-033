/// Customer row (table `customers`, docs/05 §3). Read model + input.
class Customer {
  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? photoPath;
  final String? voiceNamePath;
  final String? note;
  final int? creditLimitMinor;
  final String? creditLimitCurrency;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? lastActivityAt;

  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.photoPath,
    this.voiceNamePath,
    this.note,
    this.creditLimitMinor,
    this.creditLimitCurrency,
    required this.isArchived,
    required this.createdAt,
    this.lastActivityAt,
  });

  factory Customer.fromRow(Map<String, Object?> r) => Customer(
        id: r['id'] as String,
        shopId: r['shop_id'] as String,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        photoPath: r['photo_path'] as String?,
        voiceNamePath: r['voice_name_path'] as String?,
        note: r['note'] as String?,
        creditLimitMinor: r['credit_limit_minor'] as int?,
        creditLimitCurrency: r['credit_limit_currency'] as String?,
        isArchived: (r['is_archived'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int, isUtc: true),
        lastActivityAt: r['last_activity_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['last_activity_at'] as int, isUtc: true),
      );

  /// Phone normalised for `wa.me` / `sms:` (Yemen +967, strips spaces/dashes).
  String? get phoneE164 {
    final p = phone?.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('+')) return p;
    if (p.startsWith('00')) return '+${p.substring(2)}';
    if (p.startsWith('967')) return '+$p';
    if (p.startsWith('0')) return '+967${p.substring(1)}';
    return '+967$p';
  }
}
