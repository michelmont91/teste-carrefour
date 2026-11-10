using Microsoft.AspNetCore.Authentication.JwtBearer;
using ReadService.Consolidado.API.Application.Queries;
using ReadService.Consolidado.API.Domain;
using ReadService.Consolidado.API.Endpoints;
using ReadService.Consolidado.API.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IConsolidadoQueryRepository, MongoConsolidadoRepository>();
builder.Services.AddScoped<ObterSaldoConsolidadoQueryHandler>();

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
app.UseMiddleware<ReadService.Consolidado.API.Middlewares.AuthenticationContextMiddleware>();

app.MapConsolidadoEndpoints();

app.Run();
