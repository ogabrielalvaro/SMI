-- Funções e procedures (média/consumo, checagem de limites, registro de manutenção)
-- Parte 2
-- Ordem de execução: arquivos sql/0*.sql em sequência
--=================

--TABELA de EQUIPAMENTO

-- funcao que confere a data de instalacao contra o status
-- data futura = maquina comprada que ainda vai ser instalada -> tem que estar em 'envio'
-- data passada (ou hoje) = maquina ja instalada -> nao pode estar em 'envio'
-- obs: usei data > hoje (e nao >=) pq se fosse >= a maquina que chega hoje
-- nunca conseguiria sair de 'envio' (a data de hoje ia exigir 'envio' de novo)

CREATE OR REPLACE FUNCTION fn_check_data_equip() RETURNS TRIGGER
AS $$
BEGIN
    IF (NEW.data_instalacao > CURRENT_DATE) AND (NEW.status != 'envio') THEN
        raise exception 'operacao invalida: instalacao futura exige status "envio"';
    END IF;

    IF (NEW.data_instalacao <= CURRENT_DATE) AND (NEW.status = 'envio') THEN
        raise exception ' equipamento ja instalado nao pode ter status em envio';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--trg da data do equipamento
DROP TRIGGER IF EXISTS trg_check_data_equip on equipamento;
CREATE TRIGGER trg_check_data_equip
BEFORE INSERT OR UPDATE of data_instalacao, status on equipamento
for each row execute function fn_check_data_equip();


-- funcao que confere a troca de status do equipamento (o lado do status)
-- so olha quando o status muda de verdade
CREATE OR REPLACE FUNCTION fn_check_status_equip() RETURNS TRIGGER
AS $$
BEGIN
    -- sstatus igual nao da erro
    IF old.status = NEW.status THEN
        RETURN NEW;
    END IF;
    -- quem ja foi instalado nao volta pra envio
    IF old.status != 'envio' AND NEW.status = 'envio' THEN
        raise exception 'invalido: "envio" é somente para chegada';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--trg do status do equipameento
DROP TRIGGER IF EXISTS trg_check_status_equip on equipamento;
CREATE TRIGGER trg_check_status_equip
BEFORE UPDATE OF status on equipamento
for each row execute function fn_check_status_equip();


--tabela de MANUTENCAO
-- funcao que calcula a media de duracao dedia das manutencoes de um equipamento
-- so conta as  com status concluida
CREATE OR REPLACE FUNCTION fn_media_manut_equip(p_id_equipamento INTEGER, inicio_procura DATE, fim_procura DATE)
RETURNS INTEGER
AS $$
DECLARE
    media NUMERIC;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipamento WHERE id_equipamento = p_id_equipamento) THEN
        RAISE EXCEPTION 'operacao invalida: equipamento nao existe';
    END IF;

    IF inicio_procura >= fim_procura THEN
        RAISE EXCEPTION 'operacao invalida: inicio do periodo deve ser antes do fim';
    END IF;

    SELECT AVG(data_fim - data_inicio) INTO media FROM manutencao WHERE id_equipamento = p_id_equipamento
    AND status = 'concluida' AND data_inicio >= inicio_procura AND data_inicio < fim_procura;

    IF media IS NULL THEN
        RAISE NOTICE 'equipamento com zero manutencoes concluidas no periodo';
        RETURN NULL;
    END IF;

    RETURN media;
END;
$$ LANGUAGE plpgsql;
-- realizada    -> data_inicio < data_fim <= hoje
-- em_andamento -> data_inicio <= hoje < data_fim
-- agendada     -> hoje < data_inicio < data_fim
-- cancelada    -> sem restricao de data, so muda o status
-- obs: data_fim NULL passa em em_andamento e agendada (ainda sem previsao de fim),
-- em realizada nao passa (precisa de data_fim)

CREATE OR REPLACE FUNCTION fn_check_data_manut() RETURNS TRIGGER
AS $$
BEGIN
        IF NEW.data_fim IS NOT NULL AND NEW.data_fim <= NEW.data_inicio THEN
            RAISE EXCEPTION'operacao invalida: data de inicio deve ser antes do fim';
        END IF;

--cada status separado
    IF NEW.status = 'cancelada' THEN
        RETURN NEW;

    ELSIF NEW.status = 'concluida' THEN
        IF (NEW.data_fim IS NULL) OR NOT ((NEW.data_inicio < NEW.data_fim) AND (NEW.data_fim <= CURRENT_DATE)) THEN
            RAISE EXCEPTION 'operacao invalida: manutencao realizada exige inicio e fim antes de hoje';
        END IF;
    

    ELSIF NEW.status = 'em_andamento' THEN
        IF (NEW.data_fim IS NOT NULL AND NEW.data_fim <= CURRENT_DATE) OR NOT (NEW.data_inicio < CURRENT_DATE ) THEN
            RAISE EXCEPTION 'operacao invalida: manutencao em andamento nao comeca no futuro e deve ter fim depois';
        END IF;
    

    ELSIF NEW.status = 'agendada' THEN
        IF NOT (NEW.data_inicio > CURRENT_DATE) THEN
            RAISE EXCEPTION 'operacao invalida: manutencao agendada deve ter começo depois de hoje';
        END IF;
    

    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

