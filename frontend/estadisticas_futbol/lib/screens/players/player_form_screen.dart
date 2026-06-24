import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/player_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class PlayerFormScreen extends StatefulWidget {
  final String? playerId;

  const PlayerFormScreen({super.key, this.playerId});

  bool get isEditing => playerId != null;

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _api = PlayerApi();
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _numberController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _dniController = TextEditingController();

  DateTime? _birthDate;
  String _position = PlayerPositions.all.first;
  String _status = 'available';
  int? _categoryId;
  bool _active = true;

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _numberController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _nationalityController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthState>().session!.accessToken;

    try {
      final categories = await _api.getCategories(token);
      final player = widget.isEditing
          ? await _api.getPlayer(widget.playerId!, token)
          : null;

      setState(() {
        _categories = categories;
        if (player != null) {
          _firstNameController.text = player.firstName;
          _lastNameController.text = player.lastName;
          _numberController.text =
              player.number == 0 ? '' : player.number.toString();
          _heightController.text =
              player.heightCm == 0 ? '' : player.heightCm.toString();
          _weightController.text =
              player.weightKg == 0 ? '' : player.weightKg.toString();
          _nationalityController.text = player.nationality;
          _dniController.text = player.dni ?? '';
          _birthDate = player.birthDate;
          _position = player.position.isNotEmpty
              ? player.position
              : PlayerPositions.all.first;
          _status = player.status;
          _categoryId = player.categoryId ??
              (categories.isEmpty ? null : categories.first.id);
          _active = player.active;
        } else {
          _categoryId = categories.isEmpty ? null : categories.first.id;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos cargar los datos. Intentá nuevamente.';
        _loading = false;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 70),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null) {
      setState(() => _error = 'No hay categorías disponibles para asignar.');
      return;
    }

    if (_birthDate != null) {
      final now = DateTime.now();
      var age = now.year - _birthDate!.year;
      if (now.month < _birthDate!.month ||
          (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
        age--;
      }
      if (age < 10) {
        setState(() => _error = 'Edad mínima: 10 años');
        return;
      }
      if (age > 60) {
        setState(() => _error = 'Edad máxima: 60 años');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    final player = PlayerModel(
      id: widget.playerId ?? '0',
      name: '$firstName $lastName'.trim(),
      shortName: '$firstName $lastName'.trim(),
      position: _position,
      number: int.tryParse(_numberController.text.trim()) ?? 0,
      age: 0,
      nationality: _nationalityController.text.trim(),
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      status: _status,
      rating: 0,
      matchesPlayed: 0,
      stats: const {},
      firstName: firstName,
      lastName: lastName,
      birthDate: _birthDate,
      dni: _dniController.text.trim().isEmpty
          ? null
          : _dniController.text.trim(),
      categoryId: _categoryId,
      active: _active,
    );

    final token = context.read<AuthState>().session!.accessToken;

    try {
      if (widget.isEditing) {
        await _api.updatePlayer(widget.playerId!, player, token);
      } else {
        await _api.createPlayer(player, token);
      }

      if (mounted) context.pop(true);
    } on PlayerApiException catch (error) {
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pudimos guardar los datos. Intentá nuevamente.';
        _saving = false;
      });
    }
  }

  String? _validateNombre(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nombre requerido';
    final v = value.trim();
    if (v.length > 100) return 'Máximo 100 caracteres';
    if (!RegExp(r"^[\p{L}\s'\-]+$", unicode: true).hasMatch(v)) {
      return 'Solo letras y espacios';
    }
    return null;
  }

  String? _validateNumero(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null || n < 1 || n > 99) return 'Debe ser entre 1 y 99';
    return null;
  }

  String? _validateAltura(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value.trim());
    if (n == null || n < 140 || n > 220) return 'Entre 140 y 220 cm';
    return null;
  }

  String? _validatePeso(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value.trim());
    if (n == null || n < 45 || n > 160) return 'Entre 45 y 160 kg';
    return null;
  }

  String? _validateNacionalidad(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (v.length > 50) return 'Máximo 50 caracteres';
    if (!RegExp(r'^[\p{L}\s]+$', unicode: true).hasMatch(v)) {
      return 'Solo letras y espacios';
    }
    return null;
  }

  String? _validateDni(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (v.length > 20) return 'Máximo 20 caracteres';
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) return 'Solo letras y números';
    return null;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: widget.isEditing ? 'Editar jugador' : 'Nuevo jugador',
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            enabled: !_saving,
                            decoration:
                                const InputDecoration(labelText: 'Nombre'),
                            validator: _validateNombre,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            enabled: !_saving,
                            decoration:
                                const InputDecoration(labelText: 'Apellido'),
                            validator: _validateNombre,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _saving ? null : _pickBirthDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento'),
                        child: Text(
                          _birthDate == null
                              ? 'Sin definir'
                              : _formatDate(_birthDate!),
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _position,
                      decoration: const InputDecoration(labelText: 'Posición'),
                      items: PlayerPositions.all
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(PlayerPositions.names[p] ?? p)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _position = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _numberController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Número de camiseta'),
                      validator: _validateNumero,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _heightController,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Altura (cm)'),
                      validator: _validateAltura,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _weightController,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      validator: _validatePeso,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nationalityController,
                      enabled: !_saving,
                      decoration:
                          const InputDecoration(labelText: 'Nacionalidad'),
                      validator: _validateNacionalidad,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dniController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'DNI',
                        hintText: 'Opcional',
                      ),
                      validator: _validateDni,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                            value: 'available', child: Text('Disponible')),
                        DropdownMenuItem(
                            value: 'injured', child: Text('Lesionado')),
                        DropdownMenuItem(
                            value: 'suspended', child: Text('Suspendido')),
                      ],
                      onChanged:
                          _saving ? null : (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _categoryId = v),
                      validator: (v) =>
                          v == null ? 'Seleccioná una categoría' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      label: Text(widget.isEditing
                          ? 'Guardar cambios'
                          : 'Crear jugador'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
