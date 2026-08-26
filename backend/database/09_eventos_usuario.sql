-- 09_eventos_usuario.sql
-- Agrega trazabilidad del usuario que registra cada evento de partido.

IF COL_LENGTH('dbo.EventosPartido', 'UsuarioId') IS NULL
BEGIN
    ALTER TABLE dbo.EventosPartido
    ADD UsuarioId INT NULL;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = 'FK_EventosPartido_Usuarios'
      AND parent_object_id = OBJECT_ID('dbo.EventosPartido')
)
BEGIN
    ALTER TABLE dbo.EventosPartido
    ADD CONSTRAINT FK_EventosPartido_Usuarios
        FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios (UsuarioId);
END
GO
