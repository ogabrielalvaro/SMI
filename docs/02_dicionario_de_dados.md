# Dicionário de dados

Todas as tabelas ficam no schema `public` do banco `industrial`. Os tipos e
restrições abaixo são os mesmos de `sql/01_schema.sql`.

Legenda: **PK** chave primária, **FK** chave estrangeira, **UQ** única,
**NN** não nulo. Os identificadores são preenchidos por sequences
(`seq_<tabela>`), criadas no próprio script.

---

## planta

Unidade industrial. Sequence: `seq_planta`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_planta | integer | PK | Identificador da planta |
| nome | varchar(80) | NN, UQ | Nome da planta |
| localizacao | varchar(120) | NN | Cidade/endereço |
| responsavel | varchar(80) | NN | Pessoa responsável pela planta |

## linha_producao

Linha de produção dentro de uma planta. Sequence: `seq_linha`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_linha | integer | PK | Identificador da linha |
| nome | varchar(80) | NN | Nome da linha |
| descricao | text | | O que a linha faz |
| id_planta | integer | NN, FK → planta | Planta à qual a linha pertence |

Restrição extra: `UNIQUE (id_planta, nome)`. Plantas diferentes podem ter
linhas com o mesmo nome, a mesma planta não.

## equipamento

Máquina instalada em uma linha. Sequence: `seq_equipamento`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_equipamento | integer | PK | Identificador do equipamento |
| tag | varchar(30) | NN, UQ | Código usado no chão de fábrica (ex.: `MOT-101`) |
| nome | varchar(80) | NN | Nome descritivo |
| fabricante | varchar(60) | | Fabricante |
| modelo | varchar(60) | | Modelo |
| data_instalacao | date | NN | Data em que foi instalado |
| status | varchar(15) | NN, padrão `operando` | Situação atual |
| id_linha | integer | NN, FK → linha_producao | Linha onde está instalado |

`CHECK`: `status` só aceita `operando`, `parado`, `manutencao` ou `desativado`.

## tipo_sensor

Classificação dos sensores. Sequence: `seq_tipo_sensor`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_tipo_sensor | integer | PK | Identificador do tipo |
| nome | varchar(50) | NN, UQ | Ex.: Temperatura, Vibração, Pressão |
| descricao | text | | Descrição do tipo |

## unidade_medida

Unidades em que os sensores medem. Sequence: `seq_unidade`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_unidade | integer | PK | Identificador da unidade |
| sigla | varchar(15) | NN, UQ | Ex.: `°C`, `bar`, `A`, `mm/s` |
| descricao | varchar(80) | NN | Nome por extenso |

## sensor

Instrumento de medição de um equipamento. Sequence: `seq_sensor`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_sensor | integer | PK | Identificador do sensor |
| tag | varchar(30) | NN, UQ | Código do instrumento (ex.: `TT-101`) |
| descricao | varchar(120) | | O que o sensor mede e onde |
| limite_inferior | numeric(12,3) | NN | Menor valor aceitável |
| limite_superior | numeric(12,3) | NN | Maior valor aceitável |
| id_equipamento | integer | NN, FK → equipamento | Equipamento monitorado |
| id_tipo_sensor | integer | NN, FK → tipo_sensor | Tipo do sensor |
| id_unidade | integer | NN, FK → unidade_medida | Unidade da medição |

`CHECK`: `limite_inferior < limite_superior`.

## leitura

Cada medição enviada por um sensor. É a tabela que mais cresce.
Sequence: `seq_leitura`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_leitura | bigint | PK | Identificador da leitura |
| data_hora | timestamp | NN | Momento da medição |
| valor | numeric(12,3) | NN | Valor medido, na unidade do sensor |
| qualidade | varchar(10) | NN, padrão `boa` | Confiabilidade do sinal |
| id_sensor | integer | NN, FK → sensor | Sensor que fez a medição |

`CHECK`: `qualidade` só aceita `boa`, `incerta` ou `ruim`.
Restrição extra: `UNIQUE (id_sensor, data_hora)`, um sensor não registra duas
leituras no mesmo instante.

## alerta

