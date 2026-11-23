-- =====================================================================
-- SMI - Sistema de Monitoramento e Gestão de Dados Industriais
-- 01_schema.sql  (Parte 1: modelagem física)
--
-- Antes de rodar, criar o banco (fora deste script):
--     createdb industrial
--     psql -d industrial -v ON_ERROR_STOP=1 -f sql/01_schema.sql
--
-- O script pode ser rodado de novo: ele apaga as tabelas antes de criar.
-- Tudo fica no schema public pra não complicar os GRANTs da Parte 3.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Limpeza (ordem inversa das dependências)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS manutencao_tecnico CASCADE;
DROP TABLE IF EXISTS manutencao         CASCADE;
DROP TABLE IF EXISTS alerta             CASCADE;
DROP TABLE IF EXISTS leitura            CASCADE;
DROP TABLE IF EXISTS sensor             CASCADE;
DROP TABLE IF EXISTS equipamento        CASCADE;
DROP TABLE IF EXISTS linha_producao     CASCADE;
DROP TABLE IF EXISTS planta             CASCADE;
DROP TABLE IF EXISTS tecnico            CASCADE;
DROP TABLE IF EXISTS tipo_manutencao    CASCADE;
DROP TABLE IF EXISTS unidade_medida     CASCADE;
DROP TABLE IF EXISTS tipo_sensor        CASCADE;

DROP SEQUENCE IF EXISTS seq_planta, seq_linha, seq_equipamento, seq_tipo_sensor,
                        seq_unidade, seq_sensor, seq_leitura, seq_alerta,
                        seq_tecnico, seq_tipo_manutencao, seq_manutencao;

-- ---------------------------------------------------------------------
-- Sequences
-- Criadas à mão (em vez de SERIAL) pra ficarem visíveis no script.
-- Cada uma é "dona" da coluna que usa (OWNED BY, mais abaixo), então
-- se a tabela for apagada a sequence vai junto.
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_planta          START 1;
CREATE SEQUENCE seq_linha           START 1;
CREATE SEQUENCE seq_equipamento     START 1;
CREATE SEQUENCE seq_tipo_sensor     START 1;
CREATE SEQUENCE seq_unidade         START 1;
CREATE SEQUENCE seq_sensor          START 1;
CREATE SEQUENCE seq_leitura         START 1;
CREATE SEQUENCE seq_alerta          START 1;
CREATE SEQUENCE seq_tecnico         START 1;
CREATE SEQUENCE seq_tipo_manutencao START 1;
CREATE SEQUENCE seq_manutencao      START 1;

-- ---------------------------------------------------------------------
-- Tabelas de apoio (não dependem de ninguém)
-- ---------------------------------------------------------------------
CREATE TABLE planta (
    id_planta    integer      PRIMARY KEY DEFAULT nextval('seq_planta'),
    nome         varchar(80)  NOT NULL UNIQUE,
    localizacao  varchar(120) NOT NULL,
    responsavel  varchar(80)  NOT NULL
);

CREATE TABLE tipo_sensor (
    id_tipo_sensor integer     PRIMARY KEY DEFAULT nextval('seq_tipo_sensor'),
    nome           varchar(50) NOT NULL UNIQUE,
    descricao      text
);

CREATE TABLE unidade_medida (
    id_unidade integer     PRIMARY KEY DEFAULT nextval('seq_unidade'),
    sigla      varchar(15) NOT NULL UNIQUE,
    descricao  varchar(80) NOT NULL
);

CREATE TABLE tecnico (
    id_tecnico    integer      PRIMARY KEY DEFAULT nextval('seq_tecnico'),
    nome          varchar(80)  NOT NULL,
    especialidade varchar(60)  NOT NULL,
    contato       varchar(120)
);

CREATE TABLE tipo_manutencao (
    id_tipo_manutencao integer     PRIMARY KEY DEFAULT nextval('seq_tipo_manutencao'),
    nome               varchar(50) NOT NULL UNIQUE,
    descricao          text
);

