# 📜 Catálogo de Contratos das APIs e Eventos Assíncronos

Especificação técnica dos contratos REST (HTTP/JSON), políticas de segurança OAuth2/OIDC (Keycloak) e schemas de mensageria assíncrona (Redpanda/Kafka) da solução de Fluxo de Caixa do Banco Carrefour.

---

## 🔐 1. Autenticação e Autorização (Keycloak OIDC)

Todas as APIs exigem o envio de um token JWT válido no cabeçalho `Authorization: Bearer <token>`. A validação ocorre com `MapInboundClaims = false`, preservando a claim nativa `roles` emitida pelo Keycloak.

### Obtenção de Token (OAuth2 Resource Owner Password Credentials Grant)
* **Método:** `POST`
* **Endpoint:** `http://localhost:8080/realms/banco-carrefour/protocol/openid-connect/token`
* **Content-Type:** `application/x-www-form-urlencoded`

#### Parâmetros do Form-Data
| Parâmetro | Valor Padrão (Dev) | Obrigatório | Descrição |
| :--- | :--- | :--- | :--- |
| `client_id` | `admin-cli` | Sim | Identificador do cliente OIDC |
| `grant_type` | `password` | Sim | Fluxo de concessão por credenciais diretas |
| `username` | `admin` | Sim | Nome do utilizador |
| `password` | `admin` | Sim | Senha do utilizador |

#### Matriz de Controle de Acesso Baseado em Roles (RBAC)
| Microsserviço | Endpoint | Política Exigida | Roles Aceitas no JWT |
| :--- | :--- | :--- | :--- |
| `WriteService.API` | `POST /api/lancamentos` | `writer` | `writer`, `admin` |
| `WriteService.API` | `PUT /api/lancamentos/{id}` | `admin` | `admin` |
| `ReadService.Consolidado.API` | `GET /api/consolidado/{filialId}` | `read` | `read`, `admin` |
| `ReadService.Extrato.API` | `GET /api/extrato/{filialId}` | `read` | `read`, `admin` |

---

## ✍️ 2. Command Side — `WriteService.API` (Porta `5001`)

Responsável pela recepção transacional de lançamentos contábeis, validação de domínio e publicação de eventos no Redpanda.

### 2.1. Criar Lançamento Contábil
* **Método:** `POST`
* **Rota:** `/api/lancamentos`
* **Autenticação:** Bearer JWT (Roles: `writer` ou `admin`)

#### Request Body (`application/json`)
```json
{
  "valor": 150.50,
  "descricao": "Venda PDV - Caixa 04",
  "filialId": "11111111-1111-1111-1111-111111111111",
  "tipoLancamentoId": "33333333-3333-3333-3333-333333333333"
}
```

#### Regras de Domínio e Mapeamento de `tipoLancamentoId`
* `valor`: Decimal estritamente maior que zero (`> 0`).
* `descricao`: Obrigatória, máximo de 250 caracteres.
* `filialId`: UUID válido da filial de origem.
* `tipoLancamentoId`: Determina a natureza da operação contábil conforme tabela de domínio:
  * `33333333-3333-3333-3333-333333333333` (ou final par) -> `1` (**Crédito / Entrada**)
  * `22222222-2222-2222-2222-222222222222` (Débito explícito) -> `2` (**Débito / Saída**)

#### Response `201 Created`
* **Header:** `Location: /api/lancamentos/90fa8614-750b-4fe7-8a05-e0a1e767d7a9`
```json
{
  "id": "90fa8614-750b-4fe7-8a05-e0a1e767d7a9",
  "valor": 150.50,
  "dataLancamento": "2026-11-11T01:16:40.5131294Z",
  "descricao": "Venda PDV - Caixa 04",
  "filialId": "11111111-1111-1111-1111-111111111111",
  "operacao": 1
}
```

---

### 2.2. Editar / Retificar Lançamento Contábil
* **Método:** `PUT`
* **Rota:** `/api/lancamentos/{id}`
* **Autenticação:** Bearer JWT (Role exclusiva: `admin`)

#### Request Body (`application/json`)
```json
{
  "novoValor": 200.00,
  "novaDescricao": "Retificacao de Fechamento PDV - Caixa 04",
  "novoTipoLancamentoId": "33333333-3333-3333-3333-333333333333"
}
```

#### Response `200 OK`
```json
{
  "id": "90fa8614-750b-4fe7-8a05-e0a1e767d7a9",
  "valor": 200.00,
  "dataLancamento": "2026-11-11T01:16:40.5131294Z",
  "descricao": "Retificacao de Fechamento PDV - Caixa 04",
  "filialId": "11111111-1111-1111-1111-111111111111",
  "operacao": 1
}
```

#### Códigos de Status HTTP (`WriteService.API`)
| Status | Cenário |
| :--- | :--- |
| `201 Created` | Lançamento criado no PostgreSQL e publicado no Redpanda |
| `200 OK` | Lançamento retificado com sucesso e evento de estorno/ajuste publicado |
| `400 Bad Request` | Violação de invariante de domínio (ex.: `valor <= 0` ou descrição vazia) |
| `401 Unauthorized` | Token JWT ausente, expirado ou assinatura inválida |
| `403 Forbidden` | Token válido, mas sem a role exigida (`writer` ou `admin`) |
| `404 Not Found` | `id` do lançamento não encontrado na operação de `PUT` |

