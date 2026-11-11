using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Worker.Application.Services;
using Worker.Domain.Projections;
using Worker.Infrastructure.Persistence;
using Worker.Infrastructure.Messaging;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSingleton<IProjectionRepository, MongoProjectionRepository>();
builder.Services.AddSingleton<ConsolidacaoProcessor>();
builder.Services.AddHostedService<KafkaConsolidacaoWorker>();

var host = builder.Build();
host.Run();
