cat << 'EOF' > setup.sh
#!/usr/bin/env bash
set -e

echo "=== 1. Limpando ambiente anterior ==="
rm -rf src tests BancoCarrefour.sln *.csproj

echo "=== 2. Criando Solução e Projetos (.NET LTS Atual) ==="
dotnet new sln -n BancoCarrefour

# Criar pastas base
mkdir -p src/BuildingBlocks/BancoCarrefour.EventBus.Contracts
mkdir -p src/WriteService/WriteService.Domain/Entities
mkdir -p src/WriteService/WriteService.Domain/Ports
mkdir -p src/WriteService/WriteService.Application/UseCases
mkdir -p src/WriteService/WriteService.Infrastructure/Persistence
mkdir -p src/WriteService/WriteService.Infrastructure/Adapters
mkdir -p src/WriteService/WriteService.API
mkdir -p src/ConsolidationWorker/Worker.Domain/Projections
mkdir -p src/ConsolidationWorker/Worker.Application/Services
mkdir -p src/ConsolidationWorker/Worker.Infrastructure/Persistence
mkdir -p src/ConsolidationWorker/Worker.Host
mkdir -p src/ReadService.Consolidado/ReadService.Consolidado.API
mkdir -p src/ReadService.Extrato/ReadService.Extrato.API
mkdir -p tests/BancoCarrefour.UnitTests/Domain
mkdir -p tests/BancoCarrefour.UnitTests/Application
mkdir -p tests/BancoCarrefour.UnitTests/Worker

# 1. BuildingBlocks
dotnet new classlib -n BancoCarrefour.EventBus.Contracts -o src/BuildingBlocks/BancoCarrefour.EventBus.Contracts --force
dotnet sln add src/BuildingBlocks/BancoCarrefour.EventBus.Contracts

# 2. WriteService
dotnet new classlib -n WriteService.Domain -o src/WriteService/WriteService.Domain --force
dotnet new classlib -n WriteService.Application -o src/WriteService/WriteService.Application --force
dotnet new classlib -n WriteService.Infrastructure -o src/WriteService/WriteService.Infrastructure --force
dotnet new webapi -n WriteService.API -o src/WriteService/WriteService.API --force

dotnet add src/WriteService/WriteService.Application reference src/WriteService/WriteService.Domain src/BuildingBlocks/BancoCarrefour.EventBus.Contracts
dotnet add src/WriteService/WriteService.Infrastructure reference src/WriteService/WriteService.Application
dotnet add src/WriteService/WriteService.API reference src/WriteService/WriteService.Infrastructure

dotnet add src/WriteService/WriteService.Infrastructure package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/WriteService/WriteService.Infrastructure package Confluent.Kafka
dotnet add src/WriteService/WriteService.API package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet sln add src/WriteService/**/*.csproj

# 3. ConsolidationWorker
dotnet new classlib -n Worker.Domain -o src/ConsolidationWorker/Worker.Domain --force
dotnet new classlib -n Worker.Application -o src/ConsolidationWorker/Worker.Application --force
dotnet new classlib -n Worker.Infrastructure -o src/ConsolidationWorker/Worker.Infrastructure --force
dotnet new worker -n Worker.Host -o src/ConsolidationWorker/Worker.Host --force

dotnet add src/ConsolidationWorker/Worker.Application reference src/ConsolidationWorker/Worker.Domain src/BuildingBlocks/BancoCarrefour.EventBus.Contracts
dotnet add src/ConsolidationWorker/Worker.Infrastructure reference src/ConsolidationWorker/Worker.Application
dotnet add src/ConsolidationWorker/Worker.Host reference src/ConsolidationWorker/Worker.Infrastructure

dotnet add src/ConsolidationWorker/Worker.Infrastructure package MongoDB.Driver
dotnet add src/ConsolidationWorker/Worker.Infrastructure package Confluent.Kafka
dotnet sln add src/ConsolidationWorker/**/*.csproj

# 4. ReadService.Consolidado
dotnet new webapi -n ReadService.Consolidado.API -o src/ReadService.Consolidado/ReadService.Consolidado.API --force
dotnet add src/ReadService.Consolidado/ReadService.Consolidado.API package MongoDB.Driver
dotnet add src/ReadService.Consolidado/ReadService.Consolidado.API package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet sln add src/ReadService.Consolidado/ReadService.Consolidado.API

