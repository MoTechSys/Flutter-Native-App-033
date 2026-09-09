// ============================================================
// كِتابي - طلباتي (قائمة) + تفاصيل الطلب (تتبع الحالة / إلغاء)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../data/repos/repos.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../shared/widgets.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _repo = OrderRepo();
  List<Order>? _orders;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.forUser(context.read<Session>().uid);
    if (mounted) setState(() => _orders = list);
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: SafeArea(
        child: orders == null
            ? const Center(child: CircularProgressIndicator(color: Palette.gold))
            : orders.isEmpty
            ? const EmptyView(icon: Icons.receipt_long_outlined, title: 'لا توجد طلبات', subtitle: 'ستظهر طلباتك هنا بعد إتمام الشراء من السلة')
            : Column(
                children: [
                  _Stats(orders: orders),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final o = orders[i];
                        return Card(
                          child: ListTile(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(order: o)));
                              _load();
                            },
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: _statusColor(o.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_statusIcon(o.status), color: _statusColor(o.status)),
                            ),
                            title: Text('طلب #${o.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${o.itemCount} كتاب • ${fmtDate(o.createdAt)}', style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fmtPrice(o.total), style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w800)),
                                Text(o.status.label, style: TextStyle(fontSize: 11, color: _statusColor(o.status))),
                              ],
                            ),
                          ),
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

Color _statusColor(OrderStatus s) => switch (s) {
  OrderStatus.placed => Palette.gold,
  OrderStatus.processing => const Color(0xFF4EA8DE),
  OrderStatus.delivered => Palette.success,
};

IconData _statusIcon(OrderStatus s) => switch (s) {
  OrderStatus.placed => Icons.receipt_long,
  OrderStatus.processing => Icons.inventory_2_outlined,
  OrderStatus.delivered => Icons.check_circle_outline,
};

class _Stats extends StatelessWidget {
  final List<Order> orders;
  const _Stats({required this.orders});
  @override
  Widget build(BuildContext context) {
    final spent = orders.fold<double>(0, (a, o) => a + o.total);
    final books = orders.fold<int>(0, (a, o) => a + o.itemCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _Stat('الطلبات', '${orders.length}', Icons.receipt_long),
          const SizedBox(width: 10),
          _Stat('الكتب', '$books', Icons.menu_book),
          const SizedBox(width: 10),
          _Stat('الإنفاق', fmtPrice(spent), Icons.payments_outlined),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String k, v;
  final IconData i;
  const _Stat(this.k, this.v, this.i);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Palette.nightSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.line)),
      child: Column(
        children: [
          Icon(i, color: Palette.gold, size: 20),
          const SizedBox(height: 4),
          Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(k, style: const TextStyle(fontSize: 11, color: Palette.ivoryDim)),
        ],
      ),
    ),
  );
}
