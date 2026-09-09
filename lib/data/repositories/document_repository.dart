import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../core/docs/doc_data.dart';
import '../../core/docs/doc_layout.dart';
import '../../core/docs/doc_renderer.dart';
import '../../core/docs/pdf_helpers.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/money/currency.dart';
import '../models/customer.dart';
import 'overdue_repository.dart';

/// Saved template (row of `doc_templates`).
class DocTemplate {
  final String id;
  final String nameAr;
  final DocKind kind;
  final DocLayout layout;
  final bool isDefault;
  const DocTemplate({required this.id, required this.nameAr, required this.kind, required this.layout, required this.isDefault});
}

/// A generated file on disk (or bytes only on web).
class GeneratedDoc {
  final Uint8List bytes;
  final String fileName;
  final String? path;
  const GeneratedDoc({required this.bytes, required this.fileName, this.path});
}

/// Builds document data from the ledger, renders with the chosen layout,
/// saves to `المستندات/YYYY/MM/` (docs/09 §6) and logs to audit_log.
class DocumentRepository {
  final Database _db;
  final LedgerService _ledger;
  final String deviceId;
  DocumentRepository(this._db, this._ledger, {required this.deviceId});
  static const _uuid = Uuid();

  // ---- templates ----
  Future<List<DocTemplate>> templates({DocKind? kind}) async {
    final rows = await _db.query('doc_templates',
        where: kind == null ? null : 'kind = ?', whereArgs: kind == null ? null : [kind.db], orderBy: 'is_default DESC, created_at');
    return rows
        .map((r) => DocTemplate(
              id: r['id'] as String,
              nameAr: r['name_ar'] as String,
              kind: DocKind.fromDb(r['kind'] as String),
              layout: DocLayout.decode(r['layout_json'] as String),
              isDefault: (r['is_default'] as int) == 1,
            ))
        .toList();
  }

  /// Default layout for a kind: saved default template, else preset per kind.
  Future<DocLayout> defaultLayout(DocKind kind) async {
    final t = await templates(kind: kind);
    final def = t.where((x) => x.isDefault).firstOrNull ?? t.firstOrNull;
    if (def != null) return def.layout;
    return switch (kind) {
      DocKind.debtAck => DocLayout.preset(DocPreset.classic).copyWith(signatures: ['customer', 'shop', 'witness1', 'witness2']),
      DocKind.receipt => DocLayout.preset(DocPreset.compact).copyWith(pageSize: 'A5'),
      _ => DocLayout.preset(DocPreset.modern),
    };
  }

