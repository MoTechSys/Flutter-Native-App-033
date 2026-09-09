// ============================================================
// كِتابي - لوحة المدير: نموذج إضافة / تعديل كتاب
// Form + Validation → INSERT / UPDATE في SQLite
// الغلاف: من معرض الهاتف أو الكاميرا (يُنسخ إلى مجلد التطبيق)،
//         أو غلاف مولَّد بلون التصنيف إن لم تُختر صورة.
// ============================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../state/store_state.dart';
import '../shared/cover_store_io.dart' if (dart.library.js_interop) '../shared/cover_store_web.dart';
import '../shared/widgets.dart';

class BookFormPage extends StatefulWidget {
  /// null = إضافة كتاب جديد
  final Book? book;
  const BookFormPage({super.key, this.book});

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.book?.title ?? '');
  late final _author = TextEditingController(text: widget.book?.author ?? '');
  late final _desc = TextEditingController(text: widget.book?.description ?? '');
  late final _price = TextEditingController(text: widget.book?.price.toStringAsFixed(0) ?? '');
  late final _oldPrice = TextEditingController(text: widget.book?.oldPrice?.toStringAsFixed(0) ?? '');
  late final _pages = TextEditingController(text: widget.book?.pages.toString() ?? '');
  late final _year = TextEditingController(text: widget.book?.year.toString() ?? '${DateTime.now().year}');
  late int? _categoryId = widget.book?.categoryId;
  late double _rating = widget.book?.rating ?? 4.0;
  late bool _featured = widget.book?.featured ?? false;
  late String _cover = widget.book?.cover ?? 'generated';
  bool _busy = false;

  bool get isEdit => widget.book != null;

  @override
  void dispose() {
    for (final c in [_title, _author, _desc, _price, _oldPrice, _pages, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ الغلاف
  Future<void> _pickCover(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 900, maxHeight: 1350, imageQuality: 85);
      if (x == null) return;
      // أندرويد: نسخ إلى مجلد التطبيق · ويب: base64 داخل SQLite (انظر cover_store_*.dart)
      final stored = await storeCover(x);
      setState(() => _cover = stored);
    } catch (e) {
      if (mounted) notify(context, 'تعذّر اختيار الصورة: $e', error: true);
    }
  }

  void _showCoverSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Palette.nightSoft,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text('غلاف الكتاب', style: AppText.serifStyle(18, color: Palette.gold)),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Palette.gold),
              title: const Text('من معرض الصور'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCover(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: Palette.gold),
                title: const Text('التقاط بالكاميرا'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCover(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Palette.gold),
              title: const Text('غلاف مولَّد بلون التصنيف'),
              subtitle: const Text('يُعرض العنوان على خلفية بلون التصنيف', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _cover = 'generated');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ الحفظ
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categoryId == null) {
      notify(context, 'اختر التصنيف', error: true);
      return;
    }
    final catalog = context.read<CatalogState>();
    final cat = catalog.category(_categoryId!)!;
    final old = _oldPrice.text.trim().isEmpty ? null : double.parse(_oldPrice.text.trim());
    final draft = Book(
      id: widget.book?.id ?? 0,
      categoryId: _categoryId!,
      title: _title.text.trim(),
      author: _author.text.trim(),
      description: _desc.text.trim(),
      price: double.parse(_price.text.trim()),
      oldPrice: old,
      rating: _rating,
      pages: int.parse(_pages.text.trim()),
      year: int.parse(_year.text.trim()),
      cover: _cover,
      coverColor: cat.color,
      featured: _featured,
    );
    setState(() => _busy = true);
    try {
      if (isEdit) {
        await catalog.updateBook(draft);
      } else {
        await catalog.addBook(draft);
      }
      if (!mounted) return;
      notify(context, isEdit ? 'تم حفظ تعديلات "${draft.title}"' : 'تمت إضافة "${draft.title}" إلى المتجر', icon: Icons.check_circle_outline);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      notify(context, 'فشل الحفظ: $e', error: true);
    }
  }

  String? _num(String? v, {bool integer = false, bool optional = false, double min = 0}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return optional ? null : 'مطلوب';
    final n = integer ? int.tryParse(t)?.toDouble() : double.tryParse(t);
    if (n == null) return integer ? 'أدخل رقماً صحيحاً' : 'أدخل رقماً';
    if (n < min) return 'يجب أن يكون ≥ ${min.toStringAsFixed(0)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<CatalogState>().categories;
    final previewCat = cats.where((c) => c.id == _categoryId).firstOrNull;
    final preview = Book(
      id: widget.book?.id ?? -1,
      categoryId: _categoryId ?? 0,
      title: _title.text.isEmpty ? 'عنوان الكتاب' : _title.text,
      author: _author.text,
      description: '',
      price: 0,
      rating: _rating,
      pages: 0,
      year: 0,
      cover: _cover,
      coverColor: previewCat?.color ?? Palette.walnut.toARGB32(),
    );

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل كتاب' : 'إضافة كتاب')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ---------------- الغلاف
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: _showCoverSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          BookCover(book: preview, width: 120, radius: 12, hero: false),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 16, color: Palette.night),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showCoverSheet,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(_cover == 'generated' ? 'اختيار صورة غلاف' : 'تغيير الغلاف', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ---------------- البيانات
              TextFormField(
                controller: _title,
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل عنوان الكتاب' : null,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'عنوان الكتاب', prefixIcon: Icon(Icons.title)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _author,
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل اسم المؤلف' : null,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'المؤلف', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('book_category'),
                initialValue: _categoryId,
                isExpanded: true,
                dropdownColor: Palette.nightSoft,
                decoration: const InputDecoration(labelText: 'التصنيف', prefixIcon: Icon(Icons.category_outlined)),
                items: cats
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(c.color), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'اختر التصنيف' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => _num(v, min: 1),
                      decoration: const InputDecoration(labelText: 'السعر (ر.س)', prefixIcon: Icon(Icons.sell_outlined)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _oldPrice,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final e = _num(v, optional: true);
                        if (e != null) return e;
                        final t = (v ?? '').trim();
                        final p = double.tryParse(_price.text.trim());
                        if (t.isNotEmpty && p != null && double.parse(t) <= p) return 'أكبر من السعر';
                        return null;
                      },
                      decoration: const InputDecoration(labelText: 'السعر قبل الخصم', prefixIcon: Icon(Icons.local_offer_outlined)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pages,
                      keyboardType: TextInputType.number,
                      validator: (v) => _num(v, integer: true, min: 1),
                      decoration: const InputDecoration(labelText: 'عدد الصفحات', prefixIcon: Icon(Icons.menu_book_outlined)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final e = _num(v, integer: true, min: 1000);
                        if (e != null) return e;
                        if (int.parse(v!.trim()) > DateTime.now().year + 1) return 'سنة غير صالحة';
                        return null;
                      },
                      decoration: const InputDecoration(labelText: 'سنة النشر', prefixIcon: Icon(Icons.calendar_today_outlined)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 4,
                validator: (v) => (v ?? '').trim().length < 10 ? 'أدخل وصفاً (10 أحرف على الأقل)' : null,
                decoration: const InputDecoration(labelText: 'الوصف', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 14),

              // ---------------- التقييم والمميز
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('التقييم الابتدائي')),
                          Text(_rating.toStringAsFixed(1), style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, color: Palette.gold, size: 18),
                        ],
                      ),
                      Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 8,
                        activeColor: Palette.gold,
                        label: _rating.toStringAsFixed(1),
                        onChanged: (v) => setState(() => _rating = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _featured,
                        activeThumbColor: Palette.gold,
                        title: const Text('كتاب مميز'),
                        subtitle: const Text('يظهر في رفّ "اختيارات كِتابي" على الرئيسية', style: TextStyle(fontSize: 12)),
                        onChanged: (v) => setState(() => _featured = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.night))
                    : Icon(isEdit ? Icons.save_outlined : Icons.add_circle_outline),
                label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة الكتاب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
