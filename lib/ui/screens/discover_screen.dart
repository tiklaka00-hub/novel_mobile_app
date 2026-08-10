import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'explore_screen.dart';
import 'reader_screen.dart';
import 'support_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.onOpenSupport,
    required this.onChangeAccount,
  });

  final AppBootstrap data;
  final ApiService apiService;
  final VoidCallback onOpenSupport;
  final Future<void> Function() onChangeAccount;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final List<String> _tabs;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = widget.data.discoverTabs.isNotEmpty
        ? widget.data.discoverTabs
        : const ['New', 'Popular', 'Fanfiction', 'Newsfeed'];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
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
        // Header with menu, title, and search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ExploreScreen(topics: widget.data.exploreTopics),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_open_rounded, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Inkitt',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 28,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SearchScreen(apiService: widget.apiService),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search_rounded, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 24),
                  onSelected: (value) async {
                    if (value == 'support') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SupportScreen(apiService: widget.apiService),
                        ),
                      );
                      return;
                    }

                    if (value == 'change_account') {
                      final approved = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: const Text(
                            'Are you sure you want to log out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('NO'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('YES'),
                            ),
                          ],
                        ),
                      );
                      if (approved == true) {
                        await widget.onChangeAccount();
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'support',
                      child: Text('Contact support'),
                    ),
                    PopupMenuItem<String>(
                      value: 'change_account',
                      child: Text('Change accounts'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

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

        // Content based on selected tab
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
                    builder: (_) =>
                        ExploreScreen(topics: widget.data.exploreTopics),
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
                        builder: (_) =>
                            ExploreScreen(topics: widget.data.exploreTopics),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
              if (i == 2) ...[
                _AuthorsStrip(books: allBooks),
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
              return _StoryCard(
                book: covers[index],
                width: 86,
                apiService: apiService,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(book: lead),
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
    _pageController = PageController(viewportFraction: 0.28);
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
            itemCount: widget.section.books.length,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) {
              final item = widget.section.books[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _StoryCard(
                  book: item,
                  width: 96,
                  apiService: widget.apiService,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(
          book: book,
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
  const _ActiveStoryDetail({required this.book, this.onRead});

  final BookCardModel book;
  final VoidCallback? onRead;

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
        Text(
          book.description.isEmpty
              ? 'A fresh novel update waiting for you.'
              : book.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF666666),
            height: 1.45,
          ),
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

class _GenrePillRow extends StatelessWidget {
  const _GenrePillRow({
    required this.topics,
    required this.books,
    required this.apiService,
    required this.onOpenExplore,
  });

  final List<ExploreTopicModel> topics;
  final List<BookCardModel> books;
  final ApiService apiService;
  final VoidCallback onOpenExplore;

  @override
  Widget build(BuildContext context) {
    final effectiveTopics = topics.isNotEmpty
        ? topics
        : books
              .map((b) => b.primaryGenre)
              .where((g) => g.trim().isNotEmpty)
              .toSet()
              .take(10)
              .map((name) => ExploreTopicModel(name: name, topicCount: 0))
              .toList();

    if (effectiveTopics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Browse genres',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(onPressed: onOpenExplore, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: effectiveTopics.length.clamp(0, 12),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = effectiveTopics[index];
              final cover = books.isEmpty ? null : books[index % books.length];

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onOpenExplore,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(18),
                    image: cover == null || cover.coverPath.isEmpty
                        ? null
                        : DecorationImage(
                            image: NetworkImage(
                              apiService.resolveAssetUrl(cover.coverPath),
                            ),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.35),
                              BlendMode.darken,
                            ),
                          ),
                  ),
                  child: Text(
                    topic.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cover == null ? AppTheme.ink : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuthorsStrip extends StatelessWidget {
  const _AuthorsStrip({required this.books});

  final List<BookCardModel> books;

  @override
  Widget build(BuildContext context) {
    final byAuthor = <String, BookCardModel>{};
    for (final book in books) {
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
              final letter = author.isNotEmpty ? author[0].toUpperCase() : 'A';
              return Column(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE8EEF9),
                    child: Text(
                      letter,
                      style: const TextStyle(color: AppTheme.brand),
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

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.book,
    required this.apiService,
    this.width = 140,
  });

  final BookCardModel book;
  final ApiService apiService;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(book.accentHex);

    return Container(
      width: width,
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
          fit: StackFit.expand,
          children: [
            // Background image or gradient
            book.coverPath.isNotEmpty
                ? Image.network(
                    apiService.resolveAssetUrl(book.coverPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _BookCoverFallback(color: color),
                  )
                : _BookCoverFallback(color: color),

            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xA0000000)],
                ),
              ),
            ),

            // Content - positioned at bottom to avoid overflow
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${book.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

// Placeholder screens
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  String _genre = '';
  double _minRating = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
    });
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
    _runSearch();
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

          // Genre filter
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

          // Rating filter
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

          // Completion status
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

          // Apply button
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

// Story Detail Screen
class StoryDetailScreen extends StatelessWidget {
  const StoryDetailScreen({
    super.key,
    required this.book,
    required this.apiService,
  });

  final BookDetailModel book;
  final ApiService apiService;

  Future<void> _saveToLibrary(BuildContext context) async {
    try {
      await apiService.addLibraryEntry({
        'book_id': book.id,
        'reading_status': 'Reading',
        'updated_text': book.statusText.isNotEmpty ? book.statusText : 'Just added',
        'chapters': 1,
        'primary_genre': book.genre,
        'secondary_genre': '',
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Current Reads')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFFFF6B9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'by ${book.author}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFF3C623),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${book.rating} Rating',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Icon(Icons.access_time, color: AppTheme.muted, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        book.statusText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description with Read more / Show less
                  _ExpandableDescription(text: book.description),
                  const SizedBox(height: 20),

                  // Genres
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(book.genre),
                        backgroundColor: AppTheme.brand.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Read button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brand,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReaderScreen(
                              title: book.title,
                              author: book.author,
                              description: book.description,
                            ),
                          ),
                        );
                      },
                      child: const Text('Read Now'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bookmark_outline),
                      label: const Text('Save to Library'),
                      onPressed: () => _saveToLibrary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});

  final String text;

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
            onPressed: () => setState(() => _expanded = !_expanded),
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
  return Color(int.parse('FF$normalized', radix: 16));
}