-- ---------------------------------------------------------------------
-- Estrutura da fábrica: planta -> linha -> equipamento
-- ---------------------------------------------------------------------
CREATE TABLE linha_producao (
    id_linha   integer      PRIMARY KEY DEFAULT nextval('seq_linha'),
    nome       varchar(80)  NOT NULL,
    descricao  text,
    id_planta  integer      NOT NULL REFERENCES planta (id_planta),
    -- duas plantas podem ter uma "Linha 1", mas a mesma planta não
    CONSTRAINT uq_linha_planta_nome UNIQUE (id_planta, nome)
);

CREATE TABLE equipamento (
    id_equipamento  integer      PRIMARY KEY DEFAULT nextval('seq_equipamento'),
    tag             varchar(30)  NOT NULL UNIQUE,   -- código usado no chão de fábrica
    nome            varchar(80)  NOT NULL,
    fabricante      varchar(60),
    modelo          varchar(60),
    data_instalacao date         NOT NULL,
    status          varchar(15)  NOT NULL DEFAULT 'operando',
    id_linha        integer      NOT NULL REFERENCES linha_producao (id_linha),
    CONSTRAINT ck_equipamento_status
        CHECK (status IN ('operando', 'parado', 'manutencao', 'desativado'))
);

-- ---------------------------------------------------------------------
-- Sensores e leituras
-- ---------------------------------------------------------------------
CREATE TABLE sensor (
    id_sensor       integer       PRIMARY KEY DEFAULT nextval('seq_sensor'),
    tag             varchar(30)   NOT NULL UNIQUE,
    descricao       varchar(120),
    limite_inferior numeric(12,3) NOT NULL,
    limite_superior numeric(12,3) NOT NULL,
    id_equipamento  integer       NOT NULL REFERENCES equipamento (id_equipamento),
    id_tipo_sensor  integer       NOT NULL REFERENCES tipo_sensor (id_tipo_sensor),
    id_unidade      integer       NOT NULL REFERENCES unidade_medida (id_unidade),
    CONSTRAINT ck_sensor_limites CHECK (limite_inferior < limite_superior)
);

-- Obs.: no DER de referência a leitura também guardava id_equipamento.
-- Tiramos porque o equipamento já é conhecido pelo sensor (ver
-- docs/03_modelo_logico_e_3fn.md, é uma dependência transitiva).
CREATE TABLE leitura (
    id_leitura bigint        PRIMARY KEY DEFAULT nextval('seq_leitura'),
    data_hora  timestamp     NOT NULL,
    valor      numeric(12,3) NOT NULL,
    qualidade  varchar(10)   NOT NULL DEFAULT 'boa',
    id_sensor  integer       NOT NULL REFERENCES sensor (id_sensor),
    CONSTRAINT ck_leitura_qualidade CHECK (qualidade IN ('boa', 'incerta', 'ruim')),
    -- um sensor não manda duas leituras no mesmo instante
    CONSTRAINT uq_leitura_sensor_hora UNIQUE (id_sensor, data_hora)
);

CREATE TABLE alerta (
    id_alerta  bigint       PRIMARY KEY DEFAULT nextval('seq_alerta'),
    data_hora  timestamp    NOT NULL DEFAULT now(),
    severidade varchar(10)  NOT NULL,
    descricao  text         NOT NULL,
    status     varchar(15)  NOT NULL DEFAULT 'aberto',
    id_leitura bigint       NOT NULL REFERENCES leitura (id_leitura),
    CONSTRAINT ck_alerta_severidade CHECK (severidade IN ('baixa', 'media', 'alta', 'critica')),
    CONSTRAINT ck_alerta_status     CHECK (status IN ('aberto', 'reconhecido', 'resolvido'))
);

