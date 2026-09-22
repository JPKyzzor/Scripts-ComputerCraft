term.setBackgroundColor(colors.black)
term.clear()
term.setCursorBlink(false)

local SAMPLE_SECONDS = 5
local EXPECTED_TICKS = SAMPLE_SECONDS * 20

local MAX_SAMPLES = 7
local samples = {}

local function center(text, y)
    local w, h = term.getSize()
    local x = math.floor((w - #text) / 2) + 1

    term.setCursorPos(math.max(1, x), y)
    term.write(text)
end

local function getColor(tps)
    if not term.isColor() then
        return colors.white
    end

    if tps >= 19 then
        return colors.lime
    elseif tps >= 15 then
        return colors.yellow
    elseif tps >= 10 then
        return colors.orange
    else
        return colors.red
    end
end

local function getStatus(tps)
    if tps >= 19 then
        return "EXCELENTE"
    elseif tps >= 15 then
        return "BOM"
    elseif tps >= 10 then
        return "INSTAVEL"
    else
        return "CRITICO"
    end
end

local function median(values)
    local copy = {}

    for i, value in ipairs(values) do
        copy[i] = value
    end

    table.sort(copy)

    local n = #copy

    if n == 0 then
        return 20
    end

    if n % 2 == 1 then
        return copy[math.ceil(n / 2)]
    end

    local middle = n / 2

    return (
        copy[middle]
        + copy[middle + 1]
    ) / 2
end

local function draw(tps)
    local w, h = term.getSize()

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    center("SERVER STATUS", 1)

    term.setTextColor(colors.lightGray)
    center("TPS ESTIMADO", 3)

    local tpsText = string.format("%.2f", tps)

    term.setTextColor(getColor(tps))
    center(tpsText, 4)

    -- Barra de TPS
    local barWidth = math.min(18, w - 4)

    local filled =
        math.floor(
            (tps / 20) * barWidth + 0.5
        )

    if filled < 0 then
        filled = 0
    end

    if filled > barWidth then
        filled = barWidth
    end

    local empty =
        barWidth - filled

    local bar =
        string.rep("#", filled)
        .. string.rep("-", empty)

    term.setTextColor(getColor(tps))
    center(bar, 6)

    -- MSPT estimado
    local mspt =
        1000 / math.max(tps, 0.01)

    term.setTextColor(colors.white)

    center(
        string.format(
            "MSPT EST. %.1f",
            mspt
        ),
        8
    )

    local status =
        getStatus(tps)

    term.setTextColor(getColor(tps))
    center("Status: " .. status, 10)

    term.setTextColor(colors.gray)

    center(
        "Mediana "
        .. #samples
        .. "/"
        .. MAX_SAMPLES,
        h
    )
end

local function measureTPS()
    local start =
        os.epoch("utc")

    local timer =
        os.startTimer(SAMPLE_SECONDS)

    while true do
        local event, id =
            os.pullEvent("timer")

        if id == timer then
            break
        end
    end

    local elapsedMs =
        os.epoch("utc") - start

    if elapsedMs <= 0 then
        return 20
    end

    -- Tempo medio observado por tick
    local tickInterval =
        elapsedMs / EXPECTED_TICKS

    local tps =
        1000 / tickInterval

    if tps > 20 then
        tps = 20
    end

    if tps < 0 then
        tps = 0
    end

    return tps
end

-- Primeira tela
term.setTextColor(colors.white)
center("SERVER STATUS", 1)

term.setTextColor(colors.gray)
center("Coletando dados...", 5)

while true do
    local tps =
        measureTPS()

    table.insert(
        samples,
        tps
    )

    if #samples > MAX_SAMPLES then
        table.remove(
            samples,
            1
        )
    end

    local tpsFiltrado =
        median(samples)

    draw(tpsFiltrado)
end