using System.Security.Claims;
using Microsoft.AspNetCore.Http;

namespace ReadService.Extrato.API.Middlewares;

public class AuthenticationContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            context.Items["UsuarioId"] = context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "leitor-autenticado";
        }
        await next(context);
    }
}
