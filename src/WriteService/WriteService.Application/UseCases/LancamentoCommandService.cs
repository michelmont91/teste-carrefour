using BancoCarrefour.EventBus.Contracts;
using WriteService.Domain.Entities;
using WriteService.Domain.Ports;

namespace WriteService.Application.UseCases;

public record CriarLancamentoRequest(decimal Valor, string Descricao, Guid FilialId, Guid TipoLancamentoId);
public record EditarLancamentoRequest(decimal NovoValor, string NovaDescricao, Guid NovoTipoLancamentoId);
public record LancamentoResponse(Guid Id, decimal Valor, DateTime DataLancamento, string Descricao, Guid FilialId, TipoOperacao Operacao);

public class LancamentoCommandService(ILancamentoRepository repository, IEventProducer eventProducer)
{
    public async Task<LancamentoResponse> CriarAsync(CriarLancamentoRequest request, string usuarioId, CancellationToken ct = default)
    {
        if (!await repository.FilialExisteAsync(request.FilialId, ct))
            throw new InvalidOperationException($"Filial com ID {request.FilialId} nao encontrada no sistema.");

        var tipoLancamento = await repository.ObterTipoLancamentoAsync(request.TipoLancamentoId, ct)
            ?? throw new InvalidOperationException($"Tipo de lancamento contabil {request.TipoLancamentoId} nao encontrado.");

        var lancamento = new Lancamento(request.Valor, request.Descricao, usuarioId, request.FilialId, request.TipoLancamentoId);
        await repository.AdicionarAsync(lancamento, ct);

        // Publica evento imutável para o Redpanda (Consolidação assíncrona)
        var evento = new LancamentoCriadoEvent(
            lancamento.Id, 
            lancamento.FilialId, 
            lancamento.Valor,
            (TipoOperacaoEvento)tipoLancamento.Operacao, 
            lancamento.Descricao,
            lancamento.UsuarioId, 
            lancamento.DataLancamento);

        await eventProducer.PublicarAsync(lancamento.FilialId.ToString(), evento, ct);

        return new LancamentoResponse(
            lancamento.Id, 
            lancamento.Valor, 
            lancamento.DataLancamento, 
            lancamento.Descricao, 
            lancamento.FilialId, 
            tipoLancamento.Operacao);
    }

    public async Task<LancamentoResponse> EditarAsync(Guid id, EditarLancamentoRequest request, string usuarioEditorId, CancellationToken ct = default)
    {
        var lancamento = await repository.ObterPorIdComTipoAsync(id, ct) 
            ?? throw new KeyNotFoundException($"Lancamento {id} nao encontrado para edicao.");
        
        var novoTipo = await repository.ObterTipoLancamentoAsync(request.NovoTipoLancamentoId, ct) 
            ?? throw new InvalidOperationException("Novo tipo de lancamento invalido.");

        var valorAnterior = lancamento.Valor;
        var operacaoAnterior = lancamento.TipoLancamento!.Operacao;

        lancamento.Atualizar(request.NovoValor, request.NovaDescricao, request.NovoTipoLancamentoId, usuarioEditorId);
        await repository.AtualizarAsync(lancamento, ct);

        // Publica evento de retificação para recalcular deltas no worker
        var evento = new LancamentoEditadoEvent(
            lancamento.Id, 
            lancamento.FilialId, 
            valorAnterior, 
            (TipoOperacaoEvento)operacaoAnterior,
            lancamento.Valor, 
            (TipoOperacaoEvento)novoTipo.Operacao, 
            lancamento.Descricao,
            usuarioEditorId, 
            lancamento.DataLancamento, 
            lancamento.UpdatedAtUtc ?? DateTime.UtcNow);

        await eventProducer.PublicarAsync(lancamento.FilialId.ToString(), evento, ct);

        return new LancamentoResponse(
            lancamento.Id, 
            lancamento.Valor, 
            lancamento.DataLancamento, 
            lancamento.Descricao, 
            lancamento.FilialId, 
            novoTipo.Operacao);
    }
}
