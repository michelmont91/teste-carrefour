# 🏦 Sistema de Fluxo de Caixa — Banco Carrefour

Arquitetura técnica de alta performance, resiliente e orientada a eventos para o sistema de fluxo de caixa do Banco Carrefour, desenvolvida em **.NET LTS**, **PostgreSQL**, **MongoDB** e **Apache Kafka**, operando integralmente via nuvem (**GitHub Codespaces**).

---

## 📐 Decisões Arquiteturais e Justificativas (ADRs)

### 1. Arquitetura Hexagonal (Ports & Adapters)
* **O que é:** Isolamento estrito entre o domínio de negócios (regras contábeis) e os detalhes de infraestrutura (frameworks, bases de dados, protocolos de transporte).
* **Por que foi adotada:** Garante testabilidade absoluta (testes unitários isolados com xUnit/NSubstitute) e flexibilidade para alterar ORMs ou brokers de mensageria sem impactar as regras centrais de negócio do banco.

### 2. Domain-Driven Design (DDD) & CQRS (Command Query Responsibility Segregation)
* **O que é:** Separação física e lógica entre os fluxos de escrita (comandos transacionais) e os fluxos de leitura (consultas analíticas e consolidadas).
* **Por que foi adotada:** A escrita prioriza consistência rigorosa (**ACID** via PostgreSQL), enquanto a leitura prioriza alta volumetria e baixa latência (**MongoDB** com projeções otimizadas em memória via motor WiredTiger).

### 3. Event-Driven Architecture com Apache Kafka & Dead Letter Queue (DLQ)
* **O que é:** Comunicação assíncrona entre o microsserviço de escrita e as projeções de leitura através de eventos imutáveis (`LancamentoCriadoEvent`, `LancamentoEditadoEvent`) particionados por `FilialId`.
* **Por que foi adotada:** Garante ordenação estrita por loja, desacoplamento temporal, resiliência a falhas de rede e tratamento automatizado de erros irrecuperáveis através da **DLQ** (`lancamentos-dlq`).

### 4. Ausência de Redis (*Overengineering*) & Confiabilidade do MongoDB
* **Decisão:** O uso de cache distribuído (Redis) foi descartado.
* **Justificativa:** Para atingir a meta de requisições por segundo (≥ 50 req/s) com baixo consumo de hardware (ideal para GitHub Codespaces / PCs antigos), o sistema confia diretamente no motor de armazenamento **WiredTiger do MongoDB**, que utiliza cache nativo em memória RAM e índices compostos de alta performance, eliminando a complexidade operacional de um componente adicional.

---

## 🧩 Topologia do Monorepo

O repositório está estruturado em módulos independentes dentro de `src/`:

```text
BancoCarrefour.sln
│
├── src/
│   ├── BuildingBlocks/
│   │   └── BancoCarrefour.EventBus.Contracts  # Contratos imutáveis de eventos Kafka
│   ├── WriteService/
│   │   ├── WriteService.Domain                # Entidades e Value Objects (DDD)
│   │   ├── WriteService.Application           # Casos de uso e Commands
│   │   ├── WriteService.Infrastructure        # PostgreSQL (EF Core) & Kafka Producer
│   │   └── WriteService.API                   # Endpoints de escrita protegidos por OAuth2
│   ├── ConsolidationWorker/
│   │   ├── Worker.Domain                      # Modelos de Projeção (MongoDB)
│   │   ├── Worker.Application                 # Motor de cálculo matemático por deltas
│   │   ├── Worker.Infrastructure              # Repositório MongoDB com índices compostos
│   │   └── Worker.Host                        # Consumidor Kafka Background Service + DLQ
│   ├── ReadService.Consolidado/
│   │   └── ReadService.Consolidado.API        # API dedicada a saldos consolidados (~50 req/s)
│   └── ReadService.Extrato/
│       └── ReadService.Extrato.API            # API dedicada a consultas de extrato analítico
│
└── tests/
    └── BancoCarrefour.UnitTests               # Testes unitários (xUnit & NSubstitute)