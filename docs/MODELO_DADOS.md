# Modelo de Dados Poliglota (PostgreSQL 16 & MongoDB 7.0)

Especificacao fisica e logica das estruturas de armazenamento da arquitetura CQRS do Sistema de Fluxo de Caixa do Banco Carrefour.

## 1. Command Side - Modelo Relacional (PostgreSQL 16)

- **Database:** `banco_carrefour`
- **ORM:** Entity Framework Core 9.0 (`WriteDbContext`)
- **Garantias:** Transacoes ACID, integridade referencial por FK e precisao `numeric(18,2)`.

### 1.1. DDL das Tabelas Relacionais
```sql
CREATE TABLE Filiais (
    Id uuid PRIMARY KEY,
    Nome varchar(150) NOT NULL,
    CodigoInterno varchar(20) NOT NULL,
    Ativa boolean NOT NULL DEFAULT TRUE
);

CREATE TABLE TiposLancamento (
    Id uuid PRIMARY KEY,
    Descricao varchar(100) NOT NULL,
    NaturezaOperacao int NOT NULL -- 1: Credito | 2: Debito
);

CREATE TABLE Lancamentos (
    Id uuid PRIMARY KEY,
    Valor numeric(18,2) NOT NULL CHECK (Valor > 0),
    DataLancamento timestamptz NOT NULL,
    Descricao varchar(250) NOT NULL,
    FilialId uuid NOT NULL REFERENCES Filiais(Id),
    TipoLancamentoId uuid NOT NULL REFERENCES TiposLancamento(Id),
    Operacao int NOT NULL,
    UsuarioId varchar(100) NOT NULL
);
```

### 1.2. Seed Inicial de Dominio
| Tabela | Id (UUID) | Descricao | Natureza |
| :--- | :--- | :--- | :--- |
| Filiais | `11111111-1111-1111-1111-111111111111` | Filial Matriz Carrefour SP | Ativa padrao |
| TiposLancamento | `33333333-3333-3333-3333-333333333333` | Recebimento Venda / PIX | 1 (Credito) |
| TiposLancamento | `22222222-2222-2222-2222-222222222222` | Pagamento Fornecedor / Despesa | 2 (Debito) |

## 2. Query Side - Modelo Documental (MongoDB 7.0)

- **Database:** `fluxo_caixa_read_db`
- **Serializacao:** `MongoDB.Driver 3.0.0` com `GuidRepresentation.Standard` (UUID) e `Decimal128`.

### 2.1. Colecao `SaldosDiarios` (ReadService.Consolidado.API)
Chave primaria `_id` no formato `{FilialId}_{YYYY-MM-DD}` para leitura O(1) em menos de 5ms via `$inc` atomico:
```json
{
  "_id": "11111111-1111-1111-1111-111111111111_2026-11-11",
  "FilialId": "11111111-1111-1111-1111-111111111111",
  "DataConsolidacao": "2026-11-11",
  "TotalCreditos": 1500.00,
  "TotalDebitos": 300.00,
  "SaldoFinal": 1200.00,
  "UltimaAtualizacao": "2026-11-11T01:16:40.530Z"
}
```

### 2.2. Colecao `ExtratoLancamentos` (ReadService.Extrato.API)
Indice composto: `{ FilialId: 1, DataReferencia: 1, DataLancamento: -1 }`.
```json
{
  "_id": "90fa8614-750b-4fe7-8a05-e0a1e767d7a9",
  "FilialId": "11111111-1111-1111-1111-111111111111",
  "DataReferencia": "2026-11-11",
  "DataLancamento": "2026-11-11T01:16:40.513Z",
  "Valor": 150.50,
  "TipoOperacao": 1,
  "Descricao": "Venda PDV - Fluxo Autenticado",
  "UsuarioId": "sistema-autenticado"
}
```