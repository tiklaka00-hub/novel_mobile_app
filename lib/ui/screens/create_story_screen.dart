import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, required this.apiService, this.story});

  final ApiService apiService;
  final Map<String, dynamic>? story; // non-null when editing

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _authorController = TextEditingController();
  final _genreController = TextEditingController();
  final _tagsController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;
  String _coverPath = '';

  bool get _isEditing => widget.story != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.story!['title']?.toString() ?? '';
      _summaryController.text = widget.story!['description']?.toString() ?? '';
      _authorController.text = widget.story!['author']?.toString() ?? '';
      _genreController.text = widget.story!['genre']?.toString() ?? '';
      _coverPath = widget.story!['cover_path']?.toString() ?? '';
      _tagsController.text =
          (widget.story!['tags'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .join(', ') ??
          '';
    }
  }

  Future<void> _pickCover() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final payload = await widget.apiService.uploadWriterImage(
      bytes,
      picked.name,
    );
    final path = payload['path']?.toString() ?? '';
    if (!mounted || path.isEmpty) {
      return;
    }

    setState(() => _coverPath = path);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cover image uploaded')));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final author = _authorController.text.trim();
    final genre = _genreController.text.trim();
    final tagsText = _tagsController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'title': title,
        'description': summary,
        'author': author.isEmpty ? 'Me' : author,
        'genre': genre.isEmpty ? 'Fiction' : genre,
        'cover_path': _coverPath,
        'tags': tagsText.isEmpty
            ? <String>[]
            : tagsText
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList(),
      };

      if (_isEditing) {
        await widget.apiService.updateWriterStory(
          widget.story!['id'] as int,
          payload,
        );
      } else {
        await widget.apiService.createWriterStory(payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving story: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Story' : 'Create Story'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Skip',
              style: TextStyle(color: AppTheme.brand, fontSize: 15),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Cover image
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                width: 120,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF),
                  borderRadius: BorderRadius.circular(8),
                  image: _coverPath.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(
                            widget.apiService.resolveAssetUrl(_coverPath),
                          ),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _coverPath.isEmpty
                    ? const Icon(
                        Icons.book_rounded,
                        color: Colors.white70,
                        size: 48,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickCover,
              child: const Text(
                'Change Cover',
                style: TextStyle(color: AppTheme.brand, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Title field
            _LabeledField(
              label: 'TITLE',
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Enter title here',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Author field
            _LabeledField(
              label: 'AUTHOR',
              child: TextField(
                controller: _authorController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Your pen name',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Genre field
            _LabeledField(
              label: 'GENRE',
              child: TextField(
                controller: _genreController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'e.g. Romance, Fantasy...',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Tags field
            _LabeledField(
              label: 'TAGS',
              child: TextField(
                controller: _tagsController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Comma-separated tags, e.g. romance, mystery',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Summary field
            _LabeledField(
              label: 'SUMMARY',
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _summaryController,
                builder: (context, value, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _summaryController,
                        maxLines: 6,
                        maxLength: 640,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText:
                              'Enter summary here - a longer description of what your story is about',
                          hintStyle: TextStyle(color: AppTheme.muted),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                      Text(
                        '${value.text.length}/640',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Create Story',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
