-- =====================================================================
-- SMI - Sistema de Monitoramento e Gestão de Dados Industriais
-- 02_dados.sql  (Parte 1: dados de exemplo)
--
-- Rodar depois do 01_schema.sql:
--     psql -d industrial -v ON_ERROR_STOP=1 -f sql/02_dados.sql
--
-- Cenário: duas plantas de uma indústria fictícia em Minas Gerais, com
-- motores, bombas, compressores, fornos e ventiladores monitorados.
-- Período das leituras: 09/11/2026 a 15/11/2026, uma leitura por hora
-- por sensor.
--
-- Os valores "normais" são gerados por fórmula (senoide ao longo do dia
-- mais um ruído). O setseed deixa o ruído sempre igual, então todo mundo
-- do grupo vai ter os mesmos números. Depois a gente força algumas
-- leituras fora do limite pra ter alerta pra testar.
-- =====================================================================

SELECT setseed(0.42);

-- ---------------------------------------------------------------------
-- Plantas e linhas
-- ---------------------------------------------------------------------
INSERT INTO planta (nome, localizacao, responsavel) VALUES
    ('Planta Uberlândia', 'Distrito Industrial, Uberlândia - MG', 'Marcos Tavares'),
    ('Planta Araxá',      'Zona Industrial, Araxá - MG',           'Renata Viana');

INSERT INTO linha_producao (nome, descricao, id_planta)
SELECT v.nome, v.descricao, p.id_planta
FROM (VALUES
    ('Linha de Envase',     'Envase e transporte do produto acabado', 'Planta Uberlândia'),
    ('Linha de Utilidades', 'Ar comprimido, secagem e utilidades',    'Planta Uberlândia'),
    ('Linha de Moagem',     'Moagem e exaustão de pó',                'Planta Araxá'),
    ('Linha de Embalagem',  'Embalagem e vácuo',                      'Planta Araxá')
) AS v(nome, descricao, planta)
JOIN planta p ON p.nome = v.planta;

-- ---------------------------------------------------------------------
-- Tabelas de apoio
-- ---------------------------------------------------------------------
INSERT INTO tipo_sensor (nome, descricao) VALUES
    ('Temperatura',        'Mede temperatura de enrolamentos, mancais, ar e câmaras'),
    ('Vibração',           'Mede velocidade de vibração em mancais e carcaças'),
    ('Pressão',            'Mede pressão em linhas de descarga, redes e vácuo'),
    ('Corrente elétrica',  'Mede corrente consumida por motores e resistências'),
    ('Vazão',              'Mede vazão de líquidos nas bombas');

INSERT INTO unidade_medida (sigla, descricao) VALUES
    ('°C',    'Graus Celsius'),
    ('mm/s',  'Milímetros por segundo (velocidade de vibração RMS)'),
    ('bar',   'Bar (pressão manométrica)'),
    ('A',     'Ampères'),
    ('m³/h',  'Metros cúbicos por hora');

INSERT INTO tipo_manutencao (nome, descricao) VALUES
    ('Preventiva', 'Feita em intervalos fixos, antes de dar problema'),
    ('Corretiva',  'Feita depois de uma falha ou desvio'),
    ('Preditiva',  'Feita com base em medições (vibração, temperatura, corrente)'),
    ('Inspeção',   'Verificação de rotina, sem troca grande de peças');

INSERT INTO tecnico (nome, especialidade, contato) VALUES
    ('Carlos Eduardo Lima',  'Mecânica',        'carlos.lima@smi.exemplo'),
    ('Fernanda Alves',       'Elétrica',        'fernanda.alves@smi.exemplo'),
    ('Rogério Pinheiro',     'Instrumentação',  'rogerio.pinheiro@smi.exemplo'),
    ('Juliana Matos',        'Mecânica',        'juliana.matos@smi.exemplo'),
    ('Anderson Silva',       'Automação',       'anderson.silva@smi.exemplo'),
    ('Patrícia Nogueira',    'Elétrica',        'patricia.nogueira@smi.exemplo');

