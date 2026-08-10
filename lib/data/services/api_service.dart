import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_bootstrap.dart';

class ApiService {
  ApiService();

  String? _authToken;

  String? get authTokenForPersistence => _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  static const String _productionApiBaseUrl =
      'https://lakmasachith-novel-app-backend.hf.space';

  static const String _overrideApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  String get _baseUrl {
    if (_overrideApiBaseUrl.isNotEmpty) {
      return _overrideApiBaseUrl;
    }

    if (kDebugMode) {
      // Use defaultTargetPlatform which works on all platforms including web
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000';
      }
      return 'http://127.0.0.1:8000';
    }

    return _productionApiBaseUrl;
  }

  Map<String, String> get _authHeaders {
    if (_authToken == null || _authToken!.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $_authToken'};
  }

  Future<http.Response> _requestWithHostFallback(
    Future<http.Response> Function(String baseUrl) request,
    Duration timeout,
  ) async {
    try {
      return await request(_baseUrl).timeout(timeout);
    } on http.ClientException {
      if (_baseUrl == _productionApiBaseUrl) rethrow;
      return request(_productionApiBaseUrl).timeout(timeout);
    } on TimeoutException {
      if (_baseUrl == _productionApiBaseUrl) rethrow;
      return request(_productionApiBaseUrl).timeout(timeout);
    }
  }

  Future<http.Response> _get(
    String path, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders),
      timeout,
    );
  }

  String resolveAssetUrl(String path) {
    if (path.isEmpty) {
      return path;
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // Legacy: story_card_images/... or assets/story_card_images/...
    if (trimmed.contains('story_card_images/')) {
      final filename = trimmed.split('/').last;
      return '$_baseUrl/uploads/$filename';
    }
    // Bare filename (e.g. story15.jpg) or uploads/filename without leading slash
    if (!trimmed.startsWith('/')) {
      if (trimmed.startsWith('uploads/')) {
        return '$_baseUrl/$trimmed';
      }
      // Treat as uploads file name
      return '$_baseUrl/uploads/$trimmed';
    }
    // Absolute path on API host (e.g. /uploads/uuid.jpg)
    return '$_baseUrl$trimmed';
  }

  Future<http.Response> _post(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json', ..._authHeaders},
        body: jsonEncode(body),
      ),
      timeout,
    );
  }

  Future<http.Response> _put(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.put(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json', ..._authHeaders},
        body: jsonEncode(body),
      ),
      timeout,
    );
  }

  Future<http.Response> _delete(
    String path, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) =>
          http.delete(Uri.parse('$baseUrl$path'), headers: _authHeaders),
      timeout,
    );
  }

  void _ensureSuccessResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Backend request failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<AppBootstrap> fetchBootstrap() async {
    try {
      final response = await _get(
        '/api/bootstrap',
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        return AppBootstrap.fromMap(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}

    return AppBootstrap.fromMap(_fallbackData);
  }

  Future<String> fetchContentVersion() async {
    try {
      final response = await _get(
        '/api/content/version',
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return payload['value']?.toString() ?? '';
      }
    } catch (_) {}

    return '';
  }

  /// Live per-user profile (display name, story/library counts).
  /// Requires auth token. Returns empty map if unauthenticated or offline.
  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final response = await _get(
        '/api/me',
        timeout: const Duration(seconds: 6),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadWriterImage(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/write/upload-image'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadSupportAttachment(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/support/upload-attachment'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({String? tab}) async {
    try {
      final response = await _get(
        '/api/notifications${tab != null && tab.trim().isNotEmpty ? '?tab=${Uri.encodeComponent(tab)}' : ''}',
        timeout: const Duration(seconds: 7),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(
          payload['items'] as List<dynamic>,
        );
      }
    } catch (_) {}

    final fallback = (_fallbackData['notifications'] as List<dynamic>)
        .where((item) {
          if (tab == null || tab.trim().isEmpty) return true;
          return (item as Map<String, dynamic>)['tab'] == tab;
        })
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
    return fallback;
  }

  Future<void> submitSupportRequest(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/support/requests',
      payload,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to submit support request');
    }
  }

  Future<Map<String, dynamic>> verifyGoogleSignIn({
    String? idToken,
    String? accessToken,
  }) async {
    final response = await _post('/api/auth/google', {
      'id_token': idToken,
      'access_token': accessToken,
    }, timeout: const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to verify Google sign-in');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyEmailSignIn(String email) async {
    final response = await _post('/api/auth/email', {
      'email': email,
    }, timeout: const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to verify email sign-in');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyGuestSignIn() async {
    final response = await _post(
      '/api/auth/guest',
      const <String, dynamic>{},
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to verify guest sign-in');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchStories({
    String query = '',
    String genre = '',
    double minRating = 0,
  }) async {
    try {
      final uri = Uri(
        path: '/api/search',
        queryParameters: {
          'query': query,
          'genre': genre,
          'min_rating': minRating.toString(),
        },
      );
      final response = await _get('${uri.path}?${uri.query}');
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLibraryEntries() async {
    try {
      final response = await _get('/api/library');
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchChatMessages() async {
    try {
      final response = await _get('/api/chat/messages');
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> addLibraryEntry(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/library',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> updateLibraryEntry(int id, Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/library/$id',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteLibraryEntry(int id) async {
    final response = await _delete(
      '/api/library/$id',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchReadingLists() async {
    try {
      final response = await _get('/api/reading-lists');
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> createReadingList(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/reading-lists',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchWriterStories() async {
    try {
      final response = await _get(
        '/api/write/stories',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> createWriterStory(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/write/stories',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> updateWriterStory(int id, Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/write/stories/$id',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteWriterStory(int id) async {
    final response = await _delete(
      '/api/write/stories/$id',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapters(int storyId) async {
    try {
      final response = await _get(
        '/api/write/stories/$storyId/chapters',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<int?> createStoryChapter(
    int storyId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/api/write/stories/$storyId/chapters',
      payload,
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id'] as int?;
  }

  Future<void> updateStoryChapter(
    int chapterId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _put(
      '/api/write/chapters/$chapterId',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapterRevisions(
    int chapterId,
  ) async {
    try {
      final response = await _get(
        '/api/write/chapters/$chapterId/revisions',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> deleteStoryChapter(int chapterId) async {
    final response = await _delete(
      '/api/write/chapters/$chapterId',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  static final Map<String, dynamic> _fallbackData = <String, dynamic>{
    'discover_tabs': ['New', 'Popular', 'Fanfiction', 'Newsfeed'],
    'recently_updated': [
      {
        'id': 1,
        'title': 'Reclaimed by the Alpha',
        'author': 'L. Cross',
        'cover_path':
            'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg',
        'accent_hex': '#A06054',
      },
      {
        'id': 2,
        'title': 'The Unexpected Prisoner',
        'author': 'SpicySammy',
        'cover_path':
            'story_card_images/04d68518-aafb-497e-995e-10bc6e4bef90.jpg',
        'accent_hex': '#7661A8',
      },
      {
        'id': 3,
        'title': 'James',
        'author': 'Tamaska Tyne',
        'cover_path':
            'story_card_images/19eb26e8-6ee4-4010-8848-8f5779f602dd.jpg',
        'accent_hex': '#A98A52',
      },
      {
        'id': 4,
        'title': 'Soul Rebirth',
        'author': 'Inferno',
        'cover_path':
            'story_card_images/0d88ca6e-bdb9-4d45-b7f4-013f0ef843e5.jpg',
        'accent_hex': '#5B5AA8',
      },
    ],
    'recently_completed': [
      {
        'id': 5,
        'title': 'The Silence of Shadows',
        'author': 'Kurt Brunnhuber',
        'cover_path':
            'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg',
        'accent_hex': '#674C6B',
      },
      {
        'id': 6,
        'title': 'What Now?',
        'author': 'Angela Lawece',
        'cover_path':
            'story_card_images/6a5c2a85-2d8c-498d-9153-1d72ec4005e4.jpg',
        'accent_hex': '#C69595',
      },
      {
        'id': 7,
        'title': 'Perpromenos',
        'author': 'Koyar Kora',
        'cover_path':
            'story_card_images/7d7d5cc8-5b0a-4821-9e57-3f58c36998b0.jpg',
        'accent_hex': '#8E9877',
      },
    ],
    'discover_books': [
      {
        'id': 1,
        'title': 'Reclaimed by the Alpha',
        'author': 'L. Cross',
        'description': 'A second chance romance with a dangerous secret heir.',
        'cover_path':
            'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg',
        'accent_hex': '#A06054',
        'section_name': 'recently_updated',
        'status_text': '2hr ago',
        'rating': 5.0,
        'genre': 'Romance',
        'primary_genre': 'Romance',
        'secondary_genre': 'Drama',
        'is_completed': 0,
        'cta_label': 'Read now',
      },
      {
        'id': 2,
        'title': 'The Unexpected Prisoner',
        'author': 'SpicySammy',
        'description':
            'A fantasy romance trapped between politics and prophecy.',
        'cover_path':
            'story_card_images/04d68518-aafb-497e-995e-10bc6e4bef90.jpg',
        'accent_hex': '#7661A8',
        'section_name': 'recently_updated',
        'status_text': '1hr ago',
        'rating': 4.8,
        'genre': 'Fantasy',
        'primary_genre': 'Fantasy',
        'secondary_genre': 'Romance',
        'is_completed': 0,
        'cta_label': 'Read now',
      },
      {
        'id': 3,
        'title': 'The Silence of Shadows',
        'author': 'Kurt Brunnhuber',
        'description':
            'A complete dark fantasy novel about a city with no sun.',
        'cover_path':
            'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg',
        'accent_hex': '#674C6B',
        'section_name': 'recently_completed',
        'status_text': 'Completed',
        'rating': 4.8,
        'genre': 'Fantasy',
        'primary_genre': 'Fantasy',
        'secondary_genre': 'Mystery',
        'is_completed': 1,
        'cta_label': 'Read now',
      },
      {
        'id': 4,
        'title': 'Goddess Tamer',
        'author': 'Ari Nova',
        'description':
            'A reborn hero must tame a dangerous goddess to survive.',
        'cover_path':
            'story_card_images/32b84f85-8e95-4a2d-8674-f3dc957133c8.jpg',
        'accent_hex': '#7F74C1',
        'section_name': 'recently_completed',
        'status_text': 'Completed',
        'rating': 4.9,
        'genre': 'Adventure',
        'primary_genre': 'Adventure',
        'secondary_genre': 'Fantasy',
        'is_completed': 1,
        'cta_label': 'Read now',
      },
      {
        'id': 5,
        'title': 'Demon King Leveling System',
        'author': 'J. Ard',
        'description': 'A modern student unlocks an infernal leveling system.',
        'cover_path':
            'story_card_images/60bf539d-3d16-4f7b-bda6-bb0bc5bd8385.jpg',
        'accent_hex': '#3F6FA0',
        'section_name': 'recently_updated',
        'status_text': '5m ago',
        'rating': 4.7,
        'genre': 'Fantasy',
        'primary_genre': 'Fantasy',
        'secondary_genre': 'Action',
        'is_completed': 0,
        'cta_label': 'Read now',
      },
      {
        'id': 6,
        'title': 'The Apex Transfer',
        'author': 'Elena Torres',
        'description': 'An outlier discovers she carries royal wolf blood.',
        'cover_path':
            'story_card_images/3379b80d-dc86-4a35-9a05-926f8b2cbbc5.jpg',
        'accent_hex': '#7B5D56',
        'section_name': 'recently_completed',
        'status_text': 'Completed',
        'rating': 5.0,
        'genre': 'Fantasy',
        'primary_genre': 'Fantasy',
        'secondary_genre': 'Paranormal',
        'is_completed': 1,
        'cta_label': 'Read now',
      },
    ],
    'featured_book': {
      'id': 1,
      'title': 'Reclaimed by the Alpha: The Alpha\'s Hidden Heir',
      'author': 'L. Cross',
      'description':
          'Six years ago, Nick Blackwood broke my heart on Christmas morning when he believed a lie that destroyed us both. I disappeared, rebuilt my life, and raised his daughter alone.',
      'status_text': '2hr ago',
      'rating': 5,
      'genre': 'Romance',
      'cta': 'Read now',
    },
    'explore_topics': [
      {'name': 'Fanfiction', 'topic_count': 100},
      {'name': 'Fantasy', 'topic_count': 31},
      {'name': 'Poetry', 'topic_count': 14},
      {'name': 'Adventure', 'topic_count': 35},
      {'name': 'Horror', 'topic_count': 29},
      {'name': 'Thriller', 'topic_count': 35},
      {'name': 'Young Adult', 'topic_count': 0},
      {'name': 'LGBTQ+', 'topic_count': 0},
      {'name': 'Literary Fiction', 'topic_count': 0},
      {'name': 'Historical Fiction', 'topic_count': 0},
      {'name': 'Erotica', 'topic_count': 32},
      {'name': 'Mystery', 'topic_count': 32},
      {'name': 'SciFi', 'topic_count': 31},
      {'name': 'Humor', 'topic_count': 24},
    ],
    'library_entries': [
      {
        'id': 1,
        'book': {
          'id': 8,
          'title': 'Owned by the Lycan King (18+)',
          'author': 'E.F BONI',
          'cover_path':
              'story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg',
          'accent_hex': '#8B523C',
        },
        'reading_status': 'Completed',
        'updated_text': '31 Chapters',
        'chapters': 31,
        'primary_genre': 'Romance',
        'secondary_genre': 'Erotica',
      },
      {
        'id': 2,
        'book': {
          'id': 9,
          'title': 'Lune',
          'author': 'Angela Lawece',
          'cover_path':
              'story_card_images/9e84fd30-5477-45f2-8c48-5c290f275856.jpg',
          'accent_hex': '#66738D',
        },
        'reading_status': '2wk ago',
        'updated_text': '4 Chapters',
        'chapters': 4,
        'primary_genre': 'Fantasy',
        'secondary_genre': 'SciFi',
      },
    ],
    'write_screen': {
      'manage_tabs': ['Manage Stories', 'Analytics'],
      'story_tabs': ['Submitted', 'Drafts'],
      'filter_label': 'All stories',
      'sort_label': 'Recently Updated',
      'empty_title': "You haven't submitted any story yet",
      'empty_cta': 'Submit Stories',
    },
    'notifications': [
      {
        'tab': 'System',
        'title': 'Inkitt',
        'message':
            'Earn some karma. Help this author today by reading their story!',
        'created_at': 'Tue Apr 19:11',
      },
    ],
    'menu_sections': [
      {
        'section': 'Profile',
        'items': [
          {'label': 'My Profile', 'icon': 'person', 'route': 'profile'},
          {'label': 'Reading Stats', 'icon': 'bar_chart', 'route': 'stats'},
        ],
      },
      {
        'section': 'Community',
        'items': [
          {'label': 'Groups', 'icon': 'groups', 'route': 'groups'},
        ],
      },
      {
        'section': 'Support',
        'items': [
          {'label': 'Help Center', 'icon': 'help', 'route': 'help'},
          {'label': 'Contact Us', 'icon': 'chat', 'route': 'contact'},
        ],
      },
      {
        'section': 'Settings',
        'items': [
          {
            'label': 'Notifications',
            'icon': 'notifications',
            'route': 'notifications',
          },
          {'label': 'App Language', 'icon': 'language', 'route': 'language'},
          {'label': 'Favourite Genres', 'icon': 'favorite', 'route': 'genres'},
          {
            'label': 'AI Content Review',
            'icon': 'auto_awesome',
            'route': 'ai-review',
          },
          {'label': 'Content Warnings', 'icon': 'warning', 'route': 'warnings'},
        ],
      },
      {
        'section': 'Legal',
        'items': [
          {
            'label': 'Manage Cookie Preferences',
            'icon': 'cookie',
            'route': 'cookies',
          },
          {
            'label': 'Terms of Service',
            'icon': 'description',
            'route': 'terms',
          },
          {'label': 'Privacy Policy', 'icon': 'lock', 'route': 'privacy'},
        ],
      },
      {
        'section': 'Change Accounts',
        'items': [
          {'label': 'Sign Out', 'icon': 'logout', 'route': 'logout'},
        ],
      },
    ],
    'profile': {
      'display_name': 'Sghj',
      'username': '@sghj',
      'following': 1,
      'followers': 0,
      'blocked': 0,
      'chapters_read': 0,
      'social_karma': 0,
      'day_streak': 0,
      'reading_lists': [
        {
          'name': 'Currently Reading',
          'story_count': 2,
          'cover_path':
              'story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg',
        },
        {
          'name': 'Archived / Finished Books',
          'story_count': 0,
          'cover_path':
              'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg',
        },
      ],
    },
    'achievements': [
      {
        'group_name': 'Lifetime Reviews Given',
        'items': [
          {
            'title': 'Reviewer-in-Training',
            'subtitle': '0/1 Reviews Left',
            'progress_label': '0/1 Reviews Left',
            'badge_value': '1',
            'style': 'silver',
          },
          {
            'title': 'Community Voice',
            'subtitle': '0/2 Reviews Left',
            'progress_label': '0/2 Reviews Left',
            'badge_value': '2',
            'style': 'silver',
          },
          {
            'title': 'Story Critic',
            'subtitle': '0/3 Reviews Left',
            'progress_label': '0/3 Reviews Left',
            'badge_value': '3',
            'style': 'silver',
          },
        ],
      },
      {
        'group_name': 'Lifetime Words Published',
        'items': [
          {
            'title': 'Ink Sprout',
            'subtitle': '0/1000 Words Published',
            'progress_label': '0/1000 Words Published',
            'badge_value': '1000',
            'style': 'dark',
          },
          {
            'title': 'Wordsmith',
            'subtitle': '0/5000 Words Published',
            'progress_label': '0/5000 Words Published',
            'badge_value': '5000',
            'style': 'dark',
          },
          {
            'title': 'Pen Prodigy',
            'subtitle': '0/10000 Words Published',
            'progress_label': '0/10000 Words Published',
            'badge_value': '10000',
            'style': 'dark',
          },
        ],
      },
      {
        'group_name': 'Lifetime Reading',
        'items': [
          {
            'title': 'Page Flipper',
            'subtitle': '0/2 Chapters Read',
            'progress_label': '0/2 Chapters Read',
            'badge_value': '2',
            'style': 'ink',
          },
          {
            'title': 'Book Explorer',
            'subtitle': '0/5 Chapters Read',
            'progress_label': '0/5 Chapters Read',
            'badge_value': '5',
            'style': 'ink',
          },
          {
            'title': 'Reading Enthusiast',
            'subtitle': '0/10 Chapters Read',
            'progress_label': '0/10 Chapters Read',
            'badge_value': '10',
            'style': 'ink',
          },
        ],
      },
    ],
  };
}
