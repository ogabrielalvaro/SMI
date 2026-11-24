-- SMI - dados de exemplo (parte 1)
--
-- rodar depois do 01_schema.sql:
--   psql -d industrial -v ON_ERROR_STOP=1 -f sql/02_dados.sql
--
-- as chaves (id) entram pela sequence, na ordem em que os inserts estao
-- escritos. por isso os numeros usados nas chaves estrangeiras abaixo
-- (ex.: id_planta = 1) sao os da ordem de cada lista.
--
-- esse script nao pode rodar duas vezes seguidas. pra recarregar, roda o
-- 01_schema.sql antes.

select setseed(0.42);

insert into planta (nome, localizacao, responsavel) values
    ('Planta Uberlandia', 'Distrito Industrial, Uberlandia - MG', 'Marcos Tavares'),
    ('Planta Araxa', 'Zona Industrial, Araxa - MG', 'Renata Viana');

-- 1 envase, 2 utilidades (planta 1) / 3 moagem, 4 embalagem (planta 2)
insert into linha_producao (nome, descricao, id_planta) values
    ('Linha de Envase', 'Envase e transporte do produto acabado', 1),
    ('Linha de Utilidades', 'Ar comprimido, secagem e utilidades', 1),
    ('Linha de Moagem', 'Moagem e exaustao de po', 2),
    ('Linha de Embalagem', 'Embalagem e vacuo', 2);

-- 1 temperatura, 2 vibracao, 3 pressao, 4 corrente, 5 vazao
insert into tipo_sensor (nome, descricao) values
    ('Temperatura', 'Temperatura de enrolamentos, mancais, ar e camaras'),
    ('Vibracao', 'Velocidade de vibracao em mancais e carcacas'),
    ('Pressao', 'Pressao em linhas de descarga, redes e vacuo'),
    ('Corrente eletrica', 'Corrente consumida por motores e resistencias'),
    ('Vazao', 'Vazao de liquidos nas bombas');

-- mesma ordem do tipo_sensor: 1 C, 2 mm/s, 3 bar, 4 A, 5 m3/h
insert into unidade_medida (sigla, descricao) values
    ('C', 'Graus Celsius'),
    ('mm/s', 'Milimetros por segundo (velocidade de vibracao)'),
    ('bar', 'Bar (pressao)'),
    ('A', 'Amperes'),
    ('m3/h', 'Metros cubicos por hora');

-- 1 preventiva, 2 corretiva, 3 preditiva, 4 inspecao
insert into tipo_manutencao (nome, descricao) values
    ('Preventiva', 'Feita em intervalos fixos, antes de dar problema'),
    ('Corretiva', 'Feita depois de uma falha'),
    ('Preditiva', 'Feita a partir de medicoes (vibracao, temperatura, corrente)'),
    ('Inspecao', 'Verificacao de rotina');

insert into tecnico (nome, especialidade, contato) values
    ('Carlos Eduardo Lima', 'Mecanica', 'carlos.lima@smi.exemplo'),
    ('Fernanda Alves', 'Eletrica', 'fernanda.alves@smi.exemplo'),
    ('Rogerio Pinheiro', 'Instrumentacao', 'rogerio.pinheiro@smi.exemplo'),
    ('Juliana Matos', 'Mecanica', 'juliana.matos@smi.exemplo'),
    ('Anderson Silva', 'Automacao', 'anderson.silva@smi.exemplo'),
    ('Patricia Nogueira', 'Eletrica', 'patricia.nogueira@smi.exemplo');

-- equipamentos (o ultimo numero e a linha)
insert into equipamento (tag, nome, fabricante, modelo, data_instalacao, status, id_linha) values
    ('MOT-101', 'Motor da esteira principal', 'WEG', 'W22 75cv', '2019-03-12', 'operando', 1),
    ('BOM-102', 'Bomba de recalque', 'KSB', 'Meganorm 50', '2020-07-01', 'operando', 1),
    ('CMP-103', 'Compressor reserva', 'Schulz', 'SRP 3030', '2018-11-20', 'parado', 1),
    ('CMP-201', 'Compressor de ar', 'Atlas Copco', 'GA 55', '2021-02-15', 'operando', 2),
    ('FRN-202', 'Forno de secagem', 'Eletrotherm', 'ET-900', '2017-05-30', 'operando', 2),
    ('MOT-301', 'Motor do moinho', 'WEG', 'W22 150cv', '2016-09-08', 'operando', 3),
    ('VEN-302', 'Ventilador de exaustao', 'Ventisilva', 'VS-450', '2019-10-25', 'operando', 3),
    ('MOT-401', 'Motor da embaladora', 'Siemens', '1LE1 30cv', '2022-01-18', 'manutencao', 4),
    ('BOM-402', 'Bomba de vacuo', 'Busch', 'R5 RA 0100', '2020-12-04', 'operando', 4);