# 5. ReadService.Extrato
dotnet new webapi -n ReadService.Extrato.API -o src/ReadService.Extrato/ReadService.Extrato.API --force
dotnet add src/ReadService.Extrato/ReadService.Extrato.API package MongoDB.Driver
dotnet add src/ReadService.Extrato/ReadService.Extrato.API package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet sln add src/ReadService.Extrato/ReadService.Extrato.API

# 6. Testes Unitários
dotnet new xunit -n BancoCarrefour.UnitTests -o tests/BancoCarrefour.UnitTests --force
dotnet sln add tests/BancoCarrefour.UnitTests
dotnet add tests/BancoCarrefour.UnitTests reference src/BuildingBlocks/BancoCarrefour.EventBus.Contracts src/WriteService/WriteService.Domain src/WriteService/WriteService.Application src/ConsolidationWorker/Worker.Domain src/ConsolidationWorker/Worker.Application
dotnet add tests/BancoCarrefour.UnitTests package NSubstitute

# Remover ficheiros padrão desnecessários
find . -name "Class1.cs" -type f -delete
find . -name "UnitTest1.cs" -type f -delete
find . -name "Worker.cs" -type f -delete

echo "=== 3. Escrevendo o Código C# de todos os módulos ==="

cat << 'EOF' > src/BuildingBlocks/BancoCarrefour.EventBus.Contracts/Events.cs
namespace BancoCarrefour.EventBus.Contracts;

public enum TipoOperacaoEvento
{
    Debito = 0,
    Credito = 1
}

public record LancamentoCriadoEvent(
    Guid Id,
    Guid FilialId,
    decimal Valor,
    TipoOperacaoEvento TipoOperacao,
    string Descricao,
    string UsuarioId,
    DateTime DataLancamentoUtc);

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
    DateTime DataEdicaoUtc);

public record EnvelopeEvento(
    string EventType,
    string PayloadJson,
    DateTime OccurredAtUtc);
EOF

cat << 'EOF' > src/WriteService/WriteService.Domain/Entities/DomainModels.cs
namespace WriteService.Domain.Entities;

public abstract class EntityBase
{
    public Guid Id { get; protected set; } = Guid.NewGuid();
    public DateTime CreatedAtUtc { get; protected set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; protected set; }
}

public enum TipoOperacao
{
    Debito = 0,
    Credito = 1
}

public class Filial : EntityBase
{
    public string Nome { get; private set; } = string.Empty;
    public string CodigoDocumento { get; private set; } = string.Empty;

    protected Filial() { }

    public Filial(Guid id, string nome, string codigoDocumento)
    {
        Id = id;
        Nome = nome;
        CodigoDocumento = codigoDocumento;
    }
}

public class TipoLancamento : EntityBase
{
    public TipoOperacao Operacao { get; private set; }
    public string Descricao { get; private set; } = string.Empty;

    protected TipoLancamento() { }

    public TipoLancamento(Guid id, TipoOperacao operacao, string descricao)
    {
        Id = id;
        Operacao = operacao;
        Descricao = descricao;
    }
}

public class Lancamento : EntityBase
{
    public decimal Valor { get; private set; }
    public DateTime DataLancamento { get; private set; }
    public string Descricao { get; private set; } = string.Empty;
    public string UsuarioId { get; private set; } = string.Empty;
    public Guid FilialId { get; private set; }
    public Guid TipoLancamentoId { get; private set; }

    public Filial? Filial { get; private set; }
    public TipoLancamento? TipoLancamento { get; private set; }

    protected Lancamento() { }

    public Lancamento(decimal valor, string descricao, string usuarioId, Guid filialId, Guid tipoLancamentoId)
    {
        Validar(valor, descricao, filialId, tipoLancamentoId);
        Valor = valor;
        DataLancamento = DateTime.UtcNow;
        Descricao = descricao.Trim();
        UsuarioId = usuarioId;
        FilialId = filialId;
        TipoLancamentoId = tipoLancamentoId;
    }

    public void Atualizar(decimal novoValor, string novaDescricao, Guid novoTipoLancamentoId, string usuarioEditorId)
    {
        Validar(novoValor, novaDescricao, FilialId, novoTipoLancamentoId);
        Valor = novoValor;
        Descricao = novaDescricao.Trim();
        TipoLancamentoId = novoTipoLancamentoId;
        UsuarioId = usuarioEditorId;
        UpdatedAtUtc = DateTime.UtcNow;
    }

