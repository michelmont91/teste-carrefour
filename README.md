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
    participant Redpanda as "Redpanda (Tópico)"
    participant Worker as "KafkaConsolidacaoWorker"
    participant Processor as "ConsolidacaoProcessor"
    participant MongoRepo as "MongoProjectionRepository"
    participant Mongo as "MongoDB (Leitura)"
    participant DLQ as "Tópico DLQ"

    Redpanda->>Worker: Consome EnvelopeEvento
    Worker->>Processor: Interpreta tipo de evento
    alt Sucesso no Processamento
        Processor->>MongoRepo: Envia Inserção/Atualização & Deltas
        MongoRepo->>Mongo: Upsert Extrato & Atualização Atômica de Saldo
        Mongo-->>Worker: Confirmação de persistência
        Worker->>Redpanda: Commit Offset
    else Erro Inesperado
        Processor-->>Worker: Lança Exceção
        Worker->>DLQ: Publica mensagem na DLQ
        Worker->>Redpanda: Commit Offset (Evita travamento)
    end
    sequenceDiagram
    autonumber
    participant Redpanda as "Redpanda (Tópico)"
    participant Worker as "KafkaConsolidacaoWorker"
    participant Processor as "ConsolidacaoProcessor"
    participant MongoRepo as "MongoProjectionRepository"
    participant Mongo as "MongoDB (Leitura)"
    participant DLQ as "Tópico DLQ"

    Redpanda->>Worker: Consome EnvelopeEvento
    Worker->>Processor: Interpreta tipo de evento
    alt Sucesso no Processamento
        Processor->>MongoRepo: Envia Inserção/Atualização & Deltas
        MongoRepo->>Mongo: Upsert Extrato & Atualização Atômica de Saldo
        Mongo-->>Worker: Confirmação de persistência
        Worker->>Redpanda: Commit Offset
    else Erro Inesperado
        Processor-->>Worker: Lança Exceção
        Worker->>DLQ: Publica mensagem na DLQ
        Worker->>Redpanda: Commit Offset (Evita travamento)
    end
    