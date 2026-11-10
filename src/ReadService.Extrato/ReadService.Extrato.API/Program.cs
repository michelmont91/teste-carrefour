using Microsoft.AspNetCore.Authentication.JwtBearer;
using ReadService.Extrato.API.Domain;
using ReadService.Extrato.API.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IExtratoQueryRepository, MongoExtratoRepository>();

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

app.MapGet("/api/extrato/{filialId:guid}", async (
    Guid filialId, 
    string data, 
    IExtratoQueryRepository repository, 
    CancellationToken ct) =>
{
    if (string.IsNullOrWhiteSpace(data))
        return Results.BadRequest(new { mensagem = "O parametro 'data' (formato YYYY-MM-DD) e obrigatorio." });

    var extrato = await repository.ObterExtratoPorFilialEDataAsync(filialId, data, ct);
    return Results.Ok(extrato);
}).RequireAuthorization("read");

app.Run();
