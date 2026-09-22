-- =========================================================
-- HIDEWAY CITY
-- Sistema da cidade:
--  monitor_12 = moradores online/offline
--  monitor_13 = mural de avisos
--  monitor_14 = guia de comandos
-- =========================================================

-- =========================
-- PERIFERICOS
-- =========================

local function aguardarPeriferico(nome)
    while not peripheral.isPresent(nome) do
        sleep(1)
    end

    return peripheral.wrap(nome)
end

-- Apos o reinicio do servidor, os perifericos podem carregar alguns segundos
-- depois do computador. Aguarda todos antes de iniciar os paineis.
local cidade = aguardarPeriferico("monitor_12")
local mural = aguardarPeriferico("monitor_13")
local comandos = aguardarPeriferico("monitor_14")

local detector = aguardarPeriferico("player_detector_1")
local chat = aguardarPeriferico("chat_box_2")


-- =========================
-- CONFIGURACAO
-- =========================

local ARQUIVO_DADOS = "avisos.db"
local ARQUIVO_OFFLINE = "offline.db"

local LIMITE_CARACTERES = 255
local LIMITE_AVISOS_POR_MORADOR = 3

local INTERVALO_PAGINA = 10

-- Horario de Brasilia
local TIMEZONE_OFFSET = -3

-- O arquivo players.lua fica ao lado deste programa e pode ser alterado
-- diretamente no ComputerCraft, sem mudar a logica do mural.
local configuracaoJogadores = require("players")

if type(configuracaoJogadores) ~= "table"
    or type(configuracaoJogadores.moradores) ~= "table"
    or type(configuracaoJogadores.administradores) ~= "table"
then
    error(
        "players.lua invalido. Ele deve retornar as tabelas moradores e administradores."
    )
end

local moradores = configuracaoJogadores.moradores
local administradores = configuracaoJogadores.administradores


-- =========================
-- LISTAS DE CONSULTA
-- =========================

local moradoresSet = {}
local adminsSet = {}

for _, nome in ipairs(moradores) do
    moradoresSet[nome] = true
end

for _, nome in ipairs(administradores) do
    adminsSet[nome] = true
    moradoresSet[nome] = true
end


-- =========================
-- DADOS DO MURAL
-- =========================

local dados = {
    contador = 0,
    avisos = {}
}

local paginaAtual = 1
local segundosProximaPagina = INTERVALO_PAGINA

-- Guarda desde quando cada morador foi visto offline nesta execucao.
local offlineDesde = {}

-- Estado independente do quadro de moradores (monitor_12).
local paginaCidade = 1
local paginasCidade = { {} }
local botaoProximaCidade = nil


-- =========================
-- FUNCOES AUXILIARES
-- =========================

local function trim(texto)
    return texto:match("^%s*(.-)%s*$")
end


local function enviarToast(player, mensagem)
    chat.sendToast({
        title = "Mural de Avisos",
        message = mensagem,
        player = player
    })
end


local function dataHoraAtual()
    local epochMs = os.epoch("utc")

    local segundos =
        math.floor(epochMs / 1000)
        + (TIMEZONE_OFFSET * 3600)

    return os.date("!%d/%m %H:%M", segundos)
end


-- =========================
-- PERSISTENCIA
-- =========================

local function salvarDados()
    local temporario = ARQUIVO_DADOS .. ".tmp"

    local arquivo = fs.open(temporario, "w")

    if not arquivo then
        error("Nao foi possivel criar o arquivo temporario.")
    end

    arquivo.write(textutils.serialize(dados))
    arquivo.close()

    if fs.exists(ARQUIVO_DADOS) then
        fs.delete(ARQUIVO_DADOS)
    end

    fs.move(temporario, ARQUIVO_DADOS)
end


local function carregarDados()
    if not fs.exists(ARQUIVO_DADOS) then
        return
    end

    local arquivo = fs.open(ARQUIVO_DADOS, "r")

    if not arquivo then
        return
    end

    local conteudo = arquivo.readAll()
    arquivo.close()

    local carregado = textutils.unserialize(conteudo)

    if type(carregado) == "table" then
        dados = carregado
        dados.contador = dados.contador or 0
        dados.avisos = dados.avisos or {}
    end
end


-- =========================
-- QUEBRA AUTOMATICA DE LINHA
-- =========================

