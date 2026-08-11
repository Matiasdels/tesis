class ManagedUserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final int roleId;
  final String roleName;
  final bool active;
  final DateTime createdAt;

  const ManagedUserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roleId,
    required this.roleName,
    required this.active,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ManagedUserModel.fromApi(Map<String, dynamic> json) {
    return ManagedUserModel(
      id: json['usuarioId'] as int,
      username: json['nombreUsuario'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['nombre'] as String? ?? '',
      lastName: json['apellido'] as String? ?? '',
      roleId: json['rolId'] as int,
      roleName: json['rol'] as String? ?? 'Sin rol',
      active: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['fechaCreacion'] as String),
    );
  }
}

class RoleModel {
  final int id;
  final String name;

  const RoleModel({required this.id, required this.name});

  factory RoleModel.fromApi(Map<String, dynamic> json) {
    return RoleModel(
      id: json['rolId'] as int,
      name: json['nombre'] as String? ?? '',
    );
  }
}

class CreateUserDraft {
  final String username;
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final int roleId;

  const CreateUserDraft({
    required this.username,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.roleId,
  });

  Map<String, dynamic> toApiJson() {
    return {
      'nombreUsuario': username,
      'email': email,
      'password': password,
      'nombre': firstName,
      'apellido': lastName,
      'rolId': roleId,
    };
  }
}
