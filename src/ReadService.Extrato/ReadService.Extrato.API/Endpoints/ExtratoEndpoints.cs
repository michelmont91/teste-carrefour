using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using ReadService.Extrato.API.Application.Queries;

namespace ReadService.Extrato.API.Endpoints;

public static class ExtratoEndpoints
{
    public static void MapExtratoEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/extrato/{filialId:guid}", ObterExtratoAsync)
            .RequireAuthorization("read")
            .WithTags("Consultas - Extrato Analítico")
            .Produces<IEnumerable<object>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest);
    }

    private static async Task<IResult> ObterExtratoAsync(
        Guid filialId,
        string data,
        ObterExtratoQueryHandler queryHandler,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(data))
            return Results.BadRequest(new { mensagem = "O parametro 'data' (formato YYYY-MM-DD) e obrigatorio." });

        var resultado = await queryHandler.ExecutarAsync(filialId, data, ct);
        return Results.Ok(resultado);
    }
}