local function quebrarLinha(texto, largura)
    local linhas = {}

    while #texto > largura do
        local trecho = texto:sub(1, largura)
        local ultimoEspaco = nil

        for i = #trecho, 1, -1 do
            if trecho:sub(i, i) == " " then
                ultimoEspaco = i
                break
            end
        end

        if ultimoEspaco and ultimoEspaco > 1 then
            table.insert(
                linhas,
                texto:sub(1, ultimoEspaco - 1)
            )

            texto = trim(
                texto:sub(ultimoEspaco + 1)
            )
        else
            table.insert(
                linhas,
                texto:sub(1, largura)
            )

            texto = texto:sub(largura + 1)
        end
    end

    if texto ~= "" then
        table.insert(linhas, texto)
    end

    return linhas
end


-- =========================================================
-- PAGINACAO DO MURAL
-- =========================================================

local function montarPaginas()
    local largura, altura = mural.getSize()

    local primeiraLinhaConteudo = 4
    local ultimaLinhaConteudo = altura

    local paginas = {}
    local pagina = {}
    local linhasUsadas = 0

    local capacidade =
        ultimaLinhaConteudo
        - primeiraLinhaConteudo
        + 1

    -- Avisos mais novos primeiro
    for i = #dados.avisos, 1, -1 do
        local aviso = dados.avisos[i]

        local texto =
            "[" .. aviso.id .. "] "
            .. aviso.dataHora .. " "
            .. aviso.autor .. ": "
            .. aviso.texto

        local linhas =
            quebrarLinha(texto, largura)

        local tamanhoAviso =
            #linhas + 1

        if
            #pagina > 0
            and linhasUsadas + tamanhoAviso > capacidade
        then
            table.insert(paginas, pagina)

            pagina = {}
            linhasUsadas = 0
        end

        table.insert(pagina, {
            aviso = aviso,
            linhas = linhas
        })

        linhasUsadas =
            linhasUsadas + tamanhoAviso
    end

    if #pagina > 0 then
        table.insert(paginas, pagina)
    end

    if #paginas == 0 then
        paginas = {
            {}
        }
    end

    return paginas
end


-- =========================================================
-- MONITOR 13
-- MURAL DE AVISOS
-- =========================================================

