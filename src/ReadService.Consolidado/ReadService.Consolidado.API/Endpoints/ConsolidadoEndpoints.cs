using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using ReadService.Consolidado.API.Application.Queries;
using ReadService.Consolidado.API.Domain;

namespace ReadService.Consolidado.API.Endpoints;

public static class ConsolidadoEndpoints
{
    public static void MapConsolidadoEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/consolidado/{filialId:guid}", ObterSaldoConsolidadoAsync)
            .RequireAuthorization("read")
            .WithTags("Consultas - Saldos Consolidados")
            .Produces<SaldoDiarioReadModel>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest);
    }

    private static async Task<IResult> ObterSaldoConsolidadoAsync(
        Guid filialId,
        string data,
        ObterSaldoConsolidadoQueryHandler queryHandler,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(data))
            return Results.BadRequest(new { mensagem = "O parametro 'data' (formato YYYY-MM-DD) e obrigatorio." });

        var resultado = await queryHandler.ExecutarAsync(filialId, data, ct);
        return Results.Ok(resultado);
    }
}
