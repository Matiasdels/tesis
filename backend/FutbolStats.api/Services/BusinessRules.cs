namespace FutbolStats.Api.Services;

public static class BusinessRules
{
    public static string NormalizeRequiredText(string value, string fieldName)
    {
        var normalized = value.Trim();

        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new ArgumentException($"{fieldName} es obligatorio.", fieldName);
        }

        return normalized;
    }

    public static string? NormalizeOptionalText(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }
}
