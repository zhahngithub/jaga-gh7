import 'package:flutter/material.dart';

class DestinationSearchBar extends StatelessWidget {
  const DestinationSearchBar({super.key});

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
      child: const Row(
        children: [
          Icon(Icons.search, color: Colors.grey),
          SizedBox(width: 12),
          Text(
            'Search destination...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}