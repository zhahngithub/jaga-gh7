enum ReportPolarity { hazard, protective }

class SafetyCategory {
  const SafetyCategory({
    required this.id,
    required this.polarity,
    required this.label,
    required this.sigmaMeters,
    required this.halfLifeHours,
    required this.ttlHours,
  });

  final String id;
  final ReportPolarity polarity;
  final String label;
  final double sigmaMeters;
  final double halfLifeHours;
  final double ttlHours;
}

const Map<String, SafetyCategory> safetyCategories = {
  'poor_lighting': SafetyCategory(
    id: 'poor_lighting',
    polarity: ReportPolarity.hazard,
    label: 'Poor lighting',
    sigmaMeters: 80,
    halfLifeHours: 2160,
    ttlHours: 4320,
  ),
  'damaged_road': SafetyCategory(
    id: 'damaged_road',
    polarity: ReportPolarity.hazard,
    label: 'Damaged road or pavement',
    sigmaMeters: 60,
    halfLifeHours: 1440,
    ttlHours: 2880,
  ),
  'accident_prone': SafetyCategory(
    id: 'accident_prone',
    polarity: ReportPolarity.hazard,
    label: 'Accident-prone area',
    sigmaMeters: 100,
    halfLifeHours: 2160,
    ttlHours: 4320,
  ),
  'suspicious_activity': SafetyCategory(
    id: 'suspicious_activity',
    polarity: ReportPolarity.hazard,
    label: 'Suspicious activity',
    sigmaMeters: 120,
    halfLifeHours: 72,
    ttlHours: 168,
  ),
  'theft': SafetyCategory(
    id: 'theft',
    polarity: ReportPolarity.hazard,
    label: 'Theft (pencurian)',
    sigmaMeters: 150,
    halfLifeHours: 336,
    ttlHours: 1440,
  ),
  'robbery': SafetyCategory(
    id: 'robbery',
    polarity: ReportPolarity.hazard,
    label: 'Robbery / mugging (begal)',
    sigmaMeters: 180,
    halfLifeHours: 336,
    ttlHours: 1440,
  ),
  'harassment': SafetyCategory(
    id: 'harassment',
    polarity: ReportPolarity.hazard,
    label: 'Harassment',
    sigmaMeters: 150,
    halfLifeHours: 336,
    ttlHours: 1440,
  ),
  'flooding_obstruction': SafetyCategory(
    id: 'flooding_obstruction',
    polarity: ReportPolarity.hazard,
    label: 'Flooding or obstruction',
    sigmaMeters: 60,
    halfLifeHours: 6,
    ttlHours: 24,
  ),
  'other_hazard': SafetyCategory(
    id: 'other_hazard',
    polarity: ReportPolarity.hazard,
    label: 'Other hazard',
    sigmaMeters: 100,
    halfLifeHours: 168,
    ttlHours: 336,
  ),
  'cctv': SafetyCategory(
    id: 'cctv',
    polarity: ReportPolarity.protective,
    label: 'CCTV camera',
    sigmaMeters: 60,
    halfLifeHours: 8760,
    ttlHours: 17520,
  ),
  'police_station': SafetyCategory(
    id: 'police_station',
    polarity: ReportPolarity.protective,
    label: 'Police station',
    sigmaMeters: 250,
    halfLifeHours: 8760,
    ttlHours: 17520,
  ),
  'security_post': SafetyCategory(
    id: 'security_post',
    polarity: ReportPolarity.protective,
    label: 'Security post',
    sigmaMeters: 120,
    halfLifeHours: 8760,
    ttlHours: 17520,
  ),
  'safety_device': SafetyCategory(
    id: 'safety_device',
    polarity: ReportPolarity.protective,
    label: 'Safety device (alarm, emergency button)',
    sigmaMeters: 80,
    halfLifeHours: 8760,
    ttlHours: 17520,
  ),
};
