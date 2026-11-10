using Microsoft.AspNetCore.Authentication.JwtBearer;
using ReadService.Consolidado.API.Domain;
using ReadService.Consolidado.API.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IConsolidadoQueryRepository, MongoConsolidadoRepository>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => 
    { 
        opt.Authority = builder.Configuration["Keycloak:Authority"] ?? "http://localhost:8080/realms/banco-carrefour"; 
        opt.RequireHttpsMetadata = false; 
        opt.TokenValidationParameters.ValidateAudience = false; 
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("read", p => p.RequireRole("read", "admin"));

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/api/consolidado/{filialId:guid}", async (
    Guid filialId, 
    string data, 
    IConsolidadoQueryRepository repository, 
    CancellationToken ct) =>
{
    if (string.IsNullOrWhiteSpace(data))
        return Results.BadRequest(new { mensagem = "O parametro 'data' (formato YYYY-MM-DD) e obrigatorio." });

    var saldo = await repository.ObterPorFilialEDataAsync(filialId, data, ct);
    
    if (saldo is null)
    {
        // Retorna zero se ainda nao houver movimentacoes consolidadas no dia
        return Results.Ok(new SaldoDiarioReadModel
        {
            Id = $"{filialId}_{data}",
            FilialId = filialId,
            DataConsolidacao = data,
            TotalCreditos = 0m,
            TotalDebitos = 0m,
            SaldoFinal = 0m,
            UltimaAtualizacao = DateTime.UtcNow
        });
    }

    return Results.Ok(saldo);
}).RequireAuthorization("read");

app.Run();
