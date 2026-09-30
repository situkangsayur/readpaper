import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import 'csl_locale.dart';

const String _ns = 'http://purl.org/net/xbiblio/csl';

/// Hiasan yang boleh menempel pada hampir setiap elemen CSL.
///
/// Dikumpulkan jadi satu karena memang begitu spesifikasinya: `prefix`,
/// `suffix`, miring, tebal, dan huruf besar-kecil berlaku sama di `text`,
/// `group`, `names`, `date`, dan `number`. Menyalinnya lima kali berarti
/// empat kesempatan untuk lupa satu.
@immutable
class CslFormat {
  const CslFormat({
    this.prefix = '',
    this.suffix = '',
    this.fontStyle = '',
    this.fontWeight = '',
    this.fontVariant = '',
    this.textDecoration = '',
    this.verticalAlign = '',
    this.textCase = '',
    this.display = '',
    this.quotes = false,
    this.stripPeriods = false,
  });

  factory CslFormat.of(XmlElement e) => CslFormat(
    prefix: e.getAttribute('prefix') ?? '',
    suffix: e.getAttribute('suffix') ?? '',
    fontStyle: e.getAttribute('font-style') ?? '',
    fontWeight: e.getAttribute('font-weight') ?? '',
    fontVariant: e.getAttribute('font-variant') ?? '',
    textDecoration: e.getAttribute('text-decoration') ?? '',
    verticalAlign: e.getAttribute('vertical-align') ?? '',
    textCase: e.getAttribute('text-case') ?? '',
    display: e.getAttribute('display') ?? '',
    quotes: e.getAttribute('quotes') == 'true',
    stripPeriods: e.getAttribute('strip-periods') == 'true',
  );

  final String prefix;
  final String suffix;
  final String fontStyle;
  final String fontWeight;
  final String fontVariant;
  final String textDecoration;
  final String verticalAlign;
  final String textCase;
  final String display;
  final bool quotes;
  final bool stripPeriods;

  bool get isItalic => fontStyle == 'italic' || fontStyle == 'oblique';
  bool get isBold => fontWeight == 'bold';
  bool get isSmallCaps => fontVariant == 'small-caps';
}

/// Satu simpul yang bisa menghasilkan teks.
@immutable
sealed class CslNode {
  const CslNode();
}

/// `<text>` — satu medan, satu makro, satu istilah, atau satu nilai tetap.
class CslTextNode extends CslNode {
  const CslTextNode({
    this.variable = '',
    this.macro = '',
    this.term = '',
    this.value = '',
    this.form = '',
    this.plural = false,
    this.format = const CslFormat(),
  });

  final String variable;
  final String macro;
  final String term;
  final String value;
  final String form;
  final bool plural;
  final CslFormat format;
}

/// `<group>` — sekumpulan simpul dengan pemisah.
///
/// Punya sifat yang sering disalahpahami dan justru paling penting: sebuah
/// grup yang **memanggil medan** tetapi semua medannya kosong akan hilang
/// seluruhnya, termasuk `prefix` dan `suffix`-nya. Itulah yang mencegah
/// "Jurnal , , hlm. " muncul untuk item tanpa volume dan nomor.
class CslGroupNode extends CslNode {
  const CslGroupNode({
    required this.children,
    this.delimiter = '',
    this.format = const CslFormat(),
  });

  final List<CslNode> children;
  final String delimiter;
  final CslFormat format;
}

/// Syarat pada `<if>` dan `<else-if>`.
@immutable
class CslCondition {
  const CslCondition({
    this.types = const <String>[],
    this.variables = const <String>[],
    this.isNumeric = const <String>[],
    this.isUncertainDate = const <String>[],
    this.locators = const <String>[],
    this.positions = const <String>[],
    this.disambiguate,
    this.match = 'all',
  });

  final List<String> types;
  final List<String> variables;
  final List<String> isNumeric;
  final List<String> isUncertainDate;
  final List<String> locators;
  final List<String> positions;
  final bool? disambiguate;

  /// `all`, `any`, atau `none`.
  final String match;

  bool get isEmpty =>
      types.isEmpty &&
      variables.isEmpty &&
      isNumeric.isEmpty &&
      isUncertainDate.isEmpty &&
      locators.isEmpty &&
      positions.isEmpty &&
      disambiguate == null;
}

