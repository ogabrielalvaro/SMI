# Modelo lógico e normalização

## Passagem do DER para o modelo relacional

Regras usadas:

1. Toda entidade vira uma tabela, e o identificador dela vira a chave primária.
2. Todo relacionamento 1:N vira uma chave estrangeira na tabela do lado N.
3. Todo relacionamento N:N vira uma tabela própria, com as duas chaves
   estrangeiras formando a chave primária composta.
4. Atributos de uma entidade viram colunas da própria tabela. Não há atributos
   multivalorados nem compostos no DER, então nada precisou ser desmembrado.

Notação: `*` marca a chave primária e `#` marca a chave estrangeira.

## Esquema relacional

```
planta              (*id_planta, nome, localizacao, responsavel)

linha_producao      (*id_linha, nome, descricao, #id_planta)

equipamento         (*id_equipamento, tag, nome, fabricante, modelo,
                     data_instalacao, status, #id_linha)

tipo_sensor         (*id_tipo_sensor, nome, descricao)

unidade_medida      (*id_unidade, sigla, descricao)

sensor              (*id_sensor, tag, descricao, limite_inferior,
                     limite_superior, #id_equipamento, #id_tipo_sensor,
                     #id_unidade)

leitura             (*id_leitura, data_hora, valor, qualidade, #id_sensor)

alerta              (*id_alerta, data_hora, severidade, descricao, status,
                     #id_leitura)

tecnico             (*id_tecnico, nome, especialidade, contato)

tipo_manutencao     (*id_tipo_manutencao, nome, descricao)

manutencao          (*id_manutencao, data_inicio, data_fim, descricao,
                     status, #id_equipamento, #id_tipo_manutencao)

manutencao_tecnico  (*#id_manutencao, *#id_tecnico)
```

Chaves candidatas além da primária (viraram `UNIQUE`): `planta.nome`,
`equipamento.tag`, `sensor.tag`, `tipo_sensor.nome`, `unidade_medida.sigla`,
`tipo_manutencao.nome`, `(linha_producao.id_planta, nome)` e
`(leitura.id_sensor, data_hora)`.

## Normalização

### 1ª forma normal (1FN)

Todas as colunas guardam um valor só, sem listas dentro de uma célula e sem
grupos repetidos. Por exemplo, a manutenção não tem uma coluna "técnicos" com
vários nomes: isso virou a tabela `manutencao_tecnico`. Cada tabela também tem
chave primária definida. Está em 1FN.

### 2ª forma normal (2FN)

A 2FN só pode ser violada em tabelas com chave composta. A única que tem é
`manutencao_tecnico`, e ela não possui atributos além das duas colunas da
chave, então não há o que depender só de uma parte dela. Nas demais, a chave
primária é um atributo só (`id_*`), e nesse caso a 2FN vale automaticamente.
Está em 2FN.

### 3ª forma normal (3FN)

A pergunta aqui é: algum atributo que não é chave depende de outro atributo
que também não é chave? Passando tabela por tabela:

| Tabela | Dependências | 3FN? |
|--------|--------------|------|
| planta | Tudo depende de `id_planta` | Sim |
| linha_producao | Nome e descrição dependem da linha. A planta é referenciada só pelo `id_planta`, sem repetir nome ou localização | Sim |
| equipamento | Idem. Linha e planta são alcançadas por join, não copiadas | Sim, com a ressalva abaixo |
| sensor | Tipo e unidade só entram como FK, sem copiar nome ou sigla | Sim |
| leitura | Valor, hora e qualidade dependem da leitura. Equipamento é descoberto pelo sensor | Sim, depois do ajuste abaixo |
| alerta | Depende só da leitura que o disparou | Sim |
| manutencao | Equipamento e tipo entram por FK | Sim |
| tecnico, tipo_*, unidade_medida | Tabelas pequenas, tudo depende da chave | Sim |

### O ajuste que fizemos: `leitura.id_equipamento`

No DER de referência a tabela `leitura` tinha `id_sensor` **e**
`id_equipamento`. Só que:

```
id_leitura  →  id_sensor        (cada leitura é de um sensor)
id_sensor   →  id_equipamento   (cada sensor está em um equipamento)
```

Logo `id_leitura → id_equipamento` passando por `id_sensor`. Isso é uma
**dependência transitiva**: o atributo `id_equipamento` não depende diretamente
da chave da leitura, depende do `id_sensor`, que também não é chave da tabela.
É exatamente o que a 3FN proíbe.

Além da teoria, tem um problema prático. Se a coluna ficasse, nada impediria
alguém de gravar uma leitura do sensor `TT-101` (que fica no motor `MOT-101`)
com `id_equipamento` apontando para a bomba `BOM-102`. O banco aceitaria e os
relatórios por equipamento passariam a dar resultados diferentes dependendo do
caminho (`leitura → equipamento` ou `leitura → sensor → equipamento`).

Removendo a coluna, o equipamento de uma leitura sempre é obtido pelo join:

```sql
SELECT e.tag, l.data_hora, l.valor
FROM leitura l
JOIN sensor s       ON s.id_sensor = l.id_sensor
JOIN equipamento e  ON e.id_equipamento = s.id_equipamento;
```

O custo é um join a mais, que é barato porque `sensor` é pequena e a coluna
`id_sensor` está indexada.

### O outro ajuste: manutenção e técnico

Se `manutencao` guardasse `id_tecnico` direto (como no DER original), cada
manutenção teria um técnico só. Para registrar dois técnicos, só haveria duas
saídas ruins: repetir a manutenção inteira (descrição, datas, equipamento) em
duas linhas, ou criar `id_tecnico1`, `id_tecnico2`, que fere a 1FN. A tabela
`manutencao_tecnico` resolve sem repetir nada.

## Pontos que podemos ser questionados

Estes casos estão em 3FN do jeito que o modelo foi desenhado, mas dependem de
uma hipótese que vale a pena saber explicar:

- **`equipamento.modelo` e `equipamento.fabricante`.** Se cada modelo
  existisse para um fabricante só, teríamos `modelo → fabricante`, outra
  dependência transitiva. Tratamos os dois como atributos descritivos do
  equipamento porque um nome de modelo pode se repetir entre fabricantes
  diferentes. Se o grupo preferir, dá para criar uma tabela
  `modelo_equipamento (id_modelo, fabricante, modelo)`.
- **`tecnico.especialidade`.** Aparece repetida (vários técnicos de
  "Mecânica"), mas repetir um valor não é violação: nenhum outro atributo
  depende da especialidade. Só viraria tabela se ela tivesse atributos
  próprios.
- **`status`, `severidade`, `qualidade`.** Usamos `CHECK` com lista fixa em vez
  de tabelas de domínio. Os valores são poucos, não têm atributos próprios e
  não mudam. A normalização continua válida.
- **BCNF.** Nas tabelas com mais de uma chave candidata (`sensor`, `equipamento`,
  `leitura`), todo determinante é chave candidata, então o modelo também
  satisfaz a Forma Normal de Boyce-Codd.

## Desnormalização: usamos alguma?

Não. Todas as tabelas respeitam a 3FN. Se o volume de `leitura` crescer
muito, a otimização indicada não seria desnormalizar e sim particionar a
tabela por data ou usar índice BRIN em `data_hora`. Isso está citado em
`04_roteiro_apresentacao.md`.