    private static void Validar(decimal valor, string descricao, Guid filialId, Guid tipoLancamentoId)
    {
        if (valor <= 0) throw new ArgumentException("O valor do lancamento deve ser maior que zero.");
        if (string.IsNullOrWhiteSpace(descricao)) throw new ArgumentException("A descricao do lancamento e obrigatoria.");
        if (filialId == Guid.Empty) throw new ArgumentException("A filial informada e invalida.");
        if (tipoLancamentoId == Guid.Empty) throw new ArgumentException("O tipo de lancamento informado e invalido.");
    }
}
EOF

cat << 'EOF' > src/WriteService/WriteService.Domain/Ports/IRepositories.cs
using WriteService.Domain.Entities;

namespace WriteService.Domain.Ports;

public interface ILancamentoRepository
{
    Task<Lancamento?> ObterPorIdComTipoAsync(Guid id, CancellationToken ct = default);
    Task<TipoLancamento?> ObterTipoLancamentoAsync(Guid tipoLancamentoId, CancellationToken ct = default);
    Task<bool> FilialExisteAsync(Guid filialId, CancellationToken ct = default);
    Task AdicionarAsync(Lancamento lancamento, CancellationToken ct = default);
    Task AtualizarAsync(Lancamento lancamento, CancellationToken ct = default);
}

public interface IEventProducer
{
    Task PublicarAsync<TEvent>(string key, TEvent evento, CancellationToken ct = default) where TEvent : class;
}
EOF

cat << 'EOF' > src/WriteService/WriteService.Application/UseCases/LancamentoCommandService.cs
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
            throw new InvalidOperationException("Filial nao encontrada.");

        var tipoLancamento = await repository.ObterTipoLancamentoAsync(request.TipoLancamentoId, ct)
            ?? throw new InvalidOperationException("Tipo de lancamento nao encontrado.");

        var lancamento = new Lancamento(request.Valor, request.Descricao, usuarioId, request.FilialId, request.TipoLancamentoId);
        await repository.AdicionarAsync(lancamento, ct);

        var evento = new LancamentoCriadoEvent(
            lancamento.Id, lancamento.FilialId, lancamento.Valor,
            (TipoOperacaoEvento)tipoLancamento.Operacao, lancamento.Descricao,
            lancamento.UsuarioId, lancamento.DataLancamento);

        await eventProducer.PublicarAsync(lancamento.FilialId.ToString(), evento, ct);

        return new LancamentoResponse(lancamento.Id, lancamento.Valor, lancamento.DataLancamento, lancamento.Descricao, lancamento.FilialId, tipoLancamento.Operacao);
    }

    public async Task<LancamentoResponse> EditarAsync(Guid id, EditarLancamentoRequest request, string usuarioEditorId, CancellationToken ct = default)
    {
        var lancamento = await repository.ObterPorIdComTipoAsync(id, ct) ?? throw new KeyNotFoundException("Lancamento nao encontrado.");
        var novoTipo = await repository.ObterTipoLancamentoAsync(request.NovoTipoLancamentoId, ct) ?? throw new InvalidOperationException("Novo tipo de lancamento invalido.");

        var valorAnterior = lancamento.Valor;
        var operacaoAnterior = lancamento.TipoLancamento!.Operacao;

        lancamento.Atualizar(request.NovoValor, request.NovaDescricao, request.NovoTipoLancamentoId, usuarioEditorId);
        await repository.AtualizarAsync(lancamento, ct);

        var evento = new LancamentoEditadoEvent(
            lancamento.Id, lancamento.FilialId, valorAnterior, (TipoOperacaoEvento)operacaoAnterior,
            lancamento.Valor, (TipoOperacaoEvento)novoTipo.Operacao, lancamento.Descricao,
            usuarioEditorId, lancamento.DataLancamento, lancamento.UpdatedAtUtc ?? DateTime.UtcNow);

        await eventProducer.PublicarAsync(lancamento.FilialId.ToString(), evento, ct);

        return new LancamentoResponse(lancamento.Id, lancamento.Valor, lancamento.DataLancamento, lancamento.Descricao, lancamento.FilialId, novoTipo.Operacao);
    }
}
EOF

