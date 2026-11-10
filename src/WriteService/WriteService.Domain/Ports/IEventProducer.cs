namespace WriteService.Domain.Ports;

public interface IEventProducer
{
    Task PublicarAsync<T>(string chave, T evento, CancellationToken ct = default) where T : class;
}
