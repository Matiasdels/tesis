abstract class RolePermissions {
  static const _sportWriteRoles = {
    'responsable institucional',
    'cuerpo tecnico',
    'admin',
    'entrenador',
    'asistente',
    'analista',
    'preparador fisico',
  };

  static const _userManagementRoles = {
    'responsable institucional',
    'admin',
  };

  static String normalize(String? role) => (role ?? '').trim().toLowerCase();

  static bool isPlayer(String? role) => normalize(role) == 'jugador';

  static bool canWriteSportData(String? role) {
    return _sportWriteRoles.contains(normalize(role));
  }

  static bool canManageUsers(String? role) {
    return _userManagementRoles.contains(normalize(role));
  }
}
