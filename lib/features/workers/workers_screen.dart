import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/photo_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/customer_avatar.dart';

/// Workers (phase 2): add/edit accounts, PIN, permissions, activity log.
/// Owner only. Multi-user on one phone (D-multi-worker).
class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  List<AppUser> _users = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await context.read<SessionProvider>().allUsers();
    if (!mounted) return;
    setState(() {
      _users = u;
      _loading = false;
    });
  }

  Future<void> _edit([AppUser? u]) async {
    final changed = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => _EditWorkerScreen(existing: u)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().user;
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.workers)),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _edit(),
        tooltip: 'إضافة عامل',
        child: const Icon(Icons.person_add_alt_1_rounded, size: 36),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final u = _users[i];
                  final permCount = AppUser.allPerms.where(u.can).length;
                  return Opacity(
                    opacity: u.isActive ? 1 : 0.5,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _edit(u),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CustomerAvatar(name: u.name, photoPath: u.photoPath, size: 56,
                                  borderColor: u.isOwner ? AppColors.accent : null),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(u.name,
                                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                        if (u.id == me?.id)
                                          const Padding(
                                            padding: EdgeInsetsDirectional.only(start: 6),
                                            child: Text('(أنت)',
                                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      [
                                        u.isOwner ? S.owner : S.worker,
                                        u.hasPin ? 'برمز' : 'بلا رمز',
                                        if (!u.isOwner) '$permCount/${AppUser.allPerms.length} صلاحيات',
                                        if (!u.isActive) 'موقوف',
                                      ].join(' • '),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'سجل النشاط',
                                onPressed: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => _ActivityScreen(user: u))),
                                icon: const Icon(Icons.history_rounded, size: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EditWorkerScreen extends StatefulWidget {
  final AppUser? existing;
  const _EditWorkerScreen({this.existing});

  @override
  State<_EditWorkerScreen> createState() => _EditWorkerScreenState();
}

class _EditWorkerScreenState extends State<_EditWorkerScreen> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _photos = PhotoService();
  String? _photo;
  bool _isOwner = false;
  bool _active = true;
  late Map<String, bool> _perms;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _perms = {for (final p in AppUser.allPerms) p: e?.perms[p] ?? false};
    if (e != null) {
      _name.text = e.name;
      _photo = e.photoPath;
      _isOwner = e.isOwner;
      _active = e.isActive;
    } else {
      _perms[AppUser.permAddCustomer] = true; // sensible default
    }
  }

  Future<void> _save() async {
    final session = context.read<SessionProvider>();
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (_pin.text.isNotEmpty && _pin.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز 4 أرقام')));
      return;
    }
    setState(() => _saving = true);
    if (_isEdit) {
      final u = widget.existing!;
      await session.updateUser(u.id, name: name, photoPath: _photo ?? '', isActive: _active, perms: _perms);
      if (_pin.text.isNotEmpty) await session.setPin(u.id, _pin.text);
    } else {
      await session.addUser(
          name: name, isOwner: _isOwner, photoPath: _photo, pin: _pin.text.isEmpty ? null : _pin.text, perms: _perms);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<SessionProvider>().user;
    final editingSelf = _isEdit && widget.existing!.id == me?.id;
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(_isEdit ? S.edit : 'عامل جديد')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(70),
                      onTap: () async {
                        final p = await _photos.pick(fromCamera: true, folder: 'users');
                        if (p != null && mounted) setState(() => _photo = p);
                      },
                      child: _photo == null
                          ? Container(
                              width: 120, height: 120,
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 2)),
                              child: const Icon(Icons.add_a_photo_rounded, size: 48, color: AppColors.primary))
                          : CustomerAvatar(name: _name.text, photoPath: _photo, size: 120, borderColor: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: _isEdit ? 'رمز جديد (اتركه فارغاً للإبقاء)' : S.setPinOptional,
                      prefixIcon: const Icon(Icons.lock_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!editingSelf)
                    SwitchListTile(
                      title: const Text('مالك (كل الصلاحيات)', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('يرى الإجماليات والتقارير ويعكس الحركات'),
                      value: _isOwner,
                      onChanged: _isEdit ? null : (v) => setState(() => _isOwner = v),
                    ),
                  if (!_isOwner) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('صلاحيات العامل',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                    ),
                    for (final p in AppUser.allPerms)
                      CheckboxListTile(
                        value: _perms[p],
                        onChanged: (v) => setState(() => _perms[p] = v ?? false),
                        title: Text(AppUser.permLabel(p), style: const TextStyle(fontSize: 16)),
                        subtitle: Text(AppUser.permHint(p), style: const TextStyle(fontSize: 12)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                  if (_isEdit && !editingSelf)
                    SwitchListTile(
                      title: const Text('الحساب فعّال', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('الموقوف لا يظهر في شاشة الدخول؛ حركاته تبقى'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded, size: 30),
                  label: const Text(S.save, style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Activity log for one user from `audit_log` + `transactions`.
class _ActivityScreen extends StatelessWidget {
  final AppUser user;
  const _ActivityScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppServices>().db;
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text('نشاط ${user.name}')),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: db.rawQuery('''
            SELECT entity, action, at, after_json FROM audit_log
            WHERE actor_id = ? ORDER BY at DESC LIMIT 200
          ''', [user.id]),
          builder: (context, snap) {
            final rows = snap.data;
            if (rows == null) return const Center(child: CircularProgressIndicator());
            if (rows.isEmpty) return const Center(child: Text('لا نشاط مسجَّل'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                final at = DateTime.fromMillisecondsSinceEpoch(r['at'] as int, isUtc: true);
                return ListTile(
                  dense: true,
                  leading: Icon(_icon(r['action'] as String), color: _color(r['action'] as String)),
                  title: Text(_label(r['entity'] as String, r['action'] as String),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(DateLabels.full(at), style: const TextStyle(fontSize: 12)),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static IconData _icon(String a) => switch (a) {
        'record' => Icons.add_circle_outline_rounded,
        'reverse' => Icons.undo_rounded,
        'create' => Icons.person_add_alt_1_rounded,
        'archive' => Icons.archive_outlined,
        _ => Icons.edit_outlined,
      };
  static Color _color(String a) => a == 'reverse' ? AppColors.debt : AppColors.primary;
  static String _label(String e, String a) {
    final ent = e == 'transaction' ? 'حركة' : (e == 'customer' ? 'زبون' : e);
    final act = switch (a) {
      'record' => 'سجّل',
      'reverse' => 'عكس',
      'create' => 'أضاف',
      'update' => 'عدّل',
      'archive' => 'أرشف',
      'unarchive' => 'أعاد',
      _ => a,
    };
    return '$act $ent';
  }
}
