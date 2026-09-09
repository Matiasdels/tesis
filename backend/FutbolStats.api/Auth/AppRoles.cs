namespace FutbolStats.Api.Auth;

public static class AppRoles
{
    public const string ResponsableInstitucional = "Responsable institucional";
    public const string CuerpoTecnico = "Cuerpo tecnico";
    public const string Jugador = "Jugador";

    public const string LegacyAdmin = "Admin";
    public const string LegacyEntrenador = "Entrenador";
    public const string LegacyAsistente = "Asistente";
    public const string LegacyAnalista = "Analista";
    public const string LegacyPreparadorFisico = "Preparador fisico";

    public const string GestionUsuarios =
        ResponsableInstitucional + "," +
        LegacyAdmin;

    public const string EscrituraDeportiva =
        ResponsableInstitucional + "," +
        CuerpoTecnico + "," +
        LegacyAdmin + "," +
        LegacyEntrenador + "," +
        LegacyAsistente + "," +
        LegacyAnalista + "," +
        LegacyPreparadorFisico;
}