cat << 'EOF' > src/WriteService/WriteService.Infrastructure/Persistence/WriteDbContext.cs
using Microsoft.EntityFrameworkCore;
using WriteService.Domain.Entities;

namespace WriteService.Infrastructure.Persistence;

public class WriteDbContext(DbContextOptions<WriteDbContext> options) : DbContext(options)
{
    public static readonly Guid FilialMatrizId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    public static readonly Guid TipoDebitoId = Guid.Parse("22222222-2222-2222-2222-222222222222");
    public static readonly Guid TipoCreditoId = Guid.Parse("33333333-3333-3333-3333-333333333333");

    public DbSet<Filial> Filiais => Set<Filial>();
    public DbSet<TipoLancamento> TiposLancamento => Set<TipoLancamento>();
    public DbSet<Lancamento> Lancamentos => Set<Lancamento>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Filial>(b =>
        {
            b.ToTable("Filiais");
            b.HasKey(x => x.Id);
            b.Property(x => x.Nome).HasMaxLength(150).IsRequired();
            b.Property(x => x.CodigoDocumento).HasMaxLength(20).IsRequired();
            b.HasData(new Filial(FilialMatrizId, "Filial Carrefour Pinheiros", "45.543.915/0001-81"));
        });

        modelBuilder.Entity<TipoLancamento>(b =>
        {
            b.ToTable("TiposLancamento");
            b.HasKey(x => x.Id);
            b.Property(x => x.Operacao).IsRequired();
            b.Property(x => x.Descricao).HasMaxLength(100).IsRequired();
            b.HasData(
                new TipoLancamento(TipoDebitoId, TipoOperacao.Debito, "Saida / Pagamento Fornecedor"),
                new TipoLancamento(TipoCreditoId, TipoOperacao.Credito, "Entrada / Venda PDV"));
        });

        modelBuilder.Entity<Lancamento>(b =>
        {
            b.ToTable("Lancamentos");
            b.HasKey(x => x.Id);
            b.Property(x => x.Valor).HasPrecision(18, 2).IsRequired();
            b.Property(x => x.Descricao).HasMaxLength(300).IsRequired();
            b.Property(x => x.UsuarioId).HasMaxLength(100).IsRequired();
            b.HasOne(x => x.Filial).WithMany().HasForeignKey(x => x.FilialId);
            b.HasOne(x => x.TipoLancamento).WithMany().HasForeignKey(x => x.TipoLancamentoId);
        });
    }
}
EOF

cat << 'EOF' > src/WriteService/WriteService.Infrastructure/Adapters/PostgresAndKafkaAdapters.cs
using System.Text.Json;
using BancoCarrefour.EventBus.Contracts;
using Confluent.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using WriteService.Domain.Entities;
using WriteService.Domain.Ports;
using WriteService.Infrastructure.Persistence;

namespace WriteService.Infrastructure.Adapters;

public class LancamentoRepository(WriteDbContext db) : ILancamentoRepository
{
    public async Task<Lancamento?> ObterPorIdComTipoAsync(Guid id, CancellationToken ct = default) =>
        await db.Lancamentos.Include(x => x.TipoLancamento).FirstOrDefaultAsync(x => x.Id == id, ct);

    public async Task<TipoLancamento?> ObterTipoLancamentoAsync(Guid tipoLancamentoId, CancellationToken ct = default) =>
        await db.TiposLancamento.FirstOrDefaultAsync(x => x.Id == tipoLancamentoId, ct);

    public async Task<bool> FilialExisteAsync(Guid filialId, CancellationToken ct = default) =>
        await db.Filiais.AnyAsync(x => x.Id == filialId, ct);

