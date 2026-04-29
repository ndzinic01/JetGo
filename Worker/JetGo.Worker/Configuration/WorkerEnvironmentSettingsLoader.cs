using JetGo.Application.Configuration;
using JetGo.Infrastructure.Configuration;

namespace JetGo.Worker.Configuration;

internal static class WorkerEnvironmentSettingsLoader
{
    public static WorkerEnvironmentSettings Load()
    {
        return new WorkerEnvironmentSettings
        {
            ConnectionString = EnvironmentVariableReader.GetRequired("JETGO_CONNECTION_STRING"),
            RabbitMq = new RabbitMqSettings
            {
                Host = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_HOST"),
                Port = EnvironmentVariableReader.GetRequiredInt("JETGO_RABBITMQ_PORT"),
                UserName = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_USERNAME"),
                Password = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_PASSWORD"),
                VirtualHost = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_VIRTUAL_HOST"),
                NotificationsQueueName = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_NOTIFICATIONS_QUEUE")
            }
        };
    }
}