-- ---------------------------------------------------------------------
-- Equipamentos
-- ---------------------------------------------------------------------
INSERT INTO equipamento (tag, nome, fabricante, modelo, data_instalacao, status, id_linha)
SELECT v.tag, v.nome, v.fabricante, v.modelo, v.data_instalacao::date, v.status, l.id_linha
FROM (VALUES
    ('MOT-101', 'Motor da esteira principal', 'WEG',          'W22 75cv',     '2019-03-12', 'operando',   'Linha de Envase',     'Planta Uberlândia'),
    ('BOM-102', 'Bomba de recalque',          'KSB',          'Meganorm 50',  '2020-07-01', 'operando',   'Linha de Envase',     'Planta Uberlândia'),
    ('CMP-103', 'Compressor reserva',         'Schulz',       'SRP 3030',     '2018-11-20', 'parado',     'Linha de Envase',     'Planta Uberlândia'),
    ('CMP-201', 'Compressor de ar',           'Atlas Copco',  'GA 55',        '2021-02-15', 'operando',   'Linha de Utilidades', 'Planta Uberlândia'),
    ('FRN-202', 'Forno de secagem',           'Eletrotherm',  'ET-900',       '2017-05-30', 'operando',   'Linha de Utilidades', 'Planta Uberlândia'),
    ('MOT-301', 'Motor do moinho',            'WEG',          'W22 150cv',    '2016-09-08', 'operando',   'Linha de Moagem',     'Planta Araxá'),
    ('VEN-302', 'Ventilador de exaustão',     'Ventisilva',   'VS-450',       '2019-10-25', 'operando',   'Linha de Moagem',     'Planta Araxá'),
    ('MOT-401', 'Motor da embaladora',        'Siemens',      '1LE1 30cv',    '2022-01-18', 'manutencao', 'Linha de Embalagem',  'Planta Araxá'),
    ('BOM-402', 'Bomba de vácuo',             'Busch',        'R5 RA 0100',   '2020-12-04', 'operando',   'Linha de Embalagem',  'Planta Araxá')
) AS v(tag, nome, fabricante, modelo, data_instalacao, status, linha, planta)
JOIN planta p         ON p.nome = v.planta
JOIN linha_producao l ON l.nome = v.linha AND l.id_planta = p.id_planta;

-- ---------------------------------------------------------------------
-- Sensores (16)
-- ---------------------------------------------------------------------
INSERT INTO sensor (tag, descricao, limite_inferior, limite_superior, id_equipamento, id_tipo_sensor, id_unidade)
SELECT v.tag, v.descricao, v.inf, v.sup, e.id_equipamento, t.id_tipo_sensor, u.id_unidade
FROM (VALUES
    ('TT-101', 'Temperatura do enrolamento do motor da esteira',  20.0,  90.0, 'MOT-101', 'Temperatura',       '°C'),
    ('VT-101', 'Vibração no mancal do motor da esteira',           0.0,   7.0, 'MOT-101', 'Vibração',          'mm/s'),
    ('IT-101', 'Corrente do motor da esteira',                    30.0, 110.0, 'MOT-101', 'Corrente elétrica', 'A'),
    ('PT-102', 'Pressão na descarga da bomba de recalque',         2.0,   8.0, 'BOM-102', 'Pressão',           'bar'),
    ('FT-102', 'Vazão da bomba de recalque',                      20.0, 120.0, 'BOM-102', 'Vazão',             'm³/h'),
    ('TT-103', 'Temperatura do ar na saída do compressor reserva',40.0, 110.0, 'CMP-103', 'Temperatura',       '°C'),
    ('TT-201', 'Temperatura do ar na saída do compressor',        40.0, 110.0, 'CMP-201', 'Temperatura',       '°C'),
    ('PT-201', 'Pressão da rede de ar comprimido',                 6.0,   9.0, 'CMP-201', 'Pressão',           'bar'),
    ('TT-202', 'Temperatura interna do forno de secagem',        150.0, 220.0, 'FRN-202', 'Temperatura',       '°C'),
    ('IT-202', 'Corrente das resistências do forno',              10.0,  60.0, 'FRN-202', 'Corrente elétrica', 'A'),
    ('TT-301', 'Temperatura do mancal do moinho',                 20.0,  85.0, 'MOT-301', 'Temperatura',       '°C'),
    ('VT-301', 'Vibração no mancal do moinho',                     0.0,   8.0, 'MOT-301', 'Vibração',          'mm/s'),
    ('IT-301', 'Corrente do motor do moinho',                     80.0, 220.0, 'MOT-301', 'Corrente elétrica', 'A'),
    ('VT-302', 'Vibração do ventilador de exaustão',               0.0,   6.0, 'VEN-302', 'Vibração',          'mm/s'),
    ('TT-401', 'Temperatura do motor da embaladora',              20.0,  85.0, 'MOT-401', 'Temperatura',       '°C'),
    ('PT-402', 'Pressão de vácuo da bomba',                       -0.9,  -0.5, 'BOM-402', 'Pressão',           'bar')
) AS v(tag, descricao, inf, sup, equip, tipo, unidade)
JOIN equipamento e   ON e.tag  = v.equip
JOIN tipo_sensor t   ON t.nome = v.tipo
JOIN unidade_medida u ON u.sigla = v.unidade;

