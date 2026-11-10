using ReadService.Extrato.API.Domain;

namespace ReadService.Extrato.API.Application.Queries;

public class ObterExtratoQueryHandler(IExtratoQueryRepository repository)
{
    public async Task<IEnumerable<ExtratoItemReadModel>> ExecutarAsync(Guid filialId, string data, CancellationToken ct = default)
    {
        return await repository.ObterExtratoPorFilialEDataAsync(filialId, data, ct);
    }
}
