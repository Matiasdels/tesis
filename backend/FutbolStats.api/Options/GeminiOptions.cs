namespace FutbolStats.Api.Options;

public class GeminiOptions
{
    public string? ApiKey { get; set; }
    public string BaseUrl { get; set; } = "https://generativelanguage.googleapis.com/v1beta";

    /// <summary>
    /// Identificador del modelo Gemini a utilizar.
    /// Debe configurarse en appsettings o mediante la variable de entorno Gemini__Model.
    /// Si está vacío, el endpoint de IA responde con un mensaje controlado (sin lanzar excepción).
    /// </summary>
    public string Model { get; set; } = string.Empty;

    public int TimeoutSeconds { get; set; } = 45;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ApiKey) && !string.IsNullOrWhiteSpace(Model);
}
