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
  bool _listsLoading = false;
  bool _entriesLoadedFromApi = false;
  bool _listsLoadedFromApi = false;

  bool _isCompleted(LibraryEntryModel entry) {
    final status = entry.readingStatus.toLowerCase().trim();
    return status == 'completed' ||
        status == 'complete' ||
        status == 'finished' ||
        status == 'done';
  }

  List<LibraryEntryModel> get _currentEntries =>
      _entries.where((entry) => !_isCompleted(entry)).toList();

  List<LibraryEntryModel> get _historyEntries =>
      _entries.where(_isCompleted).toList();

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
    setState(() => _loading = true);
    try {
      final rows = await widget.apiService.fetchLibraryEntries();
      if (!mounted) return;
      setState(() {
        // Once API responds successfully, always trust live data
        // (including empty) so seed bootstrap does not stick forever.
        _entries = rows.map((row) => LibraryEntryModel.fromMap(row)).toList();
        _entriesLoadedFromApi = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Keep bootstrap only if we never got a successful API response.
        if (!_entriesLoadedFromApi) {
          _entries = List<LibraryEntryModel>.from(widget.data.libraryEntries);
        }
        _loading = false;
      });
    }
  }

  Future<void> _loadReadingLists() async {
    setState(() => _listsLoading = true);
    try {
      final rows = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      setState(() {
        _readingLists =
            rows.map((row) => ReadingListModel.fromMap(row)).toList();
        _listsLoadedFromApi = true;
        _listsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!_listsLoadedFromApi) {
          _readingLists = List<ReadingListModel>.from(
            widget.data.profile.readingLists,
          );
        }
        _listsLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadEntries(), _loadReadingLists()]);
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
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
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

    if (name == null || name.trim().isEmpty) return;

    try {
      // Backend ReadingListCreateRequest is user-scoped (auth token).
      // Do not send profile_id — server sets user_id from the token.
      await widget.apiService.createReadingList({
        'name': name.trim(),
        'story_count': 0,
        'cover_path': '',
        'sort_order': _readingLists.length + 1,
      });
      await _loadReadingLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reading list created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create list: $e')),
        );
      }
    }
  }

  Future<void> _removeEntry(LibraryEntryModel entry) async {
    try {
      await widget.apiService.deleteLibraryEntry(entry.id);
      if (mounted) await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Future<void> _changeStatus(LibraryEntryModel entry) async {
    final nextStatus = _isCompleted(entry) ? 'Reading' : 'Completed';

    try {
      await widget.apiService.updateLibraryEntry(entry.id, {
        'reading_status': nextStatus,
        'updated_text': entry.updatedText,
        'chapters': entry.chapters,
        'primary_genre': entry.primaryGenre,
        'secondary_genre': entry.secondaryGenre,
      });
      if (mounted) await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.brand,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          labelStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Current Reads'),
            Tab(text: 'Reading Lists'),
            Tab(text: 'History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CurrentReadsTab(
                entries: _currentEntries,
                apiService: widget.apiService,
                loading: _loading,
                onDelete: _removeEntry,
                onToggleStatus: _changeStatus,
                onOpenDiscover: widget.onOpenDiscover,
                onRefresh: _refreshAll,
              ),
              _ReadingListsTab(
                lists: _readingLists,
                apiService: widget.apiService,
                loading: _listsLoading,
                onCreateList: _createReadingList,
                onRefresh: _refreshAll,
              ),
              _HistoryTab(
                entries: _historyEntries,
                apiService: widget.apiService,
                loading: _loading,
                onRefresh: _refreshAll,
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
    required this.onRefresh,
  });

  final List<LibraryEntryModel> entries;
  final ApiService apiService;
  final bool loading;
  final ValueChanged<LibraryEntryModel> onDelete;
  final ValueChanged<LibraryEntryModel> onToggleStatus;
  final VoidCallback onOpenDiscover;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add stories from Discover, or mark them as Reading.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted),
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
      ),
    );
  }
}

class _ReadingListsTab extends StatelessWidget {
  const _ReadingListsTab({
    required this.lists,
    required this.apiService,
    required this.loading,
    required this.onCreateList,
    required this.onRefresh,
  });

  final List<ReadingListModel> lists;
  final ApiService apiService;
  final bool loading;
  final Future<void> Function() onCreateList;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (lists.isEmpty)
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
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a list to organize stories you want to read.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted),
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
              onPressed: () => onCreateList(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New List'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.entries,
    required this.apiService,
    required this.loading,
    required this.onRefresh,
  });

  final List<LibraryEntryModel> entries;
  final ApiService apiService;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        children: [
          Text(
            'Reading History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mark a book as Completed from Current Reads (menu → Toggle Status) to see it here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted),
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
                      Icons.history_outlined,
                      size: 48,
                      color: AppTheme.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your reading history appears here',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryEntryCard(
                  entry: entry,
                  apiService: apiService,
                ),
              ),
            ),
        ],
      ),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Completed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
            ),
          ),
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
    final status = entry.readingStatus.toLowerCase().trim();
    final completed = status == 'completed' ||
        status == 'complete' ||
        status == 'finished' ||
        status == 'done' ||
        status.contains('complet');

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (completed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.done_all_rounded,
                            color: AppTheme.brand,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.brand,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: AppTheme.muted,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.readingStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    Text(
                      '${entry.chapters} Chapters',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF555555),
                            fontSize: 12,
                          ),
                    ),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'status') onToggleStatus();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'status',
                child: Text(
                  completed ? 'Mark as Reading' : 'Mark as Completed',
                ),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${list.storyCount} stories',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.muted),
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
  if (normalized.length != 6) return const Color(0xFFA1A1A1);
  return Color(int.parse('FF$normalized', radix: 16));
}
