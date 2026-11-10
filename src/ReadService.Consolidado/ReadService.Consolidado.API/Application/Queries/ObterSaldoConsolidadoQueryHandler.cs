using ReadService.Consolidado.API.Domain;

namespace ReadService.Consolidado.API.Application.Queries;

public class ObterSaldoConsolidadoQueryHandler(IConsolidadoQueryRepository repository)
{
    public async Task<SaldoDiarioReadModel> ExecutarAsync(Guid filialId, string data, CancellationToken ct = default)
    {
        var saldo = await repository.ObterPorFilialEDataAsync(filialId, data, ct);

        if (saldo is null)
        {
            return new SaldoDiarioReadModel
            {
                Id = $"{filialId}_{data}",
                FilialId = filialId,
                DataConsolidacao = data,
                TotalCreditos = 0m,
                TotalDebitos = 0m,
                SaldoFinal = 0m,
                UltimaAtualizacao = DateTime.UtcNow
            };
        }

        return saldo;
    }
}
