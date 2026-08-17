using System.Net;
using System.Text;
using System.Text.Json;
using FutbolStats.Api.Data;
using FutbolStats.Api.Models;
using FutbolStats.Api.Options;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FutbolStats.Api.Services;

public class AnalisisPartidoService(
    FutbolStatsDbContext context,
    HttpClient httpClient,
    IOptions<GeminiOptions> geminiOptions,
    ILogger<AnalisisPartidoService> logger)
{
    private const int MinEventosParaZonas = 3;
    private const int MinEventosParaAnalisis = 3;
    private const int MaxItemsPorSeccion = 4;
    private const string MensajeSinDatos =
        "Todavia no hay eventos registrados para generar un analisis del partido.";
    private const string MensajeDatosInsuficientes =
        "Todavia no hay datos suficientes para generar un analisis util. Registra al menos 3 eventos del partido.";
    private const string MensajeRequiereIa =
        "Para generar el analisis inteligente se necesita conexion a internet y una clave de IA configurada en el backend.";
    private const string MensajeErrorIa =
        "No se pudo generar el analisis con IA. Verifica la conexion a internet e intenta nuevamente.";
    private const string MensajeRespuestaInvalidaIa =
        "La IA respondio, pero no se pudo leer el resultado. Intenta nuevamente.";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true
    };

    public async Task<AnalisisPartidoResponse?> GenerarAsync(
        int partidoId,
        CancellationToken cancellationToken = default)
    {
        var partido = await context.Partidos
            .Include(p => p.Categoria)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.PartidoId == partidoId && p.Activo, cancellationToken);

        if (partido is null) return null;

        var eventos = await context.EventosPartido
            .Include(e => e.TipoEvento)
            .Include(e => e.Jugador)
            .AsNoTracking()
            .Where(e => e.PartidoId == partidoId)
            .OrderBy(e => e.Minuto)
            .ThenBy(e => e.FechaRegistro)
            .ToListAsync(cancellationToken);

        if (eventos.Count == 0)
        {
            return EmptyResponse(MensajeSinDatos);
        }

        if (eventos.Count < MinEventosParaAnalisis)
        {
            return EmptyResponse(MensajeDatosInsuficientes);
        }

        var options = geminiOptions.Value;
        if (!options.IsConfigured)
        {
            return EmptyResponse(MensajeRequiereIa);
        }

        var datosPartido = BuildInputData(partido, eventos);
        var puedeAnalizarZonas = eventos.Count(HasValidLocation) >= MinEventosParaZonas;

        try
        {
            var aiPayload = await GenerateWithGeminiAsync(
                datosPartido,
                options,
                cancellationToken);
            aiPayload.Normalize(puedeAnalizarZonas);

            return new AnalisisPartidoResponse(
                aiPayload.ResumenGeneral,
                aiPayload.PuntosPositivos,
                aiPayload.AspectosAMejorar,
                aiPayload.SugerenciasEntrenamiento,
                aiPayload.AnalisisZonas,
                true,
                null);
        }
        catch (GeminiRequestException ex)
        {
            logger.LogWarning(
                "Gemini rechazo el analisis para el partido {PartidoId}. Estado: {StatusCode}. Respuesta: {ResponseBody}",
                partidoId,
                (int)ex.StatusCode,
                ex.ResponseBody);

            return EmptyResponse(FriendlyGeminiMessage(ex.StatusCode));
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException)
        {
            logger.LogWarning(ex, "No se pudo interpretar el analisis inteligente para el partido {PartidoId}.", partidoId);
            return EmptyResponse(MensajeRespuestaInvalidaIa);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            logger.LogWarning(ex, "No se pudo generar el analisis inteligente para el partido {PartidoId}.", partidoId);
            return EmptyResponse(MensajeErrorIa);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error inesperado al generar el analisis inteligente para el partido {PartidoId}.", partidoId);
            return EmptyResponse(MensajeErrorIa);
        }
    }

    private async Task<AiAnalysisPayload> GenerateWithGeminiAsync(
        object datosPartido,
        GeminiOptions options,
        CancellationToken cancellationToken)
    {
        httpClient.Timeout = TimeSpan.FromSeconds(Math.Max(5, options.TimeoutSeconds));
        GeminiRequestException? lastModelError = null;
        Exception? lastInvalidResponse = null;

        foreach (var model in BuildModelCandidates(options))
        {
            try
            {
                return await GenerateWithGeminiModelAsync(
                    datosPartido,
                    options,
                    model,
                    cancellationToken);
            }
            catch (GeminiRequestException ex) when (CanRetryWithFallbackModel(ex.StatusCode))
            {
                lastModelError = ex;
                logger.LogWarning(
                    "Gemini rechazo el modelo {Model}. Estado: {StatusCode}. Respuesta: {ResponseBody}",
                    model,
                    (int)ex.StatusCode,
                    ex.ResponseBody);
            }
            catch (Exception ex) when (ex is JsonException or InvalidOperationException)
            {
                lastInvalidResponse = ex;
                logger.LogWarning(
                    ex,
                    "Gemini respondio con un formato no interpretable usando el modelo {Model}.",
                    model);
            }
        }

        if (lastModelError is not null)
        {
            throw lastModelError;
        }

        if (lastInvalidResponse is not null)
        {
            throw new InvalidOperationException("No se pudo interpretar la respuesta de Gemini.", lastInvalidResponse);
        }

        throw new InvalidOperationException("No hay modelos de Gemini configurados.");
    }

    private async Task<AiAnalysisPayload> GenerateWithGeminiModelAsync(
        object datosPartido,
        GeminiOptions options,
        string model,
        CancellationToken cancellationToken)
    {
        httpClient.Timeout = TimeSpan.FromSeconds(Math.Max(5, options.TimeoutSeconds));

        var requestBody = new
        {
            systemInstruction = new
            {
                parts = new[]
                {
                    new { text = BuildInstructions() }
                }
            },
            contents = new[]
            {
                new
                {
                    role = "user",
                    parts = new[]
                    {
                        new { text = JsonSerializer.Serialize(datosPartido, JsonOptions) }
                    }
                }
            },
            generationConfig = new
            {
                temperature = 0.2,
                maxOutputTokens = 2000,
                responseMimeType = "application/json"
            }
        };

        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"{options.BaseUrl.TrimEnd('/')}/models/{Uri.EscapeDataString(model)}:generateContent");

        request.Headers.Add("x-goog-api-key", options.ApiKey);
        request.Content = new StringContent(
            JsonSerializer.Serialize(requestBody, JsonOptions),
            Encoding.UTF8,
            "application/json");

        using var response = await httpClient.SendAsync(request, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new GeminiRequestException(response.StatusCode, responseBody);
        }

        using var document = JsonDocument.Parse(responseBody);
        var outputText = ExtractOutputText(document.RootElement);
        if (string.IsNullOrWhiteSpace(outputText))
        {
            throw new InvalidOperationException("La respuesta de Gemini no incluyo texto.");
        }

        return DeserializeAiPayload(outputText);
    }

    private static IReadOnlyList<string> BuildModelCandidates(GeminiOptions options)
    {
        return new[] { options.Model }
            .Concat(options.FallbackModels)
            .Where(model => !string.IsNullOrWhiteSpace(model))
            .Select(model => model.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static bool CanRetryWithFallbackModel(HttpStatusCode statusCode)
    {
        return statusCode is
            HttpStatusCode.BadRequest or
            HttpStatusCode.NotFound or
            HttpStatusCode.RequestTimeout or
            HttpStatusCode.TooManyRequests or
            HttpStatusCode.InternalServerError or
            HttpStatusCode.BadGateway or
            HttpStatusCode.ServiceUnavailable or
            HttpStatusCode.GatewayTimeout;
    }

    private static AiAnalysisPayload DeserializeAiPayload(string outputText)
    {
        foreach (var candidate in BuildJsonCandidates(outputText))
        {
            try
            {
                var payload = JsonSerializer.Deserialize<AiAnalysisPayload>(candidate, JsonOptions);
                if (payload is not null && payload.HasContent)
                {
                    return NormalizeNestedJsonPayload(payload);
                }
            }
            catch (JsonException)
            {
                // Se intenta con el siguiente candidato limpio.
            }
        }

        var cleanText = CleanLooseText(outputText);
        if (!string.IsNullOrWhiteSpace(cleanText))
        {
            return new AiAnalysisPayload
            {
                ResumenGeneral = cleanText
            };
        }

        throw new InvalidOperationException("No se pudo interpretar la respuesta de Gemini.");
    }

    private static IEnumerable<string> BuildJsonCandidates(string outputText)
    {
        var cleanText = CleanLooseText(outputText);
        if (string.IsNullOrWhiteSpace(cleanText)) yield break;

        yield return cleanText;

        var withoutFence = RemoveMarkdownFence(cleanText);
        if (!string.Equals(withoutFence, cleanText, StringComparison.Ordinal))
        {
            yield return withoutFence;
        }

        var jsonObject = ExtractFirstJsonObject(withoutFence);
        if (!string.IsNullOrWhiteSpace(jsonObject) &&
            !string.Equals(jsonObject, withoutFence, StringComparison.Ordinal))
        {
            yield return jsonObject;
        }
    }

    private static AiAnalysisPayload NormalizeNestedJsonPayload(AiAnalysisPayload payload)
    {
        var nestedJson = ExtractFirstJsonObject(payload.ResumenGeneral);
        if (string.IsNullOrWhiteSpace(nestedJson) ||
            !nestedJson.Contains("resumenGeneral", StringComparison.OrdinalIgnoreCase))
        {
            return payload;
        }

        try
        {
            var nestedPayload = JsonSerializer.Deserialize<AiAnalysisPayload>(nestedJson, JsonOptions);
            if (nestedPayload is not null && nestedPayload.HasContent)
            {
                return nestedPayload;
            }
        }
        catch (JsonException)
        {
            return payload;
        }

        return payload;
    }

    private static string CleanLooseText(string value)
    {
        return value.Trim()
            .Trim('\uFEFF')
            .Trim();
    }

    private static string RemoveMarkdownFence(string value)
    {
        var trimmed = value.Trim();
        if (!trimmed.StartsWith("```", StringComparison.Ordinal)) return trimmed;

        var firstLineBreak = trimmed.IndexOf('\n');
        if (firstLineBreak < 0) return trimmed.Trim('`').Trim();

        var content = trimmed[(firstLineBreak + 1)..].Trim();
        if (content.EndsWith("```", StringComparison.Ordinal))
        {
            content = content[..^3];
        }

        return content.Trim();
    }

    private static string? ExtractFirstJsonObject(string value)
    {
        var start = value.IndexOf('{');
        if (start < 0) return null;

        var depth = 0;
        var insideString = false;
        var escaping = false;

        for (var index = start; index < value.Length; index++)
        {
            var current = value[index];
            if (insideString)
            {
                if (escaping)
                {
                    escaping = false;
                }
                else if (current == '\\')
                {
                    escaping = true;
                }
                else if (current == '"')
                {
                    insideString = false;
                }

                continue;
            }

            if (current == '"')
            {
                insideString = true;
            }
            else if (current == '{')
            {
                depth++;
            }
            else if (current == '}')
            {
                depth--;
                if (depth == 0)
                {
                    return value[start..(index + 1)].Trim();
                }
            }
        }

        return null;
    }

    private static object AnalysisSchema()
    {
        return new
        {
            type = "object",
            additionalProperties = false,
            required = new[]
            {
                "resumenGeneral",
                "puntosPositivos",
                "aspectosAMejorar",
                "sugerenciasEntrenamiento",
                "analisisZonas"
            },
            properties = new
            {
                resumenGeneral = new { type = "string" },
                puntosPositivos = new
                {
                    type = "array",
                    items = new { type = "string" }
                },
                aspectosAMejorar = new
                {
                    type = "array",
                    items = new { type = "string" }
                },
                sugerenciasEntrenamiento = new
                {
                    type = "array",
                    items = new { type = "string" }
                },
                analisisZonas = new { type = "string" }
            }
        };
    }

    private static string ExtractOutputText(JsonElement root)
    {
        if (TryGetStringProperty(root, "output_text", out var outputText) ||
            TryGetStringProperty(root, "outputText", out outputText) ||
            TryGetCandidateText(root, out outputText))
        {
            return outputText;
        }

        return FindJsonText(root) ?? string.Empty;
    }

    private static bool TryGetStringProperty(JsonElement root, string propertyName, out string value)
    {
        if (root.TryGetProperty(propertyName, out var property) &&
            property.ValueKind == JsonValueKind.String)
        {
            value = property.GetString() ?? string.Empty;
            return true;
        }

        value = string.Empty;
        return false;
    }

    private static bool TryGetCandidateText(JsonElement root, out string value)
    {
        value = string.Empty;

        if (!root.TryGetProperty("candidates", out var candidates) ||
            candidates.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        foreach (var candidate in candidates.EnumerateArray())
        {
            if (!candidate.TryGetProperty("content", out var content) ||
                !content.TryGetProperty("parts", out var parts) ||
                parts.ValueKind != JsonValueKind.Array)
            {
                continue;
            }

            var builder = new StringBuilder();
            foreach (var part in parts.EnumerateArray())
            {
                if (TryGetStringProperty(part, "text", out var partText) &&
                    !string.IsNullOrWhiteSpace(partText))
                {
                    builder.Append(partText);
                }
            }

            value = builder.ToString();
            if (!string.IsNullOrWhiteSpace(value)) return true;
        }

        return false;
    }

    private static string? FindJsonText(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.String:
                var value = element.GetString();
                return LooksLikeJsonObject(value) ? value : null;
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    var nested = FindJsonText(property.Value);
                    if (!string.IsNullOrWhiteSpace(nested)) return nested;
                }
                break;
            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    var nested = FindJsonText(item);
                    if (!string.IsNullOrWhiteSpace(nested)) return nested;
                }
                break;
        }

        return null;
    }

    private static bool LooksLikeJsonObject(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return false;
        var trimmed = value.Trim();
        return trimmed.StartsWith('{') && trimmed.EndsWith('}');
    }

    private static object BuildInputData(Partido partido, IReadOnlyList<EventoPartido> eventos)
    {
        var eventosConUbicacion = eventos
            .Where(e => HasValidLocation(e))
            .ToList();
        var puedeAnalizarZonas = eventosConUbicacion.Count >= MinEventosParaZonas;

        var countByType = eventos
            .GroupBy(EventName)
            .Where(group => !string.IsNullOrWhiteSpace(group.Key))
            .ToDictionary(group => group.Key, group => group.Count());

        var jugadores = eventos
            .Where(e => e.Jugador is not null)
            .GroupBy(e => $"{e.Jugador!.Nombre} {e.Jugador.Apellido}".Trim())
            .OrderByDescending(group => group.Count())
            .Take(10)
            .Select(group => new
            {
                nombre = group.Key,
                eventos = group.Count(),
                tipos = group
                    .GroupBy(EventName)
                    .Where(typeGroup => !string.IsNullOrWhiteSpace(typeGroup.Key))
                    .ToDictionary(typeGroup => typeGroup.Key, typeGroup => typeGroup.Count())
            })
            .ToList();

        return new
        {
            partido = new
            {
                partidoId = partido.PartidoId,
                rival = partido.Rival,
                condicion = partido.EsLocal ? "Local" : "Visitante",
                categoria = partido.Categoria?.Nombre,
                tipoCompeticion = partido.TipoCompeticion,
                estado = partido.Estado,
                golesEquipo = partido.GolesEquipo,
                golesRival = partido.GolesRival,
                minutoActual = partido.MinutoActual,
                fecha = partido.Fecha
            },
            reglas = new
            {
                usarSoloEventosReales = true,
                totalEventosRegistrados = eventos.Count,
                eventosSinJugador = eventos.Count(e => e.Jugador is null),
                eventosConUbicacion = eventosConUbicacion.Count,
                minimoEventosParaAnalisis = MinEventosParaAnalisis,
                minimoEventosParaAnalisisPorZonas = MinEventosParaZonas,
                puedeAnalizarZonas,
                datosLimitados = eventos.Count < 8,
                eventosSinUbicacion = eventos.Count - eventosConUbicacion.Count,
                indicacionDatosLimitados = eventos.Count < 8
                    ? "Hay pocos eventos registrados. El analisis debe ser prudente y no sacar conclusiones fuertes."
                    : null
            },
            metricas = new
            {
                totalEventos = eventos.Count,
                porTipo = countByType,
                goles = Count(eventos, EventTypeNames.Gol),
                golesRivales = Count(eventos, EventTypeNames.GolRival),
                asistencias = Count(eventos, EventTypeNames.Asistencia),
                remates = Count(eventos, EventTypeNames.Remate),
                faltas = Count(eventos, EventTypeNames.Falta),
                tarjetasAmarillas = Count(eventos, EventTypeNames.TarjetaAmarilla),
                tarjetasRojas = Count(eventos, EventTypeNames.TarjetaRoja),
                recuperaciones = Count(eventos, "Recuperaci\u00f3n", "Recuperacion"),
                intercepciones = Count(eventos, "Intercepci\u00f3n", "Intercepcion"),
                perdidas = Count(eventos, "P\u00e9rdida", "Perdida"),
                pasesCorrectos = Count(eventos, "Pase correcto"),
                pasesIncorrectos = Count(eventos, "Pase incorrecto"),
                pasesClave = Count(eventos, "Pase clave"),
                primerTiempo = eventos.Count(e => e.Minuto <= 45),
                segundoTiempo = eventos.Count(e => e.Minuto > 45)
            },
            jugadores,
            zonas = puedeAnalizarZonas
                ? BuildZoneSummary(eventosConUbicacion)
                : null,
            eventos = eventos.Select(e => new
            {
                minuto = e.Minuto,
                tipo = EventName(e),
                jugador = e.Jugador is null ? null : $"{e.Jugador.Nombre} {e.Jugador.Apellido}".Trim(),
                pitchX = e.PitchX,
                pitchY = e.PitchY
            })
        };
    }

    private static object BuildZoneSummary(IReadOnlyList<EventoPartido> eventos)
    {
        var actividadPorTercio = eventos
            .GroupBy(e => LongitudinalZone(e.PitchY!.Value))
            .ToDictionary(group => group.Key, group => group.Count());

        var actividadPorCarril = eventos
            .GroupBy(e => Lane(e.PitchX!.Value))
            .ToDictionary(group => group.Key, group => group.Count());

        var tercioPrincipal = actividadPorTercio
            .OrderByDescending(entry => entry.Value)
            .First().Key;
        var carrilPrincipal = actividadPorCarril
            .OrderByDescending(entry => entry.Value)
            .First().Key;

        return new
        {
            totalEventosConUbicacion = eventos.Count,
            minimoUsado = MinEventosParaZonas,
            zonaConMasEventos = $"{tercioPrincipal}, {carrilPrincipal}",
            actividadPorTercio,
            actividadPorCarril,
            rematesPorZona = CountZonesForTypes(eventos, EventTypeNames.Remate),
            golesPorZona = CountZonesForTypes(eventos, EventTypeNames.Gol),
            perdidasPorZona = CountZonesForTypes(eventos, "P\u00e9rdida", "Perdida"),
            faltasPorZona = CountZonesForTypes(eventos, EventTypeNames.Falta)
        };
    }

    private static IReadOnlyDictionary<string, int> CountZonesForTypes(
        IReadOnlyList<EventoPartido> eventos,
        params string[] types)
    {
        return eventos
            .Where(e => types.Contains(EventName(e), StringComparer.OrdinalIgnoreCase))
            .GroupBy(e => $"{LongitudinalZone(e.PitchY!.Value)}, {Lane(e.PitchX!.Value)}")
            .ToDictionary(group => group.Key, group => group.Count());
    }

    private static string LongitudinalZone(decimal pitchY)
    {
        var value = (double)pitchY;
        if (value < 0.33) return "campo propio";
        if (value < 0.66) return "mitad de cancha";
        return "campo rival";
    }

    private static string Lane(decimal pitchX)
    {
        var value = (double)pitchX;
        if (value < 0.33) return "sector izquierdo";
        if (value < 0.66) return "sector central";
        return "sector derecho";
    }

    private static bool HasValidLocation(EventoPartido evento)
    {
        return evento.PitchX is >= 0 and <= 1 &&
               evento.PitchY is >= 0 and <= 1;
    }

    private static int Count(IReadOnlyList<EventoPartido> eventos, params string[] types)
    {
        return eventos.Count(e => types.Contains(EventName(e), StringComparer.OrdinalIgnoreCase));
    }

    private static string EventName(EventoPartido evento)
    {
        return evento.TipoEvento?.Nombre ?? string.Empty;
    }

    private static string BuildInstructions()
    {
        return """
        Sos un asistente de analisis deportivo para el cuerpo tecnico de Colon FC.
        Tu tarea es leer datos reales de un partido y devolver una lectura breve, prudente y util.

        Reglas obligatorias:
        - Usa unicamente el JSON recibido. No inventes jugadores, eventos, marcadores, metricas, zonas ni contexto externo.
        - No menciones posesion, xG, distancia recorrida, intensidad fisica, cambios, formaciones tacticas ni datos que no esten en el JSON.
        - Si hay pocos eventos, aclara que la lectura es preliminar y evita conclusiones fuertes.
        - Si un evento no tiene jugador, podes mencionarlo como accion sin jugador asociado, pero no atribuirlo a nadie.
        - No hagas predicciones, no elijas titulares, no des recomendaciones medicas y no uses lenguaje tecnico innecesario.
        - Escribi en espanol rioplatense claro, profesional y orientado al cuerpo tecnico.
        - Devolve exclusivamente un objeto JSON valido, sin markdown, sin ```json y sin texto antes o despues.

        Estructura de respuesta:
        - resumenGeneral: 2 o 3 frases. Debe explicar que se observa del partido sin exagerar.
        - puntosPositivos: maximo 4 puntos concretos respaldados por eventos.
        - aspectosAMejorar: maximo 4 puntos concretos respaldados por eventos.
        - sugerenciasEntrenamiento: maximo 4 sugerencias entrenables y realistas, conectadas con lo observado.
        - analisisZonas: solo escribir si reglas.puedeAnalizarZonas es true y zonas no es null. Si no, devolver string vacio.

        Para el analisis por zonas:
        - Usalo solo como apoyo, no como verdad absoluta.
        - No digas que el equipo domina una zona si hay pocos eventos.
        - Si reglas.puedeAnalizarZonas es false, analisisZonas debe ser exactamente "".
        """;
    }

    private static AnalisisPartidoResponse EmptyResponse(string message)
    {
        return new AnalisisPartidoResponse(
            string.Empty,
            [],
            [],
            [],
            string.Empty,
            false,
            message);
    }

    private static string FriendlyGeminiMessage(HttpStatusCode statusCode)
    {
        return statusCode switch
        {
            HttpStatusCode.Unauthorized =>
                "La clave de IA no es valida o fue desactivada. Genera una clave nueva y reinicia el backend.",
            HttpStatusCode.Forbidden =>
                "La cuenta no tiene permiso para usar Gemini API o el modelo configurado.",
            HttpStatusCode.TooManyRequests =>
                "La cuota gratuita de IA se agoto por ahora o se alcanzo el limite de uso.",
            HttpStatusCode.BadRequest or HttpStatusCode.NotFound =>
                "El modelo de IA configurado no esta disponible. Revisa la configuracion del backend.",
            HttpStatusCode.RequestTimeout or HttpStatusCode.InternalServerError or HttpStatusCode.BadGateway or
                HttpStatusCode.ServiceUnavailable or HttpStatusCode.GatewayTimeout =>
                "No se pudo conectar con el servicio de IA. Verifica internet e intenta nuevamente.",
            _ => MensajeErrorIa
        };
    }

    private sealed class GeminiRequestException(HttpStatusCode statusCode, string responseBody)
        : Exception($"Gemini respondio con estado {(int)statusCode}.")
    {
        public HttpStatusCode StatusCode { get; } = statusCode;
        public string ResponseBody { get; } = TrimResponse(responseBody);

        private static string TrimResponse(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return string.Empty;
            return value.Length <= 1000 ? value : value[..1000];
        }
    }

    private sealed class AiAnalysisPayload
    {
        public string ResumenGeneral { get; set; } = string.Empty;
        public List<string> PuntosPositivos { get; set; } = [];
        public List<string> AspectosAMejorar { get; set; } = [];
        public List<string> SugerenciasEntrenamiento { get; set; } = [];
        public string AnalisisZonas { get; set; } = string.Empty;

        public bool HasContent =>
            !string.IsNullOrWhiteSpace(ResumenGeneral) ||
            PuntosPositivos.Count > 0 ||
            AspectosAMejorar.Count > 0 ||
            SugerenciasEntrenamiento.Count > 0 ||
            !string.IsNullOrWhiteSpace(AnalisisZonas);

        public void Normalize(bool puedeAnalizarZonas)
        {
            ResumenGeneral = CleanText(ResumenGeneral);
            PuntosPositivos = CleanList(PuntosPositivos);
            AspectosAMejorar = CleanList(AspectosAMejorar);
            SugerenciasEntrenamiento = CleanList(SugerenciasEntrenamiento);
            AnalisisZonas = puedeAnalizarZonas ? CleanText(AnalisisZonas) : string.Empty;
        }

        private static string CleanText(string? value)
        {
            return string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim();
        }

        private static List<string> CleanList(List<string>? values)
        {
            if (values is null) return [];

            return values
                .Select(CleanText)
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(MaxItemsPorSeccion)
                .ToList();
        }
    }
}

public record AnalisisPartidoResponse(
    string ResumenGeneral,
    IReadOnlyList<string> PuntosPositivos,
    IReadOnlyList<string> AspectosAMejorar,
    IReadOnlyList<string> SugerenciasEntrenamiento,
    string AnalisisZonas,
    bool GeneradoConIa,
    string? Mensaje);
