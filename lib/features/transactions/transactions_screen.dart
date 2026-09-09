import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../data/app_services.dart';
import '../../data/repositories/transactions_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/filter_chips.dart';
import '../../shared/widgets/tx_tile.dart';
import 'new_transaction_flow.dart';
import '../../shared/widgets/app_back_button.dart';

/// Transactions list — mockup `03_transactions_list.png` (docs/03 §6.3):
/// chips الكل/أخذوا/دفعوا/اليوم, sticky-ish date headers, 72dp rows,
/// incremental loading 20 at a time, FAB "+" bottom-start.
class TransactionsScreen extends StatefulWidget {
  final String? customerId;
  const TransactionsScreen({super.key, this.customerId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const _pageSize = 20;
  TxFilter _filter = TxFilter.all;
  final _items = <TxListItem>[];
  bool _loading = false;
  bool _end = false;
  bool _searching = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400 && !_loading && !_end) _loadMore();
    });
    _reset();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() {
      _items.clear();
      _end = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    final repo = context.read<AppServices>().transactions;
    final page = await repo.page(
      filter: _filter,
      customerId: widget.customerId,
      query: _search.text,
      limit: _pageSize,
      offset: _items.length,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      if (page.length < _pageSize) _end = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => _reset(),
                decoration: const InputDecoration(hintText: S.search, border: InputBorder.none),
                style: const TextStyle(fontSize: 18),
              )
            : const Text(S.transactions),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: S.search,
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              });
              _reset();
            },
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'add_tx',
        tooltip: S.newTransactionFull,
        onPressed: () async {
          final saved = await NewTransactionFlow.start(context, customerId: widget.customerId);
          if (saved && mounted) _reset();
        },
        child: const Icon(Icons.add_rounded, size: 40),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FilterChipsRow<TxFilter>(
                value: _filter,
                items: const [
                  (TxFilter.all, S.all, null),
                  (TxFilter.took, S.tookFilter, AppColors.debt),
                  (TxFilter.paid, S.paidFilter, AppColors.payment),
                  (TxFilter.today, S.today, null),
                ],
                onChanged: (f) {
                  _filter = f;
                  _reset();
                },
              ),
            ),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? const Center(
                      child: Text(S.noTransactionsYet,
                          style: TextStyle(fontSize: 18, color: AppColors.textSecondary)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final it = _items[i];
                        final showHeader = i == 0 ||
                            !DateLabels.sameDay(_items[i - 1].tx.occurredAt, it.tx.occurredAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader)
                              Padding(
                                padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 18, 4, 8),
                                child: Text(
                                  DateLabels.sectionHeader(it.tx.occurredAt),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TxTile(
                                item: it,
                                onTap: () async {
                                  await Navigator.pushNamed(context, AppRoutes.txDetail,
                                      arguments: it.tx.id);
                                  if (mounted) _reset();
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
