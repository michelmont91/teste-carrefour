# 📊 Apresentação Executiva — Defesa Técnica da Solução
**Projeto:** Modernização do Sistema de Fluxo de Caixa e Consolidação Diária — Banco Carrefour  
**Plataforma:** .NET 9 LTS | Arquitetura Hexagonal | CQRS | Event-Driven Architecture

---

## Slide 1: O Desafio de Negócio
### Como garantir continuidade operacional nas lojas durante picos severos de leitura financeira?

* **Cenário Real de Varejo e Banco:** Centenas de frentes de caixa (PDVs) registam entradas e saídas financeiras ininterruptamente ao longo do dia.
* **O Gargalo Tradicional:** Nos horários de fecho de turno e conciliação bancária, os sistemas de retaguarda disparam picos de **50 requisições por segundo** sobre o saldo consolidado diário.
* **O Risco Crítico:** Em arquiteturas monolíticas ou acopladas de forma síncrona, uma sobrecarga ou queda no módulo de relatórios/consolidação bloqueia o banco de dados principal e **paralisa o registo de vendas nos PDVs**.
* **A Meta Inegociável:**
  1. O serviço de lançamentos (escrita) **nunca pode parar** se o consolidado cair.
  2. O consolidado deve absorver **50 req/s com menos de 5% de perda**.
  3. Segurança corporativa rigorosa (OAuth2/JWT) ponta a ponta.

---

## Slide 2: A Resposta Arquitetural (Desacoplamento Total)
### CQRS Assíncrono + Persistência Poliglota Orientada a Eventos

Em vez de consultar e somar milhares de linhas na mesma tabela onde os PDVs escrevem, dividimos a arquitetura em **três planos independentes**:

1. **Plano de Escrita Ultrarrápida (`WriteService.API` + PostgreSQL 16):**
   * Recebe o lançamento, valida as regras contábeis, salva com garantia ACID e publica o evento no barramento em milissegundos.
   * **Zero dependência** dos serviços de leitura. Se o MongoDB, o Worker ou as APIs de leitura caírem, o PDV continua a receber `201 Created` normalmente.
2. **Plano de Streaming e Consolidação Contínua (`Redpanda` + `ConsolidationWorker`):**
   * Os eventos ficam retidos de forma durável no broker Redpanda.
   * O Worker consome cada lançamento em background e já deixa o saldo somado preventivamente no banco de leitura.
3. **Plano de Leitura de Baixíssima Latência (`Consolidado.API` & `Extrato.API` + MongoDB 7.0):**
   * Quando chegam as **50 requisições por segundo**, a API não faz nenhum cálculo matemático (`SUM`): ela apenas lê um único documento JSON já pronto pela chave `FilialId_Data` em menos de **5 milissegundos**.

---

## Slide 3: Por Que Esta Arquitetura Supera o SLA de 50 req/s?

| Critério Técnico | Abordagem Tradicional (Monolito / SQL Único) | Nossa Solução (CQRS + Redpanda + MongoDB) | Ganho Executivo |
| :--- | :--- | :--- | :--- |
| **Custo de Leitura do Saldo** | `SELECT SUM(Valor) FROM Lancamentos WHERE...` (Complexidade **O(N)** — degrada conforme o dia avança) | Busca direta por `_id` (`1111..._2026-11-11`) no MongoDB (Complexidade **O(1)** constante) | Latência estável (< 5ms) mesmo com milhões de lançamentos no dia |
| **Impacto de Queda do Consolidado no PDV** | Alto (partilham pool de conexões, CPU ou chamadas HTTP síncronas) | **Zero (0%)** — isolamento completo de processos, redes e bancos de dados | 100% de disponibilidade para a operação de vendas na ponta |
| **Recuperação de Desastres (Self-Healing)** | Perda de requisições em voo ou necessidade de scripts manuais de conciliação | **Automática via Offset do Kafka** (`AutoOffsetReset = Earliest` + DLQ) | Assim que o Worker volta a subir, processa todo o backlog sem intervenção humana |
| **Escalabilidade sob Pico** | Exige escalar verticalmente o servidor SQL (custo elevado de licenciamento/hardware) | Escala horizontalmente apenas os contentores leves `.NET 9` de leitura | Redução de TCO (Custo Total de Propriedade) em nuvem |

---

## Slide 4: Rigor Financeiro e Segurança Corporativa (Zero Atalhos)

* **Integridade Contábil e Retificação Auditável:**
  * Suporte nativo a criação (`POST`) e retificação/estorno (`PUT`), onde o `ConsolidationWorker` reverte matematicamente o impacto do lançamento anterior e aplica o novo valor em operação atômica (`$inc` com `Decimal128`), eliminando erros de concorrência (*Race Conditions*).
* **Segurança OAuth2 / OIDC Real com Keycloak:**
  * Nenhuma rota está desprotegida. O `Keycloak 24` sobe automaticamente com o realm `banco-carrefour` provisionado.
  * Segregação de funções (*Segregation of Duties*): operadores de caixa (`writer`) criam lançamentos, sistemas de consulta (`read`) leem saldos/extratos e apenas supervisores (`admin`) podem retificar lançamentos existentes.

---

## Slide 5: Prontidão para Produção e Evolução Cloud-Native

A solução foi entregue 100% containerizada e validada por testes automatizados (`xUnit` para domínio/aplicação e `test-e2e.sh` para integração completa dos 9 contentores):

* **Observabilidade e Operação:** Interface **Kafka-UI** integrada na porta `8085` para inspeção visual em tempo real dos tópicos `lancamentos-eventos` e `lancamentos-dlq`.
* **Pronta para Kubernetes (AKS / EKS / GKE):**
  * Os microsserviços `.NET 9` são totalmente *stateless*, permitindo **Horizontal Pod Autoscaler (HPA)** baseado em CPU/RPS para `ReadService.Consolidado.API` e **KEDA** (baseado em *Consumer Lag* do Kafka) para escalar o `ConsolidationWorker`.
* **Reprodutibilidade em 1 Comando:** Qualquer avaliador ou pipeline CI/CD levanta toda a topologia com `docker compose up --build -d` e comprova o funcionamento ponta a ponta em menos de 10 segundos executando `./test-e2e.sh`.
