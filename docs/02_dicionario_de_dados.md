# Dicionário de dados

Banco `industrial`, schema `public`. Os tipos e restrições são os de
`sql/01_schema.sql`.

PK = chave primária, FK = chave estrangeira, UQ = única, NN = não nulo. Cada
PK é preenchida por uma sequence chamada `seq_<tabela>`.

## planta

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_planta | integer | PK | Identificador |
| nome | varchar(80) | NN, UQ | Nome da planta |
| localizacao | varchar(120) | NN | Cidade/endereço |
| responsavel | varchar(80) | NN | Responsável pela planta |

## linha_producao

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_linha | integer | PK | Identificador |
| nome | varchar(80) | NN | Nome da linha |
| descricao | text | | O que a linha faz |
| id_planta | integer | NN, FK → planta | Planta da linha |

Tem também `UNIQUE (id_planta, nome)`: duas plantas podem ter linhas com o
mesmo nome, mas a mesma planta não.

## equipamento

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_equipamento | integer | PK | Identificador |
| tag | varchar(30) | NN, UQ | Código na fábrica (ex.: MOT-101) |
| nome | varchar(80) | NN | Nome |
| fabricante | varchar(60) | | Fabricante |
| modelo | varchar(60) | | Modelo |
| data_instalacao | date | NN | Data de instalação |
| status | varchar(15) | NN, padrão `operando` | Situação atual |
| id_linha | integer | NN, FK → linha_producao | Linha onde está |

`CHECK`: status só pode ser `operando`, `parado`, `manutencao` ou `desativado`.

## tipo_sensor

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_tipo_sensor | integer | PK | Identificador |
| nome | varchar(50) | NN, UQ | Temperatura, Vibração... |
| descricao | text | | Descrição |

## unidade_medida

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_unidade | integer | PK | Identificador |
| sigla | varchar(15) | NN, UQ | C, bar, A, mm/s... |
| descricao | varchar(80) | NN | Nome por extenso |

## sensor

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_sensor | integer | PK | Identificador |
| tag | varchar(30) | NN, UQ | Código do instrumento (ex.: TT-101) |
| descricao | varchar(120) | | O que mede e onde |
| limite_inferior | numeric(12,3) | NN | Menor valor aceitável |
| limite_superior | numeric(12,3) | NN | Maior valor aceitável |
| id_equipamento | integer | NN, FK → equipamento | Equipamento monitorado |
| id_tipo_sensor | integer | NN, FK → tipo_sensor | Tipo |
| id_unidade | integer | NN, FK → unidade_medida | Unidade |

`CHECK`: `limite_inferior < limite_superior`.

## leitura

É a tabela que mais cresce.

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_leitura | bigint | PK | Identificador |
| data_hora | timestamp | NN | Quando foi medido |
| valor | numeric(12,3) | NN | Valor medido |
| qualidade | varchar(10) | NN, padrão `boa` | Confiabilidade do sinal |
| id_sensor | integer | NN, FK → sensor | Sensor que mediu |
| id_equipamento | integer | NN, FK → equipamento | Equipamento onde foi registrada |

`CHECK`: qualidade só pode ser `boa`, `incerta` ou `ruim`.
`UNIQUE (id_sensor, data_hora)`: um sensor não tem duas leituras no mesmo
instante.

## alerta

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_alerta | bigint | PK | Identificador |
| data_hora | timestamp | NN, padrão `now()` | Quando foi gerado |
| severidade | varchar(10) | NN | Gravidade |
| descricao | text | NN | Texto do alerta |
| status | varchar(15) | NN, padrão `aberto` | Andamento |
| id_leitura | bigint | NN, FK → leitura | Leitura que causou o alerta |

`CHECK`: severidade é `baixa`, `media`, `alta` ou `critica`; status é `aberto`,
`reconhecido` ou `resolvido`.

## tecnico

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_tecnico | integer | PK | Identificador |
| nome | varchar(80) | NN | Nome |
| especialidade | varchar(60) | NN | Mecânica, Elétrica... |
| contato | varchar(120) | | E-mail ou telefone |

## tipo_manutencao

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_tipo_manutencao | integer | PK | Identificador |
| nome | varchar(50) | NN, UQ | Preventiva, Corretiva, Preditiva, Inspeção |
| descricao | text | | Descrição |

## manutencao

| Coluna | Tipo | Restrições | Descrição |
|--------|------|------------|-----------|
| id_manutencao | integer | PK | Identificador |
| data_inicio | date | NN | Início (ou data agendada) |
| data_fim | date | | Fim. Fica vazio enquanto não termina |
| descricao | text | NN | O que foi feito |
| status | varchar(15) | NN, padrão `agendada` | Situação |
| id_equipamento | integer | NN, FK → equipamento | Equipamento |
| id_tecnico | integer | NN, FK → tecnico | Técnico responsável |
| id_tipo_manutencao | integer | NN, FK → tipo_manutencao | Tipo |

`CHECK`:
- status é `agendada`, `em_andamento`, `concluida` ou `cancelada`;
- `data_fim` vazia ou maior ou igual a `data_inicio`;
- manutenção `concluida` precisa ter `data_fim`.

## Chaves estrangeiras

Todas usam o comportamento padrão do PostgreSQL, que não deixa apagar um
registro que ainda é usado por outro. Então não dá pra apagar um sensor que
tem leituras, nem uma leitura que gerou alerta.

## Índices

O PostgreSQL cria índice sozinho para PK e UNIQUE, mas não para FK. Criamos:

| Índice | Colunas | Para quê |
|--------|---------|----------|
| idx_leitura_data_hora | leitura (data_hora) | Consultas por período |
| idx_leitura_equipamento | leitura (id_equipamento) | FK |
| idx_linha_planta | linha_producao (id_planta) | FK |
| idx_equipamento_linha | equipamento (id_linha) | FK |
| idx_sensor_equipamento | sensor (id_equipamento) | FK |
| idx_alerta_leitura | alerta (id_leitura) | FK |
| idx_manutencao_equipamento | manutencao (id_equipamento) | FK |
| idx_manutencao_tecnico | manutencao (id_tecnico) | FK |
| idx_alerta_abertos | alerta (data_hora) onde status = 'aberto' | Índice parcial, só para os alertas abertos |
| idx_equipamento_status | equipamento (status) | Filtro por status |

A `UNIQUE (id_sensor, data_hora)` da leitura também gera um índice, que ajuda
nas consultas "leituras do sensor X no período Y".
