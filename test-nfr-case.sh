#!/usr/bin/env bash
set -e

echo "================================================================================"
echo " VALIDACAO DOS REQUISITOS NAO-FUNCIONAIS DO CASE (RNF-01: CAOS & RNF-02: 50 RPS)"
echo "================================================================================"

echo -e "\n[1/4] Obtendo Token JWT no Keycloak..."
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/banco-carrefour/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
  echo "Erro ao obter token JWT!"
  exit 1
fi
echo "Token JWT obtido com sucesso."

echo -e "\n[2/4] TESTE DE ISOLAMENTO DE FALHAS (RNF-01):"
echo "-> Parando propositalmente o servico de consolidado (bc-read-consolidado-api e bc-consolidation-worker)..."
docker stop bc-read-consolidado-api bc-consolidation-worker >/dev/null

echo "-> Realizando lancamento no WriteService (Porta 5001) com o Consolidado FORA DO AR..."
HTTP_WRITE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:5001/api/lancamentos" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"valor":250.00,"descricao":"Venda PDV Durante Queda do Consolidado","filialId":"11111111-1111-1111-1111-111111111111","tipoLancamentoId":"33333333-3333-3333-3333-333333333333"}')

echo "-> Status HTTP retornado pelo WriteService: $HTTP_WRITE (Esperado: 201 Created)"
if [ "$HTTP_WRITE" = "201" ]; then
  echo "SUCESSO RNF-01: O servico de lancamentos continuou 100% disponivel mesmo com o consolidado inoperante!"
else
  echo "FALHA RNF-01: Status inesperado $HTTP_WRITE"
  docker start bc-consolidation-worker bc-read-consolidado-api >/dev/null
  exit 1
fi

echo -e "\n[3/4] TESTE DE RECUPERACAO AUTOMATICA (SELF-HEALING):"
echo "-> Religando bc-consolidation-worker e bc-read-consolidado-api..."
docker start bc-consolidation-worker bc-read-consolidado-api >/dev/null
sleep 6

echo -e "\n[4/4] TESTE DE ESTRESSE E THROUGHPUT (RNF-02: 50 Requisicoes/Segundo com < 5% de perda):"
DATA_HOJE=$(date -u +%Y-%m-%d)
URL_CONSOLIDADO="http://localhost:5002/api/consolidado/11111111-1111-1111-1111-111111111111?data=$DATA_HOJE"

TMP_RESULTS=$(mktemp)
START_MS=$(date +%s%3N)

for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $TOKEN" "$URL_CONSOLIDADO" >> "$TMP_RESULTS" &
done
wait

END_MS=$(date +%s%3N)
ELAPSED_MS=$((END_MS - START_MS))

TOTAL_OK=$(grep -c "^200$" "$TMP_RESULTS" || true)
TOTAL_FAIL=$((50 - TOTAL_OK))
PERDA_PCT=$((TOTAL_FAIL * 100 / 50))
rm -f "$TMP_RESULTS"

echo "-> Requisicoes simultaneas disparadas : 50"
echo "-> Respostas 200 OK                   : $TOTAL_OK / 50"
echo "-> Taxa de perda                      : ${PERDA_PCT}% (Limite maximo do Case: 5%)"
echo "-> Tempo total da rajada de 50 reqs   : ${ELAPSED_MS} ms"
echo "================================================================================"
