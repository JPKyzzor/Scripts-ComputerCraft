# AGENTS.md

## Contexto do projeto

Este diretório contém scripts em Lua para **ComputerCraft / CC:Tweaked** usados dentro do modpack **All The Mods 10 (ATM10)**.

Os scripts são executados em computadores, Advanced Computers, Pocket Computers e periféricos dentro de um **servidor multiplayer**.

Alguns scripts também podem integrar com periféricos de outros mods presentes no ATM10, como por exemplo:

- Advanced Peripherals
- Monitors
- Chat Box
- Player Detector
- Wired Modems
- Pocket Computers

O ambiente é um servidor compartilhado com vários jogadores, portanto o código deve ser tratado como código de produção dentro do jogo.

---

## Prioridade principal: eficiência

A prioridade mais importante é evitar impacto desnecessário no servidor.

Ao criar ou modificar scripts:

- evitar loops ocupados;
- nunca usar `while true do` sem `sleep`, `os.pullEvent`, timer ou outro mecanismo de espera;
- preferir programação orientada a eventos;
- evitar polling em intervalos muito curtos;
- evitar consultas repetidas a periféricos quando o resultado pode ser reutilizado;
- evitar redesenhar monitores sem necessidade;
- evitar operações caras a cada tick;
- evitar criar grande quantidade de timers ou eventos;
- preferir intervalos de atualização razoáveis, normalmente de alguns segundos;
- manter estruturas de dados simples e pequenas;
- não fazer processamento desnecessário em background.

Se uma tarefa puder ser feita por evento em vez de polling, preferir evento.

Exemplo:

```lua
while true do
    local event, username, message = os.pullEvent("chat")
    -- processar somente quando houver mensagem
end
```

é preferível a verificar constantemente se algo mudou.

---

## Uso de loops

Loops permanentes são aceitáveis quando ficam bloqueados esperando algo.

Bom:

```lua
while true do
    local event = { os.pullEvent() }
end
```

Bom:

```lua
while true do
    atualizar()
    sleep(5)
end
```

Evitar:

```lua
while true do
    atualizar()
end
```

Esse último exemplo pode consumir recursos desnecessariamente.

---

## Atualização de monitores

Monitores não devem ser redesenhados constantemente sem motivo.

Preferir:

- redesenhar quando os dados mudarem;
- ou atualizar em intervalos moderados;
- limpar apenas quando necessário;
- evitar chamadas repetidas de `clear`, `setCursorPos` e `write` em loops rápidos.

Para dados como jogadores online, intervalos como **5 segundos** são geralmente suficientes.

Para painéis estáticos, desenhar apenas uma vez na inicialização.

---

## Timers e polling

Ao medir ou verificar alguma informação:

- usar intervalos suficientemente longos;
- não assumir que polling mais rápido produz informação melhor;
- considerar jitter e atraso do servidor;
- usar média, mediana ou janela de amostras quando apropriado.

Para scripts de diagnóstico, deixar claro quando um valor é uma estimativa.

---

## Persistência

Quando dados precisam sobreviver a reinícios:

- usar o filesystem do ComputerCraft;
- salvar apenas quando o estado realmente mudar;
- evitar escrever em arquivo constantemente sem necessidade;
- preferir escrita segura usando arquivo temporário e rename/move quando fizer sentido.

Exemplo:

```lua
local temp = "dados.tmp"

local file = fs.open(temp, "w")
file.write(textutils.serialize(dados))
file.close()

if fs.exists("dados.db") then
    fs.delete("dados.db")
end

fs.move(temp, "dados.db")
```

---

## Estrutura e legibilidade

Priorizar código:

- simples;
- legível;
- fácil de manter;
- com nomes de variáveis claros;
- com funções pequenas;
- sem abstrações desnecessárias.

O código será mantido manualmente e pode ser editado dentro do próprio ComputerCraft, então simplicidade é importante.

Evitar overengineering.

---

## Compatibilidade

Assumir ambiente:

- Minecraft do ATM10;
- CC:Tweaked;
- Lua fornecido pelo ComputerCraft;
- APIs específicas do ComputerCraft.

Não assumir disponibilidade de bibliotecas Lua externas.

Usar APIs como:

```lua
os.pullEvent
os.startTimer
os.epoch
sleep

peripheral.wrap
peripheral.find

fs.open
fs.exists

textutils.serialize
textutils.unserialize
```

quando apropriado.

---

## Periféricos

Nunca assumir cegamente que um periférico existe.

Quando fizer sentido, validar:

```lua
local monitor = peripheral.wrap("monitor_13")

if not monitor then
    error("Monitor nao encontrado.")
end
```

Se o nome do periférico for configurável, preferir colocar no topo do arquivo.

Exemplo:

```lua
local MONITOR_NAME = "monitor_13"
local CHATBOX_NAME = "chat_box_2"
```

---

## Multitarefa

Quando um computador precisar executar várias tarefas simultaneamente, usar:

```lua
parallel.waitForAll(...)
```

ou:

```lua
parallel.waitForAny(...)
```

As funções executadas em paralelo devem bloquear com:

- `os.pullEvent`;
- `sleep`;
- timers;
- chamadas que aguardem eventos.

Nunca criar múltiplas funções paralelas com loops ocupados.

---

## Scripts para servidor

Antes de considerar um script pronto, revisar:

1. Existe algum loop sem espera?
2. Existe polling excessivo?
3. Algum periférico está sendo consultado mais vezes do que o necessário?
4. O monitor está sendo redesenhado sem necessidade?
5. O script grava arquivos com frequência excessiva?
6. O código continua funcionando depois de restart?
7. Erros de periférico podem derrubar o programa inteiro?
8. Existe uma forma mais orientada a eventos de fazer a mesma coisa?

---

## Filosofia geral

No servidor, preferir sempre:

**menos chamadas + menos polling + menos atualizações + comportamento previsível**

em vez de:

**máxima frequência de atualização**.

A diferença entre atualizar algo a cada 100 ms e a cada 5 segundos raramente é útil em ComputerCraft, mas pode gerar trabalho desnecessário no servidor.

Código eficiente e estável é mais importante do que código excessivamente reativo.
