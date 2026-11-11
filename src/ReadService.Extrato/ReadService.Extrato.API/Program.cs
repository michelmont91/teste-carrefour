using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using ReadService.Extrato.API.Application.Queries;
using ReadService.Extrato.API.Domain;
using ReadService.Extrato.API.Endpoints;
using ReadService.Extrato.API.Infrastructure;

BsonSerializer.RegisterSerializer(new GuidSerializer(GuidRepresentation.Standard));

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IExtratoQueryRepository, MongoExtratoRepository>();
builder.Services.AddScoped<ObterExtratoQueryHandler>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => 
    { 
        opt.Authority = builder.Configuration["Keycloak:Authority"] ?? "http://keycloak:8080/realms/banco-carrefour"; 
        opt.RequireHttpsMetadata = false;
        opt.MapInboundClaims = false;
        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = false,
            ValidateIssuer = true,
            ValidIssuers = new[]
            {
                "http://localhost:8080/realms/banco-carrefour",
                "http://keycloak:8080/realms/banco-carrefour"
            },
            RoleClaimType = "roles"
        };
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("read", p => p.RequireRole("read", "admin"));

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.UseMiddleware<ReadService.Extrato.API.Middlewares.AuthenticationContextMiddleware>();

app.MapExtratoEndpoints();

app.Run();