-- sensores: tag, descricao, limite inferior, limite superior,
--           equipamento, tipo de sensor, unidade
insert into sensor (tag, descricao, limite_inferior, limite_superior, id_equipamento, id_tipo_sensor, id_unidade) values
    ('TT-101', 'Temperatura do enrolamento do motor da esteira', 20, 90, 1, 1, 1),
    ('VT-101', 'Vibracao no mancal do motor da esteira', 0, 7, 1, 2, 2),
    ('IT-101', 'Corrente do motor da esteira', 30, 110, 1, 4, 4),
    ('PT-102', 'Pressao na descarga da bomba de recalque', 2, 8, 2, 3, 3),
    ('FT-102', 'Vazao da bomba de recalque', 20, 120, 2, 5, 5),
    ('TT-103', 'Temperatura do ar na saida do compressor reserva', 40, 110, 3, 1, 1),
    ('TT-201', 'Temperatura do ar na saida do compressor', 40, 110, 4, 1, 1),
    ('PT-201', 'Pressao da rede de ar comprimido', 6, 9, 4, 3, 3),
    ('TT-202', 'Temperatura interna do forno de secagem', 150, 220, 5, 1, 1),
    ('IT-202', 'Corrente das resistencias do forno', 10, 60, 5, 4, 4),
    ('TT-301', 'Temperatura do mancal do moinho', 20, 85, 6, 1, 1),
    ('VT-301', 'Vibracao no mancal do moinho', 0, 8, 6, 2, 2),
    ('IT-301', 'Corrente do motor do moinho', 80, 220, 6, 4, 4),
    ('VT-302', 'Vibracao do ventilador de exaustao', 0, 6, 7, 2, 2),
    ('TT-401', 'Temperatura do motor da embaladora', 20, 85, 8, 1, 1),
    ('PT-402', 'Pressao de vacuo da bomba', -0.9, -0.5, 9, 3, 3);

-- leituras: uma por hora, de 09/11 a 15/11/2026, pra todos os sensores.
-- o valor fica perto do meio da faixa do sensor, variando com a hora do dia
-- (seno) mais um pouco de aleatorio, entao nenhuma leitura sai do limite aqui.
-- excecoes:
--   TT-103: o compressor reserva esta parado, entao nao tem leitura
--   TT-401: o motor da embaladora entrou em manutencao dia 12, so tem ate dia 11
insert into leitura (data_hora, valor, qualidade, id_sensor, id_equipamento)
select t,
       round((s.limite_inferior + (s.limite_superior - s.limite_inferior) *
             (0.5 + 0.08 * sin(2 * pi() * extract(hour from t) / 24) + (random() - 0.5) * 0.1))::numeric, 3),
       'boa',
       s.id_sensor,
       s.id_equipamento
from sensor s
cross join generate_series(timestamp '2026-11-09 00:00', timestamp '2026-11-15 23:00', interval '1 hour') as t
where s.tag <> 'TT-103'
  and not (s.tag = 'TT-401' and t > timestamp '2026-11-11 23:00')
order by t, s.id_sensor;

-- agora forca algumas leituras pra fora do limite, pra ter alerta pra testar
-- (id_sensor: 1 TT-101, 4 PT-102, 5 FT-102, 7 TT-201, 8 PT-201, 9 TT-202,
--  12 VT-301, 13 IT-301, 14 VT-302, 15 TT-401)
update leitura set valor = 96.5 where id_sensor = 1 and data_hora = '2026-11-11 14:00';
update leitura set valor = 98.2 where id_sensor = 1 and data_hora = '2026-11-11 15:00';
update leitura set valor = 93 where id_sensor = 1 and data_hora = '2026-11-11 16:00';
update leitura set valor = 9.4 where id_sensor = 12 and data_hora = '2026-11-12 03:00';
update leitura set valor = 1.4 where id_sensor = 4 and data_hora = '2026-11-13 10:00';
update leitura set valor = 118 where id_sensor = 7 and data_hora = '2026-11-14 16:00';
update leitura set valor = 238 where id_sensor = 13 and data_hora = '2026-11-10 22:00';
update leitura set valor = 12 where id_sensor = 5 and data_hora = '2026-11-15 05:00';
update leitura set valor = 91 where id_sensor = 15 and data_hora = '2026-11-11 20:00';
update leitura set valor = 5.2 where id_sensor = 8 and data_hora = '2026-11-13 18:00';
update leitura set valor = 6.8 where id_sensor = 14 and data_hora = '2026-11-14 08:00';
update leitura set valor = 232 where id_sensor = 9 and data_hora = '2026-11-12 11:00';

