using FutbolStats.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FutbolStats.Api.Data;

public class FutbolStatsDbContext(DbContextOptions<FutbolStatsDbContext> options) : DbContext(options)
{
    public DbSet<Categoria> Categorias => Set<Categoria>();
    public DbSet<Jugador> Jugadores => Set<Jugador>();
    public DbSet<Partido> Partidos => Set<Partido>();
    public DbSet<TipoEvento> TiposEvento => Set<TipoEvento>();
    public DbSet<EventoPartido> EventosPartido => Set<EventoPartido>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
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
            entity.HasIndex(x => x.Dni).IsUnique();
            entity.Property(x => x.Nacionalidad).HasMaxLength(50);
            entity.Property(x => x.PosicionPrincipal).HasMaxLength(10);
            entity.Property(x => x.AlturaCm).HasPrecision(5, 2);
            entity.Property(x => x.PesoKg).HasPrecision(5, 2);
            entity.Property(x => x.PiernaHabil).HasMaxLength(10);
            entity.Property(x => x.Estado).HasMaxLength(20).HasDefaultValue("Disponible");
            entity.Property(x => x.Activo).HasDefaultValue(true);
        });

        modelBuilder.Entity<Partido>(entity =>
        {
            entity.ToTable("Partidos");
            entity.HasKey(x => x.PartidoId);
            entity.Property(x => x.Rival).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Lugar).HasMaxLength(150);
            entity.Property(x => x.Estado).HasMaxLength(20).HasDefaultValue("Programado");
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
            entity.Property(x => x.FechaRegistro).HasDefaultValueSql("SYSDATETIME()");
        });
    }
}
