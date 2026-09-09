import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/money/arabic_words.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../data/app_services.dart';
import '../../data/repositories/reports_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/filter_chips.dart';

/// Reports (phase 2): period summary + bar chart, top 10 debtors, worker
/// performance. Owner only (drawer hides it for workers).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.month;
  Currency _cur = Currency.yer;
  List<Currency> _active = const [Currency.yer];
  PeriodSummary? _sum;
  List<DayPoint> _days = const [];
  List<TopDebtor> _top = const [];
  List<WorkerStat> _workers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppServices>();
    final repo = ReportsRepository(s.db);
    final active = await s.currencies.active();
    final primary = await s.currencies.primary();
    if (!active.contains(_cur)) _cur = primary;
    final (from, to) = ReportsRepository.range(_period);
    final results = await Future.wait([
      repo.summary(_cur, from, to),
      repo.daily(_cur, from, to),
      repo.topDebtors(_cur),
      repo.workers(_cur, from, to),
    ]);
    if (!mounted) return;
    setState(() {
      _active = active;
      _sum = results[0] as PeriodSummary;
      _days = results[1] as List<DayPoint>;
      _top = results[2] as List<TopDebtor>;
      _workers = results[3] as List<WorkerStat>;
      _loading = false;
    });
  }

  String get _periodLabel => switch (_period) {
        ReportPeriod.today => 'اليوم',
        ReportPeriod.week => 'هذا الأسبوع',
        ReportPeriod.month => 'هذا الشهر',
        ReportPeriod.year => 'هذه السنة',
      };

  @override
  Widget build(BuildContext context) {
    final speech = context.read<SpeechService>();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(S.reports),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: S.listen,
            onPressed: _sum == null
                ? null
                : () => speech.speak(
                    '$_periodLabel: أخذوا ${ArabicWords.money(_sum!.took)}، دفعوا ${ArabicWords.money(_sum!.paid)}'),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            iconSize: 28,
            tooltip: 'مستندات',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.documents),
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  FilterChipsRow<ReportPeriod>(
                    value: _period,
                    items: const [
                      (ReportPeriod.today, 'اليوم', null),
                      (ReportPeriod.week, 'الأسبوع', null),
                      (ReportPeriod.month, 'الشهر', null),
                      (ReportPeriod.year, 'السنة', null),
                    ],
                    onChanged: (p) {
                      _period = p;
                      _load();
                    },
                  ),
                  if (_active.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final c in _active)
                            ChoiceChip(
                              label: Text(c.shortName),
                              selected: c == _cur,
                              onSelected: (_) {
                                _cur = c;
                                _load();
                              },
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _SummaryCards(sum: _sum!),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'أخذوا / دفعوا — $_periodLabel',
                    child: SizedBox(height: 160, child: _Bars(days: _days, period: _period)),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'أعلى 10 ديون',
                    child: _top.isEmpty
                        ? const Padding(padding: EdgeInsets.all(12), child: Text('لا ديون'))
                        : Column(
                            children: [
                              for (var i = 0; i < _top.length; i++)
                                InkWell(
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.customerDetail,
                                      arguments: _top[i].customerId),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Text('${i + 1}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                                        ),
                                        CustomerAvatar(name: _top[i].name, photoPath: _top[i].photoPath, size: 40),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(_top[i].name,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        Text(MoneyFormat.amount(_top[i].balance),
                                            style: const TextStyle(
                                                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.debt)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'أداء العمال — $_periodLabel',
                    child: _workers.isEmpty
                        ? const Padding(padding: EdgeInsets.all(12), child: Text('لا حركات في الفترة'))
                        : Column(
                            children: [
                              for (final w in _workers)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      CustomerAvatar(name: w.name, size: 40),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(w.name,
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                            Text(
                                              '${w.txCount} حركة${w.reversals > 0 ? ' • ${w.reversals} مُعكسة' : ''}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: w.reversals > 2 ? AppColors.debt : AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('−${MoneyFormat.amount(w.took)}',
                                              style: const TextStyle(
                                                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.debt)),
                                          Text('+${MoneyFormat.amount(w.paid)}',
                                              style: const TextStyle(
                                                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.payment)),
                                        ],
                                      ),
                                    ],
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

class _SummaryCards extends StatelessWidget {
  final PeriodSummary sum;
  const _SummaryCards({required this.sum});

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, Money m, Color color, Color bg, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(MoneyFormat.amount(m),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                ),
              ],
            ),
          ),
        );
    final net = sum.netChange;
    return Column(
      children: [
        Row(
          children: [
            cell(S.tookFilter, sum.took, AppColors.debt, AppColors.debtContainer, Icons.arrow_downward_rounded),
            const SizedBox(width: 8),
            cell(S.paidFilter, sum.paid, AppColors.payment, AppColors.paymentContainer, Icons.arrow_upward_rounded),
            const SizedBox(width: 8),
            cell(
              net.isNegative ? 'نقص الدين' : 'زاد الدين',
              net.abs,
              AppColors.accent,
              AppColors.accentContainer,
              net.isNegative ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${sum.txCount} حركة • ${sum.customersServed} زبون • ${DateLabels.short(sum.from)} → ${DateLabels.short(sum.to.subtract(const Duration(days: 1)))}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Simple two-tone bar chart (no chart package — light devices).
class _Bars extends StatelessWidget {
  final List<DayPoint> days;
  final ReportPeriod period;
  const _Bars({required this.days, required this.period});

  @override
  Widget build(BuildContext context) {
    // Aggregate to at most 12 buckets so bars stay readable.
    final buckets = _bucketize(days, 12);
    var maxV = 1;
    for (final b in buckets) {
      maxV = math.max(maxV, math.max(b.took.minor, b.paid.minor));
    }
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight - 18;
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in buckets)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _bar(b.took.minor / maxV * h, AppColors.debt)),
                          const SizedBox(width: 1),
                          Expanded(child: _bar(b.paid.minor / maxV * h, AppColors.payment)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final b in buckets)
                Expanded(
                  child: Text(_label(b.day),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ],
      );
    });
  }

  Widget _bar(double h, Color c) => Container(
        height: math.max(h, 2),
        decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      );

  String _label(DateTime d) => switch (period) {
        ReportPeriod.today => '',
        ReportPeriod.week => ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'][d.weekday - 1],
        ReportPeriod.month => '${d.day}',
        ReportPeriod.year => '${d.month}',
      };

  static List<DayPoint> _bucketize(List<DayPoint> d, int max) {
    if (d.length <= max) return d;
    final size = (d.length / max).ceil();
    final out = <DayPoint>[];
    for (var i = 0; i < d.length; i += size) {
      final chunk = d.sublist(i, math.min(i + size, d.length));
      var t = chunk.first.took, p = chunk.first.paid;
      for (final x in chunk.skip(1)) {
        t = t + x.took;
        p = p + x.paid;
      }
      out.add(DayPoint(chunk.first.day, t, p));
    }
    return out;
  }
}
