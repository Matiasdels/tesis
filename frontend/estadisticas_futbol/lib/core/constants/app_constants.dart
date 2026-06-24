abstract class AppConstants {
  // Navigation route names
  static const String routeSplash = '/splash';
  static const String routeLogin = '/login';
  static const String routeDashboard = '/';
  static const String routePlayers = '/players';
  static const String routePlayerCreate = '/players/new';
  static const String routePlayerDetail = '/players/:id';
  static const String routePlayerEdit = '/players/:id/edit';
  static const String routeMatches = '/matches';
  static const String routeMatchCreate = '/matches/new';
  static const String routeMatchDetail = '/matches/:id';
  static const String routeLineup = '/matches/:id/lineup';
  static const String routeLiveMatch = '/matches/live/:id';
  static const String routeMatchSummary = '/matches/:id/summary';
  static const String routeTraining = '/training';
  static const String routeStatistics = '/statistics';
  static const String routeReports = '/reports';
  static const String routeObservations = '/observations';

  // UI dimensions
  static const double sidebarWidth = 220.0;
  static const double cardRadius = 12.0;
  static const double chipRadius = 20.0;
  static const double pagePadding = 20.0;
  static const double sectionSpacing = 16.0;

  // Radial menu
  static const double radialMenuRadius = 88.0;
  static const double radialCenterRadius = 40.0;
  static const int radialSegments = 8;

  // Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  // Match
  static const int firstHalfDuration = 45;
  static const int secondHalfDuration = 45;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);
}

abstract class EventTypes {
  static const String passOk = 'Pase correcto';
  static const String passKey = 'Pase clave';
  static const String passBad = 'Pase incorrecto';
  static const String shot = 'Remate';
  static const String goal = 'Gol';
  static const String recovery = 'Recuperación';
  static const String foul = 'Falta';
  static const String interception = 'Intercepción';
  static const String cross = 'Centro';
  static const String assist = 'Asistencia';
  static const String yellowCard = 'Tarjeta amarilla';
  static const String redCard = 'Tarjeta roja';
  static const String save = 'Atajada';
  static const String corner = 'Corner';
  static const String offside = 'Offside';
  static const String loss = 'Pérdida';
  static const String tackleOk = 'Entrada exitosa';
  static const String tackleBad = 'Entrada fallida';

  static const List<String> all = [
    passOk,
    passBad,
    shot,
    goal,
    recovery,
    foul,
    interception,
    cross,
    assist,
    yellowCard,
    redCard,
    save,
    corner,
    offside,
    loss,
    tackleOk,
    tackleBad,
  ];

  // Radial menu — 8 primary events (most common)
  static const List<String> radialPrimary = [
    passOk,
    passBad,
    shot,
    goal,
    foul,
    recovery,
    cross,
    interception,
  ];
}

abstract class TiposCompeticion {
  static const List<String> all = ['Liga', 'Copa', 'Amistoso', 'Torneo'];
}

abstract class EstadosPartido {
  static const List<String> all = [
    'Programado',
    'EnJuego',
    'Finalizado',
    'Cancelado'
  ];
}

abstract class PlayerPositions {
  static const String goalkeeper = 'ARQ';

  // Defensas
  static const String rightBack = 'LD';
  static const String centerBack = 'DFC';
  static const String leftBack = 'LI';

  // Mediocampistas
  static const String rightMidfielder = 'MD';
  static const String defensiveMid = 'MCD';
  static const String centralMid = 'MC';
  static const String attackingMid = 'MCO';
  static const String leftMidfielder = 'MI';

  // Delanteros
  static const String rightWing = 'ED';
  static const String leftWing = 'EI';
  static const String striker = 'DC';
  static const String forward = 'DEL';

  static const Map<String, List<String>> groups = {
    'Arquero': ['ARQ'],
    'Defensas': ['LD', 'DFC', 'LI'],
    'Mediocampistas': ['MD', 'MCD', 'MC', 'MCO', 'MI'],
    'Delanteros': ['ED', 'EI', 'DC', 'DEL'],
  };

  static const Map<String, String> names = {
    'ARQ': 'Arquero',
    'LD': 'Lateral Derecho',
    'DFC': 'Defensa Central',
    'LI': 'Lateral Izquierdo',
    'MD': 'Mediocampista Derecho',
    'MCD': 'Mediocentro Defensivo',
    'MC': 'Mediocampista Central',
    'MCO': 'Mediocampista Ofensivo',
    'MI': 'Mediocampista Izquierdo',
    'ED': 'Extremo Derecho',
    'EI': 'Extremo Izquierdo',
    'DC': 'Delantero Centro',
    'DEL': 'Delantero',
  };

  static const List<String> all = [
    goalkeeper,
    rightBack,
    centerBack,
    leftBack,
    rightMidfielder,
    defensiveMid,
    centralMid,
    attackingMid,
    leftMidfielder,
    rightWing,
    leftWing,
    striker,
    forward,
  ];
}
