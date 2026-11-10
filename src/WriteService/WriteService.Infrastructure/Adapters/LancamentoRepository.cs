using Microsoft.EntityFrameworkCore;
using WriteService.Domain.Entities;
using WriteService.Domain.Ports;
using WriteService.Infrastructure.Persistence;

namespace WriteService.Infrastructure.Adapters;

public class LancamentoRepository(WriteDbContext context) : ILancamentoRepository
{
    public async Task<bool> FilialExisteAsync(Guid filialId, CancellationToken ct = default)
    {
        return await context.Filiais.AnyAsync(f => f.Id == filialId, ct);
    }

    public async Task<TipoLancamento?> ObterTipoLancamentoAsync(Guid tipoId, CancellationToken ct = default)
    {
        return await context.TiposLancamento.FindAsync([tipoId], ct);
    }

    public async Task<Lancamento?> ObterPorIdComTipoAsync(Guid id, CancellationToken ct = default)
    {
        return await context.Lancamentos
            .Include(l => l.TipoLancamento)
            .FirstOrDefaultAsync(l => l.Id == id, ct);
    }

    public async Task AdicionarAsync(Lancamento lancamento, CancellationToken ct = default)
    {
        await context.Lancamentos.AddAsync(lancamento, ct);
        await context.SaveChangesAsync(ct);
    }

    public async Task AtualizarAsync(Lancamento lancamento, CancellationToken ct = default)
    {
        context.Lancamentos.Update(lancamento);
        await context.SaveChangesAsync(ct);
    }
}
