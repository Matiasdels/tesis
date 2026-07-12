namespace FutbolStats.Api.Options;

public class GeminiOptions
{
    public string? ApiKey { get; set; }
    public string BaseUrl { get; set; } = "https://generativelanguage.googleapis.com/v1beta";
    public string Model { get; set; } = "gemini-3.5-flash";
    public int TimeoutSeconds { get; set; } = 45;
}