--trg chamar funcao de checagem de data de mantuençao
DROP TRIGGER IF EXISTS trg_check_data_manut on manutencao;
CREATE TRIGGER trg_check_data_manut
BEFORE INSERT OR UPDATE on manutencao
for each row execute function fn_check_data_manut();



-- MDOULO DA TABELA DE LEITURA
-- funcao que calcula a media das leituras de um equipamento num periodo
-- retorna a media. se nao teve leitura no periodo retorna NULL
-- sem sensor faz a media de todos, mesmo que seja um pouco incondizente com as variaveis de unidade
-- com sensor é media so dele

CREATE OR REPLACE FUNCTION fn_media_leitura_equip( p_id_equipamento INTEGER, inicio_procura TIMESTAMP, fim_procura TIMESTAMP, p_id_sensor INTEGER DEFAULT NULL) RETURNS INTEGER
AS $$
DECLARE
    media NUMERIC;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipamento WHERE id_equipamento = p_id_equipamento) THEN
        RAISE EXCEPTION 'operacao invalida: equipamento nao existe';
    END IF;

    IF inicio_procura >= fim_procura THEN
        RAISE EXCEPTION 'operacao invalida: inicio do periodo deve ser antes do fim';
    END IF;

    SELECT AVG(valor) INTO media FROM leitura WHERE id_equipamento = p_id_equipamento
    AND data_hora >= inicio_procura AND data_hora <fim_procura AND (p_id_sensor IS NULL OR id_sensor = p_id_sensor);

    IF media IS NULL THEN
        RAISE NOTICE 'equipamento com zero leituras no periodo';
        RETURN NULL;
    END IF;

    RETURN media;
END;
$$ LANGUAGE plpgsql;

-- funcao que verifica o valor da leitura contra os limites do sensor
-- retorna a flag: 1 = fora dos limites (gera alerta), 0 = dentro
-- obs: no rascunho era raise exception, mas exception cancela o INSERT da leitura
-- e o alerta nunca ia ser gerado, entao virou raise notice + flag

CREATE OR REPLACE FUNCTION fn_verifica_leitura(l_id_sensor INTEGER, l_valor NUMERIC)
RETURNS INTEGER
AS $$
BEGIN
    SELECT limite_inferior, limite_superior FROM sensor WHERE id_sensor = l_id_sensor;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'operacao invalida: sensor % nao existe', l_id_sensor;
    END IF;

    IF l_valor < limite_inferior THEN
        RAISE NOTICE 'erro: valor abaixo do limite(% < %)', l_valor, limite_inferior;
        RETURN 1;
    ELSIF l_valor > limite_superior THEN
        RAISE NOTICE 'erro: valor acima do limite (% > %)', l_valor, limite_superior;
        RETURN 1;
    ELSE
        RETURN 0; -- tudo ok
    END IF;
END;
$$ LANGUAGE plpgsql;



-- funcao que define a qualidade da leitura
--   escolhemos uma faixa = de 0,85*media ate 1,15*media para trabalhar a definicao de qualidade
--   media é a media dos limites = (limite_sup + limite_inf) / 2
-- estavel é valor dentro da faixa de 15prct em volta da media dos limites, prox do centro
-- fora da faixa é instavel, ja que estaria longe do centro
-- least/greatest pra faixa nao inverter se a media for negativa.


CREATE OR REPLACE FUNCTION fn_check_qualidade_leitura() RETURNS TRIGGER
AS $$
DECLARE
    media_limites NUMERIC(5,2);
    menor NUMERIC(5,2); -- menor_desvio_limites
    maior NUMERIC(5,2); -- maior_desvio_limites
BEGIN
    SELECT limite_inferior, limite_superior FROM sensor WHERE id_sensor = NEW.id_sensor;

    IF NOT FOUND THEN
        raise exception 'operacao invalida: nao tem sensor';
    END IF;

    media_limites = (limite_superior + limite_inferior) / 2;
    menor = (0.85 * media_limites);
    maior = (1.15 * media_limites);

    IF ((NEW.valor >= menor) AND (NEW.valor <= maior)) THEN
        NEW.qualidade = 'estavel';
    ELSE
        NEW.qualidade = 'instavel';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--trg que checka os status de qualidade da leitura
