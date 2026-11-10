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
    actor Client as "Cliente / PDV"
    participant API as "WriteService.API"
    participant Svc as "LancamentoCommandService"
    participant DB as "PostgreSQL (ACID)"
    participant Producer as "KafkaEventProducer"
    participant Redpanda as "Redpanda"

    Client->>API: POST /api/lancamentos (JWT)
    API->>Svc: Executa comando (Criar/Editar)
    Svc->>DB: Valida regras e salva Lançamento
    DB-->>Svc: Confirma transação (Commit)
    Svc->>Producer: Publica EnvelopeEvento
    Producer->>Redpanda: Envia mensagem (Key: FilialId)
    Redpanda-->>Producer: Ack de sucesso
    API-->>Client: Retorna 201/200 OK
    sequenceDiagram
    autonumber
    actor Client as "Cliente / Dashboard"
    participant ReadConsolidado as "API Consolidado"
    participant ReadExtrato as "API Extrato"
    participant Mongo as "MongoDB"

    par Consulta de Saldo Consolidado
        Client->>ReadConsolidado: GET /api/consolidado/{id}?data=YYYY-MM-DD
        ReadConsolidado->>Mongo: Busca O(1) por ID composto (Filial_Data)
        Mongo-->>ReadConsolidado: Retorna SaldoDiario
        ReadConsolidado-->>Client: Retorna JSON
    and Consulta de Extrato Analítico
        Client->>ReadExtrato: GET /api/extrato/{id}?data=YYYY-MM-DD
        ReadExtrato->>Mongo: Consulta por Índice Composto (Data/Filial)
        Mongo-->>ReadExtrato: Retorna lista ordenada
        ReadExtrato-->>Client: Retorna Array JSON
    end
    sequenceDiagram
    autonumber
    actor Client as "Cliente / Dashboard"
    participant ReadConsolidado as "API Consolidado"
    participant ReadExtrato as "API Extrato"
    participant Mongo as "MongoDB"

    par Consulta de Saldo Consolidado
        Client->>ReadConsolidado: GET /api/consolidado/{id}?data=YYYY-MM-DD
        ReadConsolidado->>Mongo: Busca O(1) por ID composto (Filial_Data)
        Mongo-->>ReadConsolidado: Retorna SaldoDiario
        ReadConsolidado-->>Client: Retorna JSON
    and Consulta de Extrato Analítico
        Client->>ReadExtrato: GET /api/extrato/{id}?data=YYYY-MM-DD
        ReadExtrato->>Mongo: Consulta por Índice Composto (Data/Filial)
        Mongo-->>ReadExtrato: Retorna lista ordenada
        ReadExtrato-->>Client: Retorna Array JSON
    end
    BancoCarrefour.sln
│
├── src/
│   ├── BuildingBlocks/
│   │   └── BancoCarrefour.EventBus.Contracts  # Contratos de Eventos Partilhados
│   ├── WriteService/
│   │   ├── WriteService.Domain                # Entidades, Invariantes e Portas (Interfaces)
│   │   ├── WriteService.Application           # Use Cases de Comandos de Escrita
│   │   ├── WriteService.Infrastructure        # Adaptadores: PostgreSQL (EF Core) e Kafka
│   │   └── WriteService.API                   # Endpoints Limpos e Middleware JWT
│   ├── ConsolidationWorker/
│   │   ├── Worker.Domain                      # Modelos de Projeção e Portas
│   │   ├── Worker.Application                 # Processador Matemático de Deltas
│   │   ├── Worker.Infrastructure              # Repositório MongoDB e Background Service
│   │   └── Worker.Host                        # Host Genérico .NET
│   ├── ReadService.Consolidado/
│   │   └── ReadService.Consolidado.API        # Hexagonal: Domínio, Queries, Infra e Endpoints
│   └── ReadService.Extrato/
│       └── ReadService.Extrato.API            # Hexagonal: Domínio, Queries, Infra e Endpoints
│
└── tests/
    └── BancoCarrefour.UnitTests               # Suíte de Testes Unitários e Mocks