  Future<DocTemplate> saveTemplate({String? id, required String nameAr, required DocKind kind, required DocLayout layout, bool makeDefault = false}) async {
    final tid = id ?? _uuid.v4();
    await _db.transaction((txn) async {
      if (makeDefault) {
        await txn.update('doc_templates', {'is_default': 0}, where: 'kind = ?', whereArgs: [kind.db]);
      }
      await txn.insert(
        'doc_templates',
        {
          'id': tid,
          'name_ar': nameAr.trim(),
          'kind': kind.db,
          'layout_json': layout.encode(),
          'is_default': makeDefault ? 1 : 0,
          'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    return (await templates(kind: kind)).firstWhere((t) => t.id == tid);
  }

  Future<void> deleteTemplate(String id) => _db.delete('doc_templates', where: 'id = ?', whereArgs: [id]);

  // ---- shop / customer ----
  Future<DocShop> shop() async {
    final r = (await _db.query('shops', limit: 1)).first;
    Uint8List? logo;
    final lp = r['logo_path'] as String?;
    if (lp != null && !kIsWeb) {
      final f = File(lp);
      if (await f.exists()) logo = await f.readAsBytes();
    }
    return DocShop(
      name: r['name'] as String,
      address: r['address'] as String?,
      phone: r['phone'] as String?,
      extraLine: r['extra_line'] as String?,
      logoBytes: logo,
    );
  }

  DocCustomer _cust(Customer c, {String? idNumber}) => DocCustomer(name: c.name, phone: c.phone, idNumber: idNumber);

  // ---- builders ----
  Future<GeneratedDoc> statement({
    required Customer customer,
    required DateTime from,
    required DateTime to,
    required bool detailed,
    DocLayout? layout,
    bool watermark = false,
    required String byUserId,
  }) async {
    await PdfHelpers.ensureFonts();
    final l = layout ?? await defaultLayout(detailed ? DocKind.statementDetailed : DocKind.statement);
    final balances = await _ledger.balancesAllCurrencies(customer.id);
    final currencies = balances.where((b) => b.txCount > 0).map((b) => b.balance.currency).toList();
    if (currencies.isEmpty) currencies.add(await _primary());
    final sections = [
      for (final c in currencies)
        await _ledger.statement(customerId: customer.id, currency: c, from: from, to: to, includeReversed: l.showReversed),
    ];
    final bytes = await DocRenderer.statement(
      StatementDoc(shop: await shop(), customer: _cust(customer), sections: sections, detailed: detailed, issuedAt: DateTime.now(), watermarkTrial: watermark),
      l,
    );
    return _finish(bytes, detailed ? DocKind.statementDetailed : DocKind.statement, customer.name, byUserId, customer.id);
  }

  Future<GeneratedDoc> receipt({
    required Customer customer,
    required String txId,
    DocLayout? layout,
    bool thermal = false,
    bool watermark = false,
    required String byUserId,
  }) async {
    await PdfHelpers.ensureFonts();
    final l = layout ?? await defaultLayout(DocKind.receipt);
    final tx = await _ledger.getById(txId);
    if (tx == null) throw StateError('tx not found');
    final bal = await _ledger.balance(customer.id, tx.amount.currency);
    final bytes = await DocRenderer.receipt(
      ReceiptDoc(
        shop: await shop(),
        customer: _cust(customer),
        receiptNo: '${tx.localSeq}',
        payment: tx,
        balanceAfter: bal.balance,
        receivedBy: tx.userNameSnap,
        issuedAt: DateTime.now(),
        watermarkTrial: watermark,
      ),
      l,
      thermal: thermal,
    );
    return _finish(bytes, DocKind.receipt, customer.name, byUserId, customer.id);
  }

  Future<GeneratedDoc> claim({required Customer customer, int payWithinDays = 7, DocLayout? layout, bool watermark = false, required String byUserId}) async {
    await PdfHelpers.ensureFonts();
    final l = layout ?? await defaultLayout(DocKind.claim);
    final balances = await _ledger.balancesAllCurrencies(customer.id);
    final lastPay = await _db.rawQuery(
        "SELECT MAX(occurred_at) AS m FROM transactions WHERE customer_id=? AND type='credit' AND reversed_by_id IS NULL AND reverses_id IS NULL",
        [customer.id]);
    final lp = lastPay.first['m'] as int?;
    final bytes = await DocRenderer.claim(
      ClaimDoc(
        shop: await shop(),
        customer: _cust(customer),
        balances: {for (final b in balances) b.balance.currency: b.balance},
        lastPaymentAt: lp == null ? null : DateTime.fromMillisecondsSinceEpoch(lp, isUtc: true),
        payWithinDays: payWithinDays,
        issuedAt: DateTime.now(),
        watermarkTrial: watermark,
      ),
      l,
    );
    return _finish(bytes, DocKind.claim, customer.name, byUserId, customer.id);
  }

  Future<GeneratedDoc> overdueReport({required int overdueDays, DocLayout? layout, bool watermark = false, required String byUserId}) async {
    await PdfHelpers.ensureFonts();
    final l = layout ?? await defaultLayout(DocKind.overdueReport);
    final cur = await _primary();
    final items = await OverdueRepository(_db).list(overdueDays: overdueDays, currency: cur);
    final bytes = await DocRenderer.overdueReport(
      OverdueReportDoc(
        shop: await shop(),
        currency: cur,
        rows: [
          for (final it in items)
            OverdueRow(name: it.customer.name, phone: it.customer.phone, balance: it.balance, lastPaymentAt: it.lastPaymentAt, daysOverdue: it.daysOverdue),
        ],
        issuedAt: DateTime.now(),
        watermarkTrial: watermark,
      ),
      l,
    );
    return _finish(bytes, DocKind.overdueReport, 'الكل', byUserId, null);
  }

  Future<GeneratedDoc> debtAck({required Customer customer, String? idNumber, DateTime? payBy, DocLayout? layout, bool watermark = false, required String byUserId}) async {
    await PdfHelpers.ensureFonts();
    final l = layout ?? await defaultLayout(DocKind.debtAck);
    final cur = await _primary();
    final bal = await _ledger.balance(customer.id, cur);
    final bytes = await DocRenderer.debtAck(
      DebtAckDoc(shop: await shop(), customer: _cust(customer, idNumber: idNumber), amount: bal.balance.abs, payBy: payBy, issuedAt: DateTime.now(), watermarkTrial: watermark),
      l,
    );
    return _finish(bytes, DocKind.debtAck, customer.name, byUserId, customer.id);
  }

  // ---- save + audit ----
  Future<GeneratedDoc> _finish(Uint8List bytes, DocKind kind, String who, String byUserId, String? customerId) async {
    final now = DateTime.now();
    final safe = who.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');
    final name = '${kind.fileAr}_${safe}_${DateFormat('yyyy-MM-dd_HHmm').format(now)}.pdf';
    String? path;
    if (!kIsWeb) {
      final dir = await documentsDir(now);
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes, flush: true);
      path = f.path;
    }
    await _db.insert('audit_log', {
      'id': _uuid.v4(),
      'entity': 'document',
      'entity_id': customerId ?? kind.db,
      'action': 'generate',
      'actor_id': byUserId,
      'at': now.toUtc().millisecondsSinceEpoch,
      'after_json': '{"kind":"${kind.db}","file":"$name"}',
      'device_id': deviceId,
    });
    return GeneratedDoc(bytes: bytes, fileName: name, path: path);
  }

  /// `Android/media/<pkg>/سِجِل/المستندات/YYYY/MM/` when available (visible in
  /// file managers like WhatsApp media), else app documents dir.
  static Future<Directory> documentsDir(DateTime now) async {
    Directory base;
    try {
      final ext = Platform.isAndroid ? await getExternalStorageDirectory() : null;
      if (ext != null) {
        // /storage/emulated/0/Android/data/<pkg>/files → /storage/emulated/0/Android/media/<pkg>
        final root = ext.path.split('/Android/').first;
        final pkg = ext.path.split('/Android/data/').last.split('/').first;
        base = Directory('$root/Android/media/$pkg/سِجِل');
      } else {
        base = Directory('${(await getApplicationDocumentsDirectory()).path}/سِجِل');
      }
    } catch (_) {
      base = Directory('${(await getApplicationDocumentsDirectory()).path}/سِجِل');
    }
    final dir = Directory('${base.path}/المستندات/${now.year}/${now.month.toString().padLeft(2, '0')}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Currency> _primary() async {
    final r = await _db.query('currencies', where: 'is_primary = 1', limit: 1);
    return r.isEmpty ? Currency.yer : Currency.byCode(r.first['code'] as String);
  }
}