@immutable
class CslBranch {
  const CslBranch({required this.children, this.condition});

  /// null berarti `<else>`.
  final CslCondition? condition;
  final List<CslNode> children;
}

/// `<choose>` — cabang pertama yang syaratnya terpenuhi yang dipakai.
class CslChooseNode extends CslNode {
  const CslChooseNode(this.branches);

  final List<CslBranch> branches;
}

/// `<label>` — kata pendamping sebuah medan, mis. "hlm." untuk `page`.
class CslLabelNode extends CslNode {
  const CslLabelNode({
    required this.variable,
    this.form = '',
    this.plural = 'contextual',
    this.format = const CslFormat(),
  });

  final String variable;
  final String form;

  /// `contextual`, `always`, atau `never`.
  final String plural;
  final CslFormat format;
}

/// `<number>` — angka, dengan bentuk biasa, ordinal, atau romawi.
class CslNumberNode extends CslNode {
  const CslNumberNode({
    required this.variable,
    this.form = 'numeric',
    this.format = const CslFormat(),
  });

  final String variable;
  final String form;
  final CslFormat format;
}

/// Satu bagian tanggal beserta hiasannya.
@immutable
class CslDatePartSpec {
  const CslDatePartSpec({
    required this.name,
    this.form = '',
    this.format = const CslFormat(),
    this.rangeDelimiter = '',
  });

  final String name;
  final String form;
  final CslFormat format;
  final String rangeDelimiter;
}

/// `<date>` — bisa memakai bentuk bawaan locale, bisa merinci sendiri.
class CslDateNode extends CslNode {
  const CslDateNode({
    required this.variable,
    this.form = '',
    this.datePartsWanted = '',
    this.parts = const <CslDatePartSpec>[],
    this.delimiter = '',
    this.format = const CslFormat(),
  });

  final String variable;

  /// `text`, `numeric`, atau kosong kalau bagiannya dirinci sendiri.
  final String form;

  /// `year`, `year-month`, atau `year-month-day`.
  final String datePartsWanted;
  final List<CslDatePartSpec> parts;
  final String delimiter;
  final CslFormat format;
}

/// Pengaturan cara menulis satu nama.
@immutable
class CslNameOptions {
  const CslNameOptions({
    this.form = 'long',
    this.and = '',
    this.delimiter = ', ',
    this.delimiterPrecedesLast = 'contextual',
    this.delimiterPrecedesEtAl = 'contextual',
    this.initialize = true,
    this.initializeWith,
    this.nameAsSortOrder = '',
    this.sortSeparator = ', ',
    this.etAlMin = 0,
    this.etAlUseFirst = 0,
    this.etAlUseLast = false,
    this.parts = const <String, CslFormat>{},
  });

  final String form;
  final String and;
  final String delimiter;
  final String delimiterPrecedesLast;
  final String delimiterPrecedesEtAl;
  final bool initialize;

  /// Kosong berarti "singkat tanpa titik"; null berarti jangan disingkat.
  final String? initializeWith;

  /// `first`, `all`, atau kosong.
  final String nameAsSortOrder;
  final String sortSeparator;
  final int etAlMin;
  final int etAlUseFirst;
  final bool etAlUseLast;

  /// Hiasan per bagian nama (`family`, `given`).
  final Map<String, CslFormat> parts;

  CslNameOptions mergedWith(CslNameOptions over) => CslNameOptions(
    form: over.form.isEmpty ? form : over.form,
    and: over.and.isEmpty ? and : over.and,
    delimiter: over.delimiter,
    delimiterPrecedesLast: over.delimiterPrecedesLast,
    delimiterPrecedesEtAl: over.delimiterPrecedesEtAl,
    initialize: over.initialize,
    initializeWith: over.initializeWith ?? initializeWith,
    nameAsSortOrder: over.nameAsSortOrder.isEmpty
        ? nameAsSortOrder
        : over.nameAsSortOrder,
    sortSeparator: over.sortSeparator,
    etAlMin: over.etAlMin == 0 ? etAlMin : over.etAlMin,
    etAlUseFirst: over.etAlUseFirst == 0 ? etAlUseFirst : over.etAlUseFirst,
    etAlUseLast: over.etAlUseLast || etAlUseLast,
    parts: <String, CslFormat>{...parts, ...over.parts},
  );
}

