import '../models/models.dart';

/// Static mock data — replace with API calls when backend is ready
abstract class MockData {
  // ── Players ───────────────────────────────────────────────────────────────

  static final List<PlayerModel> players = [
    const PlayerModel(
        id: 'p1',
        name: 'Carlos Ramírez',
        shortName: 'C. Ramírez',
        position: 'PT',
        number: 1,
        age: 28,
        nationality: 'Uruguay',
        heightCm: 186,
        weightKg: 82,
        status: 'available',
        rating: 79,
        matchesPlayed: 21,
        stats: {
          'passAccuracy': 68,
          'saves': 52,
          'goalsConceded': 18,
          'duelsWon': 0.41
        }),
    const PlayerModel(
        id: 'p2',
        name: 'Matías Suárez',
        shortName: 'M. Suárez',
        position: 'LD',
        number: 2,
        age: 23,
        nationality: 'Uruguay',
        heightCm: 178,
        weightKg: 73,
        status: 'available',
        rating: 76,
        matchesPlayed: 19,
        stats: {
          'passAccuracy': 83,
          'interceptions': 1.8,
          'duelsWon': 0.58,
          'tackles': 2.1
        }),
    const PlayerModel(
        id: 'p3',
        name: 'Diego Hernández',
        shortName: 'D. Hernández',
        position: 'DC',
        number: 4,
        age: 26,
        nationality: 'Uruguay',
        heightCm: 183,
        weightKg: 79,
        status: 'available',
        rating: 81,
        matchesPlayed: 22,
        stats: {
          'passAccuracy': 89,
          'interceptions': 2.3,
          'duelsWon': 0.68,
          'clearances': 4.2
        }),
    const PlayerModel(
        id: 'p4',
        name: 'Luis Martínez',
        shortName: 'L. Martínez',
        position: 'DC',
        number: 5,
        age: 24,
        nationality: 'Uruguay',
        heightCm: 184,
        weightKg: 78,
        status: 'available',
        rating: 91,
        matchesPlayed: 21,
        stats: {
          'passAccuracy': 94,
          'interceptions': 2.8,
          'duelsWon': 0.71,
          'clearances': 3.9
        }),
    const PlayerModel(
        id: 'p5',
        name: 'Rodrigo Pereira',
        shortName: 'R. Pereira',
        position: 'LI',
        number: 3,
        age: 22,
        nationality: 'Uruguay',
        heightCm: 175,
        weightKg: 70,
        status: 'available',
        rating: 74,
        matchesPlayed: 18,
        stats: {
          'passAccuracy': 81,
          'crosses': 1.4,
          'duelsWon': 0.55,
          'assists': 3
        }),
    const PlayerModel(
        id: 'p6',
        name: 'Fernando Cabrera',
        shortName: 'F. Cabrera',
        position: 'MDF',
        number: 6,
        age: 27,
        nationality: 'Uruguay',
        heightCm: 180,
        weightKg: 76,
        status: 'available',
        rating: 84,
        matchesPlayed: 20,
        stats: {
          'passAccuracy': 91,
          'recoveries': 4.8,
          'duelsWon': 0.62,
          'fouls': 1.1
        }),
    const PlayerModel(
        id: 'p7',
        name: 'Javier Rodríguez',
        shortName: 'J. Rodríguez',
        position: 'MC',
        number: 8,
        age: 25,
        nationality: 'Uruguay',
        heightCm: 177,
        weightKg: 72,
        status: 'available',
        rating: 87,
        matchesPlayed: 22,
        stats: {
          'passAccuracy': 88,
          'keyPasses': 2.1,
          'duelsWon': 0.59,
          'shots': 1.8
        }),
    const PlayerModel(
        id: 'p8',
        name: 'Nicolás Torres',
        shortName: 'N. Torres',
        position: 'MC',
        number: 14,
        age: 21,
        nationality: 'Uruguay',
        heightCm: 174,
        weightKg: 68,
        status: 'available',
        rating: 80,
        matchesPlayed: 17,
        stats: {
          'passAccuracy': 85,
          'keyPasses': 1.6,
          'duelsWon': 0.52,
          'shots': 1.2
        }),
    const PlayerModel(
        id: 'p9',
        name: 'Agustín Fernández',
        shortName: 'A. Fernández',
        position: 'EXD',
        number: 7,
        age: 23,
        nationality: 'Uruguay',
        heightCm: 172,
        weightKg: 67,
        status: 'available',
        rating: 83,
        matchesPlayed: 20,
        stats: {
          'passAccuracy': 78,
          'crosses': 2.8,
          'dribbles': 2.4,
          'goals': 4
        }),
    const PlayerModel(
        id: 'p10',
        name: 'Pablo Díaz',
        shortName: 'P. Díaz',
        position: 'EXI',
        number: 11,
        age: 24,
        nationality: 'Uruguay',
        heightCm: 170,
        weightKg: 66,
        status: 'injured',
        rating: 77,
        matchesPlayed: 14,
        stats: {
          'passAccuracy': 76,
          'crosses': 2.2,
          'dribbles': 3.1,
          'goals': 3
        }),
    const PlayerModel(
        id: 'p11',
        name: 'Sebastián García',
        shortName: 'S. García',
        position: 'DEL',
        number: 9,
        age: 26,
        nationality: 'Uruguay',
        heightCm: 181,
        weightKg: 77,
        status: 'available',
        rating: 88,
        matchesPlayed: 22,
        stats: {
          'passAccuracy': 72,
          'shots': 3.4,
          'goals': 11,
          'duelsWon': 0.48
        }),
    const PlayerModel(
        id: 'p12',
        name: 'Marco González',
        shortName: 'M. González',
        position: 'MC',
        number: 10,
        age: 29,
        nationality: 'Uruguay',
        heightCm: 176,
        weightKg: 74,
        status: 'suspended',
        rating: 62,
        matchesPlayed: 16,
        stats: {
          'passAccuracy': 82,
          'keyPasses': 1.9,
          'duelsWon': 0.44,
          'fouls': 2.1
        }),
  ];

