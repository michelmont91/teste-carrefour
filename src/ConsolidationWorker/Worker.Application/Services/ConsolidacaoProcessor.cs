using System.Text.Json;
using BancoCarrefour.EventBus.Contracts;
using Worker.Domain.Projections;

namespace Worker.Application.Services;

public class ConsolidacaoProcessor(IProjectionRepository repository)
{
    public async Task ProcessarEnvelopeAsync(EnvelopeEvento envelope, CancellationToken ct = default)
    {
        switch (envelope.EventType)
        {
            case nameof(LancamentoCriadoEvent):
                var criado = JsonSerializer.Deserialize<LancamentoCriadoEvent>(envelope.PayloadJson)
                    ?? throw new InvalidOperationException("Payload LancamentoCriadoEvent invalido.");
                await ProcessarCriadoAsync(criado, ct);
                break;

            case nameof(LancamentoEditadoEvent):
                var editado = JsonSerializer.Deserialize<LancamentoEditadoEvent>(envelope.PayloadJson)
                    ?? throw new InvalidOperationException("Payload LancamentoEditadoEvent invalido.");
                await ProcessarEditadoAsync(editado, ct);
                break;

            default:
                throw new NotSupportedException($"Tipo de evento desconhecido: {envelope.EventType}");
        }
    }

    private async Task ProcessarCriadoAsync(LancamentoCriadoEvent ev, CancellationToken ct)
    {
        var dataRef = ev.DataLancamentoUtc.ToString("yyyy-MM-dd");
        var deltaCredito = ev.TipoOperacao == TipoOperacaoEvento.Credito ? ev.Valor : 0m;
        var deltaDebito = ev.TipoOperacao == TipoOperacaoEvento.Debito ? ev.Valor : 0m;

        var doc = new ExtratoLancamentoDocument
        {
            Id = ev.Id,
            FilialId = ev.FilialId,
            DataReferencia = dataRef,
            DataLancamento = ev.DataLancamentoUtc,
            Valor = ev.Valor,
            TipoOperacao = (int)ev.TipoOperacao,
            Descricao = ev.Descricao,
            UsuarioId = ev.UsuarioId
        };

        await repository.ProcessarCriacaoAsync(doc, deltaCredito, deltaDebito, ct);
    }

    private async Task ProcessarEditadoAsync(LancamentoEditadoEvent ev, CancellationToken ct)
    {
        var dataRef = ev.DataLancamentoOriginalUtc.ToString("yyyy-MM-dd");
        decimal deltaCredito = 0m;
        decimal deltaDebito = 0m;

        // Estorno do valor anterior
        if (ev.TipoOperacaoAnterior == TipoOperacaoEvento.Credito) deltaCredito -= ev.ValorAnterior;
        else deltaDebito -= ev.ValorAnterior;

        // Aplicação do novo valor
        if (ev.TipoOperacaoNovo == TipoOperacaoEvento.Credito) deltaCredito += ev.ValorNovo;
        else deltaDebito += ev.ValorNovo;

        await repository.ProcessarEdicaoAsync(
            ev.Id, ev.FilialId, dataRef, 
            ev.ValorNovo, (int)ev.TipoOperacaoNovo, ev.NovaDescricao, 
            deltaCredito, deltaDebito, ct);
    }
}