/// `<names>` — daftar nama untuk satu atau beberapa peran.
class CslNamesNode extends CslNode {
  const CslNamesNode({
    required this.variables,
    this.name,
    this.label,
    this.labelBeforeName = false,
    this.etAlTerm = 'et-al',
    this.substitute = const <CslNode>[],
    this.delimiter = '',
    this.format = const CslFormat(),
  });

  final List<String> variables;
  final CslNameOptions? name;
  final CslLabelNode? label;
  final bool labelBeforeName;
  final String etAlTerm;

  /// Yang dipakai kalau tidak ada satu pun nama — biasanya judul.
  final List<CslNode> substitute;
  final String delimiter;
  final CslFormat format;
}

/// Satu kunci pengurutan.
@immutable
class CslSortKey {
  const CslSortKey({
    this.variable = '',
    this.macro = '',
    this.descending = false,
  });

  final String variable;
  final String macro;
  final bool descending;
}

/// Blok `<citation>` atau `<bibliography>`.
@immutable
class CslLayout {
  const CslLayout({
    required this.children,
    this.delimiter = '',
    this.format = const CslFormat(),
    this.sort = const <CslSortKey>[],
    this.options = const <String, String>{},
  });

  final List<CslNode> children;
  final String delimiter;
  final CslFormat format;
  final List<CslSortKey> sort;

  /// Atribut pada elemen `<citation>`/`<bibliography>`-nya sendiri, mis.
  /// `second-field-align`, `collapse`, `disambiguate-add-year-suffix`.
  final Map<String, String> options;

  String option(String name, [String fallback = '']) =>
      options[name] ?? fallback;

  bool flag(String name) => options[name] == 'true';

  int number(String name, [int fallback = 0]) =>
      int.tryParse(options[name] ?? '') ?? fallback;
}

/// Satu gaya sitasi CSL yang sudah terbaca.
@immutable
class CslStyle {
  const CslStyle({
    required this.id,
    required this.title,
    required this.styleClass,
    required this.macros,
    required this.citation,
    required this.bibliography,
    required this.defaultNameOptions,
    this.defaultLocale = '',
    this.localeOverrides = const <String, CslLocale>{},
    this.globals = const <String, String>{},
  });

  final String id;
  final String title;

  /// `in-text` atau `note`.
  final String styleClass;
  final Map<String, List<CslNode>> macros;
  final CslLayout citation;
  final CslLayout? bibliography;

  /// Pengaturan nama yang ditulis di elemen `<style>` dan berlaku di mana-mana
  /// kecuali ditimpa oleh `<name>` setempat.
  final CslNameOptions defaultNameOptions;
  final String defaultLocale;

  /// Tambalan istilah yang dibawa gayanya sendiri, per bahasa; kunci kosong
  /// berarti berlaku untuk semua bahasa.
  final Map<String, CslLocale> localeOverrides;

  /// Atribut lain di elemen `<style>`: `page-range-format`,
  /// `demote-non-dropping-particle`, dan kawan-kawan.
  final Map<String, String> globals;

  bool get isNumeric =>
      citation.options['collapse'] == 'citation-number' ||
      _usesVariable(citation.children, 'citation-number');

  static bool _usesVariable(List<CslNode> nodes, String variable) {
    for (final node in nodes) {
      final found = switch (node) {
        CslTextNode(:final variable) => variable == 'citation-number',
        CslNumberNode(:final variable) => variable == 'citation-number',
        CslGroupNode(:final children) => _usesVariable(children, variable),
        CslChooseNode(:final branches) => branches.any(
          (b) => _usesVariable(b.children, variable),
        ),
        _ => false,
      };
      if (found) return true;
    }
    return false;
  }

