using MongoDB.Bson.Serialization.Attributes;

namespace ReadService.Extrato.API.Domain;

public class ExtratoItemReadModel
{
    [BsonId]
    public Guid Id { get; set; }
    public Guid FilialId { get; set; }
    public string DataReferencia { get; set; } = string.Empty;
    public DateTime DataLancamento { get; set; }
    public decimal Valor { get; set; }
    public int TipoOperacao { get; set; }
    public string Descricao { get; set; } = string.Empty;
    public string UsuarioId { get; set; } = string.Empty;
}

public interface IExtratoQueryRepository
{
    Task<IEnumerable<ExtratoItemReadModel>> ObterExtratoPorFilialEDataAsync(Guid filialId, string data, CancellationToken ct = default);
}