DROP TRIGGER IF EXISTS trg_check_qualidade_leitura on leitura;
CREATE TRIGGER trg_check_qualidade_leitura
BEFORE INSERT on leitura
for each row execute function fn_check_qualidade_leitura();




-- ####################################################################
-- # 4. ALERTA
-- # status: 'alerta' (flag 1) ou 'ok' (flag 0)
-- # severidade: critica, alta, media, baixa ou nula (dentro dos limites)
-- ####################################################################

-- funcao que converte a flag da fn_verifica_leitura no status do alerta
CREATE OR REPLACE FUNCTION fn_check_status_alerta(flag_verifica_leitura INTEGER) RETURNS VARCHAR
AS $$
BEGIN
    IF flag_verifica_leitura = 1 THEN RETURN 'alerta';
    ELSE RETURN 'ok';
    END IF;
END;
$$ LANGUAGE plpgsql;



-- funcao que gera o alerta depois de inserir a leitura
-- e AFTER INSERT pq o alerta tem FK pra leitura, a leitura precisa existir antes
-- toda leitura gera uma linha em alerta: 'alerta' se fora dos limites, 'ok' (severidade nula) se dentro.
-- se quiser so alerta de verdade, e so envolver o INSERT num IF v_flag = 1
CREATE OR REPLACE FUNCTION fn_gera_alerta() RETURNS TRIGGER
AS $$
DECLARE
    v_flag INTEGER;
    v_status alerta.status%TYPE;
    v_severidade alerta.severidade%TYPE;
    v_descricao alerta.descricao%TYPE;
    v_tag sensor.tag%TYPE;
    v_inf sensor.limite_inferior%TYPE;
    v_sup sensor.limite_superior%TYPE;
BEGIN
    v_flag := fn_verifica_leitura(NEW.id_sensor, NEW.valor);
    v_status := fn_check_status_alerta(v_flag);
    v_severidade := fn_check_severidade_alerta(NEW.id_sensor, NEW.valor);

    SELECT tag, limite_inferior, limite_superior into v_tag, v_inf, v_sup
    FROM sensor WHERE id_sensor = NEW.id_sensor;

    IF v_flag = 1 THEN
        v_descricao := format('sensor %s: valor %s fora dos limites [%s, %s]',
                              v_tag, NEW.valor, v_inf, v_sup);
    ELSE
        v_descricao := format('sensor %s: valor %s dentro dos limites [%s, %s]',
                              v_tag, NEW.valor, v_inf, v_sup);
    END IF;

    INSERT into alerta (data_hora, severidade, descricao, status, id_leitura)
    values (NEW.data_hora, v_severidade, v_descricao, v_status, NEW.id_leitura);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gera_alerta on leitura;
CREATE TRIGGER trg_gera_alerta
AFTER INSERT ON leitura ----depois da leitura que tem que fazer, tem q ter leitura antes
for each row execute function fn_gera_alerta();


-- funcao que calcula a severidade a partir de quanto o valor passou do limite
--   acima:  critica >= 1,25*ls 
-- alta [1,10; 1,25[ 
-- media [1,03; 1,1[
 --  baixa > ls
--   abaixo: critica <= 0,75*li | alta <= 0,90*li | media <= 0,97*li | baixa < li
--   dentro dos limites: nula
-- obs: percentuais assumem limites positivos. com limite negativo ou zero
-- (ex: sensor de -10 a 0) a conta multiplicativa nao funciona direito.
CREATE OR REPLACE FUNCTION fn_check_severidade_alerta(p_id_sensor INTEGER, p_valor NUMERIC)
RETURNS VARCHAR
AS $$

BEGIN
    SELECT limite_inferior, limite_superior FROM sensor WHERE id_sensor = p_id_sensor;

    IF NOT FOUND THEN
        raise exception 'operacao invalida: sensor % nao existe', p_id_sensor;
    END IF;

    IF p_valor >= limite_inferior AND p_valor <= limite_superior THEN
        RETURN 'nula';
    END IF;

    IF p_valor > limite_superior THEN
        IF p_valor >= 1.25 * limite_superior THEN RETURN 'critica';
        ELSIF p_valor >= 1.10 * limite_superior THEN RETURN 'alta';
        ELSIF p_valor >= 1.03 * limite_superior THEN RETURN 'media';
        ELSE
            RETURN 'baixa';
    
        END IF;
    ELSE
        IF p_valor <= 0.75 * limite_inferior THEN RETURN 'critica';
        ELSIF p_valor <= 0.90 * limite_inferior THEN RETURN 'alta';
        ELSIF p_valor <= 0.97 * limite_inferior THEN RETURN 'media';
        ELSE
            RETURN 'baixa';
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

--==========