  /// Membaca berkas `.csl`.
  ///
  /// Gaya **dependen** — yang hanya menunjuk induknya — sengaja ditolak di
  /// sini dengan pesan yang menyebut induknya. Menyelesaikannya adalah tugas
  /// [CslCatalog], dan mesin render tidak boleh kebagian menebak.
  factory CslStyle.parse(String xml) {
    final root = XmlDocument.parse(xml).rootElement;
    final info = root.getElement('info', namespaceUri: _ns);

    String infoText(String tag) =>
        info?.getElement(tag, namespaceUri: _ns)?.innerText.trim() ?? '';

    for (final link
        in info?.findElements('link', namespaceUri: _ns) ??
            const <XmlElement>[]) {
      if (link.getAttribute('rel') == 'independent-parent') {
        final parent = (link.getAttribute('href') ?? '').split('/').last;
        throw CslStyleIsDependent(infoText('id').split('/').last, parent);
      }
    }

    final macros = <String, List<CslNode>>{};
    for (final macro in root.findElements('macro', namespaceUri: _ns)) {
      final name = macro.getAttribute('name');
      if (name != null) macros[name] = _children(macro);
    }

    final locales = <String, CslLocale>{};
    for (final locale in root.findElements('locale', namespaceUri: _ns)) {
      final language =
          locale.getAttribute(
            'lang',
            namespaceUri: 'http://www.w3.org/XML/1998/namespace',
          ) ??
          locale.getAttribute('xml:lang') ??
          '';
      locales[language] = CslLocale.parse(locale.toXmlString());
    }

    final citation = root.getElement('citation', namespaceUri: _ns);
    if (citation == null) {
      throw const FormatException('Gaya ini tidak punya blok <citation>');
    }

    return CslStyle(
      id: infoText('id').split('/').last,
      title: infoText('title'),
      styleClass: root.getAttribute('class') ?? 'in-text',
      macros: macros,
      citation: _layout(citation),
      bibliography: switch (root.getElement(
        'bibliography',
        namespaceUri: _ns,
      )) {
        final XmlElement e => _layout(e),
        null => null,
      },
      defaultNameOptions: _nameOptions(root),
      defaultLocale: root.getAttribute('default-locale') ?? '',
      localeOverrides: locales,
      globals: <String, String>{
        for (final attribute in root.attributes)
          attribute.name.local: attribute.value,
      },
    );
  }

  static CslLayout _layout(XmlElement block) {
    final layout = block.getElement('layout', namespaceUri: _ns);
    final sort = block.getElement('sort', namespaceUri: _ns);
    return CslLayout(
      children: layout == null ? const <CslNode>[] : _children(layout),
      delimiter: layout?.getAttribute('delimiter') ?? '',
      format: layout == null ? const CslFormat() : CslFormat.of(layout),
      sort: <CslSortKey>[
        for (final key
            in sort?.findElements('key', namespaceUri: _ns) ??
                const <XmlElement>[])
          CslSortKey(
            variable: key.getAttribute('variable') ?? '',
            macro: key.getAttribute('macro') ?? '',
            descending: key.getAttribute('sort') == 'descending',
          ),
      ],
      options: <String, String>{
        for (final attribute in block.attributes)
          attribute.name.local: attribute.value,
      },
    );
  }

  static List<CslNode> _children(XmlElement parent) => <CslNode>[
    for (final child in parent.childElements)
      if (_node(child) case final CslNode node) node,
  ];

  static CslNode? _node(XmlElement e) => switch (e.name.local) {
    'text' => CslTextNode(
      variable: e.getAttribute('variable') ?? '',
      macro: e.getAttribute('macro') ?? '',
      term: e.getAttribute('term') ?? '',
      value: e.getAttribute('value') ?? '',
      form: e.getAttribute('form') ?? '',
      plural: e.getAttribute('plural') == 'true',
      format: CslFormat.of(e),
    ),
    'group' => CslGroupNode(
      children: _children(e),
      delimiter: e.getAttribute('delimiter') ?? '',
      format: CslFormat.of(e),
    ),
    'choose' => CslChooseNode(<CslBranch>[
      for (final branch in e.childElements)
        CslBranch(
          condition: branch.name.local == 'else' ? null : _condition(branch),
          children: _children(branch),
        ),
    ]),
    'label' => CslLabelNode(
      variable: e.getAttribute('variable') ?? '',
      form: e.getAttribute('form') ?? '',
      plural: e.getAttribute('plural') ?? 'contextual',
      format: CslFormat.of(e),
    ),
    'number' => CslNumberNode(
      variable: e.getAttribute('variable') ?? '',
      form: e.getAttribute('form') ?? 'numeric',
      format: CslFormat.of(e),
    ),
    'date' => CslDateNode(
      variable: e.getAttribute('variable') ?? '',
      form: e.getAttribute('form') ?? '',
      datePartsWanted: e.getAttribute('date-parts') ?? '',
      delimiter: e.getAttribute('delimiter') ?? '',
      format: CslFormat.of(e),
      parts: <CslDatePartSpec>[
        for (final part in e.findElements('date-part', namespaceUri: _ns))
          CslDatePartSpec(
            name: part.getAttribute('name') ?? '',
            form: part.getAttribute('form') ?? '',
            format: CslFormat.of(part),
            rangeDelimiter: part.getAttribute('range-delimiter') ?? '',
          ),
      ],
    ),
    'names' => _names(e),
    _ => null,
  };

