import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/user_management_api.dart';
import '../../models/user_management_models.dart';
import '../../widgets/common/app_widgets.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _api = UserManagementApi();

  List<ManagedUserModel> _users = [];
  List<RoleModel> _roles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final canManageUsers =
        _canManageUsersRole(context.read<AuthState>().session?.user.rol);

    if (!canManageUsers) {
      setState(() {
        _users = [];
        _roles = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final results = await Future.wait([
        _api.getUsers(token),
        _api.getRoles(token),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<ManagedUserModel>;
        _roles = results[1] as List<RoleModel>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los usuarios.';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateUser() async {
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay roles disponibles.')),
      );
      return;
    }

    final draft = await showModalBottomSheet<CreateUserDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      builder: (_) => _CreateUserSheet(roles: _roles),
    );

    if (draft == null || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final created = await _api.createUser(draft, token);
      if (!mounted) return;
      setState(() {
        _users = [..._users, created]
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario creado.')),
      );
    } on UserManagementApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos crear el usuario.')),
      );
    }
  }

  Future<void> _openEditUser(ManagedUserModel user) async {
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay roles disponibles.')),
      );
      return;
    }

    final draft = await showModalBottomSheet<UpdateUserDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      builder: (_) => _EditUserSheet(user: user, roles: _roles),
    );

    if (draft == null || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      final updated = await _api.updateUser(user.id, draft, token);
      if (!mounted) return;
      setState(() {
        _users = _users
            .map((item) => item.id == updated.id ? updated : item)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado.')),
      );
    } on UserManagementApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar el usuario.')),
      );
    }
  }

  Future<void> _deactivateUser(ManagedUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text(
          'El usuario ${user.fullName.isEmpty ? user.username : user.fullName} no podra iniciar sesion mientras este inactivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _api.deactivateUser(user.id, token);
      if (!mounted) return;
      setState(() {
        _users = _users
            .map(
              (item) => item.id == user.id
                  ? ManagedUserModel(
                      id: item.id,
                      username: item.username,
                      email: item.email,
                      firstName: item.firstName,
                      lastName: item.lastName,
                      roleId: item.roleId,
                      roleName: item.roleName,
                      active: false,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario desactivado.')),
      );
    } on UserManagementApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos desactivar el usuario.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageUsers =
        _canManageUsersRole(context.watch<AuthState>().session?.user.rol);

    return PageScaffold(
      title: 'Usuarios',
      subtitle: 'Cuentas y roles del cuerpo tecnico',
      showBack: true,
      actions: [
        if (canManageUsers)
          ElevatedButton.icon(
            onPressed: _loading ? null : _openCreateUser,
            icon: const Icon(Icons.person_add_alt_rounded, size: 16),
            label: const Text('Nuevo'),
          ),
      ],
      body: canManageUsers
          ? RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          padding:
                              const EdgeInsets.all(AppConstants.pagePadding),
                          children: [
                            EmptyState(
                              icon: Icons.manage_accounts_outlined,
                              title: 'No se pudieron cargar los usuarios',
                              subtitle: _error!,
                              actionLabel: 'Reintentar',
                              onAction: _load,
                            ),
                          ],
                        )
                      : _UsersList(
                          users: _users,
                          onEdit: _openEditUser,
                          onDeactivate: _deactivateUser,
                        ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: const [
                EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Sin permiso',
                  subtitle:
                      'Tu usuario no tiene permisos para gestionar usuarios y roles.',
                ),
              ],
            ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final List<ManagedUserModel> users;
  final ValueChanged<ManagedUserModel> onEdit;
  final ValueChanged<ManagedUserModel> onDeactivate;

  const _UsersList({
    required this.users,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        children: const [
          EmptyState(
            icon: Icons.group_outlined,
            title: 'Sin usuarios',
            subtitle: 'Crea usuarios para asignar roles de trabajo.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _UserCard(
        user: users[index],
        onEdit: () => onEdit(users[index]),
        onDeactivate: () => onDeactivate(users[index]),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final ManagedUserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.fullName.isEmpty
        ? user.username.substring(0, 1).toUpperCase()
        : user.fullName
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0])
            .join()
            .toUpperCase();

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.infoDim,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? user.username : user.fullName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${user.username} - ${user.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _RoleBadge(label: user.roleName),
                    _StatusBadge(active: user.active),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Editar usuario',
            onPressed: onEdit,
            color: AppColors.textSecondary,
            icon: const Icon(Icons.edit_outlined, size: 20),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
          ),
          if (user.active)
            IconButton(
              tooltip: 'Desactivar usuario',
              onPressed: onDeactivate,
              color: AppColors.danger,
              icon: const Icon(Icons.person_off_outlined, size: 20),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

bool _canManageUsersRole(String? role) {
  final normalized = (role ?? '').trim().toLowerCase();
  return normalized == 'admin' || normalized == 'responsable institucional';
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;

  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  final List<RoleModel> roles;

  const _CreateUserSheet({required this.roles});

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  late int _roleId = widget.roles.first.id;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? _email(String? value) {
    final message = _required(value);
    if (message != null) return message;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(value!.trim());
    return valid ? null : 'Ingresa un email valido';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CreateUserDraft(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        roleId: _roleId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nuevo usuario',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _email,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Apellido'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _roleId,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: widget.roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role.id,
                        child: Text(role.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _roleId = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Contrasena inicial',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar contrasena'
                        : 'Ocultar contrasena',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                    }),
                  ),
                ),
                validator: (value) {
                  final message = _required(value);
                  if (message != null) return message;
                  return value!.length < 8 ? 'Minimo 8 caracteres' : null;
                },
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Crear usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  final ManagedUserModel user;
  final List<RoleModel> roles;

  const _EditUserSheet({
    required this.user,
    required this.roles,
  });

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late int _roleId;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    final hasCurrentRole =
        widget.roles.any((role) => role.id == widget.user.roleId);
    _roleId = hasCurrentRole ? widget.user.roleId : widget.roles.first.id;
    _active = widget.user.active;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? _email(String? value) {
    final message = _required(value);
    if (message != null) return message;
    final valid =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim());
    return valid ? null : 'Ingresa un email valido';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      UpdateUserDraft(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        roleId: _roleId,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar usuario',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _email,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Apellido'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _roleId,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: widget.roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role.id,
                        child: Text(role.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _roleId = value);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                activeThumbColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Usuario activo'),
                subtitle: const Text('Permite iniciar sesion en la app'),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
