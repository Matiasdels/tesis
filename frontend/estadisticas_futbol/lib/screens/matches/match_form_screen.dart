import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/match_api.dart';
import '../../data/remote/player_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class MatchFormScreen extends StatefulWidget {
  final int? matchId;

  const MatchFormScreen({super.key, this.matchId});

  bool get isEditing => matchId != null;

  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _api = MatchApi();
  final _playerApi = PlayerApi();
  final _formKey = GlobalKey<FormState>();

  final _rivalController = TextEditingController();
  final _lugarController = TextEditingController();

  String _tipoCompeticion = TiposCompeticion.all.first;
  String _estado = EstadosPartido.all.first;
  String _definicionEmpate = DefinicionEmpate.terminaEnEmpate;
  int? _categoriaId;
  bool _esLocal = true;
  DateTime? _fecha;

  List<CategoryModel> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rivalController.dispose();
    _lugarController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthState>().session!.accessToken;
    try {
      final categories = await _playerApi.getCategories(token);
      final match =
          widget.isEditing ? await _api.getMatch(widget.matchId!, token) : null;

      setState(() {
        _categories = categories;
        if (match != null) {
          _rivalController.text = match.rival;
          _lugarController.text = match.lugar ?? '';
          _tipoCompeticion = match.tipoCompeticion;
          _estado = match.estado;
          _categoriaId = match.categoriaId;
          _esLocal = match.esLocal;
          _fecha = match.fecha;
          _definicionEmpate = match.definicionEmpate;
        } else {
          _categoriaId = categories.isEmpty ? null : categories.first.id;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos cargar los datos. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _fecha != null
          ? TimeOfDay(hour: _fecha!.hour, minute: _fecha!.minute)
          : const TimeOfDay(hour: 15, minute: 0),
    );
    if (!mounted) return;

    setState(() {
      _fecha = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 0,
        pickedTime?.minute ?? 0,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fecha == null) {
      setState(() => _error = 'La fecha del partido es obligatoria.');
      return;
    }

    if (_categoriaId == null) {
      setState(() => _error = 'No hay categorías disponibles.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final match = PartidoModel(
      id: widget.matchId ?? 0,
      categoriaId: _categoriaId!,
      rival: _rivalController.text.trim(),
      esLocal: _esLocal,
      fecha: _fecha!,
      tipoCompeticion: _tipoCompeticion,
      lugar: _lugarController.text.trim().isEmpty
          ? null
          : _lugarController.text.trim(),
      estado: _estado,
      definicionEmpate: _definicionEmpate,
    );

    final token = context.read<AuthState>().session!.accessToken;

    try {
      if (widget.isEditing) {
        await _api.updateMatch(widget.matchId!, match, token);
        if (mounted) context.pop(true);
      } else {
        await _api.createMatch(match, token);
        if (mounted) context.pop(true);
      }
    } on MatchApiException catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos guardar los datos. Intente nuevamente.';
        _saving = false;
      });
    }
  }

  String _formatFecha(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: widget.isEditing ? 'Editar partido' : 'Nuevo partido',
      showBack: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _rivalController,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Rival'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El nombre del rival es obligatorio.';
                        }
                        if (v.trim().length > 100) {
                          return 'Máximo 100 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _saving ? null : _pickFecha,
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Fecha y hora'),
                        child: Text(
                          _fecha == null
                              ? 'Sin definir'
                              : _formatFecha(_fecha!),
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoCompeticion,
                      decoration:
                          const InputDecoration(labelText: 'Tipo de competición'),
                      items: TiposCompeticion.all
                          .map((t) =>
                              DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _tipoCompeticion = v!),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _definicionEmpate,
                      decoration: const InputDecoration(
                          labelText: 'Definición en caso de empate'),
                      items: [
                        DefinicionEmpate.terminaEnEmpate,
                        DefinicionEmpate.alargueYPenales,
                        DefinicionEmpate.penalesDirectos,
                      ]
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(DefinicionEmpate.label(v)),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) =>
                              setState(() => _definicionEmpate = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _categoriaId,
                      decoration:
                          const InputDecoration(labelText: 'Categoría'),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _categoriaId = v),
                      validator: (v) =>
                          v == null ? 'Seleccioná una categoría.' : null,
                    ),
                    const SizedBox(height: 12),
                    if (widget.isEditing) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration:
                            const InputDecoration(labelText: 'Estado'),
                        items: EstadosPartido.all
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _estado = v!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _lugarController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Lugar',
                        hintText: 'Opcional',
                      ),
                      validator: (v) {
                        if (v != null && v.trim().length > 150) {
                          return 'Máximo 150 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _esLocal ? 'Partido de local' : 'Partido de visitante',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Switch(
                          value: _esLocal,
                          onChanged:
                              _saving ? null : (v) => setState(() => _esLocal = v),
                          activeThumbColor: AppColors.accent,
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                          widget.isEditing ? 'Guardar cambios' : 'Crear partido'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
