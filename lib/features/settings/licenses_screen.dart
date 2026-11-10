import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';

/// One bundled package and the licence texts it ships with.
class _PackageLicence {
  const _PackageLicence({required this.name, required this.texts});

  final String name;

  /// Usually one entry; a package that vendored two libraries has more.
  final List<String> texts;
}

/// Collects every licence Flutter knows about, grouped by package.
///
/// `LicenseRegistry.licenses` emits one entry per licence, and an entry can name
/// several packages, so the raw stream is a poor thing to show: the same text
/// appears once per package and package order is registration order. Grouping by
/// package and sorting makes the list browsable, which is the whole point of the
/// screen.
Future<List<_PackageLicence>> _collectLicences() async {
  final texts = <String, List<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final paragraphs = entry.paragraphs
        .map((paragraph) {
          final text = paragraph.text.trim();
          if (text.isEmpty) return '';
          return paragraph.indent > 0
              ? text
                    .split('\n')
                    .map((line) => '${'    ' * paragraph.indent}$line')
                    .join('\n')
              : text;
        })
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    if (paragraphs.isEmpty) continue;
    for (final package in entry.packages) {
      final bucket = texts.putIfAbsent(package, () => <String>[]);
      if (!bucket.contains(paragraphs)) bucket.add(paragraphs);
    }
  }

  final names = texts.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [
    for (final name in names)
      _PackageLicence(name: name, texts: List.unmodifiable(texts[name]!)),
  ];
}

/// The licences of everything Ljod is built on, searchable and readable.
///
/// Replaces Flutter's stock `showLicensePage`, whose dense wall of monospaced
/// text is hard to scan on a phone: here each package is a row, the list filters
/// as you type, and tapping one opens its full text at a comfortable measure.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  final TextEditingController _search = TextEditingController();
  late final Future<List<_PackageLicence>> _licences = _collectLicences();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'LICENCES',
          style: LjodTheme.display(theme.textTheme, size: 22),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: LjodBackground(
        child: SafeArea(
          child: FutureBuilder<List<_PackageLicence>>(
            future: _licences,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView(label: 'Reading licences…');
              }
              final all = snapshot.data ?? const <_PackageLicence>[];
              final query = _query.trim().toLowerCase();
              final matches = query.isEmpty
                  ? all
                  : all
                        .where(
                          (licence) =>
                              licence.name.toLowerCase().contains(query),
                        )
                        .toList(growable: false);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    'Ljod itself is released under OSL-3.0. The '
                    '${all.length} packages below keep their own licences; the '
                    'full text of each is bundled with the app.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  LjodSearchBar(
                    controller: _search,
                    hint: 'Filter packages…',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(
                    title:
                        '${matches.length} ${matches.length == 1 ? 'package' : 'packages'}',
                    eyebrow: query.isEmpty ? 'Bundled' : 'Matches',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  if (matches.isEmpty)
                    // Bounded height: EmptyState scrolls internally, and this is
                    // already inside a list (an unbounded height would throw).
                    SizedBox(
                      height: 300,
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        message:
                            'No bundled package matches “${_query.trim()}”. '
                            'Clear the filter to see them all.',
                        compact: true,
                      ),
                    )
                  else
                    for (final licence in matches) ...[
                      _PackageRow(
                        licence: licence,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => _LicenceScreen(licence: licence),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 12),
                  Panel(
                    child: Text(
                      'Nothing here leaves the device. The texts are read from '
                      'the licences registered by the bundled packages.',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.licence, required this.onTap});

  final _PackageLicence licence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monogram = licence.name.isEmpty
        ? '#'
        : licence.name.substring(0, 1).toUpperCase();
    final count = licence.texts.length;
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LjodTheme.panelHigh,
              borderRadius: BorderRadius.circular(LjodTheme.radiusXs),
              border: Border.all(color: LjodTheme.borderLight),
            ),
            child: Text(
              monogram,
              style: const TextStyle(
                fontFamily: LjodTheme.monoFamily,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: LjodTheme.amber,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  licence.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: LjodTheme.textStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  count == 1 ? '1 licence' : '$count licences',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: LjodTheme.textMuted,
          ),
        ],
      ),
    );
  }
}

class _LicenceScreen extends StatelessWidget {
  const _LicenceScreen({required this.licence});

  final _PackageLicence licence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = licence.texts.join('\n\n· · ·\n\n');
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          licence.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: LjodTheme.textStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy licence',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Licence copied.')));
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: LjodBackground(
        showGlow: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Panel(
                child: SelectableText(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: LjodTheme.monoFamily,
                    height: 1.65,
                    color: LjodTheme.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
