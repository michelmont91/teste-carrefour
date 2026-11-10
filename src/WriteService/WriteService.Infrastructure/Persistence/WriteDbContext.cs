using Microsoft.EntityFrameworkCore;
using WriteService.Domain.Entities;

namespace WriteService.Infrastructure.Persistence;

public class WriteDbContext(DbContextOptions<WriteDbContext> options) : DbContext(options)
{
    public DbSet<Lancamento> Lancamentos => Set<Lancamento>();
    public DbSet<Filial> Filiais => Set<Filial>();
    public DbSet<TipoLancamento> TiposLancamento => Set<TipoLancamento>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Filial>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Nome).IsRequired().HasMaxLength(150);
            entity.Property(e => e.CodigoDocumento).IsRequired().HasMaxLength(20);

            // Seed Inicial para Testes Imediatos
            entity.HasData(
                new Filial(Guid.Parse("11111111-1111-1111-1111-111111111111"), "Carrefour Pinheiros - SP", "45.543.915/0001-81"),
                new Filial(Guid.Parse("22222222-2222-2222-2222-222222222222"), "Carrefour Dom Pedro - Campinas", "45.543.915/0002-62")
            );
        });

        modelBuilder.Entity<TipoLancamento>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Descricao).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Operacao).IsRequired();

            // Seed Inicial de Operações Contábeis
            entity.HasData(
                new TipoLancamento(Guid.Parse("33333333-3333-3333-3333-333333333333"), TipoOperacao.Credito, "Venda PDV / Recebimento"),
                new TipoLancamento(Guid.Parse("44444444-4444-4444-4444-444444444444"), TipoOperacao.Debito, "Pagamento Fornecedor / Sangria")
            );
        });

        modelBuilder.Entity<Lancamento>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Valor).HasColumnType("decimal(18,2)").IsRequired();
            entity.Property(e => e.Descricao).IsRequired().HasMaxLength(250);
            entity.Property(e => e.UsuarioId).IsRequired().HasMaxLength(100);

            entity.HasOne(e => e.Filial)
                  .WithMany()
                  .HasForeignKey(e => e.FilialId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.TipoLancamento)
                  .WithMany()
                  .HasForeignKey(e => e.TipoLancamentoId)
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
