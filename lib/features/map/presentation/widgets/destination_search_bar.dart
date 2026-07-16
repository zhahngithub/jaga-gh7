import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/geocoding_service.dart';

// We change this to a ConsumerWidget so it can talk to Riverpod
class DestinationSearchBar extends ConsumerStatefulWidget {
  const DestinationSearchBar({super.key});

  @override
  ConsumerState<DestinationSearchBar> createState() => _DestinationSearchBarState();
}

class _DestinationSearchBarState extends ConsumerState<DestinationSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true; // Show a loading spinner
    });

    // 1. Ask LocationIQ for the coordinates
    final result = await GeocodingService.searchDestination(query);

    // 2. If we found a location, update the Riverpod bulletin board!
    if (result != null) {
      ref.read(destinationProvider.notifier).updateLocation(result);
    } else {
      // Optional: Show a snackbar if the place wasn't found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination not found. Try a different name.')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              decoration: const InputDecoration(
                hintText: 'Search destination...',
                border: InputBorder.none,
              ),
              // 3. Trigger the search when the user hits "Done/Enter" on the keyboard
              onSubmitted: _handleSearch, 
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
    );
  }
}