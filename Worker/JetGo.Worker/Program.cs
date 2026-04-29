using JetGo.Infrastructure;
using JetGo.Infrastructure.Configuration;
using JetGo.Worker.Configuration;
using JetGo.Worker.Consumers;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = Host.CreateApplicationBuilder(args);
DotEnvLoader.LoadNearest(builder.Environment.ContentRootPath);
var environmentSettings = WorkerEnvironmentSettingsLoader.Load();

builder.Services.AddJetGoWorkerInfrastructure(
    environmentSettings.ConnectionString,
    environmentSettings.RabbitMq);
builder.Services.AddHostedService<NotificationQueueConsumer>();

var host = builder.Build();
await host.RunAsync();