---

## 📊 3. Query Side — `ReadService.Consolidado.API` (Porta `5002`)

Consulta de altíssima performance (O(1) via busca direta por chave primária composta `_id` no MongoDB) capaz de absorver 50+ requisições por segundo sem impactar o banco relacional.

### 3.1. Obter Saldo Diário Consolidado por Filial
* **Método:** `GET`
* **Rota:** `/api/consolidado/{filialId}?data={YYYY-MM-DD}`
* **Autenticação:** Bearer JWT (Roles: `read` ou `admin`)

#### Parâmetros da Requisição
| Nome | Local | Tipo | Obrigatório | Exemplo |
| :--- | :--- | :--- | :--- | :--- |
| `filialId` | Path | `Guid` | Sim | `11111111-1111-1111-1111-111111111111` |
| `data` | Query | `String` (`YYYY-MM-DD`) | Não (default: data UTC atual) | `2026-11-11` |

#### Response `200 OK`
*(Caso ainda não existam lançamentos na data consultada, retorna um objeto consolidado zerado com status `200 OK` para evitar tratamento de erro desnecessário no front-end).*
```json
{
  "id": "11111111-1111-1111-1111-111111111111_2026-11-11",
  "filialId": "11111111-1111-1111-1111-111111111111",
  "dataConsolidacao": "2026-11-11",
  "totalCreditos": 301.00,
  "totalDebitos": 0.00,
  "saldoFinal": 301.00,
  "ultimaAtualizacao": "2026-11-11T01:16:40.530Z"
}
```

---

## 📑 4. Query Side — `ReadService.Extrato.API` (Porta `5003`)

Consulta analítica e ordenada cronologicamente de todos os lançamentos de uma filial em determinada data, apoiada por índice composto no MongoDB (`FilialId ASC, DataReferencia ASC, DataLancamento DESC`).

### 4.1. Obter Extrato Detalhado por Filial e Data
* **Método:** `GET`
* **Rota:** `/api/extrato/{filialId}?data={YYYY-MM-DD}`
* **Autenticação:** Bearer JWT (Roles: `read` ou `admin`)

#### Response `200 OK`
```json
[
  {
    "id": "90fa8614-750b-4fe7-8a05-e0a1e767d7a9",
    "filialId": "11111111-1111-1111-1111-111111111111",
    "dataReferencia": "2026-11-11",
    "dataLancamento": "2026-11-11T01:16:40.513Z",
    "valor": 150.50,
    "tipoOperacao": 1,
    "descricao": "Venda PDV - Fluxo Autenticado",
    "usuarioId": "sistema-autenticado"
  }
]
```

---

## 📨 5. Contratos de Eventos Assíncronos (Redpanda / Kafka)

* **Tópico Principal:** `lancamentos-eventos`
* **Tópico de Dead-Letter Queue (DLQ):** `lancamentos-dlq`
* **Chave de Particionamento (Partition Key):** `FilialId.ToString()` (garante ordenação estrita FIFO de todos os eventos pertencentes à mesma filial dentro da mesma partição do Kafka/Redpanda).

### 5.1. Envelope Padrão (`EnvelopeEvento`)
Todas as mensagens trafegam encapsuladas num envelope polimórfico serializado em JSON:
```json
{
  "EventType": "LancamentoCriadoEvent",
  "PayloadJson": "{\"Id\":\"90fa8614-750b-4fe7-8a05-e0a1e767d7a9\",\"FilialId\":\"11111111-1111-1111-1111-111111111111\",\"Valor\":150.50,\"TipoOperacao\":1,\"Descricao\":\"Venda PDV\",\"DataLancamentoUtc\":\"2026-11-11T01:16:40.5131294Z\",\"UsuarioId\":\"sistema-autenticado\"}"
}
```

### 5.2. Payload: `LancamentoCriadoEvent`
```json
{
  "Id": "90fa8614-750b-4fe7-8a05-e0a1e767d7a9",
  "FilialId": "11111111-1111-1111-1111-111111111111",
  "Valor": 150.50,
  "TipoOperacao": 1,
  "Descricao": "Venda PDV - Fluxo Autenticado",
  "DataLancamentoUtc": "2026-11-11T01:16:40.5131294Z",
  "UsuarioId": "sistema-autenticado"
}
```

### 5.3. Payload: `LancamentoEditadoEvent`
Emitido quando um administrador retifica um lançamento existente. Contém o estado anterior e o novo estado para que o `ConsolidationWorker` execute o estorno aritmético exato e aplique o novo saldo de forma atômica:
```json
{
  "Id": "90fa8614-750b-4fe7-8a05-e0a1e767d7a9",
  "FilialId": "11111111-1111-1111-1111-111111111111",
  "ValorAnterior": 150.50,
  "TipoOperacaoAnterior": 1,
  "ValorNovo": 200.00,
  "TipoOperacaoNovo": 1,
  "NovaDescricao": "Retificacao de Fechamento PDV",
  "DataLancamentoOriginalUtc": "2026-11-11T01:16:40.5131294Z",
  "UsuarioId": "admin"
}
```
