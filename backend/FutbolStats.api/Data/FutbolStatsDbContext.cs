using FutbolStats.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Data;

public class FutbolStatsDbContext(DbContextOptions<FutbolStatsDbContext> options) : DbContext(options)
{
    public DbSet<Rol> Roles => Set<Rol>();
    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<Categoria> Categorias => Set<Categoria>();
    public DbSet<Jugador> Jugadores => Set<Jugador>();
    public DbSet<Partido> Partidos => Set<Partido>();
    public DbSet<Alineacion> Alineaciones => Set<Alineacion>();
    public DbSet<TipoEvento> TiposEvento => Set<TipoEvento>();
    public DbSet<EventoPartido> EventosPartido => Set<EventoPartido>();
    public DbSet<Observacion> Observaciones => Set<Observacion>();
    public DbSet<PenalDetalle> PenalesDetalle => Set<PenalDetalle>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Rol>(entity =>
        {
            entity.ToTable("Roles");
            entity.HasKey(x => x.RolId);
            entity.Property(x => x.Nombre).HasMaxLength(50).IsRequired();
            entity.HasIndex(x => x.Nombre).IsUnique();
        });

        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.ToTable("Usuarios");
            entity.HasKey(x => x.UsuarioId);
            entity.Property(x => x.NombreUsuario).HasMaxLength(50).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(100).IsRequired();
            entity.Property(x => x.PasswordHash).HasMaxLength(255).IsRequired();
            entity.Property(x => x.Nombre).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Apellido).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Activo).HasDefaultValue(true);
            entity.Property(x => x.FechaCreacion).HasDefaultValueSql("SYSDATETIME()");
            entity.HasIndex(x => x.NombreUsuario).IsUnique();
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasOne(x => x.Rol)
                .WithMany()
                .HasForeignKey(x => x.RolId);
        });

        modelBuilder.Entity<Categoria>(entity =>
        {
            entity.ToTable("Categorias");
            entity.HasKey(x => x.CategoriaId);
            entity.Property(x => x.Nombre).HasMaxLength(50).IsRequired();
            entity.Property(x => x.Descripcion).HasMaxLength(255);
        });

        modelBuilder.Entity<Jugador>(entity =>
        {
            entity.ToTable("Jugadores");
            entity.HasKey(x => x.JugadorId);
            entity.Property(x => x.Nombre).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Apellido).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Dni).HasColumnName("DNI").HasMaxLength(20);
            entity.HasIndex(x => x.Dni).IsUnique().HasFilter("[DNI] IS NOT NULL");
            entity.Property(x => x.Nacionalidad).HasMaxLength(50);
            entity.Property(x => x.PosicionPrincipal).HasMaxLength(10);
            entity.Property(x => x.AlturaCm).HasPrecision(5, 2);
            entity.Property(x => x.PesoKg).HasPrecision(5, 2);
            entity.Property(x => x.PiernaHabil).HasMaxLength(10);
            entity.Property(x => x.Estado).HasMaxLength(20).HasDefaultValue("Disponible");
            entity.Property(x => x.FechaEstimadaRegreso).HasColumnType("date");
            entity.Property(x => x.Activo).HasDefaultValue(true);
            entity.HasOne(x => x.Categoria)
                .WithMany()
                .HasForeignKey(x => x.CategoriaId);
        });

        modelBuilder.Entity<Partido>(entity =>
        {
            entity.ToTable("Partidos");
            entity.HasKey(x => x.PartidoId);
            entity.Property(x => x.Rival).HasMaxLength(100).IsRequired();
            entity.Property(x => x.TipoCompeticion).HasMaxLength(20).IsRequired().HasDefaultValue("Amistoso");
            entity.Property(x => x.Lugar).HasMaxLength(150);
            entity.Property(x => x.Estado).HasMaxLength(20).HasDefaultValue("Programado");
            entity.Property(x => x.DefinicionEmpate).HasMaxLength(20).IsRequired().HasDefaultValue("TerminaEnEmpate");
            entity.Property(x => x.PeriodoActual).HasMaxLength(30);
            entity.HasOne(x => x.Categoria).WithMany().HasForeignKey(x => x.CategoriaId);
        });

        modelBuilder.Entity<Alineacion>(entity =>
        {
            entity.ToTable("Alineaciones");
            entity.HasKey(x => x.AlineacionId);
            entity.Property(x => x.PosicionAsignada).HasMaxLength(10);
            entity.Property(x => x.EsTitular).HasDefaultValue(false);
            entity.HasIndex(x => new { x.PartidoId, x.JugadorId }).IsUnique();
            entity.HasOne(x => x.Partido)
                .WithMany()
                .HasForeignKey(x => x.PartidoId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Jugador)
                .WithMany()
                .HasForeignKey(x => x.JugadorId);
        });

        modelBuilder.Entity<TipoEvento>(entity =>
        {
            entity.ToTable("TiposEvento");
            entity.HasKey(x => x.TipoEventoId);
            entity.Property(x => x.Nombre).HasMaxLength(50).IsRequired();
            entity.HasIndex(x => x.Nombre).IsUnique();
        });

        modelBuilder.Entity<EventoPartido>(entity =>
        {
            entity.ToTable("EventosPartido");
            entity.HasKey(x => x.EventoId);
            entity.Property(x => x.PitchX).HasPrecision(4, 3);
            entity.Property(x => x.PitchY).HasPrecision(4, 3);
            entity.Property(x => x.Observacion).HasMaxLength(255);
            entity.Property(x => x.Periodo).HasMaxLength(30);
            entity.Property(x => x.FechaRegistro).HasDefaultValueSql("SYSDATETIME()");
            entity.HasOne(x => x.Jugador).WithMany().HasForeignKey(x => x.JugadorId).IsRequired(false);
            entity.HasOne(x => x.JugadorRelacionado).WithMany().HasForeignKey(x => x.JugadorRelacionadoId).IsRequired(false);
            entity.HasOne(x => x.TipoEvento).WithMany().HasForeignKey(x => x.TipoEventoId);
        });

        modelBuilder.Entity<PenalDetalle>(entity =>
        {
            entity.ToTable("PenalDetalle");
            entity.HasKey(x => x.PenalDetalleId);
            entity.Property(x => x.Equipo).HasMaxLength(10).IsRequired();
            entity.Property(x => x.Resultado).HasMaxLength(10).IsRequired();
            entity.Property(x => x.Activo).HasDefaultValue(true);
            entity.HasOne(x => x.Partido).WithMany().HasForeignKey(x => x.PartidoId);
            entity.HasOne(x => x.Jugador).WithMany().HasForeignKey(x => x.JugadorId).IsRequired(false);
        });

        modelBuilder.Entity<Observacion>(entity =>
        {
            entity.ToTable("Observaciones");
            entity.HasKey(x => x.ObservacionId);
            entity.Property(x => x.Tipo).HasMaxLength(20).IsRequired();
            entity.Property(x => x.Contenido).HasMaxLength(1000).IsRequired();
            entity.HasOne(x => x.Jugador).WithMany().HasForeignKey(x => x.JugadorId);
            entity.HasOne(x => x.Usuario).WithMany().HasForeignKey(x => x.UsuarioId);
        });
    }
}
