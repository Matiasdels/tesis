-- 07_roles_actores.sql
-- Alinea los roles del sistema con los actores definidos en el documento.
-- Se puede ejecutar sobre bases existentes sin perder usuarios.

IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Admin')
   AND NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Responsable institucional')
BEGIN
    UPDATE dbo.Roles
    SET Nombre = N'Responsable institucional'
    WHERE Nombre = N'Admin';
END
GO

IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Entrenador')
   AND NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Cuerpo tecnico')
BEGIN
    UPDATE dbo.Roles
    SET Nombre = N'Cuerpo tecnico'
    WHERE Nombre = N'Entrenador';
END
GO

DECLARE @CuerpoTecnicoRolId INT;
SELECT @CuerpoTecnicoRolId = RolId
FROM dbo.Roles
WHERE Nombre = N'Cuerpo tecnico';

IF @CuerpoTecnicoRolId IS NOT NULL
BEGIN
    UPDATE dbo.Usuarios
    SET RolId = @CuerpoTecnicoRolId
    WHERE RolId IN (
        SELECT RolId
        FROM dbo.Roles
        WHERE Nombre IN (N'Asistente', N'Analista', N'Preparador fisico')
    );

    DELETE FROM dbo.Roles
    WHERE Nombre IN (N'Asistente', N'Analista', N'Preparador fisico');
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Responsable institucional')
BEGIN
    INSERT INTO dbo.Roles (Nombre)
    VALUES (N'Responsable institucional');
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE Nombre = N'Cuerpo tecnico')
BEGIN
    INSERT INTO dbo.Roles (Nombre)
    VALUES (N'Cuerpo tecnico');
END
GO
