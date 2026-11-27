-- SMI - Sistema de Monitoramento e Gestao de Dados Industriais
-- 01_schema.sql (parte 1)
--
-- criar o banco antes (fora do script):
--   createdb industrial
--   psql -d industrial -v ON_ERROR_STOP=1 -f sql/01_schema.sql
--
-- pode rodar de novo, ele apaga tudo antes de criar.
-- o modelo segue o DER do professor.
-- ####################################################################
-- # Basic CREATE DATABASE statement
-- # See https://www.ibm.com/docs/en/db2-for-zos/13?topic=statements-create-database for complete syntax.
-- ####################################################################

drop table if exists alerta             cascade;
drop table if exists leitura             cascade;
drop table if exists manutencao          cascade;
drop table if exists sensor               cascade;
drop table if exists equipamento      cascade;
drop table if exists linha_producao  cascade;
drop table if exists planta            cascade;
drop table if exists tecnico          cascade;
drop table if exists tipo_manutencao cascade;
drop table if exists unidade_medida  cascade;
drop table if exists tipo_sensor     cascade;

drop sequence if exists seq_planta, seq_linha, seq_equipamento, seq_tipo_sensor,
    seq_unidade, seq_sensor, seq_leitura, seq_alerta, seq_tecnico,
    seq_tipo_manutencao, seq_manutencao;

-- sequences (uma pra cada chave primaria)
create sequence seq_planta start 1;
create sequence seq_linha start 1;
create sequence seq_equipamento start 1;
create sequence seq_tipo_sensor start 1;
create sequence seq_unidade start 1;
create sequence seq_sensor start 1;
create sequence seq_leitura start 1;
create sequence seq_alerta start 1;
create sequence seq_tecnico start 1;
create sequence seq_tipo_manutencao start 1;
create sequence seq_manutencao start 1;

-- tabelas que nao dependem de nenhuma outra

create table planta (
    id_planta integer primary key default nextval('seq_planta'),
    nome varchar(80) not null unique,
    localizacao varchar(120) not null,
    responsavel varchar(80) not null
);

create table tipo_sensor (
    id_tipo_sensor integer primary key default nextval('seq_tipo_sensor'),
    nome varchar(50) not null unique,
    descricao text
);

create table unidade_medida (
    id_unidade integer primary key default nextval('seq_unidade'),
    sigla varchar(15) not null unique,
    descricao varchar(80) not null
);

create table tecnico (
    id_tecnico integer primary key default nextval('seq_tecnico'),
    nome varchar(80) not null,
    especialidade varchar(60) not null,
    contato varchar(120)
);

create table tipo_manutencao (
    id_tipo_manutencao integer primary key default nextval('seq_tipo_manutencao'),
    nome varchar(50) not null unique,
    descricao text
);

-- planta -> linha -> equipamento

create table linha_producao (
    id_linha integer primary key default nextval('seq_linha'),
    nome varchar(80) not null,
    descricao text,
    id_planta integer not null references planta (id_planta),
    -- na mesma planta nao pode ter duas linhas com o mesmo nome
    constraint uq_linha_planta_nome unique (id_planta, nome)
);

create table equipamento (
    id_equipamento integer primary key default nextval('seq_equipamento'),
    tag varchar(30) not null unique,
    nome varchar(80) not null,
    fabricante varchar(60),
    modelo varchar(60),
    data_instalacao date not null,
    status varchar(15) not null default 'operando',
    id_linha integer not null references linha_producao (id_linha),
    constraint ck_equipamento_status
        check (status in ('operando', 'envio', 'manutencao'))
);

-- sensores e leituras

create table sensor (
    id_sensor integer primary key default nextval('seq_sensor'),
    tag varchar(30) not null unique,
    descricao varchar(120),
    limite_inferior numeric(12,3) not null,
    limite_superior numeric(12,3) not null,
    id_equipamento integer not null references equipamento (id_equipamento),
    id_tipo_sensor integer not null references tipo_sensor (id_tipo_sensor),
    id_unidade integer not null references unidade_medida (id_unidade),
    constraint ck_sensor_limites check (limite_inferior < limite_superior)
);

-- a leitura guarda o sensor e tambem o equipamento (como no DER do professor)
create table leitura (
    id_leitura bigint primary key default nextval('seq_leitura'),
    data_hora timestamp not null,
    valor numeric(12,3) not null,
    qualidade varchar(10) not null default 'estavel',
    id_sensor integer not null references sensor (id_sensor),
    id_equipamento integer not null references equipamento (id_equipamento),
    constraint ck_leitura_qualidade check (qualidade in ('estavel', 'instavel')),
    -- o mesmo sensor nao pode ter duas leituras no mesmo horario
    constraint uq_leitura_sensor_hora unique (id_sensor, data_hora)
);

create table alerta (
    id_alerta bigint primary key default nextval('seq_alerta'),
    data_hora timestamp not null default now(),
    severidade varchar(10) not null,
    descricao text not null,
    status varchar(15) not null default 'ok',
    id_leitura bigint not null references leitura (id_leitura),
    constraint ck_alerta_severidade check (severidade in ('baixa', 'media', 'alta', 'critica', 'nula')),
    constraint ck_alerta_status check (status in ('alerta', 'ok'))
);

-- manutencao

create table manutencao (
    id_manutencao integer primary key default nextval('seq_manutencao'),
    data_inicio date not null,
    data_fim date,
    descricao text not null,
    status varchar(15) not null default 'agendada',
    id_equipamento integer not null references equipamento (id_equipamento),
    id_tecnico integer not null references tecnico (id_tecnico),
    id_tipo_manutencao integer not null references tipo_manutencao (id_tipo_manutencao),
    constraint ck_manutencao_status
        check (status in ('agendada', 'em_andamento', 'concluida', 'cancelada')),
    constraint ck_manutencao_datas
        check (data_fim is null or data_fim >= data_inicio),
    -- se esta concluida tem que ter data de fim
    constraint ck_manutencao_concluida
        check (status <> 'concluida' or data_fim is not null)
);

-- indices
-- o postgres ja cria indice pra PK e pra UNIQUE, mas nao cria pra FK.
-- esses sao os que eu achei que vao ser usados nas consultas.

create index idx_leitura_data_hora on leitura (data_hora);
create index idx_leitura_equipamento on leitura (id_equipamento);
create index idx_linha_planta on linha_producao (id_planta);
create index idx_equipamento_linha on equipamento (id_linha);
create index idx_sensor_equipamento on sensor (id_equipamento);
create index idx_alerta_leitura on alerta (id_leitura);
create index idx_manutencao_equipamento on manutencao (id_equipamento);
create index idx_manutencao_tecnico on manutencao (id_tecnico);

-- indice parcial: so os alertas abertos, que sao os mais consultados
create index idx_alerta_abertos on alerta (data_hora) where status = 'aberto';
create index idx_equipamento_status on equipamento (status);


