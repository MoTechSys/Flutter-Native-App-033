import 'dart:convert';

/// Document kinds (schema `doc_templates.kind`, docs/09 §2).
enum DocKind {
  statement('statement', 'كشف حساب مختصر', 'كشف_مختصر'),
  statementDetailed('statement_detailed', 'كشف حساب تفصيلي', 'كشف_تفصيلي'),
  receipt('receipt', 'سند قبض', 'سند_قبض'),
  claim('claim', 'إشعار مطالبة', 'مطالبة'),
  overdueReport('overdue_report', 'تقرير المتأخرين', 'تقرير_المتأخرين'),
  debtAck('debt_ack', 'إقرار بالدين', 'إقرار_دين');

  final String db;
  final String titleAr;
  final String fileAr;
  const DocKind(this.db, this.titleAr, this.fileAr);

  static DocKind fromDb(String v) => DocKind.values.firstWhere((k) => k.db == v);
}

/// Design presets (docs/09 §3).
enum DocPreset { classic, modern, compact }

/// Parsed `layout_json` (docs/09 §4) with defaults for every field so the
/// renderer never sees null. Immutable; use [copyWith].
class DocLayout {
  final DocPreset preset;
  final String pageSize; // A4 | A5 | roll80
  final double margin;
  final bool logoShow;
  final String logoPosition; // right | center | left | none
  final double logoSize;
  final List<String> headerFields; // shop_name, address, phone, extra_line
  final double titleFontSize;
  final String accentColor; // #RRGGBB
  final bool headerDivider;
  final String footerText;
  final bool pageNumbers;
  final bool issuedAt;
  final bool brandStamp;
  final List<String> tableColumns; // date, description, debit, credit, running_balance, worker, time
  final bool showWorker;
  final bool showTime;
  final bool showReversed;
  final bool zebra;
  final double tableFontSize;
  final String numerals; // western | arabic
  final List<String> signatures; // shop, customer, witness1, witness2

  const DocLayout({
    this.preset = DocPreset.modern,
    this.pageSize = 'A4',
    this.margin = 36,
    this.logoShow = true,
    this.logoPosition = 'center',
    this.logoSize = 64,
    this.headerFields = const ['shop_name', 'address', 'phone', 'extra_line'],
    this.titleFontSize = 18,
    this.accentColor = '#0B5D48',
    this.headerDivider = true,
    this.footerText = '',
    this.pageNumbers = true,
    this.issuedAt = true,
    this.brandStamp = true,
    this.tableColumns = const ['date', 'description', 'debit', 'credit', 'running_balance'],
    this.showWorker = false,
    this.showTime = false,
    this.showReversed = false,
    this.zebra = true,
    this.tableFontSize = 9.5,
    this.numerals = 'western',
    this.signatures = const ['shop', 'customer'],
  });

  /// Preset defaults (docs/09 §3).
  factory DocLayout.preset(DocPreset p) => switch (p) {
        DocPreset.classic => const DocLayout(
            preset: DocPreset.classic,
            logoPosition: 'right',
            accentColor: '#222222',
            titleFontSize: 17,
            zebra: false,
          ),
        DocPreset.modern => const DocLayout(preset: DocPreset.modern),
        DocPreset.compact => const DocLayout(
            preset: DocPreset.compact,
            margin: 24,
            logoSize: 40,
            logoPosition: 'right',
            accentColor: '#333333',
            titleFontSize: 14,
            tableFontSize: 9,
            zebra: false,
            brandStamp: false,
          ),
      };

  bool get arabicDigits => numerals == 'arabic';

