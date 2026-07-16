import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/geocoding_service.dart';

class DestinationSearchBar extends ConsumerStatefulWidget {
  const DestinationSearchBar({super.key});

  @override
  ConsumerState<DestinationSearchBar> createState() => _DestinationSearchBarState();
}

class _DestinationSearchBarState extends ConsumerState<DestinationSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  
  // nyimpen hasil search
  List<LocationResult> _searchResults = [];

  // hit api pas enter
  Future<void> _handleSearch(String query) async {
    // kalau kosong reset
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = []; 
    });

    // cari top 5
    final results = await GeocodingService.searchDestinations(query);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });

    if (results.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi tidak ditemukan')),
      );
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
    
    // tutup keyboard
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  decoration: const InputDecoration(
                    hintText: 'Cari tujuan...',
                    border: InputBorder.none,
                  ),
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
        ),
        
        // dropdown result list
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            // tetep pake container buat margin sama bates tinggi
            constraints: const BoxConstraints(maxHeight: 250), 
            // pake material biar listtile bisa nampilin efek klik
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              elevation: 4.0, // ganti boxshadow pake elevation dari material
              clipBehavior: Clip.antiAlias, // biar efek klik ga bocor keluar sudut melengkung
              child: ListView.separated(
                shrinkWrap: true, 
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.redAccent),
                    title: Text(
                      result.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _selectLocation(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}