    public async Task AdicionarAsync(Lancamento lancamento, CancellationToken ct = default)
    {
        await db.Lancamentos.AddAsync(lancamento, ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task AtualizarAsync(Lancamento lancamento, CancellationToken ct = default)
    {
        db.Lancamentos.Update(lancamento);
        await db.SaveChangesAsync(ct);
    }
}

public class KafkaEventProducer : IEventProducer, IDisposable
{
    private readonly IProducer<string, string> _producer;
    private readonly string _topic;

    public KafkaEventProducer(IConfiguration config)
    {
        var producerConfig = new ProducerConfig
        {
            BootstrapServers = config["Kafka:BootstrapServers"] ?? "localhost:9092",
            Acks = Acks.All,
            EnableIdempotence = true
        };
        _producer = new ProducerBuilder<string, string>(producerConfig).Build();
        _topic = config["Kafka:Topic"] ?? "lancamentos-eventos";
    }

    public async Task PublicarAsync<TEvent>(string key, TEvent evento, CancellationToken ct = default) where TEvent : class
    {
        var envelope = new EnvelopeEvento(typeof(TEvent).Name, JsonSerializer.Serialize(evento), DateTime.UtcNow);
        var message = new Message<string, string> { Key = key, Value = JsonSerializer.Serialize(envelope) };
        await _producer.ProduceAsync(_topic, message, ct);
    }

    public void Dispose() => _producer.Dispose();
}
EOF

cat << 'EOF' > src/WriteService/WriteService.API/Program.cs
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using WriteService.Application.UseCases;
using WriteService.Domain.Ports;
using WriteService.Infrastructure.Adapters;
using WriteService.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<WriteDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("Postgres") 
        ?? "Host=localhost;Port=5432;Database=fluxo_caixa_db;Username=admin;Password=adminpassword"));

builder.Services.AddScoped<ILancamentoRepository, LancamentoRepository>();
builder.Services.AddSingleton<IEventProducer, KafkaEventProducer>();
builder.Services.AddScoped<LancamentoCommandService>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.Authority = builder.Configuration["Keycloak:Authority"] ?? "http://localhost:8080/realms/banco-carrefour";
        opt.RequireHttpsMetadata = false;
        opt.TokenValidationParameters.ValidateAudience = false;
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("writer", p => p.RequireRole("writer", "admin"))
    .AddPolicy("admin", p => p.RequireRole("admin"));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<WriteDbContext>();
    db.Database.EnsureCreated();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapPost("/api/lancamentos", async (
    CriarLancamentoRequest request,
    ClaimsPrincipal user,
    LancamentoCommandService service,
    CancellationToken ct) =>
{
    var userId = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? "operador-padrao";
    var result = await service.CriarAsync(request, userId, ct);
    return Results.Created($"/api/lancamentos/{result.Id}", result);
}).RequireAuthorization("writer");

app.MapPut("/api/lancamentos/{id:guid}", async (
    Guid id,
    EditarLancamentoRequest request,
    ClaimsPrincipal user,
    LancamentoCommandService service,
    CancellationToken ct) =>
{
    var userId = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? "admin-padrao";
    var result = await service.EditarAsync(id, request, userId, ct);
    return Results.Ok(result);
}).RequireAuthorization("admin");

app.Run();
EOF

cat << 'EOF' > src/ConsolidationWorker/Worker.Domain/Projections/ReadProjections.cs
using MongoDB.Bson.Serialization.Attributes;

namespace Worker.Domain.Projections;

public class SaldoDiarioDocument
{
    [BsonId]
    public string Id { get; set; } = string.Empty;
    public Guid FilialId { get; set; }
    public string DataConsolidacao { get; set; } = string.Empty;
    public decimal TotalCreditos { get; set; }
    public decimal TotalDebitos { get; set; }
    public decimal SaldoFinal { get; set; }
    public DateTime UltimaAtualizacao { get; set; }
}

public class ExtratoLancamentoDocument
{
    [BsonId]
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
EOF

cat << 'EOF' > src/ConsolidationWorker/Worker.Application/Services/ConsolidacaoProcessor.cs
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
                throw new NotSupportedException($"Evento desconhecido: {envelope.EventType}");
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

        if (ev.TipoOperacaoAnterior == TipoOperacaoEvento.Credito) deltaCredito -= ev.ValorAnterior;
        else deltaDebito -= ev.ValorAnterior;

        if (ev.TipoOperacaoNovo == TipoOperacaoEvento.Credito) deltaCredito += ev.ValorNovo;
        else deltaDebito += ev.ValorNovo;

        await repository.ProcessarEdicaoAsync(ev.Id, ev.FilialId, dataRef, ev.ValorNovo, (int)ev.TipoOperacaoNovo, ev.NovaDescricao, deltaCredito, deltaDebito, ct);
    }
}
EOF

cat << 'EOF' > src/ConsolidationWorker/Worker.Infrastructure/Persistence/MongoProjectionRepository.cs
using Microsoft.Extensions.Configuration;
using MongoDB.Driver;
using Worker.Domain.Projections;

