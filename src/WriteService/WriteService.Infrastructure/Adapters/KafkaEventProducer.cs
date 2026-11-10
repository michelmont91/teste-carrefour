using System.Text.Json;
using BancoCarrefour.EventBus.Contracts;
using Confluent.Kafka;
using Microsoft.Extensions.Configuration;
using WriteService.Domain.Ports;

namespace WriteService.Infrastructure.Adapters;

public class KafkaEventProducer : IEventProducer
{
    private readonly IProducer<string, string> _producer;
    private readonly string _topic;

    public KafkaEventProducer(IConfiguration configuration)
    {
        var bootstrapServers = configuration["Kafka:BootstrapServers"] ?? "localhost:9092";
        _topic = configuration["Kafka:Topic"] ?? "lancamentos-eventos";

        var config = new ProducerConfig { BootstrapServers = bootstrapServers };
        _producer = new ProducerBuilder<string, string>(config).Build();
    }

    public async Task PublicarAsync<T>(string chave, T evento, CancellationToken ct = default) where T : class
    {
        var envelope = new EnvelopeEvento(
            typeof(T).Name,
            JsonSerializer.Serialize(evento)
        );

        var message = new Message<string, string>
        {
            Key = chave,
            Value = JsonSerializer.Serialize(envelope)
        };

        await _producer.ProduceAsync(_topic, message, ct);
    }
}
