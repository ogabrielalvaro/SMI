# Modelo conceitual (DER)

## Do que se trata

O SMI guarda as leituras dos sensores de uma indústria. Cada sensor está num
equipamento e tem um limite mínimo e um máximo. Quando uma leitura passa do
limite, o sistema registra um alerta. O banco também guarda as manutenções
feitas nos equipamentos e o técnico responsável por cada uma.

Para os dados de exemplo inventamos uma indústria com duas plantas em Minas
Gerais, com motores, bombas, compressores, fornos e um ventilador. Os sensores
medem temperatura, vibração, pressão, corrente e vazão.

## Base

O DER é o que o professor passou no enunciado, sem mudar entidade, atributo
nem relacionamento. São 11 entidades.

## Entidades

| Entidade | O que é |
|----------|---------|
| planta | Fábrica |
| linha_producao | Linha dentro de uma planta |
| equipamento | Máquina de uma linha |
| sensor | Instrumento que mede alguma coisa de um equipamento |
| tipo_sensor | Temperatura, vibração, pressão... |
| unidade_medida | °C, bar, A... |
| leitura | Uma medição de um sensor |
| alerta | Aviso de leitura fora do limite |
| manutencao | Serviço feito (ou agendado) em um equipamento |
| tipo_manutencao | Preventiva, corretiva, preditiva ou inspeção |
| tecnico | Quem faz a manutenção |

## Relacionamentos

Todos são 1:N (o "1" é a tabela de cima, o "N" a de baixo):

| 1 | N | Relacionamento |
|---|---|----------------|
| planta | linha_producao | possui |
| linha_producao | equipamento | contém |
| equipamento | sensor | é monitorado por |
| tipo_sensor | sensor | classifica |
| unidade_medida | sensor | é usada por |
| sensor | leitura | gera |
| equipamento | leitura | registra |
| leitura | alerta | dispara |
| equipamento | manutencao | sofre |
| tecnico | manutencao | executa |
| tipo_manutencao | manutencao | classifica |

Sobre o N:N que o enunciado menciona ("possibilidade de N:N"): no DER como
está, cada manutenção tem um técnico só. Se um dia for preciso mais de um
técnico por manutenção, a relação vira N:N e entra uma tabela no meio, algo
como `manutencao_tecnico (id_manutencao, id_tecnico)`. Deixamos fora porque o
DER do professor não tem.

## Diagrama

O Mermaid aparece desenhado direto no GitHub.

```mermaid
erDiagram
    PLANTA ||--o{ LINHA_PRODUCAO : possui
    LINHA_PRODUCAO ||--o{ EQUIPAMENTO : contem
    EQUIPAMENTO ||--o{ SENSOR : "e monitorado por"
    TIPO_SENSOR ||--o{ SENSOR : classifica
    UNIDADE_MEDIDA ||--o{ SENSOR : "e usada por"
    SENSOR ||--o{ LEITURA : gera
    EQUIPAMENTO ||--o{ LEITURA : registra
    LEITURA ||--o{ ALERTA : dispara
    EQUIPAMENTO ||--o{ MANUTENCAO : sofre
    TECNICO ||--o{ MANUTENCAO : executa
    TIPO_MANUTENCAO ||--o{ MANUTENCAO : classifica

    PLANTA {
        int id_planta PK
        varchar nome
        varchar localizacao
        varchar responsavel
    }
    LINHA_PRODUCAO {
        int id_linha PK
        varchar nome
        text descricao
        int id_planta FK
    }
    EQUIPAMENTO {
        int id_equipamento PK
        varchar tag
        varchar nome
        varchar fabricante
        varchar modelo
        date data_instalacao
        varchar status
        int id_linha FK
    }
    TIPO_SENSOR {
        int id_tipo_sensor PK
        varchar nome
        text descricao
    }
    UNIDADE_MEDIDA {
        int id_unidade PK
        varchar sigla
        varchar descricao
    }
    SENSOR {
        int id_sensor PK
        varchar tag
        varchar descricao
        numeric limite_inferior
        numeric limite_superior
        int id_equipamento FK
        int id_tipo_sensor FK
        int id_unidade FK
    }
    LEITURA {
        bigint id_leitura PK
        timestamp data_hora
        numeric valor
        varchar qualidade
        int id_sensor FK
        int id_equipamento FK
    }
    ALERTA {
        bigint id_alerta PK
        timestamp data_hora
        varchar severidade
        text descricao
        varchar status
        bigint id_leitura FK
    }
    TECNICO {
        int id_tecnico PK
        varchar nome
        varchar especialidade
        varchar contato
    }
    TIPO_MANUTENCAO {
        int id_tipo_manutencao PK
        varchar nome
        text descricao
    }
    MANUTENCAO {
        int id_manutencao PK
        date data_inicio
        date data_fim
        text descricao
        varchar status
        int id_equipamento FK
        int id_tecnico FK
        int id_tipo_manutencao FK
    }
```

## Algumas decisões

- **Tipo dos valores:** `numeric(12,3)` e não `float`, porque a gente compara o
  valor com o limite e o `float` guarda aproximação.
- **Data e hora:** `timestamp` sem fuso, porque todos os sensores estão no
  mesmo fuso.
- **Status, severidade e qualidade:** são `varchar` com `CHECK` listando os
  valores permitidos. Pareceu exagero uma tabela para cada um.
- **Limites no sensor:** o limite fica em cada sensor e não no tipo de sensor,
  porque 90 °C é normal num forno e é muito para um motor.
