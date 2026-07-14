-- =============================================================================
-- Kancha - Migración 03: Alargue
-- Agrega campos de definición de empate, período actual y período de evento
-- =============================================================================

ALTER TABLE Partidos
ADD DefinicionEmpate NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Partidos_DefinicionEmpate DEFAULT 'TerminaEnEmpate' WITH VALUES,
    PeriodoActual NVARCHAR(30) NULL,
    HuboAlargue BIT NOT NULL
        CONSTRAINT DF_Partidos_HuboAlargue DEFAULT 0 WITH VALUES;
GO

ALTER TABLE EventosPartido
ADD Periodo NVARCHAR(30) NULL;
GO