-- ---------------------------------------------------------------------
-- Leituras "normais"
-- Cada linha do VALUES diz: sensor, valor médio, amplitude da senoide
-- diária e tamanho do ruído. Escolhi números que ficam bem dentro dos
-- limites de cada sensor.
--
-- Duas exceções de propósito:
--   TT-103 (compressor reserva) não tem leitura nenhuma: o equipamento
--          está parado.
--   TT-401 (motor da embaladora) só tem leitura até 11/11: no dia 12 o
--          motor entrou em manutenção.
-- ---------------------------------------------------------------------
INSERT INTO leitura (data_hora, valor, qualidade, id_sensor)
SELECT t.ts,
       round((p.media
              + p.amp * sin(2 * pi() * extract(hour FROM t.ts) / 24.0)
              + (random() - 0.5) * p.ruido)::numeric, 3),
       'boa',
       s.id_sensor
FROM (VALUES
    ('TT-101',  65.0,  5.0, 4.0),
    ('VT-101',   3.0,  0.4, 0.6),
    ('IT-101',  85.0,  8.0, 6.0),
    ('PT-102',   5.0,  0.5, 0.4),
    ('FT-102',  80.0, 10.0, 6.0),
    ('TT-201',  85.0,  6.0, 4.0),
    ('PT-201',   7.5,  0.4, 0.3),
    ('TT-202', 185.0,  8.0, 6.0),
    ('IT-202',  38.0,  5.0, 4.0),
    ('TT-301',  60.0,  5.0, 4.0),
    ('VT-301',   3.5,  0.5, 0.6),
    ('IT-301', 170.0, 15.0, 10.0),
    ('VT-302',   2.5,  0.3, 0.4),
    ('TT-401',  55.0,  5.0, 4.0),
    ('PT-402',  -0.7,  0.05, 0.04)
) AS p(tag, media, amp, ruido)
JOIN sensor s ON s.tag = p.tag
CROSS JOIN LATERAL generate_series(
        timestamp '2026-11-09 00:00',
        CASE WHEN p.tag = 'TT-401' THEN timestamp '2026-11-11 23:00'
             ELSE timestamp '2026-11-15 23:00' END,
        interval '1 hour') AS t(ts)
ORDER BY t.ts, s.id_sensor;     -- id_leitura cresce junto com o tempo

-- ---------------------------------------------------------------------
-- Leituras fora do limite (casos de teste pro alerta)
-- Em vez de inserir leituras novas, a gente troca o valor de leituras
-- que já existem, assim não quebra a UNIQUE (sensor, hora).
-- ---------------------------------------------------------------------
UPDATE leitura l
   SET valor = a.valor
  FROM sensor s,
       (VALUES
           ('TT-101', timestamp '2026-11-11 14:00',  96.500),  -- superaquecimento do motor da esteira
           ('TT-101', timestamp '2026-11-11 15:00',  98.200),
           ('TT-101', timestamp '2026-11-11 16:00',  93.000),
           ('VT-301', timestamp '2026-11-12 03:00',   9.400),  -- vibração alta no moinho
           ('PT-102', timestamp '2026-11-13 10:00',   1.400),  -- queda de pressão na bomba
           ('TT-201', timestamp '2026-11-14 16:00', 118.000),  -- compressor muito quente
           ('IT-301', timestamp '2026-11-10 22:00', 238.000),  -- pico de corrente no moinho
           ('FT-102', timestamp '2026-11-15 05:00',  12.000),  -- vazão quase zerada
           ('TT-401', timestamp '2026-11-11 20:00',  91.000),  -- antes de a embaladora parar
           ('PT-201', timestamp '2026-11-13 18:00',   5.200),  -- rede de ar com pressão baixa
           ('VT-302', timestamp '2026-11-14 08:00',   6.800),
           ('TT-202', timestamp '2026-11-12 11:00', 232.000)   -- forno acima do limite
       ) AS a(tag, ts, valor)
 WHERE s.tag = a.tag
   AND l.id_sensor = s.id_sensor
   AND l.data_hora = a.ts;

