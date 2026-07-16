import 'package:flutter/material.dart';

import '../../data/models/report.dart';

Icon reportMarkerIcon(Report report, {double size = 36}) {
  switch (report.category) {
    case 'police_station':
      return Icon(Icons.local_police, color: Colors.blue, size: size);
    case 'cctv':
      return Icon(Icons.videocam, color: Colors.blue, size: size);
    case 'harassment':
      return Icon(Icons.warning, color: Colors.red, size: size);
    case 'poor_lighting':
      return Icon(Icons.lightbulb_outline, color: Colors.orange, size: size);
    case 'damaged_road':
      return Icon(Icons.add_road, color: Colors.red, size: size);
  }

  final isProtective = report.reportType == 'protective';
  return Icon(
    isProtective ? Icons.shield : Icons.warning,
    color: isProtective ? Colors.blue : Colors.red,
    size: size,
  );
}
