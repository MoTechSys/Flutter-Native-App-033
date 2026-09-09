import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/settings_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_back_button.dart';

/// One help topic = icon + title + exact spoken script (matches what the
/// screen actually shows; verified against the built screens — docs/03 §7).
class HelpTopic {
  final IconData icon;
  final String title;
  final List<String> steps;
  const HelpTopic(this.icon, this.title, this.steps);
}

/// Voice help (phase 5 brought forward): big cards, each reads its steps
/// one by one. Scripts use the same words as the buttons (D11 labels
/// injected), simple Arabic, one action per sentence.
class VoiceHelpScreen extends StatefulWidget {
  const VoiceHelpScreen({super.key});

  @override
  State<VoiceHelpScreen> createState() => _VoiceHelpScreenState();
}

class _VoiceHelpScreenState extends State<VoiceHelpScreen> {
  int? _playing;
  int _step = 0;

  List<HelpTopic> _topics(SettingsRepository st) {
    final took = st.labelTook;
    final paid = st.labelPaid;
    return [
      HelpTopic(Icons.home_rounded, 'الشاشة الرئيسية', [
        'هذه الشاشة الرئيسية. الرقم الكبير في البطاقة الخضراء هو مجموع ما لك عند الناس.',
        'البطاقة الحمراء فيها عدد المتأخرين، اضغط عليها لتشاهدهم.',
        'البطاقة الصفراء تعرض ما أُخذ وما دُفع اليوم.',
        'تحت البطاقات أربعة أزرار: الزباين، عملية، التقارير، المتأخرين.',
        'في الأسفل صف صور آخر الزباين الذين تعاملت معهم. اضغط على صورة لتسجيل عملية له مباشرة.',
        'زر الخطوط الثلاثة أعلى اليمين يفتح القائمة. زر السماعة أعلى اليسار يقرأ لك الإجمالي.',
      ]),
      HelpTopic(Icons.add_circle_rounded, 'تسجيل عملية جديدة', [
        'اضغط الزر الأخضر الكبير "عملية" في الرئيسية، أو اضغط على صورة الزبون.',
        'اختر الزبون من الصور. إذا لم تجده اكتب اسمه في البحث.',
        'اختر ماذا حدث: الزر الأحمر "$took" إذا أخذ بضاعة، أو الزر الأخضر "$paid" إذا سدّد.',
        'أدخل المبلغ بالضغط على الأوراق النقدية. كل ضغطة تزيد ورقة. اضغط مطوّلاً على الورقة لتنقص واحدة.',
        'إذا أردت الكتابة بالأرقام اضغط "أرقام" فوق الأوراق.',
        'راجع المبلغ الكبير في الأعلى، ثم اضغط الزر الملوّن في الأسفل.',
        'في شاشة التأكيد سيُقرأ لك المبلغ ورصيد الزبون الجديد. اضغط "حفظ".',
        'إذا أخطأت، اضغط "تراجع" في الشريط الأسود خلال ثماني ثوانٍ.',
      ]),
      HelpTopic(Icons.people_alt_rounded, 'إضافة زبون', [
        'اضغط "الزباين" في الرئيسية.',
        'اضغط الزر الأخضر الكبير في الأسفل فيه علامة زائد وشخص.',
        'اضغط الدائرة الكبيرة لتصوير الزبون بالكاميرا. الصورة تساعدك تعرفه بسرعة.',
        'اكتب اسمه. رقم الهاتف اختياري لكنه مهم لإرسال التذكير.',
        'اضغط "حفظ".',
      ]),
      HelpTopic(Icons.person_rounded, 'صفحة الزبون', [
        'اضغط على أي زبون في شاشة الزباين.',
        'الرقم الكبير هو ما عليه الآن. أحمر يعني عليه، أخضر يعني له أو مسدَّد.',
        'الأزرار: "أخذ" و"دفع" لتسجيل عملية، "واتساب" و"رسالة" لإرسال تذكير، "كشف" لطباعة كشف حساب.',
        'اضغط السماعة ليُقرأ لك رصيده.',
        'في الأسفل آخر خمس حركات. اضغط "الكل" لمشاهدة كل الحركات.',
      ]),
      HelpTopic(Icons.receipt_long_rounded, 'الحركات وإلغاء حركة', [
        'افتح "الحركات" من القائمة أو من "الكل" في الرئيسية.',
        'الشرائح في الأعلى تصفّي: الكل، أخذوا، دفعوا، اليوم.',
        'اضغط على حركة لترى تفاصيلها.',
        'المالك فقط يستطيع عكس الحركة. لا تُحذف الحركة أبداً، بل يُسجَّل قيد عكسي مع سبب، ويبقى كل شيء ظاهراً في السجل.',
      ]),
      HelpTopic(Icons.notifications_active_rounded, 'المتأخرين والتذكير', [
        'اضغط "المتأخرين" في الرئيسية. الرقم عليه هو عدد الزباين المتأخرين.',
        'الشرائح تقسّمهم حسب مدة التأخر: ثلاثين، ستين، تسعين يوماً أو أكثر.',
        'لكل زبون أزرار: "واتساب" لإرسال رسالة تذكير، "رسالة" نصية، و"وعد" لتسجيل موعد وعد بالدفع.',
        'زر "ذكّر الكل" في الأسفل يفتح واتساب لكل زبون بالترتيب.',
      ]),
      HelpTopic(Icons.picture_as_pdf_rounded, 'المستندات والطباعة', [
        'من صفحة الزبون اضغط "كشف"، أو من التقارير اضغط أيقونة الملف.',
        'اختر نوع المستند: كشف مختصر، كشف تفصيلي، سند قبض، إشعار مطالبة، تقرير المتأخرين، أو إقرار بالدين.',
        'اختر الفترة أو الدفعة حسب النوع.',
        'بعد التوليد تظهر أربعة أزرار: فتح، مشاركة على واتساب، طباعة، حفظ في التنزيلات.',
        'الملف يُحفظ أيضاً في مجلد سِجِل في ذاكرة الهاتف.',
      ]),
      HelpTopic(Icons.savings_rounded, 'العملات', [
        'من القائمة اضغط "العملات".',
        'فعّل العملة بالمفتاح على يسار اسمها.',
        'اضغط على خانة السعر واكتب السعر مباشرة، مثلاً خمسمائة وثلاثين، ثم اضغط خارج الخانة ليُحفظ.',
        'السعر للعرض التقريبي فقط. كل عملة لها حسابها المستقل ولا تُخلط الأرصدة أبداً.',
        'زر "اجعلها رئيسية" يغيّر العملة التي تظهر في الرئيسية.',
      ]),
      HelpTopic(Icons.badge_rounded, 'العمال والدخول', [
        'من القائمة اضغط "العمال" لإضافة عامل بصورته واسمه ورمز دخول من أربعة أرقام.',
        'حدّد صلاحياته: إضافة زباين، عكس الحركات، التسويات، رؤية الإجماليات.',
        'عند فتح التطبيق يختار كل شخص صورته ويكتب رمزه.',
        'للخروج وتبديل المستخدم اضغط "تسجيل خروج" في أسفل القائمة.',
      ]),
      HelpTopic(Icons.cloud_rounded, 'النسخة الاحتياطية', [
        'من القائمة اضغط "النسخة الاحتياطية".',
        'اضغط "انسخ الآن" لحفظ نسخة في ذاكرة الهاتف. تُحفظ نسخة تلقائياً كل يوم.',
        'اربط حساب Google لرفع النسخة إلى السحابة، واستعادتها على هاتف جديد.',
        'الاستعادة لا تحذف شيئاً؛ تضيف الحركات الناقصة فقط.',
      ]),
      HelpTopic(Icons.settings_rounded, 'الإعدادات', [
        'من القائمة اضغط "الإعدادات".',
        'يمكنك تغيير كلمتَي "$took" و"$paid" حسب لهجة منطقتك.',
        'يمكنك إيقاف الصوت أو تغيير سرعته، وتشغيل الوضع الداكن، وتكبير الخط، واختيار الأرقام العربية.',
        'المالك يحدّد بعد كم يوم يُعدّ الزبون متأخراً، ونص رسالة التذكير، وقفل الفترة القديمة.',
      ]),
    ];
  }