-- Algumas leituras com qualidade ruim (valor dentro do limite, mas o
-- sinal não é confiável). Servem pra testar filtro por qualidade.
UPDATE leitura l
   SET qualidade = a.qualidade
  FROM sensor s,
       (VALUES
           ('TT-301', timestamp '2026-11-10 09:00', 'incerta'),
           ('IT-202', timestamp '2026-11-13 02:00', 'ruim'),
           ('PT-402', timestamp '2026-11-12 12:00', 'incerta')
       ) AS a(tag, ts, qualidade)
 WHERE s.tag = a.tag
   AND l.id_sensor = s.id_sensor
   AND l.data_hora = a.ts;

-- ---------------------------------------------------------------------
-- Alertas
-- Geramos um alerta pra cada leitura que está fora do limite do sensor.
-- A severidade depende de quanto o valor passou do limite, comparado
-- com a largura da faixa (limite_superior - limite_inferior):
--     mais de 25%  -> critica
--     mais de 10%  -> alta
--     mais de 3%   -> media
--     o resto      -> baixa
-- O status depende da idade: o que é mais antigo já foi resolvido, o
-- do meio foi reconhecido e o mais recente ainda está aberto.
-- (O trigger da Parte 2 vai fazer algo parecido nas leituras novas.)
-- ---------------------------------------------------------------------
INSERT INTO alerta (data_hora, severidade, descricao, status, id_leitura)
SELECT x.data_hora,
       CASE WHEN x.desvio > 0.25 THEN 'critica'
            WHEN x.desvio > 0.10 THEN 'alta'
            WHEN x.desvio > 0.03 THEN 'media'
            ELSE 'baixa' END,
       format('Sensor %s fora do limite: %s %s (faixa de %s a %s)',
              x.tag, x.valor, x.sigla, x.limite_inferior, x.limite_superior),
       CASE WHEN x.data_hora <  timestamp '2026-11-12 00:00' THEN 'resolvido'
            WHEN x.data_hora <  timestamp '2026-11-14 00:00' THEN 'reconhecido'
            ELSE 'aberto' END,
       x.id_leitura
FROM (
    SELECT l.id_leitura, l.data_hora, l.valor, s.tag, s.limite_inferior,
           s.limite_superior, u.sigla,
           CASE WHEN l.valor > s.limite_superior
                    THEN (l.valor - s.limite_superior) / (s.limite_superior - s.limite_inferior)
                ELSE (s.limite_inferior - l.valor) / (s.limite_superior - s.limite_inferior)
           END AS desvio
    FROM leitura l
    JOIN sensor s         ON s.id_sensor = l.id_sensor
    JOIN unidade_medida u ON u.id_unidade = s.id_unidade
    WHERE l.valor < s.limite_inferior OR l.valor > s.limite_superior
) x
ORDER BY x.data_hora;

