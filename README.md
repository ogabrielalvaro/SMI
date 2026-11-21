# SMI - Sistema de Monitoramento e Gestão de Dados Industriais

Projeto final de Banco de Dados (UFU) - PostgreSQL. Entrega: 01/12/2026 às 23:59.

## Divisão

| Parte | Conteúdo | Arquivos |
|-------|----------|----------|
| 1 | Modelagem (DER, dicionário, lógico, 3FN), schema, dados de exemplo | `sql/01_schema.sql`, `sql/02_dados.sql`, `docs/` |
| 2 | Funções, procedures, triggers, views, consultas | `sql/03_funcoes.sql`, `04_triggers.sql`, `05_views.sql`, `06_consultas.sql` |
| 3 | Roles, autenticação, backup/restore, relatório PDF | `sql/07_roles.sql`, `evidencias/`, `docs/` |

## Como rodar (banco limpo)

```bash
createdb industrial
for f in sql/0*.sql; do psql -d industrial -v ON_ERROR_STOP=1 -f "$f"; done
```

## Fluxo de trabalho

```bash
git pull          # sempre antes de mexer
git add .
git commit -m "mensagem"
git push
```

Depois que a Parte 1 congelar o schema, ninguém altera tabelas sem avisar o grupo.
