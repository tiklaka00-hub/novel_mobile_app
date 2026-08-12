import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

import 'explore_screen.dart';
import 'reader_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.data,
    required this.apiService,
  });

  final AppBootstrap data;
  final ApiService apiService;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<String> _tabs;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = widget.data.discoverTabs.isNotEmpty
        ? widget.data.discoverTabs
        : const ['New', 'Popular', 'Fanfiction', 'Newsfeed'];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Category tabs – pinned
        // ignore: prefer_const_constructors
        // ignore: sized_box_for_whitespace
        // Pinned tab bar
        // (uses SliverPersistentHeader so tabs stay visible while scrolling)
        //
        // Category Tabs - Pinned
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _CategoryTabs(
                labels: _tabs,
                tabController: _tabController,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildTabContent(_selectedTabIndex)),
      ],
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final tabLabel = _tabs[tabIndex].toLowerCase();
    final allBooks = _booksForDiscover();
    final sections = _discoverSectionsForTab(tabLabel, allBooks);
    final showExploreLead = tabLabel == 'new' && sections.isNotEmpty;

    return Container(
      color: Colors.white,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          if (showExploreLead) ...[
            _ExploreStoriesSection(
              books: sections.first.books,
              topics: widget.data.exploreTopics,
              apiService: widget.apiService,
              onOpenExplore: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExploreScreen(
                      topics: widget.data.exploreTopics,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          for (var i = 0; i < sections.length; i++) ...[
            if (!(showExploreLead && i == 0)) ...[
              _DynamicStoryRail(
                section: sections[i],
                apiService: widget.apiService,
              ),
              const SizedBox(height: 24),
              if (i == 1) ...[
                _GenrePillRow(
                  topics: widget.data.exploreTopics,
                  books: allBooks,
                  apiService: widget.apiService,
                  onOpenExplore: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExploreScreen(
                          topics: widget.data.exploreTopics,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
              if (i == 2) ...[
                _AuthorsStrip(books: allBooks, apiService: widget.apiService),
                const SizedBox(height: 24),
              ],
            ],
          ],
        ],
      ),
    );
  }

  List<BookCardModel> _booksForDiscover() {
    if (widget.data.discoverBooks.isNotEmpty) {
      return widget.data.discoverBooks;
    }

    final seen = <int>{};
    final merged = <BookCardModel>[];
    for (final book in [
      ...widget.data.recentlyUpdated,
      ...widget.data.recentlyCompleted,
    ]) {
      if (!seen.contains(book.id)) {
        seen.add(book.id);
        merged.add(book);
      }
    }
    return merged;
  }

  List<_DiscoverRailSection> _discoverSectionsForTab(
    String tab,
    List<BookCardModel> books,
  ) {
    List<BookCardModel> takeWhere(bool Function(BookCardModel) test) {
      return books.where(test).toList();
    }

    final recentlyUpdated = takeWhere(
      (b) => b.sectionName == 'recently_updated',
    );
    final recentlyCompleted = takeWhere(
      (b) => b.sectionName == 'recently_completed' || b.isCompleted,
    );
    final topRated = [...books]..sort((a, b) => b.rating.compareTo(a.rating));
    final fantasy = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('fantasy') ||
          b.secondaryGenre.toLowerCase().contains('fantasy'),
    );
    final paranormal = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('urban'),
    );
    final action = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('action') ||
          b.secondaryGenre.toLowerCase().contains('action') ||
          b.primaryGenre.toLowerCase().contains('adventure') ||
          b.secondaryGenre.toLowerCase().contains('adventure'),
    );

    switch (tab) {
      case 'popular':
        return [
          _DiscoverRailSection(
            title: 'Trending Now',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Most Completed',
            books: recentlyCompleted.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Fan Favorites',
            books: topRated.skip(2).take(10).toList(),
          ),
        ];
      case 'fanfiction':
        return [
          _DiscoverRailSection(
            title: 'Fan Picks',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Romance & Drama',
            books: takeWhere(
              (b) =>
                  b.primaryGenre.toLowerCase().contains('romance') ||
                  b.primaryGenre.toLowerCase().contains('drama'),
            ).take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Completed Fan Stories',
            books: recentlyCompleted.take(10).toList(),
          ),
        ];
      case 'newsfeed':
        return [
          _DiscoverRailSection(
            title: 'Fresh Updates',
            books: recentlyUpdated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Staff Picks',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Rising Stories',
            books: topRated.skip(4).take(10).toList(),
          ),
        ];
      default:
        return [
          _DiscoverRailSection(
            title: 'Recently Updated',
            books: recentlyUpdated.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Recently Completed',
            books: recentlyCompleted.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Selected Stories',
            books: topRated.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'New in Fantasy',
            books: fantasy.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Action & Adventure Fantasy',
            books: action.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Paranormal & Urban Fantasy',
            books: paranormal.take(12).toList(),
          ),
        ];
    }
  }
}

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text, this.onReadMore});

  final String text;
  final VoidCallback? onReadMore;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim().isEmpty
        ? 'No description available yet.'
        : widget.text.trim();
    final needsToggle = text.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded || !needsToggle ? null : 4,
          overflow: _expanded || !needsToggle
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: const Color(0xFF555555),
          ),
        ),
        if (needsToggle)
          TextButton(
            onPressed: () {
              if (widget.onReadMore != null) {
                widget.onReadMore!();
                return;
              }
              setState(() => _expanded = !_expanded);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: AppTheme.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  if (normalized.length < 6) return const Color(0xFFA1A1A1);
  return Color(int.parse('FF$normalized', radix: 16));
}

class _ExploreStoriesSection extends StatelessWidget {
  const _ExploreStoriesSection({
    required this.books,
    required this.topics,
    required this.apiService,
    required this.onOpenExplore,
  });

  final List<BookCardModel> books;
  final List<ExploreTopicModel> topics;
  final ApiService apiService;
  final VoidCallback onOpenExplore;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final lead = books.first;
    final covers = books.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lead.primaryGenre.isEmpty ? 'Portal Fantasy' : lead.primaryGenre,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: covers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = covers[index];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  height: 120,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StoryDetailScreen(
                            apiService: apiService,
                            book: BookDetailModel(
                              id: item.id,
                              title: item.title,
                              author: item.author,
                              description: item.description,
                              statusText: item.statusText,
                              rating: item.rating,
                              genre: item.primaryGenre,
                              cta: item.cta,
                              coverPath: item.coverPath,
                            ),
                          ),
                        ),
                      );
                    },
                    child: _StoryCard(
                      book: item,
                      width: 86,
                      apiService: apiService,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(book: lead, apiService: apiService),
        const SizedBox(height: 16),
        _GenrePillRow(
          topics: topics,
          books: books,
          apiService: apiService,
          onOpenExplore: onOpenExplore,
        ),
      ],
    );
  }
}

