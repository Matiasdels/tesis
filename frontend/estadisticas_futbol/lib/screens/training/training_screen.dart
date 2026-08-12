import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
import '../../data/remote/training_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _trainingApi = TrainingApi();
  final _playerApi = PlayerApi();

  List<TrainingSessionModel> _sessions = [];
  List<CategoryModel> _categories = [];
  List<PlayerModel> _players = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final results = await Future.wait([
        _trainingApi.getTrainingSessions(accessToken: token),
        _playerApi.getCategories(token),
      ]);
      final players = await _loadPlayersSafely(token);
      if (!mounted) return;
      final sessions = results[0] as List<TrainingSessionModel>;
      sessions.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _sessions = sessions;
        _categories = results[1] as List<CategoryModel>;
        _players = players;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los entrenamientos. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  Future<void> _createTraining() async {
    final created = await showModalBottomSheet<TrainingSessionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      builder: (sheetContext) => _TrainingFormSheet(
        categories: _categories,
      ),
    );

    if (created == null || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _trainingApi.createTrainingSession(created, token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrenamiento creado.')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos crear el entrenamiento.'),
        ),
      );
    }
  }

  Future<List<PlayerModel>> _loadPlayersSafely(String token) async {
    try {
      return _playerApi.getPlayers(accessToken: token);
    } catch (_) {
      return const [];
    }
  }

  List<PlayerModel> _playersForSession(TrainingSessionModel session) {
    final sameCategory = _players
        .where((player) => player.categoryId == session.categoriaId)
        .toList();
    return sameCategory.isEmpty ? _players : sameCategory;
  }

  Future<void> _openAttendanceSheet(TrainingSessionModel session) async {
    List<PlayerModel> players = _playersForSession(session);
    if (players.isEmpty) {
      try {
        final token = context.read<AuthState>().session!.accessToken;
        final allPlayers = await _playerApi.getPlayers(accessToken: token);
        if (!mounted) return;
        setState(() => _players = allPlayers);
        players = _playersForSession(session);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos cargar los jugadores.'),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay jugadores registrados para marcar asistencia.'),
        ),
      );
      return;
    }

    final updated = await showModalBottomSheet<TrainingSessionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      builder: (sheetContext) => _AttendanceSheet(
        session: session,
        players: players,
        onSave: (attendance) async {
          final token = context.read<AuthState>().session!.accessToken;
          final saved = await _trainingApi.updateAttendance(
            sessionId: session.id,
            attendance: attendance,
            accessToken: token,
          );
          return _sessionWithAttendance(saved, attendance);
        },
      ),
    );

    if (updated == null || !mounted) return;
    setState(() {
      _sessions = _sessions
          .map((item) => item.id == updated.id ? updated : item)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asistencia guardada: ${updated.attended} presentes.'),
      ),
    );
  }

  TrainingSessionModel _sessionWithAttendance(
    TrainingSessionModel session,
    List<TrainingAttendanceModel> attendance,
  ) {
    final attended = attendance.where((item) => item.attended).length;
    return TrainingSessionModel(
      id: session.id,
      categoriaId: session.categoriaId,
      date: session.date,
      title: session.title,
      type: session.type,
      durationMin: session.durationMin,
      place: session.place,
      attended: attended,
      absent: attendance.length - attended,
      attendance: List.unmodifiable(attendance),
    );
  }

  Future<void> _deleteTraining(TrainingSessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar entrenamiento'),
        content: Text(
          'Se eliminara "${session.title}" del seguimiento. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _trainingApi.deleteTrainingSession(
        sessionId: session.id,
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _sessions = _sessions.where((item) => item.id != session.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrenamiento eliminado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos eliminar el entrenamiento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAttendance = _sessions.fold<int>(
      0,
      (sum, session) => sum + session.attended,
    );

    return PageScaffold(
      title: 'Entrenamientos',
      subtitle: 'Planificacion y seguimiento del plantel',
      actions: [
        ElevatedButton.icon(
          onPressed: _categories.isEmpty && !_loading ? null : _createTraining,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Nuevo'),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error al cargar',
                  subtitle: _error!,
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppConstants.pagePadding),
                    children: [
                      _TrainingSummary(
                        sessionsCount: _sessions.length,
                        totalAttendance: totalAttendance,
                      ),
                      const SizedBox(height: 12),
                      if (_sessions.isEmpty)
                        EmptyState(
                          icon: Icons.fitness_center_rounded,
                          title: 'Sin entrenamientos registrados',
                          subtitle:
                              'Crea el primer entrenamiento para comenzar el seguimiento.',
                          actionLabel: 'Nuevo entrenamiento',
                          onAction: _createTraining,
                        )
                      else
                        ..._sessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TrainingCard(
                              session: session,
                              players: _playersForSession(session),
                              onAttendance: () =>
                                  _openAttendanceSheet(session),
                              onDelete: () => _deleteTraining(session),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _TrainingSummary extends StatelessWidget {
  final int sessionsCount;
  final int totalAttendance;

  const _TrainingSummary({
    required this.sessionsCount,
    required this.totalAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Sesiones',
            value: '$sessionsCount',
            icon: Icons.event_available_rounded,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Presentes',
            value: '$totalAttendance',
            icon: Icons.groups_rounded,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  final TrainingSessionModel session;
  final List<PlayerModel> players;
  final VoidCallback onAttendance;
  final VoidCallback onDelete;

  const _TrainingCard({
    required this.session,
    required this.players,
    required this.onAttendance,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date =
        '${session.date.day.toString().padLeft(2, '0')}/${session.date.month.toString().padLeft(2, '0')}/${session.date.year}';
    final duration = session.durationMin == null
        ? null
        : '${session.durationMin} min';
    final playerById = <int, PlayerModel>{};
    for (final player in players) {
      playerById[player.id] = player;
    }
    final attendedNames = session.attendance
        .where((attendance) => attendance.attended)
        .map((attendance) => playerById[attendance.playerId]?.name)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    final attendanceText = attendedNames.isEmpty
        ? session.attended > 0
            ? '${session.attended} jugadores presentes.'
            : 'Todavia no hay asistencia cargada.'
        : attendedNames.length <= 3
            ? attendedNames.join(', ')
            : '${attendedNames.take(3).join(', ')} y ${attendedNames.length - 3} mas';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [session.type, date, duration, session.place]
                          .whereType<String>()
                          .where((item) => item.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar entrenamiento',
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.danger,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricPill(
                label: 'Asistieron',
                value: '${session.attended}',
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              _MetricPill(
                label: 'Ausentes',
                value: '${session.absent}',
                color: AppColors.warning,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAttendance,
                icon: const Icon(Icons.fact_check_rounded, size: 16),
                label: const Text('Asistencia'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Presentes: $attendanceText',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSheet extends StatefulWidget {
  final TrainingSessionModel session;
  final List<PlayerModel> players;
  final Future<TrainingSessionModel> Function(
    List<TrainingAttendanceModel> attendance,
  ) onSave;

  const _AttendanceSheet({
    required this.session,
    required this.players,
    required this.onSave,
  });

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
  late Set<int> _attendedIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final savedAttendedIds = widget.session.attendance
        .where((item) => item.attended)
        .map((item) => item.playerId)
        .toSet();
    _attendedIds = savedAttendedIds.isEmpty
        ? widget.players.map((player) => player.id).toSet()
        : savedAttendedIds;
  }

  void _markAllPresent() {
    setState(() {
      _attendedIds = widget.players.map((player) => player.id).toSet();
    });
  }

  void _clearAttendance() {
    setState(_attendedIds.clear);
  }

  Future<void> _save() async {
    if (_attendedIds.isEmpty) {
      setState(() {
        _error = 'Marca al menos un jugador presente antes de guardar.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final attendance = widget.players
        .map(
          (player) => TrainingAttendanceModel(
            playerId: player.id,
            attended: _attendedIds.contains(player.id),
            rpe: widget.session.attendance
                .where((item) => item.playerId == player.id)
                .firstOrNull
                ?.rpe,
            observation: widget.session.attendance
                .where((item) => item.playerId == player.id)
                .firstOrNull
                ?.observation,
          ),
        )
        .toList();

    try {
      final updated = await widget.onSave(attendance);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No pudimos guardar la asistencia. Intente nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final selected = _attendedIds.length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Asistencia',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.session.title,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Asistieron $selected de ${widget.players.length}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _markAllPresent,
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Todos presentes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _clearAttendance,
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.players.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColors.borderSubtle,
                  ),
                  itemBuilder: (context, index) {
                    final player = widget.players[index];
                    final attended = _attendedIds.contains(player.id);

                    return SwitchListTile(
                      value: attended,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                if (value) {
                                  _attendedIds.add(player.id);
                                } else {
                                  _attendedIds.remove(player.id);
                                }
                              });
                            },
                      activeThumbColor: AppColors.accent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        player.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        player.position.isEmpty ? 'Sin posicion' : player.position,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      secondary: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.accentDim,
                        child: Text(
                          player.initials,
                          style: const TextStyle(
                            color: AppColors.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar asistencia'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrainingFormSheet extends StatefulWidget {
  final List<CategoryModel> categories;

  const _TrainingFormSheet({required this.categories});

  @override
  State<_TrainingFormSheet> createState() => _TrainingFormSheetState();
}

class _TrainingFormSheetState extends State<_TrainingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _typeController = TextEditingController(text: 'General');
  final _durationController = TextEditingController(text: '60');
  final _placeController = TextEditingController();

  late int _categoryId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isNotEmpty ? widget.categories.first.id : 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    _durationController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final durationText = _durationController.text.trim();
    Navigator.of(context).pop(
      TrainingSessionModel(
        id: 0,
        categoriaId: _categoryId,
        date: _date,
        title: _titleController.text.trim(),
        type: _typeController.text.trim(),
        durationMin: durationText.isEmpty ? null : int.parse(durationText),
        place: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        attended: 0,
        absent: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dateText =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nuevo entrenamiento',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.categories.length > 1)
                  DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: widget.categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _categoryId = value);
                    },
                  ),
                if (widget.categories.length > 1) const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresá un titulo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresá un tipo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Duracion en minutos'),
                  validator: (value) {
                    final clean = value?.trim() ?? '';
                    if (clean.isEmpty) return null;
                    final parsed = int.tryParse(clean);
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresá una duracion valida.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _placeController,
                  decoration: const InputDecoration(labelText: 'Lugar'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(dateText),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Guardar entrenamiento'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