-- ---------------------------------------------------------------------
-- Manutenções e técnicos
-- ---------------------------------------------------------------------
INSERT INTO manutencao (data_inicio, data_fim, descricao, status, id_equipamento, id_tipo_manutencao)
SELECT v.data_inicio::date, v.data_fim::date, v.descricao, v.status, e.id_equipamento, t.id_tipo_manutencao
FROM (VALUES
    ('2026-10-05', '2026-10-06', 'Lubrificação dos mancais e reaperto das conexões',                 'concluida',    'MOT-101', 'Preventiva'),
    ('2026-10-18', '2026-10-19', 'Troca do selo mecânico por vazamento',                            'concluida',    'BOM-102', 'Corretiva'),
    ('2026-10-27', '2026-10-27', 'Análise de vibração com coletor portátil',                        'concluida',    'MOT-301', 'Preditiva'),
    ('2026-11-03', '2026-11-03', 'Inspeção de rotina e troca do filtro de ar',                      'concluida',    'CMP-201', 'Inspeção'),
    ('2026-11-08', NULL,         'Cancelada: janela de produção coincidiu com pedido urgente',      'cancelada',    'BOM-402', 'Preventiva'),
    ('2026-11-12', NULL,         'Troca dos rolamentos após aumento de temperatura',                'em_andamento', 'MOT-401', 'Corretiva'),
    ('2026-11-14', NULL,         'Compressor parado, aguardando válvula de admissão',               'em_andamento', 'CMP-103', 'Corretiva'),
    ('2026-11-24', NULL,         'Calibração dos termopares e revisão das resistências',            'agendada',     'FRN-202', 'Preventiva'),
    ('2026-11-30', NULL,         'Medição de vibração e balanceamento do ventilador',               'agendada',     'VEN-302', 'Preditiva')
) AS v(data_inicio, data_fim, descricao, status, equip, tipo)
JOIN equipamento e     ON e.tag  = v.equip
JOIN tipo_manutencao t ON t.nome = v.tipo
ORDER BY v.data_inicio;

-- Quem trabalhou em cada manutenção (N:N)
INSERT INTO manutencao_tecnico (id_manutencao, id_tecnico)
SELECT m.id_manutencao, t.id_tecnico
FROM (VALUES
    ('MOT-101', '2026-10-05', 'Carlos Eduardo Lima'),
    ('MOT-101', '2026-10-05', 'Fernanda Alves'),
    ('BOM-102', '2026-10-18', 'Carlos Eduardo Lima'),
    ('MOT-301', '2026-10-27', 'Rogério Pinheiro'),
    ('MOT-301', '2026-10-27', 'Anderson Silva'),
    ('CMP-201', '2026-11-03', 'Carlos Eduardo Lima'),
    ('BOM-402', '2026-11-08', 'Juliana Matos'),
    ('MOT-401', '2026-11-12', 'Carlos Eduardo Lima'),
    ('MOT-401', '2026-11-12', 'Juliana Matos'),
    ('CMP-103', '2026-11-14', 'Fernanda Alves'),
    ('CMP-103', '2026-11-14', 'Patrícia Nogueira'),
    ('FRN-202', '2026-11-24', 'Rogério Pinheiro'),
    ('FRN-202', '2026-11-24', 'Anderson Silva'),
    ('VEN-302', '2026-11-30', 'Rogério Pinheiro')
) AS v(equip, data_inicio, tecnico)
JOIN equipamento e ON e.tag = v.equip
JOIN manutencao m  ON m.id_equipamento = e.id_equipamento
                  AND m.data_inicio = v.data_inicio::date
JOIN tecnico t     ON t.nome = v.tecnico;

-- ---------------------------------------------------------------------
-- Estatísticas atualizadas pro planner e conferência rápida
-- ---------------------------------------------------------------------
ANALYZE;

SELECT 'planta' AS tabela, count(*) AS linhas FROM planta
UNION ALL SELECT 'linha_producao',     count(*) FROM linha_producao
UNION ALL SELECT 'equipamento',        count(*) FROM equipamento
UNION ALL SELECT 'tipo_sensor',        count(*) FROM tipo_sensor
UNION ALL SELECT 'unidade_medida',     count(*) FROM unidade_medida
UNION ALL SELECT 'sensor',             count(*) FROM sensor
UNION ALL SELECT 'leitura',            count(*) FROM leitura
UNION ALL SELECT 'alerta',             count(*) FROM alerta
UNION ALL SELECT 'tecnico',            count(*) FROM tecnico
UNION ALL SELECT 'tipo_manutencao',    count(*) FROM tipo_manutencao
UNION ALL SELECT 'manutencao',         count(*) FROM manutencao
UNION ALL SELECT 'manutencao_tecnico', count(*) FROM manutencao_tecnico;