  // ── Matches ───────────────────────────────────────────────────────────────

  static final List<MatchModel> matches = [
    MatchModel(
        id: 'm1',
        homeTeam: 'Colón FC',
        awayTeam: 'Atlético Sur',
        homeAbbr: 'COL',
        awayAbbr: 'ATL',
        homeScore: 2,
        awayScore: 1,
        date: DateTime(2025, 1, 15, 16, 0),
        venue: 'Est. Municipal',
        status: 'finished'),
    MatchModel(
        id: 'm2',
        homeTeam: 'Deportivo Norte',
        awayTeam: 'Colón FC',
        homeAbbr: 'DEP',
        awayAbbr: 'COL',
        homeScore: 0,
        awayScore: 0,
        date: DateTime(2025, 1, 8, 15, 0),
        venue: 'Cancha Norte',
        status: 'finished'),
    MatchModel(
        id: 'm3',
        homeTeam: 'Colón FC',
        awayTeam: 'Real CD',
        homeAbbr: 'COL',
        awayAbbr: 'RCD',
        homeScore: 2,
        awayScore: 1,
        date: DateTime(2025, 1, 18, 16, 0),
        venue: 'Est. Municipal',
        status: 'live',
        minute: 34),
    MatchModel(
        id: 'm4',
        homeTeam: 'Colón FC',
        awayTeam: 'Unión Oeste',
        homeAbbr: 'COL',
        awayAbbr: 'UO',
        homeScore: 0,
        awayScore: 0,
        date: DateTime(2025, 1, 25, 16, 0),
        venue: 'Est. Municipal',
        status: 'upcoming'),
    MatchModel(
        id: 'm5',
        homeTeam: 'Estrella FC',
        awayTeam: 'Colón FC',
        homeAbbr: 'EST',
        awayAbbr: 'COL',
        homeScore: 0,
        awayScore: 0,
        date: DateTime(2025, 2, 1, 15, 30),
        venue: 'Cancha Estrella',
        status: 'upcoming'),
  ];

  // ── Live match events ─────────────────────────────────────────────────────

  static final List<MatchEventModel> liveEvents = [
    const MatchEventModel(
        id: 'e1',
        type: 'Pase correcto',
        playerId: 'p4',
        playerName: 'L. Martínez',
        minute: 5,
        pitchX: 0.28,
        pitchY: 0.42),
    const MatchEventModel(
        id: 'e2',
        type: 'Recuperación',
        playerId: 'p6',
        playerName: 'F. Cabrera',
        minute: 12,
        pitchX: 0.40,
        pitchY: 0.50),
    const MatchEventModel(
        id: 'e3',
        type: 'Pase correcto',
        playerId: 'p7',
        playerName: 'J. Rodríguez',
        minute: 18,
        pitchX: 0.58,
        pitchY: 0.35),
    const MatchEventModel(
        id: 'e4',
        type: 'Remate',
        playerId: 'p11',
        playerName: 'S. García',
        minute: 22,
        pitchX: 0.82,
        pitchY: 0.48),
    const MatchEventModel(
        id: 'e5',
        type: 'Gol',
        playerId: 'p11',
        playerName: 'S. García',
        minute: 22,
        pitchX: 0.88,
        pitchY: 0.50),
    const MatchEventModel(
        id: 'e6',
        type: 'Falta',
        playerId: 'p3',
        playerName: 'D. Hernández',
        minute: 28,
        pitchX: 0.35,
        pitchY: 0.60),
    const MatchEventModel(
        id: 'e7',
        type: 'Pase correcto',
        playerId: 'p9',
        playerName: 'A. Fernández',
        minute: 31,
        pitchX: 0.72,
        pitchY: 0.22),
    const MatchEventModel(
        id: 'e8',
        type: 'Gol',
        playerId: 'p9',
        playerName: 'A. Fernández',
        minute: 33,
        pitchX: 0.91,
        pitchY: 0.47),
  ];

