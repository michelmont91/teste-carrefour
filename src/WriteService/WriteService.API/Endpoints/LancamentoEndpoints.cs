using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using WriteService.Application.UseCases;

namespace WriteService.API.Endpoints;

public static class LancamentoEndpoints
{
    public static void MapLancamentoEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/lancamentos")
            .WithTags("Lançamentos Contábeis");

        group.MapPost("/", CriarLancamentoAsync)
            .RequireAuthorization("writer")
            .Produces<LancamentoResponse>(StatusCodes.Status201Created)
            .Produces(StatusCodes.Status400BadRequest);

        group.MapPut("/{id:guid}", EditarLancamentoAsync)
            .RequireAuthorization("admin")
            .Produces<LancamentoResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status404NotFound);
    }

    private static async Task<IResult> CriarLancamentoAsync(
        CriarLancamentoRequest request,
        HttpContext httpContext,
        LancamentoCommandService service,
        CancellationToken ct)
    {
        var userId = httpContext.Items["UsuarioId"]?.ToString() ?? "sistema-operador";
        var resultado = await service.CriarAsync(request, userId, ct);
        return Results.Created($"/api/lancamentos/{resultado.Id}", resultado);
    }

    private static async Task<IResult> EditarLancamentoAsync(
        Guid id,
        EditarLancamentoRequest request,
        HttpContext httpContext,
        LancamentoCommandService service,
        CancellationToken ct)
    {
        var userId = httpContext.Items["UsuarioId"]?.ToString() ?? "sistema-admin";
        var resultado = await service.EditarAsync(id, request, userId, ct);
        return Results.Ok(resultado);
    }
}