class _DiscoverRailSection {
  const _DiscoverRailSection({required this.title, required this.books});

  final String title;
  final List<BookCardModel> books;
}

class _DynamicStoryRail extends StatefulWidget {
  const _DynamicStoryRail({required this.section, required this.apiService});

  final _DiscoverRailSection section;
  final ApiService apiService;

  @override
  State<_DynamicStoryRail> createState() => _DynamicStoryRailState();
}

class _DynamicStoryRailState extends State<_DynamicStoryRail> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.32);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.books.isEmpty) {
      return const SizedBox.shrink();
    }

    final book = widget
        .section
        .books[_activeIndex.clamp(0, widget.section.books.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.section.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: widget.section.books.length,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) {
              final item = widget.section.books[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10, left: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: widget.apiService,
                          book: BookDetailModel(
                            id: item.id,
                            title: item.title,
                            author: item.author,
                            description: item.description,
                            statusText: item.statusText,
                            rating: item.rating,
                            genre: item.primaryGenre,
                            cta: item.cta,
                            coverPath: item.coverPath,
                          ),
                        ),
                      ),
                    );
                  },
                  child: _StoryCard(
                    book: item,
                    width: 96,
                    apiService: widget.apiService,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(
          book: book,
          apiService: widget.apiService,
          onRead: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: widget.apiService,
                  book: BookDetailModel(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    statusText: book.statusText,
                    rating: book.rating,
                    genre: book.primaryGenre,
                    cta: book.cta,
                    coverPath: book.coverPath,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActiveStoryDetail extends StatelessWidget {
  const _ActiveStoryDetail({required this.book, this.onRead, this.apiService});

  final BookCardModel book;
  final VoidCallback? onRead;
  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _ExpandableDescription(
          text: book.description,
          onReadMore: () {
            if (onRead != null) {
              onRead!();
              return;
            }
            if (apiService == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: apiService!,
                  book: BookDetailModel(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    statusText: book.statusText,
                    rating: book.rating,
                    genre: book.primaryGenre,
                    cta: book.cta,
                    coverPath: book.coverPath,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  book.statusText.isEmpty
                      ? 'Updated recently'
                      : book.statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (book.rating > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  book.rating.round().clamp(0, 5),
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF3C623),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (book.isCompleted) ...[
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: AppTheme.brand,
              ),
              Text(
                'Completed',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.brand),
              ),
            ],
            _GenreTag(
              label: book.primaryGenre.isEmpty ? 'Novel' : book.primaryGenre,
            ),
            if (book.secondaryGenre.isNotEmpty)
              _GenreTag(label: book.secondaryGenre),
            ElevatedButton(
              onPressed: onRead,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                book.cta,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({
    required this.book,
    required this.apiService,
    this.width = 140,
  });

  final BookCardModel book;
  final ApiService apiService;
  final double width;

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final authorId = widget.book.authorUserId;
    if (authorId == null) return;
    final following = await widget.apiService.fetchAuthorFollowing(authorId);
    if (!mounted) return;
    setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    final authorId = widget.book.authorUserId;
    if (authorId == null) return;
    try {
      if (_isFollowing) {
        await widget.apiService.unfollowAuthor(authorId);
        setState(() => _isFollowing = false);
      } else {
        await widget.apiService.followAuthor(authorId);
        setState(() => _isFollowing = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(widget.book.accentHex);

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: widget.width <= 86 ? 0.5 : 0.62,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: widget.book.coverPath.isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(
                                widget.apiService.resolveAssetUrl(
                                  widget.book.coverPath,
                                ),
                              ),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          widget.book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'by ${widget.book.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.book.authorUserId != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isFollowing
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: _isFollowing ? AppTheme.brand : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthorsStrip extends StatefulWidget {
  const _AuthorsStrip({required this.books, required this.apiService});

  final List<BookCardModel> books;
  final ApiService apiService;

  @override
  State<_AuthorsStrip> createState() => _AuthorsStripState();
}

class _AuthorsStripState extends State<_AuthorsStrip> {
  Map<int, bool> _following = {};

  @override
  void initState() {
    super.initState();
    _loadFollowStates();
  }

  Future<void> _loadFollowStates() async {
    final ids = <int>[];
    final seenNames = <String>{};
    for (final book in widget.books) {
      final name = book.author.trim().isEmpty ? 'Unknown' : book.author;
      if (seenNames.contains(name)) continue;
      seenNames.add(name);
      final aid = book.authorUserId;
      if (aid != null) ids.add(aid);
      if (seenNames.length >= 8) break;
    }
    if (ids.isEmpty) return;
    final map = await widget.apiService.fetchAuthorsFollowing(ids);
    if (!mounted) return;
    setState(() => _following = map);
  }

  Future<void> _toggleFollowFor(int authorId) async {
    final currently = _following[authorId] ?? false;
    try {
      if (currently) {
        await widget.apiService.unfollowAuthor(authorId);
      } else {
        await widget.apiService.followAuthor(authorId);
      }
      if (!mounted) return;
      setState(() => _following[authorId] = !currently);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final byAuthor = <String, BookCardModel>{};
    for (final book in widget.books) {
      byAuthor.putIfAbsent(
        book.author.trim().isEmpty ? 'Unknown' : book.author,
        () => book,
      );
      if (byAuthor.length >= 8) break;
    }

    final authors = byAuthor.entries.toList();
    if (authors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Authors on Inkitt',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: authors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final author = authors[index].key;
              final book = authors[index].value;
              final letter = author.isNotEmpty ? author[0].toUpperCase() : 'A';
              final authorId = book.authorUserId;
              final isFollowing = authorId != null
                  ? (_following[authorId] ?? false)
                  : false;
              return Column(
                children: [
                  GestureDetector(
                    onTap: authorId != null
                        ? () => _toggleFollowFor(authorId)
                        : null,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE8EEF9),
                          child: Text(
                            letter,
                            style: const TextStyle(color: AppTheme.brand),
                          ),
                        ),
                        if (authorId != null)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isFollowing
                                    ? Colors.white
                                    : Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: isFollowing
                                      ? AppTheme.brand
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 48,
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenrePillRow extends StatelessWidget {
  const _GenrePillRow({
    required this.topics,
    required this.books,
    required this.apiService,
    this.onOpenExplore,
  });

  final List<ExploreTopicModel> topics;
  final List<BookCardModel> books;
  final ApiService apiService;
  final VoidCallback? onOpenExplore;

  @override
  Widget build(BuildContext context) {
    final genres = <String>{};
    for (final b in books) {
      if (b.primaryGenre.isNotEmpty) genres.add(b.primaryGenre);
      if (genres.length >= 8) break;
    }
    final items = genres.toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final label = items[index];
          return ActionChip(label: Text(label), onPressed: onOpenExplore);
        },
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.labels, required this.tabController});

  final List<String> labels;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final isSelected = tabController.index == index;
          return GestureDetector(
            onTap: () => tabController.animateTo(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected ? AppTheme.brand : AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  width: isSelected
                      ? math.max(labels[index].length * 11.0, 60)
                      : 0,
                  color: isSelected ? AppTheme.brand : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Duplicate _StoryCard removed — the stateful _StoryCard above is used now.

class _BookCoverFallback extends StatelessWidget {
  const _BookCoverFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.3) ?? color],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarDelegate({required this.child});

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.apiService,
    this.initialQuery = '',
    this.initialGenre = '',
  });

  final ApiService apiService;
  final String initialQuery;
  final String initialGenre;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _genre = '';
  double _minRating = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    final rows = await widget.apiService.searchStories(
      query: _searchQuery,
      genre: _genre,
      minRating: _minRating,
    );
    if (!mounted) return;
    setState(() {
      _results = rows;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery;
    _genre = widget.initialGenre;
    _searchController = TextEditingController(text: widget.initialQuery);
    _runSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search stories, people, lists...',
            border: InputBorder.none,
            hintStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _runSearch();
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() => _searchQuery = '');
                _searchController.clear();
                _runSearch();
              },
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              final selected = await showModalBottomSheet<_SearchFilters>(
                context: context,
                builder: (_) => const _FilterSheet(),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              );
              if (selected == null) return;
              setState(() {
                _genre = selected.genre;
                _minRating = selected.minRating;
              });
              _runSearch();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  title: Text(item['title']?.toString() ?? ''),
                  subtitle: Text(item['author']?.toString() ?? ''),
                  trailing: Text(
                    (item['rating'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }
}

class _SearchFilters {
  const _SearchFilters({required this.genre, required this.minRating});

  final String genre;
  final double minRating;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _selectedGenre;
  double _ratingFilter = 0;
  String? _completionStatus;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Genre',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Romance', 'Fantasy', 'Mystery', 'Horror', 'Sci-Fi']
                .map(
                  (genre) => FilterChip(
                    label: Text(genre),
                    selected: _selectedGenre == genre,
                    onSelected: (selected) {
                      setState(() => _selectedGenre = selected ? genre : null);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Star Rating',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _ratingFilter,
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (value) => setState(() => _ratingFilter = value),
          ),
          const SizedBox(height: 24),
          Text(
            'Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Complete', 'Ongoing', 'Hiatus']
                .map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _completionStatus == status,
                    onSelected: (selected) {
                      setState(
                        () => _completionStatus = selected ? status : null,
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                _SearchFilters(
                  genre: _selectedGenre ?? '',
                  minRating: _ratingFilter,
                ),
              ),
              child: const Text('View Results'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Story detail (matches video: cover, stats, summary, genres, chapters, CTA)
// ---------------------------------------------------------------------------

class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({
    super.key,
    required this.book,
    required this.apiService,
  });

  final BookDetailModel book;
  final ApiService apiService;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late BookDetailModel _book;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  Future<void> _toggleFollow() async {
    final aid = _book.authorUserId;
    if (aid == null) return;
    try {
      if (_isFollowing)
        await widget.apiService.unfollowAuthor(aid);
      else
        await widget.apiService.followAuthor(aid);
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_book.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_book.coverPath.isNotEmpty)
              Image.network(
                widget.apiService.resolveAssetUrl(_book.coverPath),
                height: 180,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 12),
            Text(
              'by ${_book.author}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _book.description,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (_book.authorUserId != null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _toggleFollow,
                  child: Text(_isFollowing ? 'Following' : 'Follow'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
