namespace FutbolStats.Api.Services;

public static class BusinessRules
{
    /// <summary>
    /// Normaliza un campo de texto obligatorio y lanza <see cref="DomainValidationException"/>
    /// (→ HTTP 400) si el valor está vacío o es solo espacios.
    /// </summary>
    public static string NormalizeRequiredText(string? value, string fieldName)
    {
        var normalized = value?.Trim();

        if (string.IsNullOrWhiteSpace(normalized))
            throw new DomainValidationException($"{fieldName} es obligatorio.", fieldName);

        return normalized;
    }

    public static string? NormalizeOptionalText(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }
}
