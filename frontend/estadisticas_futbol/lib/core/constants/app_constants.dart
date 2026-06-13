abstract class AppConstants {
  // Navigation route names
  static const String routeSplash       = '/splash';
  static const String routeLogin        = '/login';
  static const String routeDashboard    = '/';
  static const String routePlayers      = '/players';
  static const String routePlayerDetail = '/players/:id';
  static const String routeMatches      = '/matches';
  static const String routeLiveMatch    = '/matches/live/:id';
  static const String routeTraining     = '/training';
  static const String routeStatistics   = '/statistics';
  static const String routeReports      = '/reports';
  static const String routeObservations = '/observations';

  // UI dimensions
  static const double sidebarWidth   = 220.0;
  static const double cardRadius     = 12.0;
  static const double chipRadius     = 20.0;
  static const double pagePadding    = 20.0;
  static const double sectionSpacing = 16.0;

  // Radial menu
  static const double radialMenuRadius   = 88.0;
  static const double radialCenterRadius = 40.0;
  static const int    radialSegments     = 8;

  // Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  // Match
  static const int firstHalfDuration  = 45;
  static const int secondHalfDuration = 45;

  // Animation durations
  static const Duration animFast   = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow   = Duration(milliseconds: 400);
}

abstract class EventTypes {
  static const String passOk       = 'Pase correcto';
  static const String passBad      = 'Pase incorrecto';
  static const String shot         = 'Remate';
  static const String goal         = 'Gol';
  static const String recovery     = 'Recuperación';
  static const String foul         = 'Falta';
  static const String interception = 'Intercepción';
  static const String cross        = 'Centro';
  static const String assist       = 'Asistencia';
  static const String yellowCard   = 'Tarjeta amarilla';
  static const String redCard      = 'Tarjeta roja';
  static const String save         = 'Atajada';
  static const String corner       = 'Corner';
  static const String offside      = 'Offside';
  static const String loss         = 'Pérdida';
  static const String tackleOk     = 'Entrada exitosa';
  static const String tackleBad    = 'Entrada fallida';

  static const List<String> all = [
    passOk, passBad, shot, goal, recovery, foul,
    interception, cross, assist, yellowCard, redCard,
    save, corner, offside, loss, tackleOk, tackleBad,
  ];

  // Radial menu — 8 primary events (most common)
  static const List<String> radialPrimary = [
    passOk, passBad, shot, goal, foul, recovery, cross, interception,
  ];
}

abstract class PlayerPositions {
  static const String goalkeeper  = 'PT';
  static const String rightBack   = 'LD';
  static const String centerBack  = 'DC';
  static const String leftBack    = 'LI';
  static const String defensiveMid = 'MDF';
  static const String centralMid  = 'MC';
  static const String attackingMid = 'MAM';
  static const String rightWing   = 'EXD';
  static const String leftWing    = 'EXI';
  static const String striker     = 'DC9';
  static const String forward     = 'DEL';
}
