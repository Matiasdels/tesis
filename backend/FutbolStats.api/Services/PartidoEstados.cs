namespace FutbolStats.Api.Services;

/// <summary>
/// Estados canónicos de un partido y reglas de transición entre ellos.
/// Toda la lógica de estados debe pasar por esta clase para que un cambio
/// en el modelo de negocio solo requiera editar un único lugar.
/// </summary>
public static class PartidoEstados
{
    public const string Programado       = "Programado";
    public const string EnJuego          = "EnJuego";
    public const string EsperandoPenales = "EsperandoPenales";
    public const string Finalizado       = "Finalizado";
    public const string Cancelado        = "Cancelado";

    /// <summary>Todos los estados válidos del sistema.</summary>
    public static readonly IReadOnlySet<string> Todos = new HashSet<string>
    {
        Programado, EnJuego, EsperandoPenales, Finalizado, Cancelado
    };

    /// <summary>Estados terminales: el partido ya no puede modificarse.</summary>
    public static readonly IReadOnlySet<string> Terminales = new HashSet<string>
    {
        Finalizado, Cancelado
    };

    /// <summary>Estados en que se pueden registrar o eliminar eventos de campo.</summary>
    public static readonly IReadOnlySet<string> PermiteEventos = new HashSet<string>
    {
        EnJuego, EsperandoPenales
    };

    /// <summary>Estado en que se puede modificar la alineación.</summary>
    public static readonly IReadOnlySet<string> PermiteModificarAlineacion = new HashSet<string>
    {
        Programado
    };

    // Transiciones válidas por estado de origen.
    // Mismo estado (idempotente) → siempre permitido; no aparece aquí.
    private static readonly IReadOnlyDictionary<string, IReadOnlySet<string>> Transiciones =
        new Dictionary<string, IReadOnlySet<string>>
        {
            [Programado]       = new HashSet<string> { EnJuego, Cancelado },
            [EnJuego]          = new HashSet<string> { Finalizado, EsperandoPenales, Cancelado },
            [EsperandoPenales] = new HashSet<string> { Finalizado, Cancelado },
            [Finalizado]       = new HashSet<string>(),
            [Cancelado]        = new HashSet<string>(),
        };

    /// <summary>
    /// Devuelve true si la transición de <paramref name="estadoActual"/>
    /// a <paramref name="estadoNuevo"/> es válida según las reglas del negocio.
    /// El mismo estado es idempotente y siempre se permite.
    /// </summary>
    public static bool TransicionPermitida(string estadoActual, string estadoNuevo)
    {
        if (estadoActual == estadoNuevo) return true;
        return Transiciones.TryGetValue(estadoActual, out var permitidos)
            && permitidos.Contains(estadoNuevo);
    }
}