namespace Worker.Infrastructure.Persistence;

public class MongoProjectionRepository : IProjectionRepository
{
    private readonly IMongoCollection<SaldoDiarioDocument> _saldos;
    private readonly IMongoCollection<ExtratoLancamentoDocument> _extratos;

    public MongoProjectionRepository(IConfiguration config)
    {
        var client = new MongoClient(config.GetConnectionString("MongoDb") ?? "mongodb://admin:adminpassword@localhost:27017");
        var db = client.GetDatabase("fluxo_caixa_read_db");
        _saldos = db.GetCollection<SaldoDiarioDocument>("SaldosDiarios");
        _extratos = db.GetCollection<ExtratoLancamentoDocument>("ExtratoLancamentos");
        CriarIndicesCompostos();
    }

    private void CriarIndicesCompostos()
    {
        var saldoIndex = Builders<SaldoDiarioDocument>.IndexKeys.Ascending(x => x.FilialId).Ascending(x => x.DataConsolidacao);
        _saldos.Indexes.CreateOne(new CreateIndexModel<SaldoDiarioDocument>(saldoIndex, new CreateIndexOptions { Unique = true }));

        var extratoIndex = Builders<ExtratoLancamentoDocument>.IndexKeys.Ascending(x => x.FilialId).Ascending(x => x.DataReferencia).Descending(x => x.DataLancamento);
        _extratos.Indexes.CreateOne(new CreateIndexModel<ExtratoLancamentoDocument>(extratoIndex));
    }

    public async Task ProcessarCriacaoAsync(ExtratoLancamentoDocument lancamento, decimal deltaCredito, decimal deltaDebito, CancellationToken ct = default)
    {
        await _extratos.ReplaceOneAsync(x => x.Id == lancamento.Id, lancamento, new ReplaceOptions { IsUpsert = true }, ct);
        await AtualizarSaldoAtomicoAsync(lancamento.FilialId, lancamento.DataReferencia, deltaCredito, deltaDebito, ct);
    }

    public async Task ProcessarEdicaoAsync(Guid lancamentoId, Guid filialId, string dataRef, decimal novoValor, int novoTipo, string novaDescricao, decimal deltaCredito, decimal deltaDebito, CancellationToken ct = default)
    {
        var updateExtrato = Builders<ExtratoLancamentoDocument>.Update.Set(x => x.Valor, novoValor).Set(x => x.TipoOperacao, novoTipo).Set(x => x.Descricao, novaDescricao);
        await _extratos.UpdateOneAsync(x => x.Id == lancamentoId, updateExtrato, cancellationToken: ct);
        await AtualizarSaldoAtomicoAsync(filialId, dataRef, deltaCredito, deltaDebito, ct);
    }

    private async Task AtualizarSaldoAtomicoAsync(Guid filialId, string dataConsolidacao, decimal deltaCredito, decimal deltaDebito, CancellationToken ct)
    {
        var docId = $"{filialId}_{dataConsolidacao}";
        var deltaSaldo = deltaCredito - deltaDebito;
        var filter = Builders<SaldoDiarioDocument>.Filter.Eq(x => x.Id, docId);
        var update = Builders<SaldoDiarioDocument>.Update
            .SetOnInsert(x => x.FilialId, filialId)
            .SetOnInsert(x => x.DataConsolidacao, dataConsolidacao)
            .Inc(x => x.TotalCreditos, deltaCredito)
            .Inc(x => x.TotalDebitos, deltaDebito)
            .Inc(x => x.SaldoFinal, deltaSaldo)
            .Set(x => x.UltimaAtualizacao, DateTime.UtcNow);

        await _saldos.UpdateOneAsync(filter, update, new UpdateOptions { IsUpsert = true }, ct);
    }
}
EOF

cat << 'EOF' > src/ConsolidationWorker/Worker.Host/Program.cs
using System.Text.Json;
using BancoCarrefour.EventBus.Contracts;
using Confluent.Kafka;
using Worker.Application.Services;
using Worker.Domain.Projections;
using Worker.Infrastructure.Persistence;

namespace Worker.Host;

