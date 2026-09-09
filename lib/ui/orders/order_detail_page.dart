// ============================================================
// كِتابي - تفاصيل الطلب: خط زمني للحالة + الأصناف + الإجماليات
// - تمرير بيانات الطلب من شاشة السلة/الطلبات (Navigation with data)
// - محاكاة تقدّم الحالة (تم الطلب → قيد التجهيز → تم التسليم)
// - إلغاء الطلب (Dialog تأكيد) ما لم يُسلَّم
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../../data/repos/repos.dart';
import '../../models/models.dart';
import '../shared/widgets.dart';

class OrderDetailPage extends StatefulWidget {
  final Order order;
  final bool justPlaced;
  const OrderDetailPage({super.key, required this.order, this.justPlaced = false});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _repo = OrderRepo();
  late Order _order = widget.order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.justPlaced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notify(context, 'تم تسجيل طلبك رقم #${_order.id} بنجاح', icon: Icons.check_circle_outline);
      });
    }
  }

  Future<void> _reload() async {
    final o = await _repo.byId(_order.id);
    if (o != null && mounted) setState(() => _order = o);
  }

  Future<void> _advance() async {
    final next = switch (_order.status) {
      OrderStatus.placed => OrderStatus.processing,
      OrderStatus.processing => OrderStatus.delivered,
      OrderStatus.delivered => null,
    };
    if (next == null) return;
    setState(() => _busy = true);
    await _repo.advanceStatus(_order.id, next);
    await _reload();
    if (!mounted) return;
    setState(() => _busy = false);
    notify(context, 'تم تحديث حالة الطلب إلى: ${next.label}', icon: Icons.local_shipping_outlined);
  }

  Future<void> _cancel() async {
    final ok = await confirm(
      context,
      title: 'إلغاء الطلب',
      message: 'هل تريد إلغاء الطلب #${_order.id}؟ لا يمكن التراجع عن هذا الإجراء.',
      okLabel: 'إلغاء الطلب',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await _repo.cancel(_order.id);
    if (!mounted) return;
    if (done) {
      notify(context, 'تم إلغاء الطلب #${_order.id}', icon: Icons.cancel_outlined);
      Navigator.pop(context, true);
    } else {
      notify(context, 'لا يمكن إلغاء طلب تم تسليمه', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final delivered = o.status == OrderStatus.delivered;
    return Scaffold(
      appBar: AppBar(
        title: Text('الطلب #${o.id}'),
        actions: [
          IconButton(
            tooltip: 'نسخ رقم الطلب',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'KTB-${o.id.toString().padLeft(5, '0')}'));
              notify(context, 'تم نسخ رقم الطلب', icon: Icons.copy_rounded);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _StatusCard(order: o),
                  const SizedBox(height: 14),
                  const SectionTitle(title: 'الأصناف'),
                  const SizedBox(height: 6),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < o.lines.length; i++) ...[
                          _LineTile(line: o.lines[i]),
                          if (i != o.lines.length - 1) const Divider(height: 1, color: Palette.line),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionTitle(title: 'ملخص الدفع'),
                  const SizedBox(height: 6),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _Row('عدد الكتب', '${o.itemCount}'),
                          _Row('المجموع الفرعي', fmtPrice(o.subtotal)),
                          if (o.discount > 0)
                            _Row(
                              'الخصم${o.coupon != null ? ' (${o.coupon})' : ''}',
                              '- ${fmtPrice(o.discount)}',
                              color: Palette.success,
                            ),
                          const Divider(color: Palette.line),
                          _Row('الإجمالي', fmtPrice(o.total), bold: true),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 15, color: Palette.ivoryDim),
                              const SizedBox(width: 6),
                              Text(fmtDate(o.createdAt), style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // شريط الإجراءات
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Palette.nightSoft,
                border: Border(top: BorderSide(color: Palette.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: delivered || _busy ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined, color: Palette.danger),
                      label: const Text('إلغاء الطلب', style: TextStyle(color: Palette.danger)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: delivered || _busy ? null : _advance,
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.night))
                          : const Icon(Icons.local_shipping_outlined),
                      label: Text(delivered ? 'تم التسليم' : 'محاكاة: الخطوة التالية'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ خط زمني للحالة
class _StatusCard extends StatelessWidget {
  final Order order;
  const _StatusCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.values;
    final current = order.status.index;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Palette.gold.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Palette.gold.withValues(alpha: .5)),
                  ),
                  child: Text(order.status.label, style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Spacer(),
                Text('KTB-${order.id.toString().padLeft(5, '0')}', style: AppText.serifStyle(15, color: Palette.ivory)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  _Dot(active: i <= current, done: i < current, icon: _iconFor(steps[i])),
                  if (i != steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: i < current ? Palette.gold : Palette.line,
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Text(
                      steps[i].label,
                      textAlign: i == 0
                          ? TextAlign.start
                          : i == steps.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: i <= current ? Palette.ivory : Palette.ivoryDim,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(OrderStatus s) => switch (s) {
    OrderStatus.placed => Icons.receipt_long_outlined,
    OrderStatus.processing => Icons.inventory_2_outlined,
    OrderStatus.delivered => Icons.home_outlined,
  };
}

class _Dot extends StatelessWidget {
  final bool active, done;
  final IconData icon;
  const _Dot({required this.active, required this.done, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Palette.gold : Palette.nightSoft,
        border: Border.all(color: active ? Palette.gold : Palette.line, width: 1.5),
      ),
      child: Icon(done ? Icons.check : icon, size: 17, color: active ? Palette.night : Palette.ivoryDim),
    );
  }
}

class _LineTile extends StatelessWidget {
  final OrderLine line;
  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 50,
        decoration: BoxDecoration(
          color: Palette.walnut,
          borderRadius: BorderRadius.circular(6),
          image: DecorationImage(image: AssetImage('assets/covers/book_${line.bookId}.png'), fit: BoxFit.cover),
        ),
      ),
      title: Text(line.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${line.qty} × ${fmtPrice(line.unitPrice)}', style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
      trailing: Text(fmtPrice(line.total), style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700)),
    );
  }
}

class _Row extends StatelessWidget {
  final String k, v;
  final bool bold;
  final Color? color;
  const _Row(this.k, this.v, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 13.5,
      color: color ?? (bold ? Palette.gold : Palette.ivory),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: TextStyle(color: Palette.ivoryDim, fontSize: bold ? 15 : 13.5)), Text(v, style: style)],
      ),
    );
  }
}
