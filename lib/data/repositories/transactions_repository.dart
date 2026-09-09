import 'package:sqflite_common/sqlite_api.dart';

import '../../core/ledger/ledger_models.dart';

/// Filter chips on the transactions list (docs/03 §6.3).
enum TxFilter { all, took, paid, today }

/// Transaction + customer display info for lists.
class TxListItem {
  final LedgerTx tx;
  final String customerName;
  final String? photoPath;
  const TxListItem({required this.tx, required this.customerName, this.photoPath});
}

/// Read-only paging over `transactions` joined with customer photo/name.
/// Writes go through LedgerService only (R1).
class TransactionsRepository {
  final Database _db;
  TransactionsRepository(this._db);

  Future<List<TxListItem>> page({
    TxFilter filter = TxFilter.all,
    String? customerId,
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    final conds = <String>[];
    final args = <Object?>[];
    switch (filter) {
      case TxFilter.all:
        break;
      case TxFilter.took:
        conds.add("t.type = 'debit'");
      case TxFilter.paid:
        conds.add("t.type = 'credit'");
      case TxFilter.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day).toUtc().millisecondsSinceEpoch;
        conds.add('t.occurred_at >= ?');
        args.add(start);
    }
    if (customerId != null) {
      conds.add('t.customer_id = ?');
      args.add(customerId);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      conds.add('(c.name LIKE ? OR t.customer_name_snap LIKE ? OR t.note_text LIKE ?)');
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }
    final where = conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    args.addAll([limit, offset]);
    final rows = await _db.rawQuery('''
      SELECT t.*, c.name AS c_name, c.photo_path AS c_photo
      FROM transactions t LEFT JOIN customers c ON c.id = t.customer_id
      $where
      ORDER BY t.occurred_at DESC, t.recorded_at DESC, t.rowid DESC
      LIMIT ? OFFSET ?
    ''', args);
    return rows
        .map((r) => TxListItem(
              tx: LedgerTx.fromRow(r),
              customerName: (r['c_name'] as String?) ?? (r['customer_name_snap'] as String),
              photoPath: r['c_photo'] as String?,
            ))
        .toList();
  }
}