  Future<void> _play(int i, List<HelpTopic> topics, SpeechService speech) async {
    if (_playing == i) {
      await speech.stop();
      setState(() {
        _playing = null;
        _step = 0;
      });
      return;
    }
    setState(() {
      _playing = i;
      _step = 0;
    });
    final t = topics[i];
    for (var s = 0; s < t.steps.length; s++) {
      if (!mounted || _playing != i) return;
      setState(() => _step = s);
      await speech.speakAndWait('${s + 1}. ${t.steps[s]}');
      if (!mounted || _playing != i) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted && _playing == i) setState(() => _playing = null);
  }

  @override
  void dispose() {
    context.read<SpeechService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsRepository>();
    final speech = context.read<SpeechService>();
    final topics = _topics(st);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.voiceHelp)),
      body: SafeArea(
        child: Column(
          children: [
            if (!st.voiceEnabled)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.accentContainer, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.volume_off_rounded, color: AppColors.accent),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('الصوت مُوقَف من الإعدادات — ستُقرأ الخطوات نصاً فقط', style: TextStyle(color: AppColors.accent))),
                  TextButton(
                    onPressed: () {
                      st.set(SettingsRepository.kVoiceEnabled, true);
                      speech.enabled = true;
                    },
                    child: const Text('تشغيل'),
                  ),
                ]),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: topics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final t = topics[i];
                  final active = _playing == i;
                  return Material(
                    color: active ? AppColors.primary : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _play(i, topics, speech),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                    color: active ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(t.icon, size: 30, color: active ? Colors.white : AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(t.title,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: active ? Colors.white : null)),
                              ),
                              Icon(active ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                  size: 40, color: active ? Colors.white : AppColors.primary),
                            ]),
                            if (active) ...[
                              const SizedBox(height: 10),
                              for (var s = 0; s < t.steps.length; s++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24, height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color: s == _step ? AppColors.darkAccent : Colors.white.withValues(alpha: 0.25),
                                            shape: BoxShape.circle),
                                        child: Text('${s + 1}',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s == _step ? Colors.black : Colors.white)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(t.steps[s],
                                            style: TextStyle(
                                                fontSize: 15, height: 1.4, color: Colors.white,
                                                fontWeight: s == _step ? FontWeight.w800 : FontWeight.w400)),
                                      ),
                                    ],
                                  ),
                                ),
                            ] else
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('${t.steps.length} خطوات — اضغط للاستماع',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ),
                          ],
                        ),
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
