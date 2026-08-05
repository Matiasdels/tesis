-- =============================================================================
-- Kancha - Modelo de base de datos (MVP)
-- SQL Server
-- Las validaciones de negocio se resuelven en el backend .NET.
-- Este script solo define estructura, relaciones e integridad referencial.
-- =============================================================================

-- =============================================================================
-- Roles
-- =============================================================================
CREATE TABLE Roles (
    RolId       INT IDENTITY(1,1) NOT NULL,
    Nombre      NVARCHAR(50)      NOT NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (RolId),
    CONSTRAINT UQ_Roles_Nombre UNIQUE (Nombre)
);
GO

-- =============================================================================
-- Usuarios
-- =============================================================================
CREATE TABLE Usuarios (
    UsuarioId       INT IDENTITY(1,1)   NOT NULL,
    NombreUsuario   NVARCHAR(50)        NOT NULL,
    Email           NVARCHAR(100)       NOT NULL,
    PasswordHash    NVARCHAR(255)       NOT NULL,
    Nombre          NVARCHAR(100)       NOT NULL,
    Apellido        NVARCHAR(100)       NOT NULL,
    RolId           INT                 NOT NULL,
    Activo          BIT                 NOT NULL DEFAULT 1,
    FechaCreacion   DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Usuarios PRIMARY KEY (UsuarioId),
    CONSTRAINT UQ_Usuarios_NombreUsuario UNIQUE (NombreUsuario),
    CONSTRAINT UQ_Usuarios_Email UNIQUE (Email),
    CONSTRAINT FK_Usuarios_Roles FOREIGN KEY (RolId) REFERENCES Roles (RolId)
);
GO

-- =============================================================================
-- Categorias
-- =============================================================================
CREATE TABLE Categorias (
    CategoriaId     INT IDENTITY(1,1)   NOT NULL,
    Nombre          NVARCHAR(50)        NOT NULL,
    Descripcion     NVARCHAR(255)       NULL,
    CONSTRAINT PK_Categorias PRIMARY KEY (CategoriaId)
);
GO

-- =============================================================================
-- Jugadores
-- =============================================================================
CREATE TABLE Jugadores (
    JugadorId           INT IDENTITY(1,1)   NOT NULL,
    Nombre              NVARCHAR(100)       NOT NULL,
    Apellido            NVARCHAR(100)       NOT NULL,
    FechaNacimiento     DATE                NULL,
    Nacionalidad        NVARCHAR(50)        NULL,
    DNI                 NVARCHAR(20)        NULL,
    PosicionPrincipal   NVARCHAR(10)        NULL,
    NumeroCamiseta      INT                 NULL,
    AlturaCm            DECIMAL(5,2)        NULL,
    PesoKg              DECIMAL(5,2)        NULL,
    PiernaHabil         NVARCHAR(10)        NULL,
    Estado              NVARCHAR(20)        NOT NULL DEFAULT 'Disponible',
    PartidosSuspendido  INT                 NULL,
    FechaEstimadaRegreso DATE               NULL,
    CategoriaId         INT                 NOT NULL,
    Activo              BIT                 NOT NULL DEFAULT 1,
    CONSTRAINT PK_Jugadores PRIMARY KEY (JugadorId),
    CONSTRAINT FK_Jugadores_Categorias FOREIGN KEY (CategoriaId) REFERENCES Categorias (CategoriaId)
);
GO

CREATE UNIQUE INDEX IX_Jugadores_DNI
    ON Jugadores (DNI)
    WHERE DNI IS NOT NULL;
GO

-- =============================================================================
-- Partidos
-- =============================================================================
CREATE TABLE Partidos (
    PartidoId           INT IDENTITY(1,1)   NOT NULL,
    CategoriaId         INT                 NOT NULL,
    Rival               NVARCHAR(100)       NOT NULL,
    EsLocal             BIT                 NOT NULL,
    Fecha               DATETIME2           NOT NULL,
    TipoCompeticion     NVARCHAR(20)        NOT NULL DEFAULT 'Amistoso',
    Lugar               NVARCHAR(150)       NULL,
    Estado              NVARCHAR(20)        NOT NULL DEFAULT 'Programado',
    GolesEquipo         INT                 NULL,
    GolesRival          INT                 NULL,
    MinutoActual        INT                 NULL,
    UsuarioCreadorId    INT                 NULL,
    Activo              BIT                 NOT NULL DEFAULT 1,
    Formacion           NVARCHAR(20)        NULL,
    CONSTRAINT PK_Partidos PRIMARY KEY (PartidoId),
    CONSTRAINT FK_Partidos_Categorias FOREIGN KEY (CategoriaId) REFERENCES Categorias (CategoriaId),
    CONSTRAINT FK_Partidos_Usuarios FOREIGN KEY (UsuarioCreadorId) REFERENCES Usuarios (UsuarioId)
);
GO

