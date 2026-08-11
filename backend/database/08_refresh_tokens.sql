-- 08_refresh_tokens.sql
-- Agrega soporte para refresh tokens y renovación silenciosa de sesión.

IF OBJECT_ID('dbo.RefreshTokens', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RefreshTokens (
        RefreshTokenId      INT IDENTITY(1,1)   NOT NULL,
        UsuarioId           INT                 NOT NULL,
        TokenHash           NVARCHAR(128)       NOT NULL,
        FechaCreacion       DATETIME2           NOT NULL
            CONSTRAINT DF_RefreshTokens_FechaCreacion DEFAULT SYSUTCDATETIME(),
        ExpiresAt           DATETIME2           NOT NULL,
        RevokedAt           DATETIME2           NULL,
        ReplacedByTokenHash NVARCHAR(128)       NULL,
        CONSTRAINT PK_RefreshTokens PRIMARY KEY (RefreshTokenId),
        CONSTRAINT UQ_RefreshTokens_TokenHash UNIQUE (TokenHash),
        CONSTRAINT FK_RefreshTokens_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId)
    );
END
GO
