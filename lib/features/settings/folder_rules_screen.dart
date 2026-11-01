import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/folder_scope.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/library/library_providers.dart';
import '../../services/library/library_service.dart';
import '../../services/settings/settings_provider.dart';

/// Editor for the folder whitelist / blacklist used by the library scan.
///
/// The same screen is used by the setup flow and from Settings, so folder rules
/// can be changed at any time without replaying setup.
class FolderRulesScreen extends ConsumerStatefulWidget {
  const FolderRulesScreen({super.key, this.rescanOnSave = true});

  /// When true, saving the rules starts a fresh library scan.
  final bool rescanOnSave;

  @override
  ConsumerState<FolderRulesScreen> createState() => _FolderRulesScreenState();
}

class _FolderRulesScreenState extends ConsumerState<FolderRulesScreen> {
  late FolderFilterMode _mode;
  late Set<String> _filters;
  final _searchController = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _mode = settings.folderFilterMode;
    _filters = settings.folderFilters.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = ref.watch(libraryFoldersProvider);

    return Scaffold(
      // A pushed route cannot rely on what the Navigator paints behind it.
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'FOLDER RULES',
          style: LjodTheme.display(theme.textTheme, size: 22),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(libraryFoldersProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload folders',
          ),
        ],
      ),
      body: LjodBackground(
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose what Ljod indexes. Folder rules are applied '
                        'on the next scan and never touch your files.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<FolderFilterMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: FolderFilterMode.all,
                            label: Text('All'),
                            icon: Icon(Icons.folder_open_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: FolderFilterMode.only,
                            label: Text('Only'),
                            icon: Icon(Icons.filter_alt_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: FolderFilterMode.exclude,
                            label: Text('Exclude'),
                            icon: Icon(Icons.block_rounded, size: 16),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (selection) {
                          setState(() => _mode = selection.first);
                        },
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          switch (_mode) {
                            FolderFilterMode.all =>
                              'Every folder reported by the device is indexed.',
                            FolderFilterMode.only => 'Only audio inside the checked folders is indexed.',
                            FolderFilterMode.exclude =>
                              'Audio inside the checked folders is ignored.',
                          },
                          key: ValueKey(_mode),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: LjodTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LjodSearchBar(
                        controller: _searchController,
                        hint: 'Filter folders…',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ],
                  ),
                ),
              ),
              ..._buildFolderSlivers(folders),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(widget.rescanOnSave ? 'Save and rescan' : 'Save rules'),
        ),
      ),
    );
  }

  List<Widget> _buildFolderSlivers(AsyncValue<List<AudioFolder>> folders) {
    return folders.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 36),
            child: LoadingView(label: 'Reading folders…'),
          ),
        ),
      ],
      error: (error, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: error.toString().contains('permission')
                ? Panel(
                    borderColor: LjodTheme.amber.withValues(alpha: 0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Music access is required to list folders.',
                          style: TextStyle(color: LjodTheme.textStrong),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _requestAccess,
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: const Text('Allow access'),
                        ),
                      ],
                    ),
                  )
                : ErrorView(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(libraryFoldersProvider),
                  ),
          ),
        ),
      ],
      data: (items) {
        final query = _query.trim().toLowerCase();
        final visible = query.isEmpty
            ? items
            : items
                  .where(
                    (folder) =>
                        folder.path.toLowerCase().contains(query) ||
                        folder.name.toLowerCase().contains(query),
                  )
                  .toList(growable: false);

        if (items.isEmpty) {
          return const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.folder_off_rounded,
                  title: 'No folders found',
                  message:
                      'Ljod could not read folder paths on this device. On '
                      'Android 11+ some libraries only expose content URIs; '
                      'folder rules apply where paths are available.',
                  compact: true,
                ),
              ),
            ),
          ];
        }

        if (visible.isEmpty) {
          return const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching folders',
                  message: 'Try a shorter folder name.',
                  compact: true,
                ),
              ),
            ),
          ];
        }

        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 6),
              child: Text(
                '${visible.length} folder${visible.length == 1 ? '' : 's'} with audio',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: LjodTheme.textMuted, letterSpacing: 0.6),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final folder = visible[index];
              final selected = _filters.contains(folder.path);
              final selectable = _mode != FolderFilterMode.all;
              return ListTile(
                leading: Icon(
                  selected && selectable
                      ? Icons.folder_rounded
                      : Icons.folder_outlined,
                  color: selected && selectable
                      ? LjodTheme.amber
                      : LjodTheme.textMuted,
                ),
                title: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${folder.parent} · ${folder.trackCount} '
                  'track${folder.trackCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selectable
                    ? Checkbox(
                        value: selected,
                        onChanged: (_) => _toggle(folder.path),
                      )
                    : Text(
                        '${folder.trackCount}',
                        style: const TextStyle(color: LjodTheme.textMuted),
                      ),
                onTap: selectable ? () => _toggle(folder.path) : null,
              );
            },
          ),
        ];
      },
    );
  }

  void _toggle(String path) {
    setState(() {
      if (!_filters.add(path)) _filters.remove(path);
    });
  }

  Future<void> _requestAccess() async {
    final granted = await ref.read(libraryServiceProvider).requestPermission();
    if (!mounted) return;
    if (!granted) {
      _toast('Music access was not granted.');
      return;
    }
    ref.invalidate(libraryFoldersProvider);
  }

  Future<void> _save() async {
    if (_mode == FolderFilterMode.only && _filters.isEmpty) {
      _toast('Pick at least one folder, or choose “All”.');
      return;
    }

    setState(() => _saving = true);
    await ref
        .read(settingsProvider.notifier)
        .setFolderScope(_mode, _filters.toList());
    if (!mounted) return;

    if (widget.rescanOnSave) {
      await ref.read(libraryProvider.notifier).rescan(requestPermission: false);
      if (!mounted) return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
