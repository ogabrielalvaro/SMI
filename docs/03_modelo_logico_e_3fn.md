# Modelo lógico e normalização

## Do DER para o modelo relacional

O que seguimos:

1. Cada entidade virou uma tabela, e o identificador virou a chave primária.
2. Cada relacionamento 1:N virou uma chave estrangeira na tabela do lado N.
3. Não tem atributo multivalorado nem composto no DER, então não foi preciso
   separar nada.

Legenda: `*` é chave primária e `#` é chave estrangeira.

```
planta          (*id_planta, nome, localizacao, responsavel)

linha_producao  (*id_linha, nome, descricao, #id_planta)

equipamento     (*id_equipamento, tag, nome, fabricante, modelo,
                 data_instalacao, status, #id_linha)

tipo_sensor     (*id_tipo_sensor, nome, descricao)

unidade_medida  (*id_unidade, sigla, descricao)

sensor          (*id_sensor, tag, descricao, limite_inferior, limite_superior,
                 #id_equipamento, #id_tipo_sensor, #id_unidade)

leitura         (*id_leitura, data_hora, valor, qualidade,
                 #id_sensor, #id_equipamento)

alerta          (*id_alerta, data_hora, severidade, descricao, status,
                 #id_leitura)

tecnico         (*id_tecnico, nome, especialidade, contato)

tipo_manutencao (*id_tipo_manutencao, nome, descricao)

manutencao      (*id_manutencao, data_inicio, data_fim, descricao, status,
                 #id_equipamento, #id_tecnico, #id_tipo_manutencao)
```

Além da chave primária, algumas tabelas têm outras colunas que não repetem
(viraram `UNIQUE`): `planta.nome`, `equipamento.tag`, `sensor.tag`,
`tipo_sensor.nome`, `unidade_medida.sigla`, `tipo_manutencao.nome`,
`(linha_producao.id_planta, nome)` e `(leitura.id_sensor, data_hora)`.

## Normalização

### 1FN

Todas as colunas guardam um valor só, sem lista dentro de uma célula e sem
colunas repetidas (por exemplo, não existe `sensor1`, `sensor2` no
equipamento). Toda tabela tem chave primária. Está em 1FN.

### 2FN

Todas as tabelas têm chave primária de uma coluna só (`id_...`), então nenhum
atributo pode depender de só uma parte da chave. Está em 2FN. A única
observação é a da `leitura`, explicada mais abaixo.

### 3FN

Aqui a pergunta é se algum atributo que não é chave depende de outro atributo
que também não é chave. Tabela por tabela:

- **planta, tipo_sensor, unidade_medida, tecnico, tipo_manutencao:** só têm
  atributos que dependem da própria chave.
- **linha_producao, equipamento, sensor, manutencao, alerta:** quando
  precisam de dado de outra tabela, guardam só a chave estrangeira. O nome da
  planta, por exemplo, não é copiado para a linha: se precisar, faz join.
- **leitura:** tem um ponto de atenção, explicado a seguir.

## O caso da `leitura.id_equipamento`

No DER do professor a `leitura` tem `id_sensor` e `id_equipamento`. Só que
cada sensor está em um equipamento (`sensor.id_equipamento`). Então, se o
sensor nunca muda de equipamento, vale:

```
id_leitura -> id_sensor -> id_equipamento
```

ou seja, o equipamento da leitura dá pra descobrir pelo sensor. Isso é uma
dependência transitiva e, na leitura estrita, **fere a 3FN**.

Mesmo assim mantivemos a coluna, pelos seguintes motivos:

1. O DER do professor tem a coluna e o relacionamento "equipamento registra
   leitura", e a ideia foi não mexer no desenho dele.
2. Ela guarda o equipamento onde a leitura foi **registrada**. Se um sensor for
   trocado de equipamento no futuro, `sensor.id_equipamento` passa a mostrar
   só onde ele está agora, e as leituras antigas continuariam apontando para o
   equipamento onde foram feitas. Nesse caso o dado não dá pra deduzir só pelo
   sensor.
3. Dá pra consultar as leituras de um equipamento sem passar pela tabela
   `sensor` (tem o índice `idx_leitura_equipamento` para isso).

O risco é gravar uma leitura com o equipamento errado (de um sensor do motor
com o `id_equipamento` da bomba, por exemplo). Nos dados de exemplo o
`id_equipamento` da leitura é sempre o mesmo do sensor, e uma conferência
simples mostra que não há nenhum diferente. Uma forma de proteger isso é um
trigger `BEFORE INSERT` na leitura que preenche o `id_equipamento` a partir do
sensor, que dá pra fazer na Parte 2.

Fora esse ponto, as demais tabelas estão em 3FN.

## Outros pontos em que podem perguntar

- **`equipamento.modelo` e `equipamento.fabricante`:** se cada modelo existisse
  para um fabricante só, o fabricante dependeria do modelo, e seria outra
  dependência transitiva. Tratamos os dois como descrição do equipamento
  porque o mesmo nome de modelo pode aparecer em fabricantes diferentes. Se
  precisar, dá pra criar uma tabela `modelo_equipamento`.
- **`tecnico.especialidade`:** o valor se repete (vários técnicos de
  "Mecânica"), mas isso não é problema de normalização: nenhum outro atributo
  depende da especialidade.
- **`status`, `severidade`, `qualidade`:** usamos `CHECK` com a lista de
  valores, em vez de uma tabela para cada um. São poucos valores, fixos e sem
  atributos próprios.
- **Mais de um técnico por manutenção:** no DER cada manutenção tem um técnico
  só. Para ter mais de um seria preciso uma tabela associativa
  `manutencao_tecnico (id_manutencao, id_tecnico)`, que é o N:N.

## Desnormalização

Fora a `leitura.id_equipamento`, não desnormalizamos nada. Se a tabela de
leituras ficar muito grande, o caminho seria particionar por data ou usar
índice BRIN em `data_hora`, e não repetir dados.
