using Microsoft.AspNetCore.Authentication.JwtBearer;
using ReadService.Extrato.API.Application.Queries;
using ReadService.Extrato.API.Domain;
using ReadService.Extrato.API.Endpoints;
using ReadService.Extrato.API.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IExtratoQueryRepository, MongoExtratoRepository>();
builder.Services.AddScoped<ObterExtratoQueryHandler>();

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

app.MapExtratoEndpoints();

app.Run();
