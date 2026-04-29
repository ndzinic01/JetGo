using JetGo.Application.Configuration;
using RabbitMQ.Client;

namespace JetGo.Infrastructure.Messaging;

public interface IRabbitMqPersistentConnection : IDisposable
{
    IConnection GetConnection();
}

public sealed class RabbitMqPersistentConnection : IRabbitMqPersistentConnection
{
    private readonly RabbitMqSettings _settings;
    private readonly object _syncRoot = new();
    private IConnection? _connection;

    public RabbitMqPersistentConnection(RabbitMqSettings settings)
    {
        _settings = settings;
    }

    public IConnection GetConnection()
    {
        if (_connection is { IsOpen: true })
        {
            return _connection;
        }

        lock (_syncRoot)
        {
            if (_connection is { IsOpen: true })
            {
                return _connection;
            }

            _connection?.Dispose();

            var factory = new ConnectionFactory
            {
                HostName = _settings.Host,
                Port = _settings.Port,
                UserName = _settings.UserName,
                Password = _settings.Password,
                VirtualHost = _settings.VirtualHost,
                DispatchConsumersAsync = true
            };

            _connection = factory.CreateConnection();
            return _connection;
        }
    }

    public void Dispose()
    {
        lock (_syncRoot)
        {
            if (_connection is null)
            {
                return;
            }

            if (_connection.IsOpen)
            {
                _connection.Close();
            }

            _connection.Dispose();
            _connection = null;
        }
    }
}
