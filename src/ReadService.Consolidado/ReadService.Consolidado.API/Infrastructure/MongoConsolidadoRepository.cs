using Microsoft.Extensions.Configuration;
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using MongoDB.Driver;
using ReadService.Consolidado.API.Domain;

namespace ReadService.Consolidado.API.Infrastructure;

public class MongoConsolidadoRepository : IConsolidadoQueryRepository
{
    private readonly IMongoCollection<SaldoDiarioReadModel> _collection;

    static MongoConsolidadoRepository()
    {
        try
        {
            BsonSerializer.RegisterSerializer(new GuidSerializer(GuidRepresentation.Standard));
        }
        catch (BsonSerializationException) { }
    }

    public MongoConsolidadoRepository(IConfiguration config)
    {
        var client = new MongoClient(config.GetConnectionString("MongoDb") ?? "mongodb://admin:adminpassword@localhost:27017");
        var db = client.GetDatabase("fluxo_caixa_read_db");
        _collection = db.GetCollection<SaldoDiarioReadModel>("SaldosDiarios");
    }

    public async Task<SaldoDiarioReadModel?> ObterPorFilialEDataAsync(Guid filialId, string data, CancellationToken ct = default)
    {
        var id = $"{filialId}_{data}";
        return await _collection.Find(x => x.Id == id).FirstOrDefaultAsync(ct);
    }
}
