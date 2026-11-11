# Especificacao de Topicos e Schemas de Eventos (Redpanda / Kafka)

Documentacao tecnica da camada de Event Streaming da solucao do Banco Carrefour.

## 1. Topologia de Topicos
| Topico | Particoes | Key | Produtor | Consumidor | Papel |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `lancamentos-eventos` | 3 | `FilialId` | `WriteService.API` | `ConsolidationWorker` | Eventos de criacao e edicao contabil |
| `lancamentos-dlq` | 1 | `FilialId` | `ConsolidationWorker` | Auditoria / DLQ | Isolamento de falhas e Poison Pills |

## 2. Garantias de Ordem (FIFO por Filial) e Entrega
- **Partition Key = FilialId:** Garante que todos os eventos de uma mesma filial caiam na mesma particao, mantendo a ordem estrita entre criacao (`POST`) e retificacao (`PUT`).
- **Commit Manual (At-Least-Once):** `EnableAutoCommit = false` e `AutoOffsetReset = Earliest`. O offset so e confirmado apos a gravacao no MongoDB.

## 3. Contratos JSON Schema (Draft-07)

### 3.1. EnvelopeEvento
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "EnvelopeEvento",
  "type": "object",
  "required": ["EventType", "PayloadJson"],
  "properties": {
    "EventType": { "type": "string", "enum": ["LancamentoCriadoEvent", "LancamentoEditadoEvent"] },
    "PayloadJson": { "type": "string" }
  }
}
```

### 3.2. LancamentoCriadoEvent
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "LancamentoCriadoEvent",
  "type": "object",
  "required": ["Id", "FilialId", "Valor", "TipoOperacao", "Descricao", "DataLancamentoUtc", "UsuarioId"],
  "properties": {
    "Id": { "type": "string", "format": "uuid" },
    "FilialId": { "type": "string", "format": "uuid" },
    "Valor": { "type": "number", "exclusiveMinimum": 0 },
    "TipoOperacao": { "type": "integer", "enum": [1, 2] },
    "Descricao": { "type": "string", "maxLength": 250 },
    "DataLancamentoUtc": { "type": "string", "format": "date-time" },
    "UsuarioId": { "type": "string" }
  }
}
```

### 3.3. LancamentoEditadoEvent
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "LancamentoEditadoEvent",
  "type": "object",
  "required": ["Id", "FilialId", "ValorAnterior", "TipoOperacaoAnterior", "ValorNovo", "TipoOperacaoNovo", "NovaDescricao", "DataLancamentoOriginalUtc", "UsuarioId"],
  "properties": {
    "Id": { "type": "string", "format": "uuid" },
    "FilialId": { "type": "string", "format": "uuid" },
    "ValorAnterior": { "type": "number", "exclusiveMinimum": 0 },
    "TipoOperacaoAnterior": { "type": "integer", "enum": [1, 2] },
    "ValorNovo": { "type": "number", "exclusiveMinimum": 0 },
    "TipoOperacaoNovo": { "type": "integer", "enum": [1, 2] },
    "NovaDescricao": { "type": "string", "maxLength": 250 },
    "DataLancamentoOriginalUtc": { "type": "string", "format": "date-time" },
    "UsuarioId": { "type": "string" }
  }
}
```