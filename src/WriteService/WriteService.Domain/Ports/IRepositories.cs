using WriteService.Domain.Entities;

namespace WriteService.Domain.Ports;

public interface ILancamentoRepository
{
    Task<Lancamento?> ObterPorIdComTipoAsync(Guid id, CancellationToken ct = default);
    Task<TipoLancamento?> ObterTipoLancamentoAsync(Guid tipoLancamentoId, CancellationToken ct = default);
    Task<bool> FilialExisteAsync(Guid filialId, CancellationToken ct = default);
    Task AdicionarAsync(Lancamento lancamento, CancellationToken ct = default);
    Task AtualizarAsync(Lancamento lancamento, CancellationToken ct = default);
}

public interface IEventProducer
{
    Task PublicarAsync<TEvent>(string key, TEvent evento, CancellationToken ct = default) where TEvent : class;
}
