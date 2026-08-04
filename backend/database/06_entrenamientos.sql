-- 06_entrenamientos.sql
-- Compatibilidad/idempotencia para entrenamientos y asistencias.
-- El esquema principal ya vive en 01_create_tables.sql. Este script se puede
-- ejecutar despues sin romper una base nueva ni una base creada parcialmente.

IF OBJECT_ID('dbo.Entrenamientos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Entrenamientos (
        EntrenamientoId     INT IDENTITY(1,1)   NOT NULL,
        CategoriaId         INT                 NOT NULL,
        Fecha               DATETIME2           NOT NULL,
        Titulo              NVARCHAR(150)       NOT NULL,
        Tipo                NVARCHAR(20)        NOT NULL,
        DuracionMinutos     INT                 NULL,
        Lugar               NVARCHAR(150)       NULL,
        CONSTRAINT PK_Entrenamientos PRIMARY KEY (EntrenamientoId),
        CONSTRAINT FK_Entrenamientos_Categorias FOREIGN KEY (CategoriaId) REFERENCES dbo.Categorias (CategoriaId)
    );
END
GO

IF COL_LENGTH('dbo.Entrenamientos', 'Titulo') IS NULL
BEGIN
    ALTER TABLE dbo.Entrenamientos
    ADD Titulo NVARCHAR(150) NOT NULL
        CONSTRAINT DF_Entrenamientos_Titulo DEFAULT N'Entrenamiento';
END
GO

IF COL_LENGTH('dbo.Entrenamientos', 'Tipo') IS NULL
BEGIN
    ALTER TABLE dbo.Entrenamientos
    ADD Tipo NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Entrenamientos_Tipo DEFAULT N'General';
END
GO

IF COL_LENGTH('dbo.Entrenamientos', 'DuracionMinutos') IS NULL
BEGIN
    ALTER TABLE dbo.Entrenamientos
    ADD DuracionMinutos INT NULL;
END
GO

IF COL_LENGTH('dbo.Entrenamientos', 'Lugar') IS NULL
BEGIN
    ALTER TABLE dbo.Entrenamientos
    ADD Lugar NVARCHAR(150) NULL;
END
GO

IF OBJECT_ID('dbo.AsistenciasEntrenamiento', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AsistenciasEntrenamiento (
        AsistenciaId        INT IDENTITY(1,1)   NOT NULL,
        EntrenamientoId     INT                 NOT NULL,
        JugadorId           INT                 NOT NULL,
        Asistio             BIT                 NOT NULL DEFAULT 0,
        Rpe                 DECIMAL(3,1)        NULL,
        Observacion         NVARCHAR(255)       NULL,
        CONSTRAINT PK_AsistenciasEntrenamiento PRIMARY KEY (AsistenciaId),
        CONSTRAINT UQ_Asistencias_Entrenamiento_Jugador UNIQUE (EntrenamientoId, JugadorId),
        CONSTRAINT FK_Asistencias_Entrenamientos FOREIGN KEY (EntrenamientoId) REFERENCES dbo.Entrenamientos (EntrenamientoId),
        CONSTRAINT FK_Asistencias_Jugadores FOREIGN KEY (JugadorId) REFERENCES dbo.Jugadores (JugadorId)
    );
END
GO

IF COL_LENGTH('dbo.AsistenciasEntrenamiento', 'Rpe') IS NULL
BEGIN
    ALTER TABLE dbo.AsistenciasEntrenamiento
    ADD Rpe DECIMAL(3,1) NULL;
END
GO

IF COL_LENGTH('dbo.AsistenciasEntrenamiento', 'Observacion') IS NULL
BEGIN
    ALTER TABLE dbo.AsistenciasEntrenamiento
    ADD Observacion NVARCHAR(255) NULL;
END
GO
