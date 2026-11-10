# 🏦 Sistema de Fluxo de Caixa — Banco Carrefour

Arquitetura de microsserviços de alta performance, resiliente, transacional e orientada a eventos para o sistema de fluxo de caixa do **Banco Carrefour**. Desenvolvida sob os mais altos padrões de mercado com **.NET 9 LTS**, **Arquitetura Hexagonal Estrita (Ports & Adapters)**, **DDD**, **CQRS** e mensageria assíncrona com **Redpanda**.

---

## 📐 Decisões Arquiteturais (ADRs)

1. **Arquitetura Hexagonal Estrita:** Isolamento absoluto entre as regras de negócio (Domínio) e os detalhes de infraestrutura (EF Core, MongoDB, Redpanda). A comunicação ocorre exclusivamente através de **Portas (Interfaces)**, garantindo a inversão de dependência e testabilidade pura.
2. **CQRS & Polyglot Persistence:** A escrita prioriza **ACID rigoroso** via PostgreSQL; a leitura prioriza baixa latência e alta volumetria via **MongoDB** (motor WiredTiger com índices compostos), eliminando a necessidade de cache auxiliar (Redis).
3. **Event-Driven com Redpanda:** Desacoplamento temporal através de tópicos particionados por `FilialId`, garantindo ordenação estrita por loja e resiliência via **Dead Letter Queue (DLQ)**.
4. **Segurança Centralizada:** Todos os endpoints são protegidos por um **Middleware de Autenticação** customizado que intercepta e valida os tokens JWT (via Keycloak), injetando o contexto do utilizador de forma limpa nos *Use Cases*.

---

## 📊 Diagramas de Fluxo de Arquitetura

### Fluxo 1: Escrita Transacional (Write Service)
*Garante consistência ACID na gravação do lançamento e publicação imutável do evento.*

```mermaid
sequenceDiagram
    autonumber
    actor Client as Cliente PDV
    participant API as WriteService.API
    participant Svc as LancamentoCommandService
    participant DB as PostgreSQL
    participant Producer as KafkaEventProducer
    participant Redpanda as Redpanda

    Client->>API: POST /api/lancamentos
    API->>Svc: Executa comando
    Svc->>DB: Valida e salva Lancamento
    DB-->>Svc: Confirma transacao ACID
    Svc->>Producer: Publica EnvelopeEvento
    Producer->>Redpanda: Envia msg Key FilialId
    Redpanda-->>Producer: Ack de sucesso
    API-->>Client: Retorna 201 Created
```

---

### Fluxo 2: Processamento Assíncrono (Consolidation Worker)
*Consome eventos em background, calcula deltas matemáticos e atualiza o MongoDB.*

```mermaid
sequenceDiagram
    autonumber
    participant Redpanda as Redpanda
    participant Worker as KafkaConsolidacaoWorker
    participant Processor as ConsolidacaoProcessor
    participant MongoRepo as MongoProjectionRepository
    participant Mongo as MongoDB
    participant DLQ as Topico DLQ

    Redpanda->>Worker: Consome EnvelopeEvento
    Worker->>Processor: Interpreta tipo evento
    alt Sucesso
        Processor->>MongoRepo: Envia Deltas
        MongoRepo->>Mongo: Upsert e Atualizacao Atomica
        Mongo-->>Worker: Confirmacao
        Worker->>Redpanda: Commit Offset
    else Erro Inesperado
        Processor-->>Worker: Lanca Excecao
        Worker->>DLQ: Publica mensagem
        Worker->>Redpanda: Commit Offset 
    end
```

---

### Fluxo 3: Consultas de Leitura Otimizadas (CQRS Read APIs)
*Consultas em milissegundos nas coleções projetadas, sem impacto na base transacional.*

```mermaid
sequenceDiagram
    autonumber
    actor Client as Dashboard
    participant ReadConsolidado as API Consolidado
    participant ReadExtrato as API Extrato
    participant Mongo as MongoDB

    par Consulta Saldo
        Client->>ReadConsolidado: GET /api/consolidado
        ReadConsolidado->>Mongo: Busca O(1) por FilialData
        Mongo-->>ReadConsolidado: Retorna SaldoDiario
        ReadConsolidado-->>Client: JSON
    and Consulta Extrato
        Client->>ReadExtrato: GET /api/extrato
        ReadExtrato->>Mongo: Indice Composto
        Mongo-->>ReadExtrato: Lista ordenada
        ReadExtrato-->>Client: Array JSON
    end
```

---

## 🧩 Topologia do Monorepo

```text
BancoCarrefour.sln
│
├── src/
│   ├── BuildingBlocks/
│   │   └── BancoCarrefour.EventBus.Contracts  
│   ├── WriteService/
│   │   ├── WriteService.Domain                
│   │   ├── WriteService.Application           
│   │   ├── WriteService.Infrastructure        
│   │   └── WriteService.API                   
│   ├── ConsolidationWorker/
│   │   ├── Worker.Domain                      
│   │   ├── Worker.Application                 
│   │   ├── Worker.Infrastructure              
│   │   └── Worker.Host                        
│   ├── ReadService.Consolidado/
│   │   └── ReadService.Consolidado.API        
│   └── ReadService.Extrato/
│       └── ReadService.Extrato.API            
│
└── tests/
    └── BancoCarrefour.UnitTests               
```

---

## 🚀 Guia de Operação (GitHub Codespaces / Docker)

### 1. Subir o Ecossistema Completo
O repositório inclui um `docker-compose.yml` que orquestra Bases de Dados, Mensageria e todos os Microsserviços em .NET:
```bash
docker-compose up --build -d
```
* **Kafka UI:** Aceda a `http://localhost:8085` para monitorizar eventos.
* **Keycloak:** Aceda a `http://localhost:8080` para gestão de utilizadores e tokens.

### 2. Dados de Teste Automáticos (Seed)
Ao iniciar, o PostgreSQL cadastra automaticamente as seguintes informações para testes rápidos:
* **Filial ID:** `11111111-1111-1111-1111-111111111111` (Carrefour Pinheiros)
* **Filial ID:** `22222222-2222-2222-2222-222222222222` (Carrefour Dom Pedro)
* **Tipo Operação (Crédito):** `33333333-3333-3333-3333-333333333333`
* **Tipo Operação (Débito):** `44444444-4444-4444-4444-444444444444`

### 3. Executando as Aplicações Manualmente (Opcional)
Se preferir rodar fora do Docker para *debug* no terminal:
```bash
dotnet run --project src/WriteService/WriteService.API/WriteService.API.csproj
dotnet run --project src/ConsolidationWorker/Worker.Host/Worker.Host.csproj
dotnet run --project src/ReadService.Consolidado/ReadService.Consolidado.API/ReadService.Consolidado.API.csproj
dotnet run --project src/ReadService.Extrato/ReadService.Extrato.API/ReadService.Extrato.API.csproj
```