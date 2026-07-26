class ResumenGlobalModel {
  final int partidosJugados;
  final int victorias;
  final int empates;
  final int derrotas;
  final int golesFavor;
  final int golesContra;
  final int diferenciaGoles;
  final double porcentajeVictorias;
  final List<RendimientoRecienteItem> rendimientoReciente;
  final List<TopJugadorItem> topGoleadores;
  final List<TopJugadorItem> topAsistidores;

  const ResumenGlobalModel({
    required this.partidosJugados,
    required this.victorias,
    required this.empates,
    required this.derrotas,
    required this.golesFavor,
    required this.golesContra,
    required this.diferenciaGoles,
    required this.porcentajeVictorias,
    required this.rendimientoReciente,
    required this.topGoleadores,
    required this.topAsistidores,
  });

  factory ResumenGlobalModel.fromApi(Map<String, dynamic> json) =>
      ResumenGlobalModel(
        partidosJugados:     (json['partidosJugados']     as num).toInt(),
        victorias:           (json['victorias']           as num).toInt(),
        empates:             (json['empates']             as num).toInt(),
        derrotas:            (json['derrotas']            as num).toInt(),
        golesFavor:          (json['golesFavor']          as num).toInt(),
        golesContra:         (json['golesContra']         as num).toInt(),
        diferenciaGoles:     (json['diferenciaGoles']     as num).toInt(),
        porcentajeVictorias: (json['porcentajeVictorias'] as num).toDouble(),
        rendimientoReciente: (json['rendimientoReciente'] as List<dynamic>)
            .map((e) => RendimientoRecienteItem.fromApi(e as Map<String, dynamic>))
            .toList(),
        topGoleadores: (json['topGoleadores'] as List<dynamic>)
            .map((e) => TopJugadorItem.fromApi(e as Map<String, dynamic>))
            .toList(),
        topAsistidores: (json['topAsistidores'] as List<dynamic>)
            .map((e) => TopJugadorItem.fromApi(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'partidosJugados':     partidosJugados,
        'victorias':           victorias,
        'empates':             empates,
        'derrotas':            derrotas,
        'golesFavor':          golesFavor,
        'golesContra':         golesContra,
        'diferenciaGoles':     diferenciaGoles,
        'porcentajeVictorias': porcentajeVictorias,
        'rendimientoReciente': rendimientoReciente.map((e) => e.toJson()).toList(),
        'topGoleadores':  topGoleadores.map((e) => e.toJson()).toList(),
        'topAsistidores': topAsistidores.map((e) => e.toJson()).toList(),
      };
}

class RendimientoRecienteItem {
  final int      partidoId;
  final String   rival;
  final int      golesFavor;
  final int      golesContra;
  final String   resultado; // "G" | "E" | "P"
  final DateTime fecha;

  const RendimientoRecienteItem({
    required this.partidoId,
    required this.rival,
    required this.golesFavor,
    required this.golesContra,
    required this.resultado,
    required this.fecha,
  });

  factory RendimientoRecienteItem.fromApi(Map<String, dynamic> json) =>
      RendimientoRecienteItem(
        partidoId:  (json['partidoId']  as num).toInt(),
        rival:       json['rival']       as String,
        golesFavor:  (json['golesFavor']  as num).toInt(),
        golesContra: (json['golesContra'] as num).toInt(),
        resultado:   json['resultado']    as String,
        fecha:       DateTime.parse(json['fecha'] as String),
      );

  Map<String, dynamic> toJson() => {
        'partidoId':  partidoId,
        'rival':       rival,
        'golesFavor':  golesFavor,
        'golesContra': golesContra,
        'resultado':   resultado,
        'fecha':       fecha.toIso8601String(),
      };
}

class TopJugadorItem {
  final int    jugadorId;
  final String nombre;
  final int    cantidad;

  const TopJugadorItem({
    required this.jugadorId,
    required this.nombre,
    required this.cantidad,
  });

  factory TopJugadorItem.fromApi(Map<String, dynamic> json) => TopJugadorItem(
        jugadorId: (json['jugadorId'] as num).toInt(),
        nombre:     json['nombre']    as String,
        cantidad:   (json['cantidad'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'jugadorId': jugadorId,
        'nombre':    nombre,
        'cantidad':  cantidad,
      };
}
