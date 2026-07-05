import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import 'news_models.dart';
import 'news_service.dart';

class NewsSection extends StatefulWidget {
  const NewsSection({required this.token, super.key});

  final String token;

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  final NewsService _service = NewsService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isDetailsLoading = false;
  String? _errorMessage;
  String? _detailsErrorMessage;

  List<NewsArticleItem> _articles = const [];
  NewsArticleDetails? _selectedDetails;
  int? _selectedArticleId;
  bool? _isPublishedFilter;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final response = await _service.fetchArticles(
        token: widget.token,
        searchText: _searchController.text,
        isPublished: _isPublishedFilter,
      );

      _articles = response.items;

      if (_articles.isEmpty) {
        _selectedArticleId = null;
        _selectedDetails = null;
        _detailsErrorMessage = null;
      } else {
        final selectedExists = _selectedArticleId != null &&
            _articles.any((item) => item.id == _selectedArticleId);
        final nextId =
            selectedExists ? _selectedArticleId! : _articles.first.id;
        await _loadArticleDetails(nextId, showLoader: false);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'News modul trenutno nije dostupan. Pokusajte ponovo.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadArticleDetails(
    int id, {
    bool showLoader = true,
  }) async {
    if (showLoader) {
      setState(() {
        _isDetailsLoading = true;
        _detailsErrorMessage = null;
      });
    } else {
      setState(() {
        _detailsErrorMessage = null;
      });
    }

    try {
      final details = await _service.getArticle(
        token: widget.token,
        id: id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedArticleId = id;
        _selectedDetails = details;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailsErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailsErrorMessage = 'Detalji vijesti trenutno nisu dostupni.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDetailsLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadArticles();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openArticleDialog({NewsArticleDetails? initial}) async {
    final value = await showDialog<_NewsArticleFormValue>(
      context: context,
      builder: (context) => _NewsArticleDialog(initial: initial),
    );

    if (value == null) {
      return;
    }

    try {
      final updated = initial == null
          ? await _service.createArticle(
              token: widget.token,
              title: value.title,
              content: value.content,
              imageUrl: value.imageUrl,
              isPublished: value.isPublished,
            )
          : await _service.updateArticle(
              token: widget.token,
              id: initial.id,
              title: value.title,
              content: value.content,
              imageUrl: value.imageUrl,
              isPublished: value.isPublished,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedArticleId = updated.id;
        _selectedDetails = updated;
      });

      await _loadArticles(showLoader: false);
      _showMessage(
        initial == null
            ? 'Vijest je uspjesno dodana.'
            : 'Vijest je uspjesno azurirana.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Spremanje vijesti trenutno nije dostupno.');
    }
  }

  Future<void> _editSelectedArticle() async {
    final details = _selectedDetails;
    if (details == null) {
      return;
    }

    await _openArticleDialog(initial: details);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildListContent(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildDetailsContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _loadArticles(),
                decoration: const InputDecoration(
                  labelText: 'Pretraga vijesti',
                  hintText: 'Naslov ili dio sadrzaja',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openArticleDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova vijest'),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Osvjezi',
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 180,
            child: DropdownButtonFormField<bool?>(
              key: ValueKey<bool?>(_isPublishedFilter),
              initialValue: _isPublishedFilter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Sve vijesti'),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text('Published'),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text('Draft'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _isPublishedFilter = value;
                });
                _loadArticles();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Nije moguce ucitati vijesti',
        message: _errorMessage!,
      );
    }

    if (_articles.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.article_outlined,
        title: 'Nema vijesti za prikaz',
        message: 'Pokusajte druge filtere ili dodajte novu vijest.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vijesti (${_articles.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Naslov')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Published')),
                  DataColumn(label: Text('Image URL')),
                ],
                rows: _articles.map((item) {
                  final isSelected = item.id == _selectedArticleId;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => _loadArticleDetails(item.id),
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(item.isPublished ? 'Published' : 'Draft')),
                      DataCell(Text(_formatDateTime(item.publishedAtUtc))),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            item.imageUrl.trim().isEmpty ? '-' : item.imageUrl,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsContent() {
    if (_isDetailsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailsErrorMessage != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded,
        title: 'Detalji nisu dostupni',
        message: _detailsErrorMessage!,
      );
    }

    final details = _selectedDetails;
    if (details == null) {
      return const _CenteredMessage(
        icon: Icons.touch_app_rounded,
        title: 'Odaberite vijest',
        message: 'Kliknite red iz tabele da otvorite detalje i uredjivanje.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Published: ${_formatDateTime(details.publishedAtUtc)}',
                  ),
                ],
              ),
            ),
            _StatusBadge(label: details.isPublished ? 'Published' : 'Draft'),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _editSelectedArticle,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Uredi vijest'),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              _DetailsBlock(
                title: 'Status i timeline',
                rows: [
                  _DetailsRow(
                    'Status',
                    details.isPublished ? 'Published' : 'Draft',
                  ),
                  _DetailsRow(
                    'Published at',
                    _formatDateTime(details.publishedAtUtc),
                  ),
                  _DetailsRow(
                    'Created at',
                    _formatDateTime(details.createdAtUtc),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Slika',
                rows: [
                  _DetailsRow(
                    'Image URL',
                    details.imageUrl.trim().isEmpty ? '-' : details.imageUrl,
                  ),
                ],
                child: _NewsImagePreview(imageUrl: details.imageUrl),
              ),
              const SizedBox(height: 16),
              _DetailsBlock(
                title: 'Sadrzaj',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(details.content),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}

class _NewsImagePreview extends StatelessWidget {
  const _NewsImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: Image.network(
            trimmed,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Text('Preview slike nije dostupan.'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({
    required this.title,
    this.rows,
    this.child,
  });

  final String title;
  final List<_DetailsRow>? rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (rows != null)
          ...rows!.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(row.value)),
                ],
              ),
            ),
          ),
        ...switch (child) {
          final value? => [value],
          null => const <Widget>[],
        },
      ],
    );
  }
}

class _DetailsRow {
  const _DetailsRow(this.label, this.value);

  final String label;
  final String value;
}

class _NewsArticleDialog extends StatefulWidget {
  const _NewsArticleDialog({this.initial});

  final NewsArticleDetails? initial;

  @override
  State<_NewsArticleDialog> createState() => _NewsArticleDialogState();
}

class _NewsArticleDialogState extends State<_NewsArticleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _imageUrlController;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _contentController = TextEditingController(
      text: widget.initial?.content ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.initial?.imageUrl ?? '',
    );
    _isPublished = widget.initial?.isPublished ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? 'Uredi vijest' : 'Nova vijest'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Naslov'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Naslov je obavezan.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Image URL je obavezan.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 14,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Sadrzaj vijesti',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Sadrzaj vijesti je obavezan.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPublished,
                  onChanged: (value) {
                    setState(() {
                      _isPublished = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  subtitle: const Text(
                    'Objavljene vijesti su odmah vidljive korisnicima u mobile aplikaciji.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              _NewsArticleFormValue(
                title: _titleController.text.trim(),
                content: _contentController.text.trim(),
                imageUrl: _imageUrlController.text.trim(),
                isPublished: _isPublished,
              ),
            );
          },
          child: const Text('Sacuvaj'),
        ),
      ],
    );
  }
}

class _NewsArticleFormValue {
  const _NewsArticleFormValue({
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.isPublished,
  });

  final String title;
  final String content;
  final String imageUrl;
  final bool isPublished;
}
