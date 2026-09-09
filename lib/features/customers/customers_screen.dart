import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/money/money_format.dart';
import '../../data/app_services.dart';
import '../../data/repositories/customer_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/filter_chips.dart';
import '../../shared/widgets/money_text.dart';
import 'add_customer_screen.dart';

/// Customers (docs/03 §6.6): grid/list toggle, filter chips, sort, search, FAB.
/// Used both as a destination and as step 1 of "new transaction" when
/// [pickMode] is true (returns the chosen customer id).
class CustomersScreen extends StatefulWidget {
  final bool pickMode;
  const CustomersScreen({super.key, this.pickMode = false});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  CustomerFilter _filter = CustomerFilter.all;
  CustomerSort _sort = CustomerSort.recentActivity;
  bool _grid = true;
  bool _searching = false;
  final _search = TextEditingController();
  Future<List<CustomerWithBalance>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<AppServices>().customers;
    setState(() {
      _future = repo.list(filter: _filter, sort: _sort, query: _search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    final id = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const AddCustomerScreen()));
    if (!mounted) return;
    if (id != null && widget.pickMode) {
      Navigator.pop(context, id);
      return;
    }
    _reload();
  }

  void _onTap(CustomerWithBalance c) async {
    if (widget.pickMode) {
      Navigator.pop(context, c.customer.id);
      return;
    }
    await Navigator.pushNamed(context, AppRoutes.customerDetail, arguments: c.customer.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => _reload(),
                decoration: const InputDecoration(
                  hintText: S.search,
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18),
              )
            : Text(widget.pickMode ? S.chooseCustomer : S.customers),
        actions: [
          IconButton(
            tooltip: S.search,
            iconSize: 28,
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              });
              _reload();
            },
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          if (!widget.pickMode)
            IconButton(
              tooltip: _grid ? 'قائمة' : 'شبكة',
              iconSize: 28,
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          PopupMenuButton<CustomerSort>(
            tooltip: 'ترتيب',
            iconSize: 28,
            icon: const Icon(Icons.sort_rounded),
            onSelected: (s) {
              _sort = s;
              _reload();
            },
            itemBuilder: (_) => [
              _sortItem(CustomerSort.recentActivity, S.sortRecent),
              _sortItem(CustomerSort.alphabetical, S.sortAlpha),
              _sortItem(CustomerSort.largestDebt, S.sortDebt),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'add_customer',
        onPressed: _openAdd,
        tooltip: S.addCustomer,
        child: const Icon(Icons.person_add_alt_1_rounded, size: 36),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FilterChipsRow<CustomerFilter>(
                value: _filter,
                items: const [
                  (CustomerFilter.all, S.all, null),
                  (CustomerFilter.owing, S.owingFilter, AppColors.debt),
                  (CustomerFilter.overdue, S.overdueFilter, AppColors.accent),
                  (CustomerFilter.settled, S.settledFilter, AppColors.payment),
                ],
                onChanged: (f) {
                  _filter = f;
                  _reload();
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CustomerWithBalance>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
                  final items = snap.data;
                  if (items == null) return const Center(child: CircularProgressIndicator());
                  if (items.isEmpty) return _Empty(onAdd: _openAdd, filtered: _filter != CustomerFilter.all || _search.text.isNotEmpty);
                  return _grid || widget.pickMode
                      ? _Grid(items: items, onTap: _onTap)
                      : _List(items: items, onTap: _onTap);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<CustomerSort> _sortItem(CustomerSort s, String label) => PopupMenuItem(
        value: s,
        child: Row(
          children: [
            Icon(_sort == s ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      );
}

class _Grid extends StatelessWidget {
  final List<CustomerWithBalance> items;
  final void Function(CustomerWithBalance) onTap;
  const _Grid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        final c = it.customer;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTap(it),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 72),
                      if (it.isOverdue)
                        PositionedDirectional(
                          end: -2,
                          top: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: AppColors.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.priority_high_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  _BalanceLine(it: it, size: 15),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _List extends StatelessWidget {
  final List<CustomerWithBalance> items;
  final void Function(CustomerWithBalance) onTap;
  const _List({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = items[i];
        final c = it.customer;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(it),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (it.isOverdue) ...[
                              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.accent),
                              const SizedBox(width: 3),
                            ],
                            Text(DateLabels.ago(c.lastActivityAt),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _BalanceLine(it: it, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceLine extends StatelessWidget {
  final CustomerWithBalance it;
  final double size;
  const _BalanceLine({required this.it, required this.size});

  @override
  Widget build(BuildContext context) {
    final b = it.primaryBalance;
    if (b.isZero && it.otherBalances.isEmpty) {
      return Text(S.settled,
          style: TextStyle(
              fontSize: size - 2, color: AppColors.payment, fontWeight: FontWeight.w700));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!b.isZero) MoneyText(b, fontSize: size, showArrow: true),
        for (final o in it.otherBalances.values)
          Text(MoneyFormat.withSymbol(o.abs),
              style: TextStyle(
                  fontSize: size - 5,
                  fontWeight: FontWeight.w700,
                  color: o.isNegative ? AppColors.payment : AppColors.debt)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  final bool filtered;
  const _Empty({required this.onAdd, required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(filtered ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 88, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(filtered ? S.noResults : S.noCustomers,
              style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          if (!filtered) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(S.addFirstCustomer),
            ),
          ],
        ],
      ),
    );
  }
}
