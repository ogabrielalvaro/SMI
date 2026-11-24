# Roteiro da Parte 1 e perguntas prováveis

Arquivo de estudo do grupo, não faz parte do relatório.

## Como explicar a Parte 1 (uns 5 minutos)

1. **O domínio.** Indústria com duas plantas, equipamentos com sensores, uma
   leitura por hora, alerta quando passa do limite e manutenção com técnico.
2. **O DER.** É o do professor, sem mudança: 11 entidades, todas as relações
   1:N.
3. **Modelo lógico.** Cada entidade vira tabela, cada 1:N vira FK no lado N.
4. **3FN.** Tudo em 3FN, menos a `leitura.id_equipamento`, que é a exceção
   consciente (explicada no `03_modelo_logico_e_3fn.md`). **Esse é o ponto
   mais provável de pergunta.**
5. **Schema.** Sequences, PK/FK, CHECK, UNIQUE, índices.
6. **Dados.** Leituras de 09 a 15/11/2026, uma por hora por sensor, mais alguns
   valores fora do limite pra gerar alerta.

## Para mostrar rodando

```bash
createdb industrial
psql -d industrial -v ON_ERROR_STOP=1 -f sql/01_schema.sql
psql -d industrial -v ON_ERROR_STOP=1 -f sql/02_dados.sql
```

No final aparece a contagem por tabela: 2 plantas, 4 linhas, 9 equipamentos,
16 sensores, 2.424 leituras, 12 alertas, 6 técnicos e 9 manutenções.

Comandos que devem **dar erro** (pra mostrar as restrições):

```sql
-- limite inferior maior que o superior
insert into sensor (tag, limite_inferior, limite_superior, id_equipamento, id_tipo_sensor, id_unidade)
values ('XX-1', 50, 10, 1, 1, 1);
-- viola a check constraint "ck_sensor_limites"

-- duas leituras do mesmo sensor no mesmo horário
insert into leitura (data_hora, valor, id_sensor, id_equipamento)
values ('2026-11-09 00:00', 1, 1, 1);
-- viola a unique "uq_leitura_sensor_hora"

-- apagar sensor que já tem leituras
delete from sensor where tag = 'TT-101';
-- viola a foreign key "leitura_id_sensor_fkey"

-- status que não existe
insert into equipamento (tag, nome, data_instalacao, status, id_linha)
values ('ZZ-1', 'teste', '2026-01-01', 'quebrado', 1);
-- viola a check constraint "ck_equipamento_status"

-- manutenção concluída sem data de fim
insert into manutencao (data_inicio, descricao, status, id_equipamento, id_tecnico, id_tipo_manutencao)
values ('2026-11-01', 'x', 'concluida', 1, 1, 1);
-- viola a check constraint "ck_manutencao_concluida"
```

Uma consulta boa pra mostrar (junta bastante coisa):

```sql
select p.nome as planta, e.tag as equipamento, s.tag as sensor,
       l.data_hora, l.valor, u.sigla, a.severidade, a.status
from alerta a
join leitura l on l.id_leitura = a.id_leitura
join sensor s on s.id_sensor = l.id_sensor
join unidade_medida u on u.id_unidade = s.id_unidade
join equipamento e on e.id_equipamento = l.id_equipamento
join linha_producao lp on lp.id_linha = e.id_linha
join planta p on p.id_planta = lp.id_planta
order by l.data_hora;
```

## Perguntas que podem aparecer

**A leitura guarda o sensor e o equipamento. Isso não é redundante? Fere a 3FN?**
Se o sensor nunca muda de equipamento, é sim, e na leitura estrita fere a 3FN.
Mantivemos porque o DER do professor tem a coluna e porque ela registra o
equipamento onde a leitura foi feita: se o sensor mudar de equipamento no
futuro, as leituras antigas continuam apontando para o equipamento certo.
Reconhecemos que existe risco de inconsistência e que um trigger resolve (na
Parte 2).

**Por que sequence criada à mão e não SERIAL?**
O enunciado pede sequences. O `SERIAL` cria uma escondida, e aqui declaramos
cada uma com `CREATE SEQUENCE` e usamos no `DEFAULT nextval(...)`. Funciona do
mesmo jeito.

**Por que `numeric` e não `float` no valor da leitura?**
Porque a gente compara o valor com o limite, e o `float` guarda uma
aproximação (0.1 + 0.2 não dá exatamente 0.3). O `numeric` é exato.

**Por que `timestamp` e não `timestamptz`?**
Todos os sensores estão no mesmo fuso. Se tivesse planta em outro país, seria
`timestamptz`.

**Por que `UNIQUE (id_sensor, data_hora)` na leitura?**
Pra um sensor não ter duas leituras no mesmo instante (envio duplicado). Esse
UNIQUE também cria um índice que ajuda nas consultas por sensor e período.

**O PostgreSQL cria índice nas chaves estrangeiras?**
Não. Cria só para PK e UNIQUE. Por isso criamos os índices das FKs.

**O que é o índice parcial `idx_alerta_abertos`?**
É um índice só das linhas com `status = 'aberto'`. Alerta aberto é a minoria e
é o que mais se consulta, então o índice fica pequeno. Com 12 alertas o
PostgreSQL nem usa, faz leitura sequencial, o que é normal em tabela
pequena.

**E se a tabela de leituras ficar muito grande?**
Um sensor mandando uma leitura por segundo gera 86 mil linhas por dia. Nesse
caso o certo seria particionar por data (`PARTITION BY RANGE (data_hora)`) ou
usar índice BRIN em `data_hora`. Não fizemos porque o volume do trabalho não
justifica.

**Por que `CHECK` e não `ENUM` ou uma tabela de status?**
Os valores são poucos e fixos. Com `CHECK`, mudar a lista é só um `ALTER TABLE`.
No `ENUM` não dá pra remover valor depois.

**O que acontece se apagar um equipamento?**
O banco não deixa se ele ainda tiver sensores, leituras ou manutenções. As
FKs são as padrão, sem `CASCADE`, pra proteger o histórico.

**Cadê o N:N que o enunciado fala?**
No DER do professor todas as relações são 1:N, e o enunciado só pede a
"possibilidade" de N:N. O caso natural é técnico e manutenção, se uma
manutenção precisar de mais de um técnico: aí entra a tabela
`manutencao_tecnico`.

**Onde ficam os alertas automáticos?**
Na Parte 2, num trigger na tabela `leitura` que compara o valor com os limites
do sensor e insere em `alerta`. Os 12 alertas dos dados de exemplo foram
gerados por um `INSERT ... SELECT` com a mesma regra.

**Como foi decidida a severidade nos dados de exemplo?**
Pelo quanto o valor passou do limite, comparado com a largura da faixa do
sensor: mais de 25% é crítica, mais de 10% é alta, mais de 3% é média, o resto
é baixa.

**Por que os dados têm `setseed`?**
Pra o aleatório ser sempre o mesmo. Assim todo mundo roda e chega nos mesmos
números.

**Por que o SQL está sem acento?**
Pra não dar problema de codificação no `psql` do Windows.
