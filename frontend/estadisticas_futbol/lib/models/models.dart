/// Core domain models — UI only, no persistence logic
library;

class PlayerModel {
  final String id;
  final String name;
  final String shortName;
  final String position;
  final int number;
  final int age;
  final String nationality;
  final double heightCm;
  final double weightKg;
  final String status; // 'available' | 'injured' | 'suspended'
  final double rating;
  final int matchesPlayed;
  final Map<String, dynamic> stats;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.position,
    required this.number,
    required this.age,
    required this.nationality,
    required this.heightCm,
    required this.weightKg,
    required this.status,
    required this.rating,
    required this.matchesPlayed,
    required this.stats,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return name.substring(0, 2).toUpperCase();
  }

  bool get isAvailable => status == 'available';
}

class MatchModel {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String homeAbbr;
  final String awayAbbr;
  final int homeScore;
  final int awayScore;
  final DateTime date;
  final String venue;
  final String status; // 'upcoming' | 'live' | 'finished'
  final int? minute;

  const MatchModel({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeAbbr,
    required this.awayAbbr,
    required this.homeScore,
    required this.awayScore,
    required this.date,
    required this.venue,
    required this.status,
    this.minute,
  });

  bool get isLive => status == 'live';
  bool get isFinished => status == 'finished';
}

class MatchEventModel {
  final String id;
  final String type; // EventTypes constant
  final String playerId;
  final String playerName;
  final int minute;
  final double pitchX; // 0.0–1.0 normalised
  final double pitchY; // 0.0–1.0 normalised

  const MatchEventModel({
    required this.id,
    required this.type,
    required this.playerId,
    required this.playerName,
    required this.minute,
    required this.pitchX,
    required this.pitchY,
  });
}

class TrainingSessionModel {
  final String id;
  final DateTime date;
  final String title;
  final String type; // 'technical' | 'tactical' | 'physical' | 'recovery'
  final int durationMin;
  final double avgRpe;
  final int attendance;

  const TrainingSessionModel({
    required this.id,
    required this.date,
    required this.title,
    required this.type,
    required this.durationMin,
    required this.avgRpe,
    required this.attendance,
  });
}

class ObservationModel {
  final String id;
  final String playerId;
  final String playerName;
  final String authorName;
  final String authorRole;
  final String tag; // 'positive' | 'improve' | 'physical' | 'tactical'
  final String text;
  final DateTime date;

  const ObservationModel({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.authorName,
    required this.authorRole,
    required this.tag,
    required this.text,
    required this.date,
  });
}

class StatCardData {
  final String label;
  final String value;
  final String? delta;
  final bool? deltaPositive;
  final String? iconCode;

  const StatCardData({
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive,
    this.iconCode,
  });
}