-- algumas leituras com qualidade ruim (valor ok, mas o sinal nao e confiavel)
update leitura set qualidade = 'incerta' where id_sensor = 11 and data_hora = '2026-11-10 09:00';
update leitura set qualidade = 'ruim' where id_sensor = 10 and data_hora = '2026-11-13 02:00';
update leitura set qualidade = 'incerta' where id_sensor = 16 and data_hora = '2026-11-12 12:00';

-- alertas: um pra cada leitura fora do limite.
-- a severidade depende de quanto passou do limite, comparado com a largura da
-- faixa do sensor (limite superior - limite inferior):
--   mais de 25%: critica / mais de 10%: alta / mais de 3%: media / resto: baixa
-- o status depende da data: o mais velho ja foi resolvido, o do meio foi
-- reconhecido e o mais novo ainda esta aberto.
insert into alerta (data_hora, severidade, descricao, status, id_leitura)
select x.data_hora,
       case when x.desvio > 0.25 then 'critica'
            when x.desvio > 0.10 then 'alta'
            when x.desvio > 0.03 then 'media'
            else 'baixa' end,
       'Sensor ' || x.tag || ' fora do limite: ' || x.valor || ' ' || x.sigla ||
           ' (faixa de ' || x.limite_inferior || ' a ' || x.limite_superior || ')',
       case when x.data_hora < timestamp '2026-11-12 00:00' then 'resolvido'
            when x.data_hora < timestamp '2026-11-14 00:00' then 'reconhecido'
            else 'aberto' end,
       x.id_leitura
from (
    select l.id_leitura, l.data_hora, l.valor, s.tag, s.limite_inferior, s.limite_superior, u.sigla,
           case when l.valor > s.limite_superior
                    then (l.valor - s.limite_superior) / (s.limite_superior - s.limite_inferior)
                else (s.limite_inferior - l.valor) / (s.limite_superior - s.limite_inferior)
           end as desvio
    from leitura l
    join sensor s on s.id_sensor = l.id_sensor
    join unidade_medida u on u.id_unidade = s.id_unidade
    where l.valor < s.limite_inferior or l.valor > s.limite_superior
) x
order by x.data_hora;

-- manutencoes: data inicio, data fim, descricao, status, equipamento, tecnico, tipo
insert into manutencao (data_inicio, data_fim, descricao, status, id_equipamento, id_tecnico, id_tipo_manutencao) values
    ('2026-10-05', '2026-10-06', 'Lubrificacao dos mancais e reaperto das conexoes', 'concluida', 1, 1, 1),
    ('2026-10-18', '2026-10-19', 'Troca do selo mecanico por vazamento', 'concluida', 2, 1, 2),
    ('2026-10-27', '2026-10-27', 'Analise de vibracao com coletor portatil', 'concluida', 6, 3, 3),
    ('2026-11-03', '2026-11-03', 'Inspecao de rotina e troca do filtro de ar', 'concluida', 4, 1, 4),
    ('2026-11-08', null, 'Cancelada: a janela de producao bateu com um pedido urgente', 'cancelada', 9, 4, 1),
    ('2026-11-12', null, 'Troca dos rolamentos depois do aumento de temperatura', 'em_andamento', 8, 4, 2),
    ('2026-11-14', null, 'Compressor parado, esperando a valvula de admissao', 'em_andamento', 3, 2, 2),
    ('2026-11-24', null, 'Calibracao dos termopares e revisao das resistencias', 'agendada', 5, 3, 1),
    ('2026-11-30', null, 'Medicao de vibracao e balanceamento do ventilador', 'agendada', 7, 3, 3);

analyze;

-- conferencia: quantas linhas ficou em cada tabela
select 'planta' as tabela, count(*) as linhas from planta
union all select 'linha_producao', count(*) from linha_producao
union all select 'equipamento', count(*) from equipamento
union all select 'tipo_sensor', count(*) from tipo_sensor
union all select 'unidade_medida', count(*) from unidade_medida
union all select 'sensor', count(*) from sensor
union all select 'leitura', count(*) from leitura
union all select 'alerta', count(*) from alerta
union all select 'tecnico', count(*) from tecnico
union all select 'tipo_manutencao', count(*) from tipo_manutencao
union all select 'manutencao', count(*) from manutencao;
