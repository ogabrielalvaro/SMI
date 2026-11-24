# SMI - Sistema de Monitoramento e Gestão de Dados Industriais

Projeto final de Banco de Dados (UFU), em PostgreSQL. Entrega: 01/12/2026 às 23:59.

## Divisão

| Parte | O que é | Arquivos | Situação |
|-------|---------|----------|----------|
| 1 | Modelagem (DER, dicionário, lógico, 3FN), schema e dados | `sql/01_schema.sql`, `sql/02_dados.sql`, `docs/` | pronta |
| 2 | Funções, procedures, triggers, views e consultas | `sql/03_funcoes.sql`, `04_triggers.sql`, `05_views.sql`, `06_consultas.sql` | a fazer |
| 3 | Roles, autenticação, backup/restore e relatório PDF | `sql/07_roles.sql`, `evidencias/` | a fazer |

## Como rodar (banco limpo)

```bash
createdb industrial
for f in sql/0*.sql; do psql -d industrial -v ON_ERROR_STOP=1 -f "$f"; done
```

O `01_schema.sql` pode rodar de novo (ele apaga e recria as tabelas). O
`02_dados.sql` não: pra recarregar os dados, roda o `01` antes.

Os `.sql` estão sem acento de propósito, pra não dar problema de codificação
no `psql` do Windows.

## O modelo

11 tabelas, iguais ao DER do professor: `planta`, `linha_producao`,
`equipamento`, `sensor`, `tipo_sensor`, `unidade_medida`, `leitura`, `alerta`,
`manutencao`, `tipo_manutencao` e `tecnico`. O diagrama está em
`docs/01_modelo_conceitual.md`.

Dados de exemplo: 2 plantas, 9 equipamentos, 16 sensores, 2.424 leituras (09 a
15/11/2026, uma por hora), 12 alertas e 9 manutenções.

## Documentação

- `docs/01_modelo_conceitual.md`: entidades, relacionamentos e DER
- `docs/02_dicionario_de_dados.md`: colunas, tipos, restrições e índices
- `docs/03_modelo_logico_e_3fn.md`: modelo relacional e a justificativa da 3FN
- `docs/04_roteiro_apresentacao.md`: roteiro e perguntas prováveis (só pra estudo)

## Pra quem for fazer as Partes 2 e 3

- O schema é o `public`.
- A `leitura` tem `id_sensor` **e** `id_equipamento`, como no DER do professor.
  Os dois sempre batem com o do sensor. Um trigger `BEFORE INSERT` pode
  preencher o `id_equipamento` a partir do sensor.
- A `manutencao` tem um técnico só (`id_tecnico`).
- Os limites ficam no sensor (`limite_inferior` e `limite_superior`).
- Nos alertas de exemplo a severidade segue o quanto o valor passou da faixa do
  sensor: mais de 25% crítica, mais de 10% alta, mais de 3% média, o resto
  baixa. Vale usar a mesma regra no trigger.
- Mudança de tabela só depois de combinar no grupo.

## Fluxo do Git

```bash
git pull          # sempre antes de mexer
git add .
git commit -m "mensagem"
git push
```