  DocLayout copyWith({
    DocPreset? preset,
    String? pageSize,
    double? margin,
    bool? logoShow,
    String? logoPosition,
    double? logoSize,
    List<String>? headerFields,
    double? titleFontSize,
    String? accentColor,
    bool? headerDivider,
    String? footerText,
    bool? pageNumbers,
    bool? issuedAt,
    bool? brandStamp,
    List<String>? tableColumns,
    bool? showWorker,
    bool? showTime,
    bool? showReversed,
    bool? zebra,
    double? tableFontSize,
    String? numerals,
    List<String>? signatures,
  }) =>
      DocLayout(
        preset: preset ?? this.preset,
        pageSize: pageSize ?? this.pageSize,
        margin: margin ?? this.margin,
        logoShow: logoShow ?? this.logoShow,
        logoPosition: logoPosition ?? this.logoPosition,
        logoSize: logoSize ?? this.logoSize,
        headerFields: headerFields ?? this.headerFields,
        titleFontSize: titleFontSize ?? this.titleFontSize,
        accentColor: accentColor ?? this.accentColor,
        headerDivider: headerDivider ?? this.headerDivider,
        footerText: footerText ?? this.footerText,
        pageNumbers: pageNumbers ?? this.pageNumbers,
        issuedAt: issuedAt ?? this.issuedAt,
        brandStamp: brandStamp ?? this.brandStamp,
        tableColumns: tableColumns ?? this.tableColumns,
        showWorker: showWorker ?? this.showWorker,
        showTime: showTime ?? this.showTime,
        showReversed: showReversed ?? this.showReversed,
        zebra: zebra ?? this.zebra,
        tableFontSize: tableFontSize ?? this.tableFontSize,
        numerals: numerals ?? this.numerals,
        signatures: signatures ?? this.signatures,
      );

  Map<String, Object?> toJson() => {
        'preset': preset.name,
        'page': {'size': pageSize, 'orientation': 'portrait', 'margin': margin},
        'header': {
          'logo': {'show': logoShow, 'position': logoPosition, 'size': logoSize},
          'fields': headerFields,
          'title_font_size': titleFontSize,
          'accent_color': accentColor,
          'divider': headerDivider,
        },
        'footer': {
          'text': footerText,
          'page_numbers': pageNumbers,
          'issued_at': issuedAt,
          'brand_stamp': brandStamp,
        },
        'table': {
          'columns': tableColumns,
          'show_worker': showWorker,
          'show_time': showTime,
          'show_reversed': showReversed,
          'zebra': zebra,
          'font_size': tableFontSize,
        },
        'numerals': numerals,
        'signatures': signatures,
      };

  String encode() => jsonEncode(toJson());

  factory DocLayout.decode(String json) {
    final m = jsonDecode(json) as Map<String, Object?>;
    final presetName = m['preset'] as String? ?? 'modern';
    final preset = DocPreset.values.firstWhere((p) => p.name == presetName, orElse: () => DocPreset.modern);
    final base = DocLayout.preset(preset);
    final page = (m['page'] as Map?) ?? {};
    final header = (m['header'] as Map?) ?? {};
    final logo = (header['logo'] as Map?) ?? {};
    final footer = (m['footer'] as Map?) ?? {};
    final table = (m['table'] as Map?) ?? {};
    List<String>? strs(Object? v) => v is List ? v.map((e) => '$e').toList() : null;
    double? dbl(Object? v) => v is num ? v.toDouble() : null;
    return base.copyWith(
      pageSize: page['size'] as String?,
      margin: dbl(page['margin']),
      logoShow: logo['show'] as bool?,
      logoPosition: logo['position'] as String?,
      logoSize: dbl(logo['size']),
      headerFields: strs(header['fields']),
      titleFontSize: dbl(header['title_font_size']),
      accentColor: header['accent_color'] as String?,
      headerDivider: header['divider'] as bool?,
      footerText: footer['text'] as String?,
      pageNumbers: footer['page_numbers'] as bool?,
      issuedAt: footer['issued_at'] as bool?,
      brandStamp: footer['brand_stamp'] as bool?,
      tableColumns: strs(table['columns']),
      showWorker: table['show_worker'] as bool?,
      showTime: table['show_time'] as bool?,
      showReversed: table['show_reversed'] as bool?,
      zebra: table['zebra'] as bool?,
      tableFontSize: dbl(table['font_size']),
      numerals: m['numerals'] as String?,
      signatures: strs(m['signatures']),
    );
  }
}
