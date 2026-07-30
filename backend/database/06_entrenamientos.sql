-- 06_entrenamientos.sql
-- Tablas para gestión de entrenamientos y asistencia de jugadores.

CREATE TABLE Entrenamientos (
    EntrenamientoId INT           IDENTITY(1,1) PRIMARY KEY,
    CategoriaId     INT           NOT NULL REFERENCES Categorias(CategoriaId),
    Fecha           DATE          NOT NULL,
    Descripcion     NVARCHAR(200) NULL
);

CREATE TABLE AsistenciaEntrenamiento (
    EntrenamientoId INT  NOT NULL REFERENCES Entrenamientos(EntrenamientoId) ON DELETE CASCADE,
    JugadorId       INT  NOT NULL REFERENCES Jugadores(JugadorId),
    Asistio         BIT  NOT NULL DEFAULT 1,
    CONSTRAINT PK_AsistenciaEntrenamiento PRIMARY KEY (EntrenamientoId, JugadorId)
);