  // ── Training sessions ─────────────────────────────────────────────────────

  static final List<TrainingSessionModel> trainings = [
    TrainingSessionModel(
        id: 't1',
        date: DateTime(2025, 1, 17, 10),
        title: 'Táctica defensiva',
        type: 'tactical',
        durationMin: 90,
        avgRpe: 6.8,
        attendance: 21),
    TrainingSessionModel(
        id: 't2',
        date: DateTime(2025, 1, 16, 10),
        title: 'Resistencia aeróbica',
        type: 'physical',
        durationMin: 75,
        avgRpe: 8.1,
        attendance: 20),
    TrainingSessionModel(
        id: 't3',
        date: DateTime(2025, 1, 15, 10),
        title: 'Técnica de pases',
        type: 'technical',
        durationMin: 60,
        avgRpe: 5.5,
        attendance: 22),
    TrainingSessionModel(
        id: 't4',
        date: DateTime(2025, 1, 14, 10),
        title: 'Recuperación activa',
        type: 'recovery',
        durationMin: 45,
        avgRpe: 3.2,
        attendance: 19),
    TrainingSessionModel(
        id: 't5',
        date: DateTime(2025, 1, 13, 10),
        title: 'Presión alta y juego posicional',
        type: 'tactical',
        durationMin: 80,
        avgRpe: 7.4,
        attendance: 21),
  ];

  // ── Observations ──────────────────────────────────────────────────────────

  static final List<ObservationModel> observations = [
    ObservationModel(
        id: 'o1',
        playerId: 'p4',
        playerName: 'L. Martínez',
        authorName: 'Carlos García',
        authorRole: 'Entrenador',
        tag: 'positive',
        text:
            'Excelente posicionamiento en la fase defensiva. Anticipación muy mejorada respecto al mes anterior.',
        date: DateTime(2025, 1, 15)),
    ObservationModel(
        id: 'o2',
        playerId: 'p4',
        playerName: 'L. Martínez',
        authorName: 'Analista Dep.',
        authorRole: 'Analista',
        tag: 'improve',
        text:
            'Salida con balón bajo presión puede mejorar. Tendencia a buscar pase largo en lugar del pase corto.',
        date: DateTime(2025, 1, 12)),
    ObservationModel(
        id: 'o3',
        playerId: 'p7',
        playerName: 'J. Rodríguez',
        authorName: 'Miguel Torres',
        authorRole: 'Prep. físico',
        tag: 'physical',
        text:
            'Semana de carga alta asimilada correctamente. Ratios de esfuerzo en zona óptima.',
        date: DateTime(2025, 1, 14)),
    ObservationModel(
        id: 'o4',
        playerId: 'p11',
        playerName: 'S. García',
        authorName: 'Carlos García',
        authorRole: 'Entrenador',
        tag: 'positive',
        text:
            'Rendimiento excepcional. Buen movimiento sin balón y finalización clínica.',
        date: DateTime(2025, 1, 15)),
    ObservationModel(
        id: 'o5',
        playerId: 'p12',
        playerName: 'M. González',
        authorName: 'Carlos García',
        authorRole: 'Entrenador',
        tag: 'improve',
        text:
            'Necesita mejorar el trabajo defensivo. Pierde posición con frecuencia en transición.',
        date: DateTime(2025, 1, 10)),
  ];

  // ── KPI stats ─────────────────────────────────────────────────────────────

  static const List<StatCardData> dashboardKpis = [
    StatCardData(
        label: 'Posición', value: '3°', delta: 'Subió 2', deltaPositive: true),
    StatCardData(
        label: '% Victorias', value: '61%', delta: '+4%', deltaPositive: true),
    StatCardData(
        label: 'Carga prom.',
        value: '74.2',
        delta: '-3.1',
        deltaPositive: false),
    StatCardData(
        label: 'Lesionados',
        value: '2',
        delta: '24 disp.',
        deltaPositive: null),
  ];

  static const List<String> recentForm = ['V', 'V', 'E', 'V', 'D'];
}
