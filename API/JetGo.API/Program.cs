using JetGo.API.Configuration;
using JetGo.API.Middlewares;
using JetGo.Infrastructure.Configuration;
using JetGo.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);
DotEnvLoader.LoadNearest(builder.Environment.ContentRootPath);
var environmentSettings = ApiEnvironmentSettingsLoader.Load();

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(x => x.Value?.Errors.Count > 0)
                .ToDictionary(
                    keySelector: x => x.Key,
                    elementSelector: x => x.Value!.Errors
                        .Select(error => string.IsNullOrWhiteSpace(error.ErrorMessage) ? "Neispravan unos." : error.ErrorMessage)
                        .ToArray());

            return new BadRequestObjectResult(new
            {
                statusCode = StatusCodes.Status400BadRequest,
                message = "Validacija korisnickog unosa nije uspjesna.",
                errors
            });
        };
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "JetGo API",
        Version = "v1"
    });

    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        Description = "Unesite JWT token u formatu: Bearer {token}",
        Reference = new OpenApiReference
        {
            Id = "Bearer",
            Type = ReferenceType.SecurityScheme
        }
    };

    options.AddSecurityDefinition("Bearer", jwtSecurityScheme);
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [jwtSecurityScheme] = Array.Empty<string>()
    });
});

builder.Services.AddJetGoInfrastructure(environmentSettings.ConnectionString, environmentSettings.Jwt, environmentSettings.RabbitMq);

var app = builder.Build();

await app.Services.InitializeDatabaseAsync();

app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