public class KafkaConsolidacaoWorker(IConfiguration config, ILogger<KafkaConsolidacaoWorker> logger, ConsolidacaoProcessor processor) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrapServers = config["Kafka:BootstrapServers"] ?? "localhost:9092";
        var mainTopic = config["Kafka:Topic"] ?? "lancamentos-eventos";
        var dlqTopic = config["Kafka:DlqTopic"] ?? "lancamentos-dlq";

        var consumerConfig = new ConsumerConfig { BootstrapServers = bootstrapServers, GroupId = "consolidacao-worker-group", AutoOffsetReset = AutoOffsetReset.Earliest, EnableAutoCommit = false };

        using var consumer = new ConsumerBuilder<string, string>(consumerConfig).Build();
        using var dlqProducer = new ProducerBuilder<string, string>(new ProducerConfig { BootstrapServers = bootstrapServers }).Build();

        consumer.Subscribe(mainTopic);

        while (!stoppingToken.IsCancellationRequested)
        {
            var result = consumer.Consume(stoppingToken);
            if (result?.Message == null) continue;

            try
            {
                var envelope = JsonSerializer.Deserialize<EnvelopeEvento>(result.Message.Value) ?? throw new InvalidOperationException("Envelope nulo.");
                await processor.ProcessarEnvelopeAsync(envelope, stoppingToken);
                consumer.Commit(result);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Erro ao consolidar mensagem. Enviando para DLQ.");
                await dlqProducer.ProduceAsync(dlqTopic, new Message<string, string> { Key = result.Message.Key, Value = result.Message.Value }, stoppingToken);
                consumer.Commit(result);
            }
        }
    }
}

public static class Program
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
EOF

cat << 'EOF' > src/ReadService.Consolidado/ReadService.Consolidado.API/Program.cs
using Microsoft.AspNetCore.Authentication.JwtBearer;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<IMongoCollection<SaldoDiarioReadModel>>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var client = new MongoClient(config.GetConnectionString("MongoDb") ?? "mongodb://admin:adminpassword@localhost:27017");
    return client.GetDatabase("fluxo_caixa_read_db").GetCollection<SaldoDiarioReadModel>("SaldosDiarios");
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => { opt.Authority = builder.Configuration["Keycloak:Authority"] ?? "http://localhost:8080/realms/banco-carrefour"; opt.RequireHttpsMetadata = false; opt.TokenValidationParameters.ValidateAudience = false; });

builder.Services.AddAuthorizationBuilder().AddPolicy("read", p => p.RequireRole("read", "admin"));

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/consolidado/{filialId:guid}", async (Guid filialId, string data, IMongoCollection<SaldoDiarioReadModel> collection, CancellationToken ct) =>
{
    var docId = $"{filialId}_{data}";
    var saldo = await collection.Find(x => x.Id == docId).FirstOrDefaultAsync(ct);
    return saldo is not null ? Results.Ok(saldo) : Results.Ok(new SaldoDiarioReadModel { Id = docId, FilialId = filialId, DataConsolidacao = data, SaldoFinal = 0m });
}).RequireAuthorization("read");

app.Run();

public class SaldoDiarioReadModel
{
    [BsonId]
    public string Id { get; set; } = string.Empty;
    public Guid FilialId { get; set; }
    public string DataConsolidacao { get; set; } = string.Empty;
    public decimal TotalCreditos { get; set; }
    public decimal TotalDebitos { get; set; }
    public decimal SaldoFinal { get; set; }
    public DateTime UltimaAtualizacao { get; set; }
}
EOF

cat << 'EOF' > src/ReadService.Extrato/ReadService.Extrato.API/Program.cs
using Microsoft.AspNetCore.Authentication.JwtBearer;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<IMongoCollection<ExtratoItemReadModel>>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var client = new MongoClient(config.GetConnectionString("MongoDb") ?? "mongodb://admin:adminpassword@localhost:27017");
    return client.GetDatabase("fluxo_caixa_read_db").GetCollection<ExtratoItemReadModel>("ExtratoLancamentos");
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => { opt.Authority = builder.Configuration["Keycloak:Authority"] ?? "http://localhost:8080/realms/banco-carrefour"; opt.RequireHttpsMetadata = false; opt.TokenValidationParameters.ValidateAudience = false; });

