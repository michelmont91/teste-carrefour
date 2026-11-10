namespace WriteService.Domain.Entities;

public abstract class EntityBase
{
    public Guid Id { get; protected set; } = Guid.NewGuid();
    public DateTime CreatedAtUtc { get; protected set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; protected set; }
}

public enum TipoOperacao
{
    Debito = 0,
    Credito = 1
}

public class Filial : EntityBase
{
    public string Nome { get; private set; } = string.Empty;
    public string CodigoDocumento { get; private set; } = string.Empty;

    protected Filial() { }

    public Filial(Guid id, string nome, string codigoDocumento)
    {
        Id = id;
        Nome = nome;
        CodigoDocumento = codigoDocumento;
    }
}

public class TipoLancamento : EntityBase
{
    public TipoOperacao Operacao { get; private set; }
    public string Descricao { get; private set; } = string.Empty;

    protected TipoLancamento() { }

    public TipoLancamento(Guid id, TipoOperacao operacao, string descricao)
    {
        Id = id;
        Operacao = operacao;
        Descricao = descricao;
    }
}

public class Lancamento : EntityBase
{
    public decimal Valor { get; private set; }
    public DateTime DataLancamento { get; private set; }
    public string Descricao { get; private set; } = string.Empty;
    public string UsuarioId { get; private set; } = string.Empty;
    public Guid FilialId { get; private set; }
    public Guid TipoLancamentoId { get; private set; }

    public Filial? Filial { get; private set; }
    public TipoLancamento? TipoLancamento { get; private set; }

    protected Lancamento() { }

    public Lancamento(decimal valor, string descricao, string usuarioId, Guid filialId, Guid tipoLancamentoId)
    {
        Validar(valor, descricao, filialId, tipoLancamentoId);

        Valor = valor;
        DataLancamento = DateTime.UtcNow;
        Descricao = descricao.Trim();
        UsuarioId = usuarioId;
        FilialId = filialId;
        TipoLancamentoId = tipoLancamentoId;
    }

    public void Atualizar(decimal novoValor, string novaDescricao, Guid novoTipoLancamentoId, string usuarioEditorId)
    {
        Validar(novoValor, novaDescricao, FilialId, novoTipoLancamentoId);

        Valor = novoValor;
        Descricao = novaDescricao.Trim();
        TipoLancamentoId = novoTipoLancamentoId;
        UsuarioId = usuarioEditorId;
        UpdatedAtUtc = DateTime.UtcNow;
    }

    private static void Validar(decimal valor, string descricao, Guid filialId, Guid tipoLancamentoId)
    {
        if (valor <= 0)
            throw new ArgumentException("O valor do lançamento deve ser maior que zero.");
        if (string.IsNullOrWhiteSpace(descricao))
            throw new ArgumentException("A descrição do lançamento é obrigatória.");
        if (filialId == Guid.Empty)
            throw new ArgumentException("A filial informada é inválida.");
        if (tipoLancamentoId == Guid.Empty)
            throw new ArgumentException("O tipo de lançamento informado é inválido.");
    }
}
