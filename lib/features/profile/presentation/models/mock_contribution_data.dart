import 'dart:math';

class MockContributionData {
  const MockContributionData({
    required this.helpedCount,
    required this.confirmedReports,
    required this.pendingReports,
    required this.helperResponses,
  });

  final int helpedCount;
  final int confirmedReports;
  final int pendingReports;
  final int helperResponses;

  factory MockContributionData.random({Random? random}) {
    final source = random ?? Random();

    return MockContributionData(
      helpedCount: source.nextInt(96) + 25,
      confirmedReports: source.nextInt(14) + 2,
      pendingReports: source.nextInt(7),
      helperResponses: source.nextInt(9),
    );
  }
}