builder.Services.AddAuthorizationBuilder().AddPolicy("read", p => p.RequireRole("read", "admin"));

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/extrato/{filialId:guid}", async (Guid filialId, string data, IMongoCollection<ExtratoItemReadModel> collection, CancellationToken ct) =>
{
    var filter = Builders<ExtratoItemReadModel>.Filter.And(
        Builders<ExtratoItemReadModel>.Filter.Eq(x => x.FilialId, filialId),
        Builders<ExtratoItemReadModel>.Filter.Eq(x => x.DataReferencia, data));
    var lancamentos = await collection.Find(filter).SortByDescending(x => x.DataLancamento).ToListAsync(ct);
    return Results.Ok(lancamentos);
}).RequireAuthorization("read");

app.Run();

public class ExtratoItemReadModel
{
    [BsonId]
    public Guid Id { get; set; }
    public Guid FilialId { get; set; }
    public string DataReferencia { get; set; } = string.Empty;
    public DateTime DataLancamento { get; set; }
    public decimal Valor { get; set; }
    public int TipoOperacao { get; set; }
    public string Descricao { get; set; } = string.Empty;
    public string UsuarioId { get; set; } = string.Empty;
}
EOF

cat << 'EOF' > tests/BancoCarrefour.UnitTests/Domain/LancamentoTests.cs
using WriteService.Domain.Entities;
using Xunit;

namespace BancoCarrefour.UnitTests.Domain;

public class LancamentoTests
{
    [Fact]
    public void CriarLancamento_ComDadosValidos_DeveInstanciarCorretamente()
    {
        var filialId = Guid.NewGuid();
        var tipoId = Guid.NewGuid();
        var lancamento = new Lancamento(150.75m, " Venda Caixa 01 ", "user-123", filialId, tipoId);

        Assert.NotEqual(Guid.Empty, lancamento.Id);
        Assert.Equal(150.75m, lancamento.Valor);
        Assert.Equal("Venda Caixa 01", lancamento.Descricao);
        Assert.Equal(filialId, lancamento.FilialId);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-10.50)]
    public void CriarLancamento_ComValorInvalido_DeveLancarArgumentException(decimal valorInvalido)
    {
        Assert.Throws<ArgumentException>(() =>
            new Lancamento(valorInvalido, "Teste", "user-123", Guid.NewGuid(), Guid.NewGuid()));
    }
}
EOF

cat << 'EOF' > tests/BancoCarrefour.UnitTests/Worker/ConsolidacaoProcessorTests.cs
using System.Text.Json;
using BancoCarrefour.EventBus.Contracts;
using NSubstitute;
using Worker.Application.Services;
using Worker.Domain.Projections;
using Xunit;

namespace BancoCarrefour.UnitTests.Worker;

public class ConsolidacaoProcessorTests
{
    private readonly IProjectionRepository _repoMock = Substitute.For<IProjectionRepository>();
    private readonly ConsolidacaoProcessor _sut;

    public ConsolidacaoProcessorTests() => _sut = new ConsolidacaoProcessor(_repoMock);

    [Fact]
    public async Task ProcessarEnvelope_EdicaoInvertendoCreditoParaDebito_DeveEstornarCreditoESomarDebito()
    {
        var evento = new LancamentoEditadoEvent(
            Guid.NewGuid(), Guid.NewGuid(),
            ValorAnterior: 200m, TipoOperacaoAnterior: TipoOperacaoEvento.Credito,
            ValorNovo: 80m, TipoOperacaoNovo: TipoOperacaoEvento.Debito,
            NovaDescricao: "Correcao contabil", UsuarioEditorId: "admin-1",
            DataLancamentoOriginalUtc: new DateTime(2026, 11, 9, 10, 0, 0, DateTimeKind.Utc),
            DataEdicaoUtc: DateTime.UtcNow);

        var envelope = new EnvelopeEvento(nameof(LancamentoEditadoEvent), JsonSerializer.Serialize(evento), DateTime.UtcNow);

        await _sut.ProcessarEnvelopeAsync(envelope);

        await _repoMock.Received(1).ProcessarEdicaoAsync(
            evento.Id, evento.FilialId, "2026-11-09",
            novoValor: 80m, novoTipo: (int)TipoOperacaoEvento.Debito,
            novaDescricao: "Correcao contabil", deltaCredito: -200m, deltaDebito: 80m,
            Arg.Any<CancellationToken>());
    }
}
EOF

echo "=== 4. Compilando solução e executando testes unitários ==="
dotnet build
dotnet test
EOF

bash setup.sh
rm setup.sh