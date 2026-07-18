-- Migración 04: Definición por penales
-- Ejecutar sobre la BD ya actualizada con 03_alargue.sql

ALTER TABLE Partidos
ADD HuboPenales BIT NOT NULL
        CONSTRAINT DF_Partidos_HuboPenales DEFAULT 0 WITH VALUES,
    ResultadoPenalesEquipo INT NULL,
    ResultadoPenalesRival  INT NULL;

CREATE TABLE PenalDetalle (
    PenalDetalleId INT IDENTITY(1,1) PRIMARY KEY,
    PartidoId      INT NOT NULL,
    Equipo         NVARCHAR(10)  NOT NULL,   -- 'Propio' | 'Rival'
    JugadorId      INT NULL,
    Resultado      NVARCHAR(10)  NOT NULL,   -- 'Gol' | 'Errado'
    Orden          INT NOT NULL,
    Activo         BIT NOT NULL
                       CONSTRAINT DF_PenalDetalle_Activo DEFAULT 1,
    CONSTRAINT FK_PenalDetalle_Partidos  FOREIGN KEY (PartidoId) REFERENCES Partidos(PartidoId),
    CONSTRAINT FK_PenalDetalle_Jugadores FOREIGN KEY (JugadorId) REFERENCES Jugadores(JugadorId)
);
