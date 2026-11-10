namespace Worker.Domain.Projections;

public class SaldoDiarioDocument
{
    public string Id { get; set; } = string.Empty; // Formato: {FilialId}_{YYYY-MM-DD}
    public Guid FilialId { get; set; }
    public string DataConsolidacao { get; set; } = string.Empty;
    public decimal TotalCreditos { get; set; }
    public decimal TotalDebitos { get; set; }
    public decimal SaldoFinal { get; set; }
    public DateTime UltimaAtualizacao { get; set; }
}

public class ExtratoLancamentoDocument
{
    public Guid Id { get; set; }
    public Guid FilialId { get; set; }
    public string DataReferencia { get; set; } = string.Empty;
    public DateTime DataLancamento { get; set; }
    public decimal Valor { get; set; }
    public int TipoOperacao { get; set; }
    public string Descricao { get; set; } = string.Empty;
    public string UsuarioId { get; set; } = string.Empty;
}

public interface IProjectionRepository
{
    Task ProcessarCriacaoAsync(ExtratoLancamentoDocument lancamento, decimal deltaCredito, decimal deltaDebito, CancellationToken ct = default);
    Task ProcessarEdicaoAsync(Guid lancamentoId, Guid filialId, string dataRef, decimal novoValor, int novoTipo, string novaDescricao, decimal deltaCredito, decimal deltaDebito, CancellationToken ct = default);
}
