/// Roles reales de TEC (Elytron, `tb_rol.rol_nombre`). La App solo los usa para mostrar
/// u ocultar opciones: la autorización real la valida TEC en cada petición
/// (`@RolesAllowed`); ocultar una opción no es seguridad.
abstract final class RolTec {
  static const String administrador = 'SITEC-Administrador';
  static const String tribunal = 'SITEC-Tribunal';
  static const String iglesiaAdmin = 'SITEC-IglesiaAdmin';
  static const String presidenteMesa = 'SITEC-Presidente-mesa';
  static const String tecnico = 'SITEC-Tecnico';
  static const String gerencial = 'SITEC-Gerencial';
  static const String supervisor = 'SITEC-Supervisor';
  static const String superadministrador = 'SITEC-Superadministrador';

  /// Roles con acceso al módulo Tribunal Electoral en la primera versión.
  /// Un usuario con varios roles recibe la unión de sus permisos.
  static const Set<String> moduloTribunal = {administrador, tribunal, iglesiaAdmin, presidenteMesa};

  /// Secciones del módulo (mismos roles que exige TEC en ConsultaMovilService).
  static const Set<String> seccionMesa = {presidenteMesa};
  static const Set<String> seccionIglesia = {iglesiaAdmin};
  static const Set<String> seccionProceso = {administrador, tribunal};
}
