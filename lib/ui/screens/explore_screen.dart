import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({
    super.key,
    required this.topics,
    required this.apiService,
  });

  final List<ExploreTopicModel> topics;
  final ApiService apiService;

  static const List<ExploreTopicModel> _fallbackTopics = [
    ExploreTopicModel(name: 'Fanfiction', topicCount: 100),
    ExploreTopicModel(name: 'Fantasy', topicCount: 31),
    ExploreTopicModel(name: 'Poetry', topicCount: 14),
    ExploreTopicModel(name: 'Adventure', topicCount: 35),
    ExploreTopicModel(name: 'Horror', topicCount: 29),
    ExploreTopicModel(name: 'Thriller', topicCount: 35),
    ExploreTopicModel(name: 'Young Adult', topicCount: 6),
    ExploreTopicModel(name: 'LGBTQ+', topicCount: 0),
    ExploreTopicModel(name: 'Literary Fiction', topicCount: 0),
    ExploreTopicModel(name: 'Historical Fiction', topicCount: 0),
    ExploreTopicModel(name: 'Erotica', topicCount: 32),
    ExploreTopicModel(name: 'Mystery', topicCount: 32),
    ExploreTopicModel(name: 'SciFi', topicCount: 31),
    ExploreTopicModel(name: 'Humor', topicCount: 24),
    ExploreTopicModel(name: 'Action', topicCount: 33),
    ExploreTopicModel(name: 'Drama', topicCount: 30),
    ExploreTopicModel(name: 'Romance', topicCount: 35),
  ];

  @override
  Widget build(BuildContext context) {
    final displayTopics = topics.isNotEmpty ? topics : _fallbackTopics;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Explore',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: displayTopics.length,
        separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1),
        itemBuilder: (context, index) {
          final topic = displayTopics[index];
          return _GenreListTile(topic: topic, apiService: apiService);
        },
      ),
    );
  }
}

class _GenreListTile extends StatelessWidget {
  const _GenreListTile({required this.topic, required this.apiService});

  final ExploreTopicModel topic;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                _GenreStoriesScreen(genre: topic.name, apiService: apiService),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                topic.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.ink,
                ),
              ),
            ),
            Text(
              topic.topicCount > 0 ? '${topic.topicCount} topics' : '0 topics',
              style: const TextStyle(fontSize: 14, color: AppTheme.muted),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreStoriesScreen extends StatefulWidget {
  const _GenreStoriesScreen({required this.genre, required this.apiService});

  final String genre;
  final ApiService apiService;

  @override
  State<_GenreStoriesScreen> createState() => _GenreStoriesScreenState();
}

class _GenreStoriesScreenState extends State<_GenreStoriesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stories = [];

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final results = await widget.apiService.searchStories(
      query: '',
      genre: widget.genre,
      minRating: 0,
    );
    if (!mounted) return;
    setState(() {
      _stories = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.genre),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stories.isEmpty
          ? Center(
              child: Text(
                'No stories found for ${widget.genre}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _stories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final story = _stories[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  title: Text(story['title']?.toString() ?? ''),
                  subtitle: Text(story['author']?.toString() ?? ''),
                  trailing: Text(
                    (story['rating'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }
}
