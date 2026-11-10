namespace BancoCarrefour.EventBus.Contracts;

public enum TipoOperacaoEvento
{
    Debito = 0,
    Credito = 1
}

public record EnvelopeEvento(string EventType, string PayloadJson);

public record LancamentoCriadoEvent(
    Guid Id,
    Guid FilialId,
    decimal Valor,
    TipoOperacaoEvento TipoOperacao,
    string Descricao,
    string UsuarioId,
    DateTime DataLancamentoUtc
);

public record LancamentoEditadoEvent(
    Guid Id,
    Guid FilialId,
    decimal ValorAnterior,
    TipoOperacaoEvento TipoOperacaoAnterior,
    decimal ValorNovo,
    TipoOperacaoEvento TipoOperacaoNovo,
    string NovaDescricao,
    string UsuarioEditorId,
    DateTime DataLancamentoOriginalUtc,
    DateTime DataEdicaoUtc
);
