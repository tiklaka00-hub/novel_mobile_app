import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.onOpenDiscover,
  });

  final AppBootstrap data;
  final ApiService apiService;
  final VoidCallback onOpenDiscover;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<LibraryEntryModel> _entries;
  late List<ReadingListModel> _readingLists;
  bool _loading = false;

  List<LibraryEntryModel> get _currentEntries => _entries
      .where((entry) => entry.readingStatus.toLowerCase() != 'completed')
      .toList();

  List<LibraryEntryModel> get _historyEntries => _entries
      .where((entry) => entry.readingStatus.toLowerCase() == 'completed')
      .toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _entries = List<LibraryEntryModel>.from(widget.data.libraryEntries);
    _readingLists = List<ReadingListModel>.from(
      widget.data.profile.readingLists,
    );
    _loadEntries();
    _loadReadingLists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
    });
    final rows = await widget.apiService.fetchLibraryEntries();
    if (!mounted) return;
    setState(() {
      // Only replace entries when the API returned actual data.
      // If the request failed (empty list due to 401/network),
      // keep the bootstrap fallback data so the tab is never blank.
      if (rows.isNotEmpty) {
        _entries = rows.map((row) => LibraryEntryModel.fromMap(row)).toList();
      }
      _loading = false;
    });
  }

  Future<void> _loadReadingLists() async {
    final rows = await widget.apiService.fetchReadingLists();
    if (!mounted) {
      return;
    }
    // Only replace reading lists when the API returned actual data.
    // Otherwise keep the bootstrap fallback data.
    if (rows.isNotEmpty) {
      setState(() {
        _readingLists = rows
            .map((row) => ReadingListModel.fromMap(row))
            .toList();
      });
    }
  }

  Future<void> _createReadingList() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    // Do not dispose the controller here — disposing it immediately after
    // `showDialog` can cause the TextField to be used after disposal during
    // framework animation/update callbacks. Letting it be GC'd avoids
    // intermittent "used after being disposed" errors.

    if (name == null || name.trim().isEmpty) {
      return;
    }

    await widget.apiService.createReadingList({
      'profile_id': 1,
      'name': name.trim(),
      'story_count': 0,
      'cover_path': '',
      'sort_order': _readingLists.length + 1,
    });
    await _loadReadingLists();
  }

  Future<void> _removeEntry(LibraryEntryModel entry) async {
    await widget.apiService.deleteLibraryEntry(entry.id);
    if (mounted) {
      _loadEntries();
    }
  }

  Future<void> _changeStatus(LibraryEntryModel entry) async {
    final nextStatus = entry.readingStatus.toLowerCase() == 'completed'
        ? 'Reading'
        : 'Completed';

    await widget.apiService.updateLibraryEntry(entry.id, {
      'reading_status': nextStatus,
      'updated_text': entry.updatedText,
      'chapters': entry.chapters,
      'primary_genre': entry.primaryGenre,
      'secondary_genre': entry.secondaryGenre,
    });
    if (mounted) {
      _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Text(
            'Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.brand,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          labelStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Current Reads'),
            Tab(text: 'Reading Lists'),
            Tab(text: 'History'),
          ],
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Current Reads
              _CurrentReadsTab(
                entries: _currentEntries,
                apiService: widget.apiService,
                loading: _loading,
                onDelete: _removeEntry,
                onToggleStatus: _changeStatus,
                onOpenDiscover: widget.onOpenDiscover,
              ),

              // Reading Lists
              _ReadingListsTab(
                lists: _readingLists,
                apiService: widget.apiService,
                onCreateList: _createReadingList,
              ),

              // History
              _HistoryTab(
                entries: _historyEntries,
                apiService: widget.apiService,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentReadsTab extends StatelessWidget {
  const _CurrentReadsTab({
    required this.entries,
    required this.apiService,
    required this.loading,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onOpenDiscover,
  });

  final List<LibraryEntryModel> entries;
  final ApiService apiService;
  final bool loading;
  final ValueChanged<LibraryEntryModel> onDelete;
  final ValueChanged<LibraryEntryModel> onToggleStatus;
  final VoidCallback onOpenDiscover;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
      children: [
        Text(
          'My Books',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 48,
                    color: AppTheme.muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No books in your library yet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ...entries.map(
            (entry) => _LibraryEntryTile(
              entry: entry,
              apiService: apiService,
              onDelete: () => onDelete(entry),
              onToggleStatus: () => onToggleStatus(entry),
            ),
          ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpenDiscover,
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('Discover more stories'),
          ),
        ),
      ],
    );
  }
}

