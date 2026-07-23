--[[
    Word Bomb DogeVoid
    Scrabble Dictionary
    WITH ADJUSTABLE AUTO TYPE & WIDE UI FOR 30+ CHAR WORDS
]]

getgenv().deletewhendupefound = true

-- === НАСТРОЙКИ ЗАДЕРЖЕК ===
local BEFORE_TYPE_DELAY = 0.55  -- Задержка ПЕРЕД началом ввода слова
local CHAR_TYPE_INTERVAL = 0.04 -- Скорость печати ОДНОЙ буквы (чуть-чуть помедленнее)

local lib = loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Lib-18698"))()
local Vim = game:GetService("VirtualInputManager")

task.wait(1)

lib.makelib("Word Bank DogeVoid")

local main = lib.maketab("Main")
local statusLabel = lib.makelabel("Loading...", main)

-- === LOAD WORDS ===
local DICTIONARY_RAW = game:HttpGet(
    "https://raw.githubusercontent.com/bro-pixel11/ultrararedict/main/ultra_rare.txt"
)

local words = {}
local wordsLower = {}

for word in DICTIONARY_RAW:gmatch("[^\r\n]+") do
    word = word:gsub("%s+", "")
    if word ~= "" then
        local wordUpper = word:upper()
        table.insert(words, wordUpper)
        table.insert(wordsLower, wordUpper:lower())
    end
end

lib.updatelabel("Loaded " .. #words .. " words", statusLabel)

-- === STATE ===
local sessionUsedWords = {}
local lettercap = math.huge
local autosearch = false
local labelword
local lastChunk = ""
local searchCache = {}
local isTyping = false

-- === UI ===
lib.maketextbox("Letter Cap", main, function(num)
    lettercap = tonumber(num) or math.huge
end)

-- === HELPERS ===
local function getChunk()
    for _, v in pairs(getgc(true)) do
        if type(v) == "function" then
            local info = debug.getinfo(v)
            if info and info.name == "updateInfoFrame" then
                for _, up in pairs(debug.getupvalues(v)) do
                    if type(up) == "table" and up.Prompt then
                        return tostring(up.Prompt):lower()
                    end
                end
            end
        end
    end
    return nil
end

local function selectWord(foundwords)
    if #foundwords == 0 then
        return nil
    end
    return foundwords[math.random(1, #foundwords)]
end

-- === AUTO TYPER ===
local function typeWord(word)
    isTyping = true
    
    task.wait(BEFORE_TYPE_DELAY)
    
    Vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    Vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    task.wait(0.05)
    
    for i = 1, #word do
        local char = word:sub(i, i)
        Vim:SendTextInVirtualInputManager(char)
        task.wait(CHAR_TYPE_INTERVAL)
    end
    
    task.wait(0.05)
    Vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    Vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    
    isTyping = false
end

-- === MAIN ===
function copyword(bruteforce)
    if isTyping then return end

    local contains = getChunk()

    if not contains then
        lib.updatelabel("WAITING...", labelword)
        return
    end

    if lastChunk ~= contains or bruteforce then
        lastChunk = contains

        local cacheKey = contains .. "|" .. lettercap
        local foundwords = searchCache[cacheKey]

        if not foundwords then
            foundwords = {}
            for i = 1, #wordsLower do
                local lower = wordsLower[i]
                if string.find(lower, contains, 1, true) then
                    if #lower <= lettercap and not sessionUsedWords[lower] then
                        table.insert(foundwords, words[i])
                    end
                end
            end

            searchCache[cacheKey] = foundwords

            if #searchCache > 300 then
                local firstKey = next(searchCache)
                searchCache[firstKey] = nil
            end
        end

        if #foundwords == 0 then
            lib.updatelabel("Not Found", labelword)
            return
        end

        local finalword = selectWord(foundwords)

        if finalword then
            sessionUsedWords[finalword:lower()] = true
            lib.updatelabel(finalword, labelword)
            
            task.spawn(typeWord, finalword:lower())
        end
    end
end

-- === BUTTONS ===
lib.makebutton("Search Word", main, function()
    copyword(true)
end)

lib.makebutton("Clear Memory", main, function()
    sessionUsedWords = {}
    searchCache = {}
    lib.updatelabel("Cleared", labelword)
end)

lib.maketoggle("Auto Search", main, function(bool)
    autosearch = bool
    while autosearch do
        task.wait(0.05)
        pcall(function()
            copyword()
        end)
    end
end)

-- === УЛУЧШЕННЫЙ UI ДЛЯ ДЛИННЫХ СЛОВ ===
labelword = lib.makelabel("Ready!", main)

-- Модифицируем созданный лейбл под любые гигантские слова
pcall(function()
    if labelword and type(labelword) == "table" and labelword.Instance then
        local textLabel = labelword.Instance:FindFirstChildOfClass("TextLabel") or labelword.Instance
        if textLabel and textLabel:IsA("TextLabel") then
            textLabel.TextWrapped = true  -- Включаем автоперенос длинного текста
            textLabel.Size = UDim2.new(0.95, 0, 0, 60) -- Увеличиваем высоту плашки под несколько строк
            textLabel.TextScaled = true   -- Автоматически уменьшает шрифт, если слово совсем огромное
        end
    end
end)

lib.ondestroyedfunc = function()
    autosearch = false
end
