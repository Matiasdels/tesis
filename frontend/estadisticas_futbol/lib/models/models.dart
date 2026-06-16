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

  // Campos adicionales para gestión de jugadores (alta/edición vía API)
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String? dni;
  final String? dominantFoot;
  final int? categoryId;
  final String? categoryName;
  final bool active;

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
    this.firstName = '',
    this.lastName = '',
    this.birthDate,
    this.dni,
    this.dominantFoot,
    this.categoryId,
    this.categoryName,
    this.active = true,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return name.substring(0, 2).toUpperCase();
  }

  bool get isAvailable => status == 'available';

  /// Indica si el jugador cuenta con datos de rendimiento registrados.
  bool get hasPerformanceData => stats.isNotEmpty;

  /// 'Disponible'|'Lesionado'|'Suspendido' (backend) -> 'available'|'injured'|'suspended' (UI)
  static String statusFromApi(String estado) {
    switch (estado) {
      case 'Lesionado':
        return 'injured';
      case 'Suspendido':
        return 'suspended';
      default:
        return 'available';
    }
  }

  /// 'available'|'injured'|'suspended' (UI) -> 'Disponible'|'Lesionado'|'Suspendido' (backend)
  static String statusToApi(String status) {
    switch (status) {
      case 'injured':
        return 'Lesionado';
      case 'suspended':
        return 'Suspendido';
      default:
        return 'Disponible';
    }
  }

  static int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  factory PlayerModel.fromApi(Map<String, dynamic> json) {
    final firstName = json['nombre'] as String? ?? '';
    final lastName = json['apellido'] as String? ?? '';
    final birthDate = json['fechaNacimiento'] != null
        ? DateTime.tryParse(json['fechaNacimiento'] as String)
        : null;

    return PlayerModel(
      id: (json['jugadorId'] as num).toString(),
      name: '$firstName $lastName'.trim(),
      shortName: '$firstName $lastName'.trim(),
      position: json['posicionPrincipal'] as String? ?? '',
      number: json['numeroCamiseta'] as int? ?? 0,
      age: birthDate != null ? _calculateAge(birthDate) : 0,
      nationality: json['nacionalidad'] as String? ?? '',
      heightCm: (json['alturaCm'] as num?)?.toDouble() ?? 0,
      weightKg: (json['pesoKg'] as num?)?.toDouble() ?? 0,
      status: statusFromApi(json['estado'] as String? ?? 'Disponible'),
      rating: 0,
      matchesPlayed: 0,
      stats: const {},
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      dni: json['dni'] as String?,
      dominantFoot: json['piernaHabil'] as String?,
      categoryId: json['categoriaId'] as int?,
      categoryName: json['categoriaNombre'] as String?,
      active: json['activo'] as bool? ?? true,
    );
  }

  PlayerModel copyWith({String? status, bool? active}) {
    return PlayerModel(
      id: id,
      name: name,
      shortName: shortName,
      position: position,
      number: number,
      age: age,
      nationality: nationality,
      heightCm: heightCm,
      weightKg: weightKg,
      status: status ?? this.status,
      rating: rating,
      matchesPlayed: matchesPlayed,
      stats: stats,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      dni: dni,
      dominantFoot: dominantFoot,
      categoryId: categoryId,
      categoryName: categoryName,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'nombre': firstName,
      'apellido': lastName,
      'fechaNacimiento': birthDate != null
          ? '${birthDate!.year.toString().padLeft(4, '0')}-'
              '${birthDate!.month.toString().padLeft(2, '0')}-'
              '${birthDate!.day.toString().padLeft(2, '0')}'
          : null,
      'nacionalidad': nationality.isEmpty ? null : nationality,
      'dni': dni,
      'posicionPrincipal': position.isEmpty ? null : position,
      'numeroCamiseta': number == 0 ? null : number,
      'alturaCm': heightCm == 0 ? null : heightCm,
      'pesoKg': weightKg == 0 ? null : weightKg,
      'piernaHabil': dominantFoot,
      'estado': statusToApi(status),
      'categoriaId': categoryId,
      'activo': active,
    };
  }
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

class CategoryModel {
  final int id;
  final String name;

  const CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromApi(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['categoriaId'] as int,
      name: json['nombre'] as String,
    );
  }
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
