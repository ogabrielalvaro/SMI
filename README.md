# SMI - Sistema de Monitoramento e Gestão de Dados Industriais

Projeto final de Banco de Dados (UFU) em PostgreSQL. Entrega: 01/12/2026 às 23:59.

## Divisão

| Parte | Conteúdo | Arquivos | Situação |
|-------|----------|----------|----------|
| 1 | Modelagem (DER, dicionário, lógico, 3FN), schema, dados de exemplo | `sql/01_schema.sql`, `sql/02_dados.sql`, `docs/01` a `docs/04` | pronta |
| 2 | Funções, procedures, triggers, views, consultas | `sql/03_funcoes.sql`, `04_triggers.sql`, `05_views.sql`, `06_consultas.sql` | a fazer |
| 3 | Roles, autenticação, backup/restore, relatório PDF | `sql/07_roles.sql`, `evidencias/` | a fazer |

## Como rodar (banco limpo)

```bash
createdb industrial
for f in sql/0*.sql; do psql -d industrial -v ON_ERROR_STOP=1 -f "$f"; done
```

O `01_schema.sql` pode ser rodado de novo (ele apaga e recria as tabelas), mas
o `02_dados.sql` não: para recarregar os dados, rode o `01` antes.

## Modelo em uma olhada

12 tabelas: `planta`, `linha_producao`, `equipamento`, `sensor`, `tipo_sensor`,
`unidade_medida`, `leitura`, `alerta`, `manutencao`, `tipo_manutencao`,
`tecnico` e `manutencao_tecnico` (N:N). O diagrama está em
`docs/01_modelo_conceitual.md`.

Dados de exemplo: 2 plantas, 9 equipamentos, 16 sensores, 2.424 leituras
(09 a 15/11/2026, uma por hora), 12 alertas e 9 manutenções.

## Documentação

- `docs/01_modelo_conceitual.md`: entidades, relacionamentos e DER
- `docs/02_dicionario_de_dados.md`: colunas, tipos, restrições e índices
- `docs/03_modelo_logico_e_3fn.md`: mapeamento relacional e justificativa da 3FN
- `docs/04_roteiro_apresentacao.md`: roteiro e perguntas prováveis (só para estudo)

## Avisos para as Partes 2 e 3

- O schema está em `public`.
- `leitura` **não** tem `id_equipamento`. Para chegar no equipamento, faça join
  por `sensor`.
- `manutencao` não tem técnico direto. Use `manutencao_tecnico`.
- Os limites ficam no sensor (`limite_inferior`, `limite_superior`).
- Os alertas de exemplo seguem esta severidade, de acordo com o quanto o valor
  passou da faixa do sensor: mais de 25% crítica, mais de 10% alta, mais de 3%
  média, o resto baixa. Vale usar a mesma regra no trigger.
- Depois que a Parte 1 for entregue, mudanças nas tabelas só combinando no grupo.

## Fluxo de trabalho

```bash
git pull          # sempre antes de mexer
git add .
git commit -m "mensagem"
git push
```
