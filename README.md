# 🏦 Sistema de Fluxo de Caixa — Banco Carrefour

Arquitetura de microsserviços de alta performance, resiliente, transacional e orientada a eventos para o sistema de fluxo de caixa do **Banco Carrefour**. Desenvolvida seguindo os mais altos padrões de mercado com **.NET LTS**, **Arquitetura Hexagonal (Ports & Adapters)**, **DDD**, **CQRS** e mensageria assíncrona com **Redpanda (Kafka API)**.

---

## 📐 Decisões Arquiteturais e Justificativas (ADRs)

1. **Arquitetura Hexagonal (Ports & Adapters):** Isolamento total entre as regras de negócio contábeis (Domínio) e os detalhes de infraestrutura (EF Core, MongoDB, Redpanda). Permite testabilidade unitária isolada de ponta a ponta.
2. **CQRS & Polyglot Persistence:** Separação estrita entre escrita (Command) e leitura (Query). A escrita prioriza **ACID rigoroso** via PostgreSQL; a leitura prioriza baixa latência e alta volumetria via **MongoDB** (motor WiredTiger).
3. **Event-Driven com Redpanda (Sem Zookeeper):** Desacoplamento temporal e de escala através de tópicos particionados por `FilialId`, garantindo ordenação estrita por loja e suporte a **Dead Letter Queue (DLQ)** para resiliência a falhas.
4. **Otimização de Hardware (Sem Redis):** Utilização do cache nativo em memória do motor **WiredTiger do MongoDB** e índices compostos avançados, eliminando a complexidade e o custo de um cluster Redis adicional.

---

## 📊 Diagramas de Fluxo de Arquitetura

### Fluxo 1: Escrita Transacional (Write Service & Event Publishing)
*Garante consistência ACID na gravação do lançamento e publicação imutável do evento.*

```mermaid
sequenceDiagram
    autonumber
    actor Client as Cliente / PDV
    participant API as WriteService.API
    participant Svc as LancamentoCommandService
    participant DB as PostgreSQL (ACID)
    participant Producer as KafkaEventProducer
    participant Redpanda as Redpanda (Kafka)

    Client->>API: POST /api/lancamentos (JWT Bearer)
    API->>Svc: Executa comando de criação/edição
    Svc->>DB: Valida filial/tipo & Salva Lancamento
    DB-->>Svc: Confirma transação (Commit ACID)
    Svc->>Producer: Serializa e publica EnvelopeEvento
    Producer->>Redpanda: Envia mensagem (Key: FilialId)
    Redpanda-->>Producer: Ack recebido com sucesso
    API-->>Client: Retorna 201 Created (LancamentoResponse)
    sequenceDiagram
    autonumber
    participant Redpanda as Redpanda (Tópico)
    participant Worker as KafkaConsolidacaoWorker
    participant Processor as ConsolidacaoProcessor
    participant MongoRepo as MongoProjectionRepository
    participant Mongo as MongoDB (Leitura)
    participant DLQ as Tópico DLQ (Falhas)

    Redpanda->>Worker: Consome EnvelopeEvento
    Worker->>Processor: Processa evento (Criado / Editado)
    alt Sucesso no Processamento
        Processor->>MongoRepo: Processa Inserção/Atualização & Delta
        MongoRepo->>Mongo: Upsert Extrato & Update Atômico (SaldosDiarios)
        Mongo-->>Worker: Confirmação de persistência
        Worker->>Redpanda: Commit Offset
    else Erro Inesperado
        Processor-->>Worker: Lança Exceção
        Worker->>DLQ: Publica mensagem original na DLQ
        Worker->>Redpanda: Commit Offset (Evita travamento)
    end
    sequenceDiagram
    autonumber
    actor Client as Cliente / Dashboard
    participant ReadConsolidado as ReadService.Consolidado.API
    participant ReadExtrato as ReadService.Extrato.API
    participant Mongo as MongoDB (WiredTiger)

    par Consulta de Saldo Consolidado
        Client->>ReadConsolidado: GET /api/consolidado/{filialId}?data=YYYY-MM-DD
        ReadConsolidado->>Mongo: Busca documento por ID composto (Filial_Data)
        Mongo-->>ReadConsolidado: Retorna SaldoDiarioReadModel
        ReadConsolidado-->>Client: Retorna JSON Consolidado
    and Consulta de Extrato Analítico
        Client->>ReadExtrato: GET /api/extrato/{filialId}?data=YYYY-MM-DD
        ReadExtrato->>Mongo: Consulta filtrada e ordenada (Índice Composto)
        Mongo-->>ReadExtrato: Retorna lista de ExtratoItemReadModel
        ReadExtrato-->>Client: Retorna Extrato Detalhado
    end
BancoCarrefour.sln
│
├── src/
│   ├── BuildingBlocks/
│   │   └── BancoCarrefour.EventBus.Contracts  # Contratos imutáveis de eventos (Records)
│   ├── WriteService/
│   │   ├── WriteService.Domain                # Entidades, Value Objects e Invariantes DDD
│   │   ├── WriteService.Application           # Casos de uso (Commands e Handlers)
│   │   ├── WriteService.Infrastructure        # PostgreSQL (EF Core Migrations) & Kafka Producer
│   │   └── WriteService.API                   # Endpoints de escrita protegidos por OAuth2/JWT
│   ├── ConsolidationWorker/
│   │   ├── Worker.Domain                      # Modelos de Projeção e Contratos do MongoDB
│   │   ├── Worker.Application                 # Motor de cálculo matemático por deltas
│   │   ├── Worker.Infrastructure              # Repositório MongoDB & Consumer Kafka Background
│   │   └── Worker.Host                        # Hospedagem e injeção de dependências do Worker
│   ├── ReadService.Consolidado/
│   │   └── ReadService.Consolidado.API        # API de consulta de saldos consolidados
│   └── ReadService.Extrato/
│       └── ReadService.Extrato.API            # API de consulta de extrato analítico por filial
│
└── tests/
    └── BancoCarrefour.UnitTests               # Suíte de testes unitários (xUnit & NSubstitute)
    