class _ReadingListsTab extends StatelessWidget {
  const _ReadingListsTab({
    required this.lists,
    required this.apiService,
    required this.onCreateList,
  });

  final List<ReadingListModel> lists;
  final ApiService apiService;
  final Future<void> Function() onCreateList;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
      children: [
        Text(
          'Private Reading Lists',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        if (lists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 48,
                    color: AppTheme.muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reading lists yet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ...lists.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReadingListRowCard(
                list: entry.value,
                index: entry.key,
                apiService: apiService,
              ),
            ),
          ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCreateList,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create New List'),
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.entries, required this.apiService});

  final List<LibraryEntryModel> entries;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
      children: [
        Text(
          'Reading History',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 48,
                    color: AppTheme.muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your reading history appears here',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ...entries
              .where(
                (entry) => entry.readingStatus.toLowerCase() == 'completed',
              )
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistoryEntryCard(
                    entry: entry,
                    apiService: apiService,
                  ),
                ),
              ),
      ],
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry, required this.apiService});

  final LibraryEntryModel entry;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8E8E8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 42,
              height: 58,
              child: entry.book.coverPath.isNotEmpty
                  ? Image.network(
                      apiService.resolveAssetUrl(entry.book.coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFFE4E4E4)),
                    )
                  : const ColoredBox(color: Color(0xFFE4E4E4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'by ${entry.book.author}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.updatedText}  •  ${entry.primaryGenre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _LibraryEntryTile extends StatelessWidget {
  const _LibraryEntryTile({
    required this.entry,
    required this.apiService,
    required this.onDelete,
    required this.onToggleStatus,
  });

  final LibraryEntryModel entry;
  final ApiService apiService;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(entry.book.accentHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 70,
              height: 100,
              child: entry.book.coverPath.isNotEmpty
                  ? Image.network(
                      apiService.resolveAssetUrl(entry.book.coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _BookCoverFallback(color: color),
                    )
                  : _BookCoverFallback(color: color),
            ),
          ),
          const SizedBox(width: 14),

          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${entry.book.author}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 8),

                // Status and metadata
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Reading status
                    if (entry.readingStatus.toLowerCase() == 'completed')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            color: AppTheme.brand,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.brand, fontSize: 12),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: AppTheme.muted,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.readingStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),

                    // Chapters
                    Text(
                      '${entry.chapters} Chapters',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF555555),
                        fontSize: 12,
                      ),
                    ),

                    // Primary genre
                    if (entry.primaryGenre.isNotEmpty)
                      Text(
                        entry.primaryGenre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF555555),
                          fontSize: 12,
                        ),
                      ),

                    // Secondary genre
                    if (entry.secondaryGenre.isNotEmpty)
                      Text(
                        entry.secondaryGenre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF555555),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'status') {
                onToggleStatus();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'status', child: Text('Toggle Status')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.brand),
          ),
        ],
      ),
    );
  }
}

class _ReadingListRowCard extends StatelessWidget {
  const _ReadingListRowCard({
    required this.list,
    required this.index,
    required this.apiService,
  });

  final ReadingListModel list;
  final int index;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: list.coverPath.isNotEmpty
                  ? Image.network(
                      apiService.resolveAssetUrl(list.coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFFDDDDDD)),
                    )
                  : const ColoredBox(color: Color(0xFFDDDDDD)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${list.storyCount} stories',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _BookCoverFallback extends StatelessWidget {
  const _BookCoverFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.3) ?? color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}
