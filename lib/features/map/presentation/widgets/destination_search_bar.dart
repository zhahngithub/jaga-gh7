import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/geocoding_service.dart';

final searchResultsVisibleProvider =
    NotifierProvider<SearchResultsVisibleNotifier, bool>(
      SearchResultsVisibleNotifier.new,
    );

class SearchResultsVisibleNotifier extends Notifier<bool> {
  Timer? _debounceTimer;
  String? _lastSearchedQuery;

  @override
  bool build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return false;
  }

  void debounceSearch(String query, void Function(String) onSearch) {
    _debounceTimer?.cancel();

    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return;

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      onSearch(normalizedQuery);
    });
  }

  bool shouldSearch(String query) {
    if (query.isEmpty || query == _lastSearchedQuery) return false;

    _lastSearchedQuery = query;
    return true;
  }

  void cancelPendingSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void resetLastSearchedQuery() => _lastSearchedQuery = '';

  void show() => state = true;

  void hide() {
    cancelPendingSearch();
    state = false;
  }
}

class DestinationSearchBar extends ConsumerStatefulWidget {
  const DestinationSearchBar({super.key});

  @override
  ConsumerState<DestinationSearchBar> createState() =>
      _DestinationSearchBarState();
}

class _DestinationSearchBarState extends ConsumerState<DestinationSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // nyimpen hasil search
  List<LocationResult> _searchResults = [];

  // hit api pas enter
  Future<void> _handleSearch(String query) async {
    if (!mounted) return;

    final normalizedQuery = query.trim();
    final searchController = ref.read(searchResultsVisibleProvider.notifier);

    // kalau kosong reset
    if (normalizedQuery.isEmpty) {
      setState(() => _searchResults = []);
      searchController.resetLastSearchedQuery();
      searchController.hide();
      return;
    }

    searchController.show();
    if (!searchController.shouldSearch(normalizedQuery)) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    // cari top 5
    final results = await GeocodingService.searchDestinations(normalizedQuery);

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });

    if (results.isEmpty && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lokasi tidak ditemukan')));
    }
  }

  // pas user klik salah satu lokasi di list
  void _selectLocation(LocationResult result) {
    // update state provider ke koordinat ini
    ref.read(destinationProvider.notifier).updateLocation(result.coordinates);

    // update text di search bar ambil nama depan aja
    _searchController.text = result.displayName.split(',')[0];

    // tutup dropdown
    setState(() {
      _searchResults = [];
    });
    ref.read(searchResultsVisibleProvider.notifier).hide();

    // tutup keyboard
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchResults = [];
      _isLoading = false;
    });

    final searchController = ref.read(searchResultsVisibleProvider.notifier);
    searchController.resetLastSearchedQuery();
    searchController.hide();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSearchResults = ref.watch(searchResultsVisibleProvider);

    return Column(
      children: [
        // bungkus search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(27.0),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    hintText: 'Cari tujuan...',
                    border: InputBorder.none,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        if (value.text.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                        );
                      },
                    ),
                  ),
                  onChanged: (query) {
                    final searchController = ref.read(
                      searchResultsVisibleProvider.notifier,
                    );

                    if (query.trim().isEmpty) {
                      setState(() => _searchResults = []);
                      searchController.resetLastSearchedQuery();
                      searchController.hide();
                      return;
                    }

                    searchController.debounceSearch(query, _handleSearch);
                  },
                  onSubmitted: (query) {
                    ref
                        .read(searchResultsVisibleProvider.notifier)
                        .cancelPendingSearch();
                    _handleSearch(query);
                  },
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),

        // dropdown result list
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return ClipRect(
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: showSearchResults && _searchResults.isNotEmpty
              ? Container(
                  key: const ValueKey('search-results'),
                  margin: const EdgeInsets.only(top: 8.0),
                  // tetep pake container buat margin sama bates tinggi
                  constraints: const BoxConstraints(maxHeight: 250),
                  // pake material biar listtile bisa nampilin efek klik
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    elevation: 4.0,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                          ),
                          title: Text(
                            result.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () => _selectLocation(result),
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('search-results-hidden')),
        ),
      ],
    );
  }
}
