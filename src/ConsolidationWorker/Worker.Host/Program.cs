using System.Text.Json;
using BancoCarrefour.EventBus.Contracts;
using Confluent.Kafka;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Worker.Application.Services;
using Worker.Domain.Projections;
using Worker.Infrastructure.Persistence;

namespace Worker.HostApp;

public class KafkaConsolidacaoWorker(
    IConfiguration config,
    ILogger<KafkaConsolidacaoWorker> logger,
    ConsolidacaoProcessor processor) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrapServers = config["Kafka:BootstrapServers"] ?? "localhost:9092";
        var mainTopic = config["Kafka:Topic"] ?? "lancamentos-eventos";
        var dlqTopic = config["Kafka:DlqTopic"] ?? "lancamentos-dlq";

        var consumerConfig = new ConsumerConfig
        {
            BootstrapServers = bootstrapServers,
            GroupId = "consolidacao-worker-group",
            AutoOffsetReset = AutoOffsetReset.Earliest,
            EnableAutoCommit = false
        };

        using var consumer = new ConsumerBuilder<string, string>(consumerConfig).Build();
        using var dlqProducer = new ProducerBuilder<string, string>(new ProducerConfig { BootstrapServers = bootstrapServers }).Build();

        consumer.Subscribe(mainTopic);

        while (!stoppingToken.IsCancellationRequested)
        {
            var result = consumer.Consume(stoppingToken);
            if (result?.Message == null) continue;

            try
            {
                var envelope = JsonSerializer.Deserialize<EnvelopeEvento>(result.Message.Value)
                    ?? throw new InvalidOperationException("Envelope nulo.");

                await processor.ProcessarEnvelopeAsync(envelope, stoppingToken);
                consumer.Commit(result);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Erro ao consolidar mensagem. Enviando para DLQ.");

                await dlqProducer.ProduceAsync(dlqTopic, new Message<string, string>
                {
                    Key = result.Message.Key,
                    Value = result.Message.Value
                }, stoppingToken);

                consumer.Commit(result);
            }
        }
    }
}

public class Program
{
    public static void Main(string[] args)
    {
        var builder = Microsoft.Extensions.Hosting.Host.CreateApplicationBuilder(args);
        builder.Services.AddSingleton<IProjectionRepository, MongoProjectionRepository>();
        builder.Services.AddSingleton<ConsolidacaoProcessor>();
        builder.Services.AddHostedService<KafkaConsolidacaoWorker>();
        builder.Build().Run();
    }
}
