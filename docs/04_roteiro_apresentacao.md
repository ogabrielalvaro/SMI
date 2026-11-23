# Roteiro da Parte 1 e perguntas prováveis

Este arquivo é para estudo do grupo antes da apresentação. Não faz parte do
relatório.

## Ordem sugerida para explicar a Parte 1 (uns 5 a 8 minutos)

1. **Domínio.** Indústria com duas plantas, equipamentos com sensores, leituras
   a cada hora, alertas quando passa do limite, manutenções com técnicos.
2. **DER.** Partimos do diagrama do professor (11 entidades). Mudamos duas
   coisas: tiramos `id_equipamento` da leitura e criamos `manutencao_tecnico`
   para o N:N. Saber explicar o porquê das duas é o ponto mais importante.
3. **Modelo lógico e 3FN.** Regras de mapeamento e a dependência transitiva
   `leitura → sensor → equipamento`.
4. **Schema físico.** Sequences, PK/FK, CHECK, UNIQUE, índices.
5. **Dados.** Leituras de 09 a 15/11/2026, uma por hora por sensor, mais casos
   forçados fora do limite para gerar alertas.

## Demonstração rápida (se pedirem pra rodar)

```bash
createdb industrial
psql -d industrial -v ON_ERROR_STOP=1 -f sql/01_schema.sql
psql -d industrial -v ON_ERROR_STOP=1 -f sql/02_dados.sql
```

No final o script mostra a contagem por tabela: 2 plantas, 4 linhas,
9 equipamentos, 16 sensores, 2.424 leituras, 12 alertas, 6 técnicos,
9 manutenções e 14 vínculos manutenção/técnico.

Para mostrar que as restrições funcionam, estes comandos devem **falhar**:

```sql
-- limite inferior maior que o superior
INSERT INTO sensor (tag, limite_inferior, limite_superior, id_equipamento, id_tipo_sensor, id_unidade)
VALUES ('XX-1', 50, 10, 1, 1, 1);
-- ERROR: new row for relation "sensor" violates check constraint "ck_sensor_limites"

-- duas leituras do mesmo sensor no mesmo instante
INSERT INTO leitura (data_hora, valor, id_sensor) VALUES ('2026-11-09 00:00', 1, 1);
-- ERROR: duplicate key value violates unique constraint "uq_leitura_sensor_hora"

-- apagar um sensor que já tem leituras
DELETE FROM sensor WHERE tag = 'TT-101';
-- ERROR: update or delete on table "sensor" violates foreign key constraint "leitura_id_sensor_fkey" on table "leitura"

-- status que não existe
INSERT INTO equipamento (tag, nome, data_instalacao, status, id_linha)
VALUES ('ZZ-1', 'teste', '2026-01-01', 'quebrado', 1);
-- ERROR: new row for relation "equipamento" violates check constraint "ck_equipamento_status"

-- manutenção concluída sem data de fim
INSERT INTO manutencao (data_inicio, descricao, status, id_equipamento, id_tipo_manutencao)
VALUES ('2026-11-01', 'x', 'concluida', 1, 1);
-- ERROR: new row for relation "manutencao" violates check constraint "ck_manutencao_concluida"
```

Consulta boa para mostrar o resultado do modelo (junta quase tudo):

```sql
SELECT p.nome AS planta, e.tag AS equipamento, s.tag AS sensor,
       l.data_hora, l.valor, u.sigla, a.severidade, a.status
FROM alerta a
JOIN leitura l         ON l.id_leitura = a.id_leitura
JOIN sensor s          ON s.id_sensor = l.id_sensor
JOIN unidade_medida u  ON u.id_unidade = s.id_unidade
JOIN equipamento e     ON e.id_equipamento = s.id_equipamento
JOIN linha_producao lp ON lp.id_linha = e.id_linha
JOIN planta p          ON p.id_planta = lp.id_planta
ORDER BY l.data_hora;
```

## Perguntas que podem aparecer

**Por que sequence criada à mão e não `SERIAL`?**
`SERIAL` cria a sequence escondida. Como o enunciado pede sequences, preferimos
declarar cada uma (`CREATE SEQUENCE`), usar no `DEFAULT nextval(...)` e ligar
à coluna com `OWNED BY`. O resultado é o mesmo do `SERIAL`, só que visível. A
alternativa moderna seria `GENERATED ALWAYS AS IDENTITY`.

**Por que `numeric` e não `float` para o valor da leitura?**
`float` guarda aproximação binária, então comparar `valor > limite_superior`
pode dar errado em casos de borda (0.1 + 0.2 não é exatamente 0.3). `numeric`
é exato. Perdemos um pouco de velocidade, mas aqui a exatidão da comparação
com o limite é o ponto central do sistema.

