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

class PartidoModel {
  final int id;
  final int categoriaId;
  final String? categoriaNombre;
  final String rival;
  final bool esLocal;
  final DateTime fecha;
  final String tipoCompeticion;
  final String? lugar;
  final String estado;
  final int? golesEquipo;
  final int? golesRival;
  final int? minutoActual;

  const PartidoModel({
    required this.id,
    required this.categoriaId,
    this.categoriaNombre,
    required this.rival,
    required this.esLocal,
    required this.fecha,
    required this.tipoCompeticion,
    this.lugar,
    required this.estado,
    this.golesEquipo,
    this.golesRival,
    this.minutoActual,
  });

  bool get isProgramado => estado == 'Programado';
  bool get isEnJuego => estado == 'EnJuego';
  bool get isFinished => estado == 'Finalizado';

  factory PartidoModel.fromApi(Map<String, dynamic> json) => PartidoModel(
        id: json['partidoId'] as int,
        categoriaId: json['categoriaId'] as int,
        categoriaNombre: json['categoriaNombre'] as String?,
        rival: json['rival'] as String,
        esLocal: json['esLocal'] as bool,
        fecha: DateTime.parse(json['fecha'] as String),
        tipoCompeticion: json['tipoCompeticion'] as String,
        lugar: json['lugar'] as String?,
        estado: json['estado'] as String,
        golesEquipo: json['golesEquipo'] as int?,
        golesRival: json['golesRival'] as int?,
        minutoActual: json['minutoActual'] as int?,
      );

  Map<String, dynamic> toApiJson() => {
        'categoriaId': categoriaId,
        'rival': rival,
        'esLocal': esLocal,
        'fecha': fecha.toUtc().toIso8601String(),
        'tipoCompeticion': tipoCompeticion,
        'lugar': lugar,
        'estado': estado,
      };
}

class AlineacionEntradaModel {
  final int alineacionId;
  final int jugadorId;
  final String nombreJugador;
  final bool esTitular;
  final String? posicionAsignada;
  final int? numeroCamiseta;

  const AlineacionEntradaModel({
    required this.alineacionId,
    required this.jugadorId,
    required this.nombreJugador,
    required this.esTitular,
    this.posicionAsignada,
    this.numeroCamiseta,
  });

  factory AlineacionEntradaModel.fromApi(Map<String, dynamic> json) =>
      AlineacionEntradaModel(
        alineacionId: json['alineacionId'] as int,
        jugadorId: json['jugadorId'] as int,
        nombreJugador: json['nombreJugador'] as String,
        esTitular: json['esTitular'] as bool,
        posicionAsignada: json['posicionAsignada'] as String?,
        numeroCamiseta: json['numeroCamiseta'] as int?,
      );
}

class EventoPartidoModel {
  final int eventoId;
  final int partidoId;
  final int? jugadorId;
  final String? nombreJugador;
  final int tipoEventoId;
  final String tipoEventoNombre;
  final int minuto;
  final double pitchX;
  final double pitchY;
  final String? observacion;

  const EventoPartidoModel({
    required this.eventoId,
    required this.partidoId,
    this.jugadorId,
    this.nombreJugador,
    required this.tipoEventoId,
    required this.tipoEventoNombre,
    required this.minuto,
    required this.pitchX,
    required this.pitchY,
    this.observacion,
  });

  factory EventoPartidoModel.fromApi(Map<String, dynamic> json) =>
      EventoPartidoModel(
        eventoId: json['eventoId'] as int,
        partidoId: json['partidoId'] as int,
        jugadorId: json['jugadorId'] as int?,
        nombreJugador: json['nombreJugador'] as String?,
        tipoEventoId: json['tipoEventoId'] as int,
        tipoEventoNombre: json['tipoEventoNombre'] as String,
        minuto: json['minuto'] as int,
        pitchX: (json['pitchX'] as num?)?.toDouble() ?? 0.5,
        pitchY: (json['pitchY'] as num?)?.toDouble() ?? 0.5,
        observacion: json['observacion'] as String?,
      );
}

class TipoEventoModel {
  final int tipoEventoId;
  final String nombre;

  const TipoEventoModel({required this.tipoEventoId, required this.nombre});

  factory TipoEventoModel.fromApi(Map<String, dynamic> json) => TipoEventoModel(
        tipoEventoId: json['tipoEventoId'] as int,
        nombre: json['nombre'] as String,
      );
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