local function desenharMural()
    mural.setTextScale(1)
    mural.setBackgroundColor(colors.black)
    mural.clear()

    local largura, altura = mural.getSize()

    local paginas = montarPaginas()
    local totalPaginas = #paginas

    if paginaAtual > totalPaginas then
        paginaAtual = 1
    end

    if paginaAtual < 1 then
        paginaAtual = 1
    end


    local titulo = "MURAL DE AVISOS"

    local xTitulo =
        math.floor((largura - #titulo) / 2) + 1


    mural.setCursorPos(xTitulo, 1)
    mural.setTextColor(colors.yellow)
    mural.write(titulo)


    local textoPagina =
        "Pagina "
        .. paginaAtual
        .. "/"
        .. totalPaginas
        .. " | Proxima: "
        .. segundosProximaPagina
        .. "s"

    mural.setCursorPos(
        largura - #textoPagina + 1,
        1
    )

    mural.setTextColor(colors.lightGray)
    mural.write(textoPagina)


    mural.setCursorPos(1, 2)
    mural.setTextColor(colors.gray)
    mural.write(string.rep("-", largura))


    if #dados.avisos == 0 then
        mural.setCursorPos(1, 4)
        mural.setTextColor(colors.lightGray)
        mural.write("Nenhum aviso publicado.")
        return
    end


    local linhaAtual = 4
    local pagina = paginas[paginaAtual]

    for _, item in ipairs(pagina) do
        mural.setTextColor(colors.white)

        for _, linha in ipairs(item.linhas) do
            if linhaAtual > altura then
                break
            end

            mural.setCursorPos(1, linhaAtual)
            mural.write(linha)

            linhaAtual = linhaAtual + 1
        end

        linhaAtual = linhaAtual + 1
    end
end


-- =========================================================
-- MONITOR 12
-- MORADORES ONLINE / OFFLINE
-- =========================================================

local function formatarTempoOffline(segundos)
    local minutos = math.floor(segundos / 60)

    if minutos < 60 then
        return minutos .. "min"
    end

    local horas = math.floor(minutos / 60)

    if horas < 24 then
        return horas .. "h"
    end

    return math.floor(horas / 24) .. "d"
end


local function salvarOffline()
    local temporario = ARQUIVO_OFFLINE .. ".tmp"

    local arquivo = fs.open(temporario, "w")

    if not arquivo then
        error("Nao foi possivel criar o arquivo temporario.")
    end

    arquivo.write(textutils.serialize(offlineDesde))
    arquivo.close()

    if fs.exists(ARQUIVO_OFFLINE) then
        fs.delete(ARQUIVO_OFFLINE)
    end

    fs.move(temporario, ARQUIVO_OFFLINE)
end


local function carregarOffline()
    if not fs.exists(ARQUIVO_OFFLINE) then
        return
    end

    local arquivo = fs.open(ARQUIVO_OFFLINE, "r")

    if not arquivo then
        return
    end

    local conteudo = arquivo.readAll()
    arquivo.close()

    local carregado = textutils.unserialize(conteudo)

    if type(carregado) == "table" then
        for nome, desde in pairs(carregado) do
            if moradoresSet[nome] and type(desde) == "number" then
                offlineDesde[nome] = desde
            end
        end
    end
end


local function atualizarDadosCidade()
    local jogadoresOnline =
        detector.getOnlinePlayers()

    local onlineSet = {}

    for _, nome in ipairs(jogadoresOnline) do
        onlineSet[nome] = true
    end


    local online = {}
    local offline = {}
    local agora = os.epoch("utc")
    local alterouOffline = false

    for _, nome in ipairs(moradores) do
        if onlineSet[nome] then
            if offlineDesde[nome] then
                offlineDesde[nome] = nil
                alterouOffline = true
            end

            table.insert(online, nome)
        else
            if not offlineDesde[nome] then
                offlineDesde[nome] = agora
                alterouOffline = true
            end

            table.insert(offline, {
                nome = nome,
                desde = offlineDesde[nome]
            })
        end
    end

    if alterouOffline then
        salvarOffline()
    end


    -- O desligamento mais recente vem primeiro. Empates sao ordenados por nome
    -- para que a lista continue previsivel.
    table.sort(offline, function(a, b)
        if a.desde == b.desde then
            return a.nome < b.nome
        end

        return a.desde > b.desde
    end)

    local largura, altura = cidade.getSize()
    local linhas = {
        { texto = "ONLINE (" .. #online .. "/" .. #moradores .. ")", cor = colors.lime }
    }

    for _, nome in ipairs(online) do
        table.insert(linhas, { texto = "- " .. nome, cor = colors.white })
    end

    table.insert(linhas, { texto = "", cor = colors.black })
    table.insert(linhas, { texto = "OFFLINE (" .. #offline .. "/" .. #moradores .. ")", cor = colors.lightGray })

    for _, jogador in ipairs(offline) do
        table.insert(linhas, {
            texto = "- " .. jogador.nome .. " - " .. formatarTempoOffline((agora - jogador.desde) / 1000),
            cor = colors.gray
        })
    end

    -- Linhas 1-2 sao o cabecalho; a ultima fica reservada para o botao.
    local capacidade = math.max(1, altura - 4)
    paginasCidade = {}

    for indice, item in ipairs(linhas) do
        local pagina = math.floor((indice - 1) / capacidade) + 1
        paginasCidade[pagina] = paginasCidade[pagina] or {}
        table.insert(paginasCidade[pagina], item)
    end

    if #paginasCidade == 0 then
        paginasCidade = { {} }
    end

    if paginaCidade > #paginasCidade then
        paginaCidade = 1
    end
end


local function desenharCidade()
    cidade.setTextScale(0.5)
    cidade.setBackgroundColor(colors.black)
    cidade.clear()

    local largura, altura = cidade.getSize()
    local titulo = "HIDEWAY CITY"
    local paginaTexto = "Pagina " .. paginaCidade .. "/" .. #paginasCidade

    cidade.setCursorPos(math.floor((largura - #titulo) / 2) + 1, 1)
    cidade.setTextColor(colors.yellow)
    cidade.write(titulo)

    cidade.setCursorPos(largura - #paginaTexto + 1, 1)
    cidade.setTextColor(colors.lightGray)
    cidade.write(paginaTexto)

    cidade.setCursorPos(1, 2)
    cidade.setTextColor(colors.gray)
    cidade.write(string.rep("-", largura))

    local linha = 4
    for _, item in ipairs(paginasCidade[paginaCidade]) do
        cidade.setCursorPos(2, linha)
        cidade.setTextColor(item.cor)
        cidade.write(item.texto:sub(1, largura - 1))
        linha = linha + 1
    end

    botaoProximaCidade = nil
    if #paginasCidade > 1 then
        local textoBotao = "[ PROXIMA > ]"
        local inicio = largura - #textoBotao + 1

        cidade.setCursorPos(inicio, altura)
        cidade.setTextColor(colors.black)
        cidade.setBackgroundColor(colors.lime)
        cidade.write(textoBotao)
        cidade.setBackgroundColor(colors.black)

        botaoProximaCidade = {
            x1 = inicio,
            x2 = largura,
            y = altura
        }
    end
end


-- =========================================================
-- MONITOR 14
-- GUIA DE COMANDOS
-- =========================================================

local function desenharComandos()
    comandos.setTextScale(0.5)
    comandos.setBackgroundColor(colors.black)
    comandos.clear()

    local largura =
        comandos.getSize()

    local titulo = "COMANDOS DO MURAL"

    local xTitulo =
        math.floor((largura - #titulo) / 2) + 1


    comandos.setCursorPos(xTitulo, 1)
    comandos.setTextColor(colors.yellow)
    comandos.write(titulo)


    comandos.setCursorPos(1, 2)
    comandos.setTextColor(colors.gray)
    comandos.write(string.rep("-", largura))


    comandos.setCursorPos(2, 4)
    comandos.setTextColor(colors.orange)
    comandos.write("MORADORES")


    comandos.setCursorPos(2, 6)
    comandos.setTextColor(colors.lime)
    comandos.write("!aviso <mensagem>")

    comandos.setCursorPos(4, 7)
    comandos.setTextColor(colors.white)
    comandos.write("Publica um novo aviso no mural.")

    comandos.setCursorPos(4, 8)
    comandos.setTextColor(colors.lightGray)
    comandos.write("Maximo de 255 caracteres.")

    comandos.setCursorPos(4, 9)
    comandos.write("Maximo de 3 avisos por morador.")


    comandos.setCursorPos(2, 12)
    comandos.setTextColor(colors.lime)
    comandos.write("!apagar <ID>")

    comandos.setCursorPos(4, 13)
    comandos.setTextColor(colors.white)
    comandos.write("Remove um aviso publicado por voce.")


    comandos.setCursorPos(2, 17)
    comandos.setTextColor(colors.orange)
    comandos.write("ADMINISTRADORES")


    comandos.setCursorPos(2, 19)
    comandos.setTextColor(colors.lime)
    comandos.write("!apagar <ID>")

    comandos.setCursorPos(4, 20)
    comandos.setTextColor(colors.white)
    comandos.write("Pode remover qualquer aviso.")

    comandos.setCursorPos(4, 21)
    comandos.setTextColor(colors.lightGray)
    comandos.write("Sem limite de avisos publicados.")


    comandos.setCursorPos(2, 24)
    comandos.setTextColor(colors.lime)
    comandos.write("!limpartodos")

    comandos.setCursorPos(4, 25)
    comandos.setTextColor(colors.white)
    comandos.write("Remove todos os avisos do mural.")
end


-- =========================
-- BUSCAR AVISOS DO PLAYER
-- =========================

local function avisosDoMorador(nome)
    local encontrados = {}

    for indice, aviso in ipairs(dados.avisos) do
        if aviso.autor == nome then
            table.insert(encontrados, {
                indice = indice,
                aviso = aviso
            })
        end
    end

    return encontrados
end


-- =========================
-- CRIAR AVISO
-- =========================

local function criarAviso(username, texto)
    texto = trim(texto)

    if texto == "" then
        enviarToast(
            username,
            "Digite uma mensagem depois de !aviso."
        )
        return
    end


    if #texto > LIMITE_CARACTERES then
        enviarToast(
            username,
            "Aviso muito grande: "
            .. #texto
            .. "/"
            .. LIMITE_CARACTERES
            .. " caracteres."
        )
        return
    end


    local avisosPlayer =
        avisosDoMorador(username)

    local removeuAntigo = false


    -- Administradores nao possuem limite.
    -- Moradores comuns possuem o limite configurado.
    if
        not adminsSet[username]
        and #avisosPlayer >= LIMITE_AVISOS_POR_MORADOR
    then
        table.remove(
            dados.avisos,
            avisosPlayer[1].indice
        )

        removeuAntigo = true
    end


    dados.contador =
        dados.contador + 1

    local id = dados.contador


    table.insert(dados.avisos, {
        id = id,
        autor = username,
        dataHora = dataHoraAtual(),
        texto = texto
    })


    paginaAtual = 1
    segundosProximaPagina = INTERVALO_PAGINA

    salvarDados()
    desenharMural()


    if removeuAntigo then
        enviarToast(
            username,
            "Aviso "
            .. id
            .. " criado! Seu aviso mais antigo foi removido."
        )
    else
        enviarToast(
            username,
            "Aviso "
            .. id
            .. " criado com sucesso!"
        )
    end
end


-- =========================
-- APAGAR AVISO
-- =========================

local function apagarAviso(username, id)
    local idNumero = tonumber(id)

    if not idNumero then
        enviarToast(
            username,
            "Informe um ID valido."
        )
        return
    end


    for indice, aviso in ipairs(dados.avisos) do
        if aviso.id == idNumero then

            if
                aviso.autor ~= username
                and not adminsSet[username]
            then
                enviarToast(
                    username,
                    "Voce nao pode apagar esse aviso."
                )
                return
            end


            table.remove(
                dados.avisos,
                indice
            )

            paginaAtual = 1
            segundosProximaPagina = INTERVALO_PAGINA

            salvarDados()
            desenharMural()


            enviarToast(
                username,
                "Aviso "
                .. idNumero
                .. " removido com sucesso!"
            )

            return
        end
    end


    enviarToast(
        username,
        "Aviso "
        .. idNumero
        .. " nao encontrado."
    )
end


-- =========================
-- LIMPAR TODO O MURAL
-- =========================

local function limparTodos(username)
    if not adminsSet[username] then
        enviarToast(
            username,
            "Apenas administradores podem limpar o mural."
        )
        return
    end


    dados.avisos = {}
    dados.contador = 0
    paginaAtual = 1
    segundosProximaPagina = INTERVALO_PAGINA

    salvarDados()
    desenharMural()


    enviarToast(
        username,
        "Todos os avisos foram removidos."
    )
end


-- =========================
-- PROCESSAMENTO DO CHAT
-- =========================

local function processarChat()
    while true do
        local event,
              uuid,
              username,
              message =
            os.pullEvent("chat")


        if message:sub(1, 1) == "!" then

            if not moradoresSet[username] then

                enviarToast(
                    username,
                    "Voce nao tem permissao para usar o mural."
                )

            else

                local textoAviso =
                    message:match("^!aviso%s+(.+)$")


                if textoAviso then

                    criarAviso(
                        username,
                        textoAviso
                    )


                elseif message == "!aviso" then

                    enviarToast(
                        username,
                        "Uso: !aviso <mensagem>"
                    )


                else

                    local id =
                        message:match(
                            "^!apagar%s+(%d+)%s*$"
                        )


                    if id then

                        apagarAviso(
                            username,
                            id
                        )


                    elseif message:match("^!apagar") then

                        enviarToast(
                            username,
                            "Uso: !apagar <ID>"
                        )


                    elseif message == "!limpartodos" then

                        limparTodos(username)

                    end
                end
            end
        end
    end
end


-- =========================
-- ATUALIZAR MORADORES
-- =========================

local function atualizarPlayers()
    local timerAtualizacao = os.startTimer(5)
    local timerInatividade = nil

    while true do
        local evento, lado, x, y = os.pullEvent()

        if evento == "timer" and lado == timerAtualizacao then
            atualizarDadosCidade()
            desenharCidade()
            timerAtualizacao = os.startTimer(5)

        elseif evento == "timer" and lado == timerInatividade then
            timerInatividade = nil

            if paginaCidade ~= 1 then
                paginaCidade = 1
                desenharCidade()
            end

        elseif evento == "monitor_touch" and lado == "monitor_12" then
            if
                botaoProximaCidade
                and y == botaoProximaCidade.y
                and x >= botaoProximaCidade.x1
                and x <= botaoProximaCidade.x2
            then
                paginaCidade = paginaCidade + 1

                if paginaCidade > #paginasCidade then
                    paginaCidade = 1
                end

                if timerInatividade then
                    os.cancelTimer(timerInatividade)
                end

                timerInatividade = os.startTimer(5)
                desenharCidade()
            end
        end
    end
end


-- =========================
-- ROTACAO DAS PAGINAS
-- =========================

local function atualizarPaginas()
    while true do
        sleep(1)

        segundosProximaPagina = segundosProximaPagina - 1

        if segundosProximaPagina <= 0 then
            segundosProximaPagina = INTERVALO_PAGINA

            local paginas = montarPaginas()

            if #paginas > 1 then
                paginaAtual =
                    paginaAtual + 1

                if paginaAtual > #paginas then
                    paginaAtual = 1
                end
            end
        end

        desenharMural()
    end
end


-- =========================================================
-- INICIALIZACAO
-- =========================================================

carregarDados()
carregarOffline()

desenharMural()
atualizarDadosCidade()
desenharCidade()
desenharComandos()


parallel.waitForAll(
    processarChat,
    atualizarPlayers,
    atualizarPaginas
)
