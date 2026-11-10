using MongoDB.Bson.Serialization.Attributes;

namespace ReadService.Consolidado.API.Domain;

public class SaldoDiarioReadModel
{
    [BsonId]
    public string Id { get; set; } = string.Empty;
    public Guid FilialId { get; set; }
    public string DataConsolidacao { get; set; } = string.Empty;
    public decimal TotalCreditos { get; set; }
    public decimal TotalDebitos { get; set; }
    public decimal SaldoFinal { get; set; }
    public DateTime UltimaAtualizacao { get; set; }
}

public interface IConsolidadoQueryRepository
{
    Task<SaldoDiarioReadModel?> ObterPorFilialEDataAsync(Guid filialId, string data, CancellationToken ct = default);
}
