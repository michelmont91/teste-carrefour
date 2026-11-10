using System.Security.Claims;
using Microsoft.AspNetCore.Http;

namespace WriteService.API.Middlewares;

public class AuthenticationContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "sistema-autenticado";
            context.Items["UsuarioId"] = userId;
        }

        await next(context);
    }
}