  static CslNamesNode _names(XmlElement e) {
    final name = e.getElement('name', namespaceUri: _ns);
    final label = e.getElement('label', namespaceUri: _ns);
    final etAl = e.getElement('et-al', namespaceUri: _ns);
    final substitute = e.getElement('substitute', namespaceUri: _ns);

    // Urutan anaknya menentukan apakah labelnya di depan atau di belakang
    // namanya: "Diedit oleh Ada" lawan "Ada (ed.)".
    var labelFirst = false;
    if (label != null && name != null) {
      labelFirst =
          e.childElements.toList().indexOf(label) <
          e.childElements.toList().indexOf(name);
    }

    return CslNamesNode(
      variables: (e.getAttribute('variable') ?? '').split(RegExp(r'\s+'))
        ..removeWhere((v) => v.isEmpty),
      name: name == null ? null : _nameOptions(name),
      label: label == null ? null : _node(label) as CslLabelNode?,
      labelBeforeName: labelFirst,
      etAlTerm: etAl?.getAttribute('term') ?? 'et-al',
      substitute: substitute == null
          ? const <CslNode>[]
          : _children(substitute),
      delimiter: e.getAttribute('delimiter') ?? '',
      format: CslFormat.of(e),
    );
  }

  /// Membaca pengaturan nama dari `<style>`, `<citation>`, atau `<name>`.
  ///
  /// Ketiganya memakai atribut yang sama persis, dan yang lebih dalam menimpa
  /// yang lebih luar. Itu sebabnya satu pembaca dipakai untuk ketiganya.
  static CslNameOptions _nameOptions(XmlElement e) {
    final initializeWith = e.getAttribute('initialize-with');
    return CslNameOptions(
      form: e.getAttribute('form') ?? '',
      and: e.getAttribute('and') ?? '',
      delimiter:
          e.getAttribute('name-delimiter') ??
          e.getAttribute('delimiter') ??
          ', ',
      delimiterPrecedesLast:
          e.getAttribute('delimiter-precedes-last') ?? 'contextual',
      delimiterPrecedesEtAl:
          e.getAttribute('delimiter-precedes-et-al') ?? 'contextual',
      initialize: e.getAttribute('initialize') != 'false',
      initializeWith: initializeWith,
      nameAsSortOrder: e.getAttribute('name-as-sort-order') ?? '',
      sortSeparator: e.getAttribute('sort-separator') ?? ', ',
      etAlMin: int.tryParse(e.getAttribute('et-al-min') ?? '') ?? 0,
      etAlUseFirst: int.tryParse(e.getAttribute('et-al-use-first') ?? '') ?? 0,
      etAlUseLast: e.getAttribute('et-al-use-last') == 'true',
      parts: <String, CslFormat>{
        for (final part in e.findElements('name-part', namespaceUri: _ns))
          if (part.getAttribute('name') case final String name)
            name: CslFormat.of(part),
      },
    );
  }

  static CslCondition _condition(XmlElement e) {
    List<String> split(String attribute) => (e.getAttribute(attribute) ?? '')
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final disambiguate = e.getAttribute('disambiguate');
    return CslCondition(
      types: split('type'),
      variables: split('variable'),
      isNumeric: split('is-numeric'),
      isUncertainDate: split('is-uncertain-date'),
      locators: split('locator'),
      positions: split('position'),
      disambiguate: disambiguate == null ? null : disambiguate == 'true',
      match: e.getAttribute('match') ?? 'all',
    );
  }
}

/// Dilempar saat gaya yang dibaca ternyata hanya menunjuk induknya.
class CslStyleIsDependent implements Exception {
  const CslStyleIsDependent(this.id, this.parent);

  final String id;
  final String parent;

  @override
  String toString() =>
      'Gaya "$id" adalah gaya dependen: ia hanya nama beserta penunjuk ke '
      '"$parent", dan tidak berisi aturan apa pun. Pakai induknya untuk '
      'merender.';
}
