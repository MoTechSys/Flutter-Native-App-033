import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_services.dart';
import '../../data/backup/backup_service.dart';
import '../../data/backup/drive_backup.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';

/// Backup (phases 1 & 4): local now / list / restore, share export, Drive.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<File> _local = const [];
  bool _busy = false;
  String? _driveEmail;
  final _drive = DriveBackup();

  BackupService get _svc {
    final s = context.read<AppServices>();
    return BackupService(s.db, deviceId: s.deviceId);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await _svc.localBackups();
    String? email;
    if (!kIsWeb) email = (await _drive.currentUser())?.email;
    if (!mounted) return;
    setState(() {
      _local = files;
      _driveEmail = email;
    });
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('FormatException: ', '')), backgroundColor: AppColors.debt));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _load();
    }
  }

  void _ok(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.primary));

  Future<void> _backupNow() => _run(() async {
        final st = context.read<SettingsRepository>();
        final f = await _svc.writeLocal();
        await st.set(SettingsRepository.kLastLocalBackupAt, DateTime.now().toUtc().millisecondsSinceEpoch);
        _ok(f == null ? 'النسخ المحلي غير متاح على الويب' : 'تم الحفظ: ${f.path.split('/').last}');
      });

  Future<void> _share() => _run(() async {
        final bytes = await _svc.exportBytes();
        final name = 'sijil_${DateTime.now().toIso8601String().substring(0, 10)}.sijil';
        await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: 'application/json')], text: 'نسخة سِجِل');
      });

  Future<void> _restoreFile(File f) async {
    final ledger = context.read<AppServices>().ledger;
    final ok = await _confirmRestore(f.path.split('/').last);
    if (ok != true) return;
    await _run(() async {
      final counts = await _svc.restore(await f.readAsBytes());
      final added = counts.values.fold<int>(0, (a, b) => a + b);
      await ledger.rebuildCache();
      _ok('تمت الاستعادة — أُضيف $added سجلاً جديداً (لم يُحذف شيء)');
    });
  }

  Future<void> _restorePick() async {
    // image_picker can't pick arbitrary files; use share-in / Drive on Android.
    // Here: pick from local list or Drive. Kept simple on purpose.
    if (_local.isEmpty) {
      _ok('لا نسخ محلية. استعد من Google Drive أو انسخ ملف .sijil إلى مجلد النسخ_الاحتياطية');
      return;
    }
    final f = await showModalBottomSheet<File>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final x in _local)
            ListTile(
              leading: const Icon(Icons.restore_rounded, color: AppColors.primary),
              title: Text(x.path.split('/').last, textDirection: TextDirection.ltr),
              subtitle: Text('${(x.lengthSync() / 1024).toStringAsFixed(1)} KB'),
              onTap: () => Navigator.pop(ctx, x),
            ),
        ]),
      ),
    );
    if (f != null) _restoreFile(f);
  }

  Future<bool?> _confirmRestore(String name) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('استعادة نسخة'),
          content: Text('$name\n\nستُؤخذ نسخة أمان أولاً، ثم تُضاف السجلات الناقصة فقط. لا يُحذف ولا يُعدَّل أي شيء موجود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استعادة')),
          ],
        ),
      );

  Future<void> _driveSignIn() => _run(() async {
        final u = await _drive.signIn();
        if (u == null) throw 'تعذّر تسجيل الدخول إلى Google';
        _ok('تم الربط: ${u.email}');
      });

  Future<void> _driveUpload() => _run(() async {
        final s = context.read<AppServices>();
        final id = await _drive.upload(await _svc.exportBytes(), deviceId: s.deviceId);
        if (id == null) throw 'لم يتم الرفع — سجّل الدخول أولاً';
        _ok('تم الرفع إلى Google Drive');
      });

  Future<void> _driveRestore() async {
    final files = await _drive.list();
    if (!mounted) return;
    if (files.isEmpty) {
      _ok('لا نسخ على Drive');
      return;
    }
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final f in files)
            ListTile(
              leading: const Icon(Icons.cloud_download_rounded, color: AppColors.primary),
              title: Text(f.name ?? '', textDirection: TextDirection.ltr),
              subtitle: Text(f.modifiedTime == null ? '' : DateLabels.full(f.modifiedTime!)),
              onTap: () => Navigator.pop(ctx, f.id),
            ),
        ]),
      ),
    );
    if (pick == null) return;
    final ok = await _confirmRestore('من Google Drive');
    if (ok != true || !mounted) return;
    final ledger = context.read<AppServices>().ledger;
    await _run(() async {
      final bytes = await _drive.download(pick);
      if (bytes == null) throw 'فشل التنزيل';
      final counts = await _svc.restore(bytes);
      await ledger.rebuildCache();
      _ok('تمت الاستعادة — ${counts.values.fold<int>(0, (a, b) => a + b)} سجلاً جديداً');
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsRepository>();
    final lastMs = st.get<int?>(SettingsRepository.kLastLocalBackupAt);
    final last = lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.backup)),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  icon: Icons.phone_android_rounded,
                  title: 'نسخة على الهاتف',
                  subtitle: last == null ? 'لم تُؤخذ نسخة بعد — تُؤخذ تلقائياً كل يوم عند فتح التطبيق' : 'آخر نسخة: ${DateLabels.ago(last)} • ${_local.length} ملف محفوظ',
                  actions: [
                    _Btn(icon: Icons.save_rounded, label: 'انسخ الآن', onTap: _backupNow, filled: true),
                    _Btn(icon: Icons.restore_rounded, label: 'استعادة', onTap: _restorePick),
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  icon: Icons.cloud_rounded,
                  title: 'Google Drive',
                  subtitle: _driveEmail == null ? 'اربط حساب Google لحفظ نسخة في السحابة واستعادتها على هاتف جديد' : 'مرتبط: $_driveEmail',
                  actions: [
                    if (_driveEmail == null)
                      _Btn(icon: Icons.login_rounded, label: 'ربط Google', onTap: kIsWeb ? null : _driveSignIn, filled: true)
                    else ...[
                      _Btn(icon: Icons.cloud_upload_rounded, label: 'ارفع الآن', onTap: _driveUpload, filled: true),
                      _Btn(icon: Icons.cloud_download_rounded, label: 'استعادة', onTap: _driveRestore),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _Card(
                  icon: Icons.ios_share_rounded,
                  title: 'تصدير / مشاركة',
                  subtitle: 'ملف .sijil يمكن إرساله لنفسك على واتساب أو لجهاز ثانٍ',
                  actions: [_Btn(icon: Icons.share_rounded, label: 'مشاركة النسخة', onTap: _share, filled: true)],
                ),
                const SizedBox(height: 16),
                const Text(
                  'الاستعادة لا تحذف شيئاً أبداً: تُضاف الحركات الناقصة فقط (كل حركة لها رقم فريد). '
                  'لذلك يمكن استعادة نسخة قديمة بأمان فوق بيانات أحدث.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
            if (_busy) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator()))),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Widget> actions;
  const _Card({required this.icon, required this.title, required this.subtitle, required this.actions});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 30, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [for (final a in actions) ...[a, const SizedBox(width: 8)]]),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  const _Btn({required this.icon, required this.label, this.onTap, this.filled = false});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: filled
            ? FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 22), label: Text(label, style: const TextStyle(fontSize: 15)))
            : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 22), label: Text(label, style: const TextStyle(fontSize: 15))),
      ),
    );
  }
}
