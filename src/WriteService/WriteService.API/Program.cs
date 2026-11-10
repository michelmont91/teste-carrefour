using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using WriteService.API.Endpoints;
using WriteService.API.Middlewares;
using WriteService.Application.UseCases;
using WriteService.Domain.Ports;
using WriteService.Infrastructure.Adapters;
using WriteService.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<WriteDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("Postgres") 
        ?? "Host=postgres;Port=5432;Database=fluxo_caixa_db;Username=admin;Password=adminpassword"));

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
app.UseMiddleware<AuthenticationContextMiddleware>();

app.MapLancamentoEndpoints();

app.Run();
