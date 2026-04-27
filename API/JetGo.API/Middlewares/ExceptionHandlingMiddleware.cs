using JetGo.Application.Exceptions;

namespace JetGo.API.Middlewares;

public sealed class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception exception)
        {
            await HandleExceptionAsync(context, exception);
        }
    }

    private Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        _logger.LogError(exception, "Unhandled exception while processing request {Method} {Path}.", context.Request.Method, context.Request.Path);

        var (statusCode, message, errors) = exception switch
        {
            ValidationException validationException => (StatusCodes.Status400BadRequest, validationException.Message, validationException.Errors),
            UnauthorizedException unauthorizedException => (StatusCodes.Status401Unauthorized, unauthorizedException.Message, (IDictionary<string, string[]>?)null),
            ForbiddenException forbiddenException => (StatusCodes.Status403Forbidden, forbiddenException.Message, null),
            NotFoundException notFoundException => (StatusCodes.Status404NotFound, notFoundException.Message, null),
            ConflictException conflictException => (StatusCodes.Status409Conflict, conflictException.Message, null),
            _ => (StatusCodes.Status500InternalServerError, "Doslo je do neocekivane greske. Pokusajte ponovo kasnije.", null)
        };

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";

        return context.Response.WriteAsJsonAsync(new
        {
            statusCode,
            message,
            errors
        });
    }
}
