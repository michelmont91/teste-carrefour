using WriteService.Domain.Entities;

namespace WriteService.Domain.Ports;

public interface ILancamentoRepository
{
    Task<bool> FilialExisteAsync(Guid filialId, CancellationToken ct = default);
    Task<TipoLancamento?> ObterTipoLancamentoAsync(Guid tipoId, CancellationToken ct = default);
    Task<Lancamento?> ObterPorIdComTipoAsync(Guid id, CancellationToken ct = default);
    Task AdicionarAsync(Lancamento lancamento, CancellationToken ct = default);
    Task AtualizarAsync(Lancamento lancamento, CancellationToken ct = default);
}
