#!/usr/bin/env bash
echo "=== 1. Obtendo Token JWT do Keycloak ==="
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/banco-carrefour/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

echo "Token JWT capturado (inicio): ${TOKEN:0:35}..."

echo -e "\n=== 2. POST Lancamento Contabil (WriteService - Porta 5001) ==="
curl -i -X POST "http://localhost:5001/api/lancamentos" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"valor":150.50,"descricao":"Venda PDV - Fluxo Autenticado","filialId":"11111111-1111-1111-1111-111111111111","tipoLancamentoId":"33333333-3333-3333-3333-333333333333"}'

sleep 3

DATA_HOJE=$(date -u +%Y-%m-%d)
echo -e "\n\n=== 3. GET Saldo Consolidado (ReadService.Consolidado - Porta 5002) ==="
curl -i -X GET "http://localhost:5002/api/consolidado/11111111-1111-1111-1111-111111111111?data=$DATA_HOJE" \
  -H "Authorization: Bearer $TOKEN"

echo -e "\n\n=== 4. GET Extrato Detalhado (ReadService.Extrato - Porta 5003) ==="
curl -i -X GET "http://localhost:5003/api/extrato/11111111-1111-1111-1111-111111111111?data=$DATA_HOJE" \
  -H "Authorization: Bearer $TOKEN"
echo ""
