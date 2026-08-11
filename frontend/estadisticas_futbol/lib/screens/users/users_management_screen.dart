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

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Usuarios',
      subtitle: 'Cuentas y roles del cuerpo tecnico',
      showBack: true,
      actions: [
        ElevatedButton.icon(
          onPressed: _loading ? null : _openCreateUser,
          icon: const Icon(Icons.person_add_alt_rounded, size: 16),
          label: const Text('Nuevo'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(AppConstants.pagePadding),
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
                : _UsersList(users: _users),
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final List<ManagedUserModel> users;

  const _UsersList({required this.users});

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
      itemBuilder: (context, index) => _UserCard(user: users[index]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final ManagedUserModel user;

  const _UserCard({required this.user});

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
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RoleBadge(label: user.roleName),
        ],
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