-- ---------------------------------------------------------------------
-- Manutenção
-- A relação entre manutenção e técnico é N:N (uma manutenção pode ter
-- mais de um técnico e um técnico faz várias manutenções), por isso
-- existe a tabela manutencao_tecnico no meio.
-- ---------------------------------------------------------------------
CREATE TABLE manutencao (
    id_manutencao      integer     PRIMARY KEY DEFAULT nextval('seq_manutencao'),
    data_inicio        date        NOT NULL,
    data_fim           date,
    descricao          text        NOT NULL,
    status             varchar(15) NOT NULL DEFAULT 'agendada',
    id_equipamento     integer     NOT NULL REFERENCES equipamento (id_equipamento),
    id_tipo_manutencao integer     NOT NULL REFERENCES tipo_manutencao (id_tipo_manutencao),
    CONSTRAINT ck_manutencao_status
        CHECK (status IN ('agendada', 'em_andamento', 'concluida', 'cancelada')),
    CONSTRAINT ck_manutencao_datas
        CHECK (data_fim IS NULL OR data_fim >= data_inicio),
    -- manutenção concluída precisa ter data de fim
    CONSTRAINT ck_manutencao_concluida
        CHECK (status <> 'concluida' OR data_fim IS NOT NULL)
);

CREATE TABLE manutencao_tecnico (
    id_manutencao integer NOT NULL REFERENCES manutencao (id_manutencao) ON DELETE CASCADE,
    id_tecnico    integer NOT NULL REFERENCES tecnico (id_tecnico),
    PRIMARY KEY (id_manutencao, id_tecnico)
);

-- ---------------------------------------------------------------------
-- Vínculo das sequences com as colunas
-- ---------------------------------------------------------------------
ALTER SEQUENCE seq_planta          OWNED BY planta.id_planta;
ALTER SEQUENCE seq_linha           OWNED BY linha_producao.id_linha;
ALTER SEQUENCE seq_equipamento     OWNED BY equipamento.id_equipamento;
ALTER SEQUENCE seq_tipo_sensor     OWNED BY tipo_sensor.id_tipo_sensor;
ALTER SEQUENCE seq_unidade         OWNED BY unidade_medida.id_unidade;
ALTER SEQUENCE seq_sensor          OWNED BY sensor.id_sensor;
ALTER SEQUENCE seq_leitura         OWNED BY leitura.id_leitura;
ALTER SEQUENCE seq_alerta          OWNED BY alerta.id_alerta;
ALTER SEQUENCE seq_tecnico         OWNED BY tecnico.id_tecnico;
ALTER SEQUENCE seq_tipo_manutencao OWNED BY tipo_manutencao.id_tipo_manutencao;
ALTER SEQUENCE seq_manutencao      OWNED BY manutencao.id_manutencao;

-- ---------------------------------------------------------------------
-- Índices
-- O Postgres já cria índice pra toda PK e UNIQUE. Aqui ficam os que
-- ajudam nas consultas que vamos fazer (Parte 2) e nas FKs, que o
-- Postgres NÃO indexa sozinho.
-- ---------------------------------------------------------------------
-- consultas por período (a tabela leitura é a que mais cresce)
CREATE INDEX idx_leitura_data_hora       ON leitura (data_hora);
-- (id_sensor, data_hora) já está coberto pela UNIQUE uq_leitura_sensor_hora

-- chaves estrangeiras
CREATE INDEX idx_linha_planta            ON linha_producao (id_planta);
CREATE INDEX idx_equipamento_linha       ON equipamento (id_linha);
CREATE INDEX idx_sensor_equipamento      ON sensor (id_equipamento);
CREATE INDEX idx_alerta_leitura          ON alerta (id_leitura);
CREATE INDEX idx_manutencao_equipamento  ON manutencao (id_equipamento);
CREATE INDEX idx_manutencao_tecnico_tec  ON manutencao_tecnico (id_tecnico);

-- filtros frequentes: alertas ainda abertos e equipamentos por status
-- (índice parcial: só guarda as linhas que interessam, fica pequeno)
CREATE INDEX idx_alerta_abertos          ON alerta (data_hora) WHERE status = 'aberto';
CREATE INDEX idx_equipamento_status      ON equipamento (status);
