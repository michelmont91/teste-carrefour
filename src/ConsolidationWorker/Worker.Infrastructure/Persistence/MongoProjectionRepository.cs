using Microsoft.Extensions.Configuration;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using Worker.Domain.Projections;

namespace Worker.Infrastructure.Persistence;

public class MongoProjectionRepository : IProjectionRepository
{
    private readonly IMongoCollection<SaldoDiarioDocument> _saldos;
    private readonly IMongoCollection<ExtratoLancamentoDocument> _extratos;

    static MongoProjectionRepository()
    {
        if (!BsonClassMap.IsClassMapRegistered(typeof(SaldoDiarioDocument)))
        {
            BsonClassMap.RegisterClassMap<SaldoDiarioDocument>(cm =>
            {
                cm.AutoMap();
                cm.MapIdMember(c => c.Id);
            });
        }

        if (!BsonClassMap.IsClassMapRegistered(typeof(ExtratoLancamentoDocument)))
        {
            BsonClassMap.RegisterClassMap<ExtratoLancamentoDocument>(cm =>
            {
                cm.AutoMap();
                cm.MapIdMember(c => c.Id);
            });
        }
    }

    public MongoProjectionRepository(IConfiguration config)
    {
        var connString = config.GetConnectionString("MongoDb") ?? "mongodb://admin:adminpassword@localhost:27017";
        var client = new MongoClient(connString);
        var db = client.GetDatabase("fluxo_caixa_read_db");

        _saldos = db.GetCollection<SaldoDiarioDocument>("SaldosDiarios");
        _extratos = db.GetCollection<ExtratoLancamentoDocument>("ExtratoLancamentos");

        // Garante Índice Composto para consultas rápidas de Extrato
        var indexKeys = Builders<ExtratoLancamentoDocument>.IndexKeys
            .Ascending(x => x.FilialId)
            .Ascending(x => x.DataReferencia)
            .Descending(x => x.DataLancamento);
        _extratos.Indexes.CreateOne(new CreateIndexModel<ExtratoLancamentoDocument>(indexKeys));
    }

    public async Task ProcessarCriacaoAsync(ExtratoLancamentoDocument lancamento, decimal deltaCredito, decimal deltaDebito, CancellationToken ct = default)
    {
        // Idempotência: substitui ou insere no extrato
        await _extratos.ReplaceOneAsync(
            x => x.Id == lancamento.Id,
            lancamento,
            new ReplaceOptions { IsUpsert = true },
            ct);

        await AtualizarSaldoAtomicoAsync(lancamento.FilialId, lancamento.DataReferencia, deltaCredito, deltaDebito, ct);
    }

    public async Task ProcessarEdicaoAsync(Guid lancamentoId, Guid filialId, string dataRef, decimal novoValor, int novoTipo, string novaDescricao, decimal deltaCredito, decimal deltaDebito, CancellationToken ct = default)
    {
        var updateExtrato = Builders<ExtratoLancamentoDocument>.Update
            .Set(x => x.Valor, novoValor)
            .Set(x => x.TipoOperacao, novoTipo)
            .Set(x => x.Descricao, novaDescricao);

        await _extratos.UpdateOneAsync(x => x.Id == lancamentoId, updateExtrato, cancellationToken: ct);
        await AtualizarSaldoAtomicoAsync(filialId, dataRef, deltaCredito, deltaDebito, ct);
    }

    private async Task AtualizarSaldoAtomicoAsync(Guid filialId, string dataRef, decimal deltaCredito, decimal deltaDebito, CancellationToken ct)
    {
        var saldoId = $"{filialId}_{dataRef}";
        var deltaLiquido = deltaCredito - deltaDebito;

        var updateSaldo = Builders<SaldoDiarioDocument>.Update
            .SetOnInsert(x => x.Id, saldoId)
            .SetOnInsert(x => x.FilialId, filialId)
            .SetOnInsert(x => x.DataConsolidacao, dataRef)
            .Inc(x => x.TotalCreditos, deltaCredito)
            .Inc(x => x.TotalDebitos, deltaDebito)
            .Inc(x => x.SaldoFinal, deltaLiquido)
            .Set(x => x.UltimaAtualizacao, DateTime.UtcNow);

        await _saldos.UpdateOneAsync(
            x => x.Id == saldoId,
            updateSaldo,
            new UpdateOptions { IsUpsert = true },
            ct);
    }
}