-- =============================================================================
-- Alineaciones
-- =============================================================================
CREATE TABLE Alineaciones (
    AlineacionId        INT IDENTITY(1,1)   NOT NULL,
    PartidoId           INT                 NOT NULL,
    JugadorId           INT                 NOT NULL,
    EsTitular           BIT                 NOT NULL DEFAULT 0,
    PosicionAsignada    NVARCHAR(10)        NULL,
    CONSTRAINT PK_Alineaciones PRIMARY KEY (AlineacionId),
    CONSTRAINT UQ_Alineaciones_Partido_Jugador UNIQUE (PartidoId, JugadorId),
    CONSTRAINT FK_Alineaciones_Partidos FOREIGN KEY (PartidoId) REFERENCES Partidos (PartidoId),
    CONSTRAINT FK_Alineaciones_Jugadores FOREIGN KEY (JugadorId) REFERENCES Jugadores (JugadorId)
);
GO

-- =============================================================================
-- TiposEvento (catalogo)
-- =============================================================================
CREATE TABLE TiposEvento (
    TipoEventoId    INT IDENTITY(1,1)   NOT NULL,
    Nombre          NVARCHAR(50)        NOT NULL,
    CONSTRAINT PK_TiposEvento PRIMARY KEY (TipoEventoId),
    CONSTRAINT UQ_TiposEvento_Nombre UNIQUE (Nombre)
);
GO

-- =============================================================================
-- EventosPartido
-- =============================================================================
CREATE TABLE EventosPartido (
    EventoId                INT IDENTITY(1,1)   NOT NULL,
    PartidoId               INT                 NOT NULL,
    JugadorId               INT                 NULL,
    TipoEventoId            INT                 NOT NULL,
    Minuto                  INT                 NOT NULL,
    PitchX                  DECIMAL(4,3)        NULL,
    PitchY                  DECIMAL(4,3)        NULL,
    JugadorRelacionadoId    INT                 NULL,
    Observacion             NVARCHAR(255)       NULL,
    FechaRegistro           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_EventosPartido PRIMARY KEY (EventoId),
    CONSTRAINT FK_EventosPartido_Partidos FOREIGN KEY (PartidoId) REFERENCES Partidos (PartidoId),
    CONSTRAINT FK_EventosPartido_Jugadores FOREIGN KEY (JugadorId) REFERENCES Jugadores (JugadorId),
    CONSTRAINT FK_EventosPartido_TiposEvento FOREIGN KEY (TipoEventoId) REFERENCES TiposEvento (TipoEventoId),
    CONSTRAINT FK_EventosPartido_JugadorRelacionado FOREIGN KEY (JugadorRelacionadoId) REFERENCES Jugadores (JugadorId)
);
GO

-- =============================================================================
-- Entrenamientos
-- =============================================================================
CREATE TABLE Entrenamientos (
    EntrenamientoId     INT IDENTITY(1,1)   NOT NULL,
    CategoriaId         INT                 NOT NULL,
    Fecha               DATETIME2           NOT NULL,
    Titulo              NVARCHAR(150)       NOT NULL,
    Tipo                NVARCHAR(20)        NOT NULL,
    DuracionMinutos     INT                 NULL,
    Lugar               NVARCHAR(150)       NULL,
    Activo              BIT                 NOT NULL DEFAULT 1,
    CONSTRAINT PK_Entrenamientos PRIMARY KEY (EntrenamientoId),
    CONSTRAINT FK_Entrenamientos_Categorias FOREIGN KEY (CategoriaId) REFERENCES Categorias (CategoriaId)
);
GO

-- =============================================================================
-- AsistenciasEntrenamiento
-- =============================================================================
CREATE TABLE AsistenciasEntrenamiento (
    AsistenciaId        INT IDENTITY(1,1)   NOT NULL,
    EntrenamientoId     INT                 NOT NULL,
    JugadorId           INT                 NOT NULL,
    Asistio             BIT                 NOT NULL DEFAULT 0,
    Rpe                 DECIMAL(3,1)        NULL,
    Observacion         NVARCHAR(255)       NULL,
    CONSTRAINT PK_AsistenciasEntrenamiento PRIMARY KEY (AsistenciaId),
    CONSTRAINT UQ_Asistencias_Entrenamiento_Jugador UNIQUE (EntrenamientoId, JugadorId),
    CONSTRAINT FK_Asistencias_Entrenamientos FOREIGN KEY (EntrenamientoId) REFERENCES Entrenamientos (EntrenamientoId),
    CONSTRAINT FK_Asistencias_Jugadores FOREIGN KEY (JugadorId) REFERENCES Jugadores (JugadorId)
);
GO

-- =============================================================================
-- Observaciones
-- =============================================================================
CREATE TABLE Observaciones (
    ObservacionId   INT IDENTITY(1,1)   NOT NULL,
    JugadorId       INT                 NOT NULL,
    UsuarioId       INT                 NOT NULL,
    Fecha           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    Tipo            NVARCHAR(20)        NOT NULL,
    Contenido       NVARCHAR(1000)      NOT NULL,
    CONSTRAINT PK_Observaciones PRIMARY KEY (ObservacionId),
    CONSTRAINT FK_Observaciones_Jugadores FOREIGN KEY (JugadorId) REFERENCES Jugadores (JugadorId),
    CONSTRAINT FK_Observaciones_Usuarios FOREIGN KEY (UsuarioId) REFERENCES Usuarios (UsuarioId)
);
GO
