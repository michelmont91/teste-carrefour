using Microsoft.Extensions.Configuration;
using MongoDB.Driver;
using ReadService.Extrato.API.Domain;

namespace ReadService.Extrato.API.Infrastructure;

public class MongoExtratoRepository : IExtratoQueryRepository
{
    private readonly IMongoCollection<ExtratoItemReadModel> _collection;

    public MongoExtratoRepository(IConfiguration config)
    {
        var client = new MongoClient(config.GetConnectionString("MongoDb") ?? "mongodb://admin:adminpassword@localhost:27017");
        var db = client.GetDatabase("fluxo_caixa_read_db");
        _collection = db.GetCollection<ExtratoItemReadModel>("ExtratoLancamentos");
    }

    public async Task<IEnumerable<ExtratoItemReadModel>> ObterExtratoPorFilialEDataAsync(Guid filialId, string data, CancellationToken ct = default)
    {
        var filter = Builders<ExtratoItemReadModel>.Filter.And(
            Builders<ExtratoItemReadModel>.Filter.Eq(x => x.FilialId, filialId),
            Builders<ExtratoItemReadModel>.Filter.Eq(x => x.DataReferencia, data));

        return await _collection.Find(filter)
            .SortByDescending(x => x.DataLancamento)
            .ToListAsync(ct);
    }
}