Aviso criado quando uma leitura sai dos limites. Sequence: `seq_alerta`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_alerta | bigint | PK | Identificador do alerta |
| data_hora | timestamp | NN, padrão `now()` | Momento em que o alerta foi gerado |
| severidade | varchar(10) | NN | Gravidade do desvio |
| descricao | text | NN | Texto do alerta (sensor, valor e faixa) |
| status | varchar(15) | NN, padrão `aberto` | Andamento do tratamento |
| id_leitura | bigint | NN, FK → leitura | Leitura que disparou o alerta |

`CHECK`: `severidade` aceita `baixa`, `media`, `alta` ou `critica`; `status`
aceita `aberto`, `reconhecido` ou `resolvido`.

## tecnico

Pessoa que executa manutenções. Sequence: `seq_tecnico`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_tecnico | integer | PK | Identificador do técnico |
| nome | varchar(80) | NN | Nome completo |
| especialidade | varchar(60) | NN | Mecânica, Elétrica, Instrumentação... |
| contato | varchar(120) | | E-mail ou telefone |

## tipo_manutencao

Classificação das manutenções. Sequence: `seq_tipo_manutencao`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_tipo_manutencao | integer | PK | Identificador do tipo |
| nome | varchar(50) | NN, UQ | Preventiva, Corretiva, Preditiva, Inspeção |
| descricao | text | | Descrição do tipo |

## manutencao

Intervenção feita ou agendada em um equipamento. Sequence: `seq_manutencao`.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_manutencao | integer | PK | Identificador da manutenção |
| data_inicio | date | NN | Início (ou data agendada) |
| data_fim | date | | Fim. Fica nula enquanto não termina |
| descricao | text | NN | O que foi ou será feito |
| status | varchar(15) | NN, padrão `agendada` | Situação |
| id_equipamento | integer | NN, FK → equipamento | Equipamento que recebe a manutenção |
| id_tipo_manutencao | integer | NN, FK → tipo_manutencao | Tipo da manutenção |

`CHECK`:
- `status` aceita `agendada`, `em_andamento`, `concluida` ou `cancelada`;
- `data_fim` nula ou maior ou igual a `data_inicio`;
- manutenção `concluida` obrigatoriamente tem `data_fim`.

## manutencao_tecnico

Tabela associativa do N:N entre manutenção e técnico.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_manutencao | integer | PK, FK → manutencao | Manutenção executada |
| id_tecnico | integer | PK, FK → tecnico | Técnico que participou |

A chave primária é composta (`id_manutencao`, `id_tecnico`), o que impede
registrar o mesmo técnico duas vezes na mesma manutenção. A FK para
`manutencao` tem `ON DELETE CASCADE`: apagar a manutenção apaga as linhas de
participação dela.

---

## Comportamento das chaves estrangeiras

Todas as FKs usam o padrão do PostgreSQL (`NO ACTION`, que na prática impede
apagar um registro que ainda é referenciado), menos a de
`manutencao_tecnico.id_manutencao`, que é `CASCADE`. Isso protege o histórico:
não dá para apagar um sensor que já tem leituras, nem uma leitura que já
gerou alerta.

## Índices

Além dos índices que o PostgreSQL cria sozinho para cada PK e UNIQUE:

| Índice | Tabela (colunas) | Motivo |
|--------|------------------|--------|
| idx_leitura_data_hora | leitura (data_hora) | Consultas por período em todos os sensores |
| idx_linha_planta | linha_producao (id_planta) | FK, joins e deletes |
| idx_equipamento_linha | equipamento (id_linha) | FK |
| idx_sensor_equipamento | sensor (id_equipamento) | FK |
| idx_alerta_leitura | alerta (id_leitura) | FK |
| idx_manutencao_equipamento | manutencao (id_equipamento) | FK |
| idx_manutencao_tecnico_tec | manutencao_tecnico (id_tecnico) | FK (a PK cobre só o `id_manutencao`) |
| idx_alerta_abertos | alerta (data_hora) **WHERE status = 'aberto'** | Índice parcial, só para a consulta de alertas abertos |
| idx_equipamento_status | equipamento (status) | Filtro por status |

Consultas por sensor e período (`WHERE id_sensor = ? AND data_hora BETWEEN ...`)
podem usar o índice da `UNIQUE (id_sensor, data_hora)`. Quem escolhe o índice
é o planner, e com poucos dados ele às vezes prefere outro.
