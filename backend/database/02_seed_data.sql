-- =============================================================================
-- Kancha - Datos semilla (catalogos)
-- =============================================================================

-- Categorias
INSERT INTO Categorias (Nombre, Descripcion) VALUES
    (N'Primera', N'Plantel principal');

-- Roles
INSERT INTO Roles (Nombre) VALUES
    (N'Responsable institucional'),
    (N'Cuerpo tecnico');

-- TiposEvento (basado en EventTypes del frontend)
INSERT INTO TiposEvento (Nombre) VALUES
    -- Legacy (no disponibles para registro nuevo, se mantienen para historial)
    (N'Pase correcto'),
    (N'Pase incorrecto'),
    (N'Entrada exitosa'),
    (N'Entrada fallida'),
    -- Activos
    (N'Remate'),
    (N'Remate al arco'),
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
    (N'Pase clave'),
    (N'Penal a favor'),
    (N'Penal en contra');
