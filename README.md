# Scripts ComputerCraft - ATM10

Scripts em Lua para computadores e perifericos do [CC:Tweaked](https://tweaked.cc/), utilizados no modpack All The Mods 10 (ATM10).

Os programas foram pensados para uso em servidor multiplayer: utilizam atualizacoes moderadas e esperas por eventos para evitar trabalho desnecessario no servidor.

## Estrutura

- `mural_avisos/hideway.lua`: mural da Hideway City. Exibe moradores online/offline, avisos e um guia de comandos em tres monitores; tambem recebe os comandos enviados pelo chat.
- `mural_avisos/players.lua`: lista de moradores autorizados e administradores do mural. Pode ser alterado diretamente no computador dentro do Minecraft.
- `tps_meter/tps_meter.lua`: medidor de TPS do servidor.

## Mural de avisos

Copie `hideway.lua` e `players.lua` para a mesma pasta no computador do ComputerCraft. O mural espera encontrar estes perifericos:

- `monitor_12`: moradores online/offline
- `monitor_13`: mural de avisos
- `monitor_14`: guia de comandos
- `player_detector_1`: detector de jogadores
- `chat_box_2`: chat box

Para adicionar ou remover jogadores, edite apenas `players.lua` e reinicie o programa `hideway.lua`. Nao e necessario alterar a logica do mural.

Os dados criados pelo programa ficam no proprio ComputerCraft:

- `avisos.db`: avisos publicados
- `offline.db`: horario em que cada morador ficou offline

Esses arquivos nao devem ser apagados se voce quiser preservar os avisos e o tempo offline.

O quadro de moradores consulta o detector a cada 5 segundos. Os offline sao
ordenados do logout mais recente para o mais antigo. Quando houver mais nomes
do que cabem na tela, use o botao `PROXIMA` no canto inferior direito; apos
cinco segundos sem clique, o quadro retorna automaticamente para a pagina 1.

## Desenvolvimento

Os scripts usam somente APIs disponiveis no CC:Tweaked e nao dependem de bibliotecas Lua externas. Antes de mudar um script, confira as orientacoes em `AGENTS.md`, especialmente as regras de eficiencia para servidor.
