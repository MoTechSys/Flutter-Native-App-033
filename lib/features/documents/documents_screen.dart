import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/docs/doc_layout.dart';
import '../../data/app_services.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transactions_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../customers/customers_screen.dart';
import 'template_editor_screen.dart';

/// Document center (phase 3): choose a kind → inputs → generate → open/share/print.
class DocumentsScreen extends StatelessWidget {
  final String? customerId;
  const DocumentsScreen({super.key, this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('المستندات'),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: 'القوالب',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplateEditorScreen())),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            for (final k in DocKind.values)
              _KindCard(
                kind: k,
                onTap: () => DocumentFlow.start(context, k, customerId: customerId),
              ),
          ],
        ),
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  final DocKind kind;
  final VoidCallback onTap;
  const _KindCard({required this.kind, required this.onTap});

  IconData get _icon => switch (kind) {
        DocKind.statement => Icons.receipt_long_rounded,
        DocKind.statementDetailed => Icons.table_chart_rounded,
        DocKind.receipt => Icons.receipt_rounded,
        DocKind.claim => Icons.mark_email_unread_rounded,
        DocKind.overdueReport => Icons.summarize_rounded,
        DocKind.debtAck => Icons.gavel_rounded,
      };

  String get _hint => switch (kind) {
        DocKind.statement => 'صفحة واحدة: افتتاحي/أخذ/دفع/ختامي',
        DocKind.statementDetailed => 'كل الحركات مع الرصيد الجاري',
        DocKind.receipt => 'لدفعة واحدة — A5 أو حراري',
        DocKind.claim => 'رسالة رسمية بطلب السداد',
        DocKind.overdueReport => 'جدول كل المتأخرين (للمالك)',
        DocKind.debtAck => 'إقرار يوقّعه الزبون وشاهدان',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 44, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(kind.titleAr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collects inputs for a kind, generates, then shows the 4-button result sheet.
class DocumentFlow {
  DocumentFlow._();

  static Future<void> start(BuildContext context, DocKind kind, {String? customerId, String? txId}) async {
    final services = context.read<AppServices>();
    final session = context.read<SessionProvider>();
    final st = context.read<SettingsRepository>();
    final repo = DocumentRepository(services.db, services.ledger, deviceId: services.deviceId);
    final by = session.user?.id ?? '';
    final watermark = st.get<String?>(SettingsRepository.kActivationCode) == null;

    Customer? customer;
    if (kind != DocKind.overdueReport) {
      var id = customerId;
      id ??= await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const CustomersScreen(pickMode: true)));
      if (id == null || !context.mounted) return;
      customer = await services.customers.getById(id);
      if (customer == null || !context.mounted) return;
    }

    GeneratedDoc? out;
    try {
      switch (kind) {
        case DocKind.statement:
        case DocKind.statementDetailed:
          final range = await _pickRange(context);
          if (range == null || !context.mounted) return;
          out = await _busy(context, () => repo.statement(
                customer: customer!, from: range.start, to: range.end, detailed: kind == DocKind.statementDetailed, watermark: watermark, byUserId: by));
        case DocKind.receipt:
          var tid = txId;
          if (tid == null) {
            if (!context.mounted) return;
            tid = await _pickPayment(context, services.transactions, customer!);
            if (tid == null || !context.mounted) return;
          }
          final thermal = await _ask(context, 'حجم السند', ['A5 (نصف ورقة)', 'طابعة حرارية 80mm']) == 1;
          if (!context.mounted) return;
          out = await _busy(context, () => repo.receipt(customer: customer!, txId: tid!, thermal: thermal, watermark: watermark, byUserId: by));
        case DocKind.claim:
          final days = await _ask(context, 'مدة السداد المطلوبة', ['3 أيام', '7 أيام', '15 يوماً', '30 يوماً']);
          if (days == null || !context.mounted) return;
          out = await _busy(context, () => repo.claim(customer: customer!, payWithinDays: [3, 7, 15, 30][days], watermark: watermark, byUserId: by));
        case DocKind.overdueReport:
          out = await _busy(context, () => repo.overdueReport(overdueDays: st.overdueDays, watermark: watermark, byUserId: by));
        case DocKind.debtAck:
          final idNo = await _text(context, 'رقم البطاقة الشخصية (اختياري)');
          if (!context.mounted) return;
          final payBy = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
            helpText: 'موعد السداد (اختياري — إلغاء = عند الطلب)',
          );
          if (!context.mounted) return;
          out = await _busy(context, () => repo.debtAck(customer: customer!, idNumber: idNo, payBy: payBy, watermark: watermark, byUserId: by));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إنشاء المستند: $e'), backgroundColor: AppColors.debt));
      }
      return;
    }
    if (out != null && context.mounted) await showResult(context, out, kind);
  }

  static Future<T> _busy<T>(BuildContext context, Future<T> Function() f) async {
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      return await f();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  static Future<DateTimeRange?> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final choice = await _ask(context, 'الفترة', ['هذا الشهر', 'الشهر الماضي', 'آخر 3 أشهر', 'منذ البداية', 'اختيار تاريخين']);
    if (choice == null) return null;
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (choice) {
      case 0:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: endOfToday);
      case 1:
        return DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0, 23, 59, 59));
      case 2:
        return DateTimeRange(start: DateTime(now.year, now.month - 3, now.day), end: endOfToday);
      case 3:
        return DateTimeRange(start: DateTime(2000), end: endOfToday);
      default:
        if (!context.mounted) return null;
        final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 5), lastDate: now, helpText: 'الفترة');
        if (r == null) return null;
        return DateTimeRange(start: r.start, end: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59));
    }
  }

  static Future<String?> _pickPayment(BuildContext context, TransactionsRepository txs, Customer c) async {
    final items = await txs.page(customerId: c.id, filter: TxFilter.paid, limit: 30);
    if (!context.mounted) return null;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا دفعات لهذا الزبون')));
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('اختر الدفعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            for (final it in items)
              ListTile(
                minTileHeight: 56,
                leading: CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 40),
                title: Text('+${it.tx.amount.minor ~/ it.tx.amount.currency.scale} ${it.tx.amount.currency.shortName}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.payment)),
                subtitle: Text(DateLabels.full(it.tx.occurredAt)),
                onTap: () => Navigator.pop(ctx, it.tx.id),
              ),
          ],
        ),
      ),
    );
  }

  static Future<int?> _ask(BuildContext context, String title, List<String> options) => showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(12), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              for (var i = 0; i < options.length; i++)
                ListTile(minTileHeight: 56, title: Text(options[i], style: const TextStyle(fontSize: 17)), onTap: () => Navigator.pop(ctx, i)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  static Future<String?> _text(BuildContext context, String title) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('تخطّي')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text(S.done)),
        ],
      ),
    );
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  /// docs/09 §6: 4 big buttons — open • share • print • save to Downloads.
  static Future<void> showResult(BuildContext context, GeneratedDoc doc, DocKind kind) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.payment, size: 48),
              const SizedBox(height: 6),
              Text('${kind.titleAr} جاهز', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(doc.fileName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textDirection: TextDirection.ltr),
              if (doc.path != null)
                Text('حُفظ في مجلد سِجِل/المستندات', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Big(icon: Icons.open_in_new_rounded, label: 'فتح', onTap: () => _preview(ctx, doc)),
                  const SizedBox(width: 10),
                  _Big(
                      icon: Icons.share_rounded,
                      label: 'مشاركة',
                      onTap: () => Share.shareXFiles([XFile.fromData(doc.bytes, name: doc.fileName, mimeType: 'application/pdf')], text: kind.titleAr)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Big(icon: Icons.print_rounded, label: 'طباعة', onTap: () => Printing.layoutPdf(onLayout: (_) async => doc.bytes, name: doc.fileName)),
                  const SizedBox(width: 10),
                  _Big(
                      icon: Icons.download_rounded,
                      label: 'حفظ في التنزيلات',
                      onTap: () => Printing.sharePdf(bytes: doc.bytes, filename: doc.fileName)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _preview(BuildContext context, GeneratedDoc doc) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(leading: const AppBackButton(), title: Text(doc.fileName, style: const TextStyle(fontSize: 12))),
            body: PdfPreview(
              build: (_) async => doc.bytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: doc.fileName,
            ),
          ),
        ),
      );

  /// Used by the template editor for live preview.
  static Future<Uint8List> raster(Uint8List pdf) async {
    await for (final page in Printing.raster(pdf, pages: [0], dpi: kIsWeb ? 60 : 90)) {
      return page.toPng();
    }
    return Uint8List(0);
  }
}

class _Big extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Big({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 34, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
