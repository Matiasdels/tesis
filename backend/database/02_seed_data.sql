-- =============================================================================
-- Kancha - Datos semilla (catalogos)
-- =============================================================================

-- Categorias
INSERT INTO Categorias (Nombre, Descripcion) VALUES
    (N'Primera', N'Plantel principal');

-- Roles
INSERT INTO Roles (Nombre) VALUES
    (N'Admin'),
    (N'Entrenador'),
    (N'Asistente'),
    (N'Analista'),
    (N'Preparador fisico');

-- TiposEvento (basado en EventTypes del frontend)
INSERT INTO TiposEvento (Nombre) VALUES
    (N'Pase correcto'),
    (N'Pase incorrecto'),
    (N'Remate'),
    (N'Gol'),
    (N'Recuperación'),
    (N'Falta'),
    (N'Intercepción'),
    (N'Centro'),
    (N'Asistencia'),
    (N'Tarjeta amarilla'),
    (N'Tarjeta roja'),
    (N'Atajada'),
    (N'Corner'),
    (N'Offside'),
    (N'Pérdida'),
    (N'Entrada exitosa'),
    (N'Entrada fallida');