**Por que `timestamp` e não `timestamptz`?**
Todos os sensores estão no mesmo fuso (Minas Gerais), então guardar o fuso não
traria nada. Se houvesse plantas em países diferentes, o correto seria
`timestamptz`.

**Por que tirou `id_equipamento` da tabela `leitura`?**
Porque o sensor já sabe de qual equipamento é. Guardar nos dois lugares
quebra a 3FN (dependência transitiva) e permite inconsistência: uma leitura
do sensor do motor apontando para a bomba. Para saber o equipamento, faz-se
join `leitura → sensor → equipamento`.

**Por que criou `manutencao_tecnico`?**
Uma manutenção pode ter mais de um técnico, e um técnico participa de várias.
É um N:N, e no modelo relacional N:N exige uma tabela no meio. Sem ela
teríamos que repetir a manutenção ou criar colunas `tecnico1`, `tecnico2`.

**Qual a chave primária de `manutencao_tecnico`?**
A combinação (`id_manutencao`, `id_tecnico`). Isso impede o mesmo técnico
duas vezes na mesma manutenção.

**Por que `UNIQUE (id_sensor, data_hora)` na leitura?**
Para um sensor não ter duas leituras no mesmo instante (envio duplicado). Ele
também serve de índice para as consultas "leituras do sensor X no período Y".

**O PostgreSQL já cria índice nas chaves estrangeiras?**
Não. Ele cria índice automático para PK e UNIQUE, mas não para FK. Por isso
criamos os índices das FKs (`idx_sensor_equipamento` etc.), que ajudam nos
joins e no `DELETE` da tabela pai.

**O que é o índice parcial `idx_alerta_abertos`?**
É um índice só das linhas com `status = 'aberto'`. Alerta aberto é a minoria e
é o que o operador consulta toda hora, então o índice fica pequeno e rápido.
Com poucos dados (12 alertas) o PostgreSQL ignora o índice e faz leitura
sequencial, o que é normal: ele só compensa em tabela grande.

**E se a tabela `leitura` ficar gigante?**
Um sensor mandando uma leitura por segundo gera 86 mil linhas por dia. Para
esse caso, o caminho é particionar `leitura` por faixa de data
(`PARTITION BY RANGE (data_hora)`) ou usar um índice BRIN em `data_hora`, que é
bem menor que o B-tree quando os dados entram em ordem cronológica. Não
fizemos porque o volume do trabalho não justifica.

**Por que `CHECK` e não `ENUM` ou tabela de status?**
Os valores são poucos e fixos. `ENUM` é difícil de alterar depois (não dá
para remover valor) e uma tabela de domínio para cada lista seria burocracia.
Com `CHECK` basta um `ALTER TABLE` para mudar a lista.

**O que acontece se apagar um equipamento?**
O banco recusa se ele ainda tiver sensores ou manutenções (FK padrão, sem
`CASCADE`). Quisemos proteger o histórico. A única FK com `ON DELETE CASCADE`
é a de `manutencao_tecnico.id_manutencao`: apagar uma manutenção apaga os
vínculos dela.

**O modelo está em BCNF?**
Sim: nas tabelas com mais de uma chave candidata (`sensor`, `equipamento`,
`leitura`), todo determinante é chave candidata.

**Tem alguma dependência que fique na dúvida na 3FN?**
`equipamento.modelo → fabricante` seria transitiva se cada modelo pertencesse
a um fabricante só. Consideramos os dois como descrição do equipamento. Se
fosse necessário, dá para separar em uma tabela `modelo_equipamento`.

**Onde ficam os alertas automáticos?**
Na Parte 2: um trigger na tabela `leitura` que compara o valor com os limites
do sensor e insere em `alerta`. Os 12 alertas que já estão nos dados de
exemplo foram gerados por um `INSERT ... SELECT` que aplica a mesma regra nas
leituras forçadas fora do limite, como ponto de partida.

**Como a severidade dos alertas foi decidida nos dados de exemplo?**
Pelo quanto o valor passou do limite, em relação à largura da faixa do sensor:
mais de 25% é crítica, mais de 10% é alta, mais de 3% é média e o resto é
baixa. A Parte 2 pode usar a mesma regra no trigger para ficar coerente.

**Por que os dados têm `setseed`?**
Para o ruído aleatório das leituras ser sempre o mesmo. Assim os três do grupo
(e o professor) rodam o script e chegam nos mesmos números.
