import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/models/customer.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/photo_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/app_back_button.dart';

/// Add or edit a customer. Photo is the hero — the biggest control on screen
/// (docs/03 §6.6, D10). Returns the customer id on save.
class AddCustomerScreen extends StatefulWidget {
  final Customer? existing;
  const AddCustomerScreen({super.key, this.existing});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _photos = PhotoService();
  String? _photoPath;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _phone.text = e.phone ?? '';
      _note.text = e.note ?? '';
      _photoPath = e.photoPath;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetAction(
                icon: Icons.photo_camera_rounded,
                label: 'كاميرا',
                onTap: () => Navigator.pop(context, true)),
            _SheetAction(
                icon: Icons.photo_library_rounded,
                label: 'من الصور',
                onTap: () => Navigator.pop(context, false)),
            if (_photoPath != null)
              _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'إزالة الصورة',
                  color: AppColors.debt,
                  onTap: () {
                    setState(() => _photoPath = null);
                    Navigator.pop(context);
                  }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (fromCamera == null) return;
    final p = await _photos.pick(fromCamera: fromCamera);
    if (p != null && mounted) setState(() => _photoPath = p);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = S.nameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = context.read<AppServices>().customers;
      final by = context.read<SessionProvider>().user?.id ?? 'unknown';
      String id;
      if (_isEdit) {
        id = widget.existing!.id;
        await repo.update(id,
            name: name,
            phone: _phone.text,
            photoPath: _photoPath ?? '',
            note: _note.text,
            byUserId: by);
      } else {
        final c = await repo.add(
            name: name,
            phone: _phone.text,
            photoPath: _photoPath,
            note: _note.text,
            byUserId: by);
        id = c.id;
      }
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'تعذّر الحفظ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(_isEdit ? S.edit : S.addCustomer)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    // Photo — hero control
                    InkWell(
                      onTap: _pickPhoto,
                      borderRadius: BorderRadius.circular(80),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _photoPath == null
                              ? Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2.5),
                                  ),
                                  child: const Icon(Icons.photo_camera_rounded,
                                      size: 64, color: AppColors.primary),
                                )
                              : CustomerAvatar(
                                  name: _name.text,
                                  photoPath: _photoPath,
                                  size: 150,
                                  borderColor: AppColors.primary,
                                ),
                          PositionedDirectional(
                            bottom: 4,
                            end: 4,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                  color: AppColors.primary, shape: BoxShape.circle),
                              child: Icon(
                                  _photoPath == null ? Icons.add_rounded : Icons.edit_rounded,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(S.takePhoto,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: S.customerName,
                        prefixIcon: const Icon(Icons.person_rounded),
                        errorText: _error == S.nameRequired ? _error : null,
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        labelText: S.phoneOptional,
                        prefixIcon: Icon(Icons.phone_rounded),
                        hintText: '77x xxx xxx',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _note,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: S.note,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (_error != null && _error != S.nameRequired) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.debt)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 30),
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

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SheetAction({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      leading: Icon(icon, size: 32, color: color ?? AppColors.primary),
      title: Text(label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      onTap: onTap,
    );
  }
}
