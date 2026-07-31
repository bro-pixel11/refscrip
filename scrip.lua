-- ═══════════════════════════════════════════════════════════════
--  PHANTOM-BOMB  |  Word Bomb Assistant  |  v2.0
--  Orion UI Edition — полностью переработанная архитектура
-- ═══════════════════════════════════════════════════════════════

-- === LOCALIZATION ===
local string_find = string.find
local string_lower = string.lower
local string_sub = string.sub
local string_gsub = string.gsub
local string_upper = string.upper
local string_byte = string.byte
local math_random = math.random
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local task_spawn = task.spawn
local task_wait = task.wait
local task_delay = task.delay
local os_time = os.time
local os_clock = os.clock
local pcall = pcall
local type = type
local typeof = typeof
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local next = next
local getgc = getgc or function() return {} end
local debug_getinfo = debug.getinfo or debug.info
local debug_getupvalues = debug.getupvalues or debug.getupvalue

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Vim = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

print("[Phantom-Bomb] Bypassing Key System... Authenticated!")

-- ═══════════════════════════════════════════════════════════════
--  ORION UI INITIALIZATION
-- ═══════════════════════════════════════════════════════════════
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()

local Window = OrionLib:MakeWindow({
    Name = "Phantom-Bomb  v2.0",
    HidePremium = true,
    SaveConfig = true,
    ConfigFolder = "PhantomBomb",
    IntroEnabled = true,
    IntroText = "Phantom-Bomb",
    IntroIcon = "rbxassetid://7733965386",
    Icon = "rbxassetid://7733965386",
    CloseCallback = function()
        print("[Phantom-Bomb] UI closed, script still running")
    end
})

local TabMain = Window:MakeTab({ Name = "Main", Icon = "rbxassetid://7734053426" })
local TabDict = Window:MakeTab({ Name = "Dictionary", Icon = "rbxassetid://7733964640" })
local TabSettings = Window:MakeTab({ Name = "Settings", Icon = "rbxassetid://7734056608" })
local TabStats = Window:MakeTab({ Name = "Stats", Icon = "rbxassetid://7733774602" })

-- ═══════════════════════════════════════════════════════════════
--  DICTIONARY ENGINE
-- ═══════════════════════════════════════════════════════════════
local Dictionary = {
    words = {},
    index = {},
    indexed = false,
    totalWords = 0,
    url = "https://raw.githubusercontent.com/bro-pixel11/wbdict/main/word-bomb-list.txt"
}

local SessionData = {
    usedWords = {},
    lastPrompt = "",
    isMyTurn = false,
    isTyping = false,
    typingSession = 0,
    totalTurns = 0,
    startTime = os_time(),
    wordsTyped = {},
    avgWordLength = 0,
    longestWord = "",
    rarestWord = ""
}

-- ═══════════════════════════════════════════════════════════════
--  CONFIGURATION STATE
-- ═══════════════════════════════════════════════════════════════
local Config = {
    autoSearch = false,
    autoType = false,
    instantType = false,
    autoJoin = false,
    letterCap = math_huge,
    wordMode = "Hyphenated / Short",
    typingWPM = 500,
    checkDelay = 1.0,
    autoJoinDelay = 2,
    
    -- Humanization
    rngVariation = 0,
    jitterEnabled = false,
    jitterIntensity = 0.05,
    typosEnabled = false,
    typoChance = 3,
    
    -- Advanced
    antiDupe = true,
    debugMode = false,
    gcCacheTime = 3.0
}

-- ═══════════════════════════════════════════════════════════════
--  LETTER RARITY SCORING
-- ═══════════════════════════════════════════════════════════════
local RarityWeights = {
    q = 12, x = 12, z = 12, j = 12,
    k = 6, v = 6, w = 6, y = 5, f = 5, p = 5,
    b = 4, g = 4, m = 4, c = 4, d = 4,
    h = 3, l = 3, u = 3,
    e = 1, t = 1, a = 1, o = 1, i = 1, n = 1, s = 1, r = 1
}

local function calculateRarity(word)
    local score = 0
    local len = #word
    for i = 1, len do
        score = score + (RarityWeights[string_sub(word, i, i)] or 2)
    end
    if len > 8 then score = score + (len - 8) * 4 end
    if string_find(word, "-", 1, true) then score = score + 15 end
    if string_find(word, "'", 1, true) then score = score + 10 end
    return score
end

-- ═══════════════════════════════════════════════════════════════
--  DICTIONARY LOADING & INDEXING
-- ═══════════════════════════════════════════════════════════════
local function loadDictionary()
    task_spawn(function()
        TabMain:AddLabel("Downloading dictionary...")
        
        local ok, raw = pcall(function() return game:HttpGet(Dictionary.url) end)
        if not ok or not raw then
            TabMain:AddLabel("Dictionary download FAILED!")
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Failed to load dictionary",
                Image = "rbxassetid://7733658504",
                Time = 5
            })
            return
        end
        
        local count = 0
        local seen = {}
        
        for line in raw:gmatch("[^\r\n]+") do
            local word = string_gsub(line, "%s+", ""):lower()
            local wlen = #word
            
            if wlen >= 2 then
                count = count + 1
                table_insert(Dictionary.words, word)
                
                -- Index substrings of length 2 and 3
                for subLen = 2, 3 do
                    for i = 1, wlen - subLen + 1 do
                        local sub = string_sub(word, i, i + subLen - 1)
                        if not seen[sub] then
                            seen[sub] = {}
                        end
                        seen[sub][word] = true
                    end
                end
                
                if count % 5000 == 0 then
                    TabMain:AddLabel("Indexing: " .. count .. " words...")
                    task_wait()
                end
            end
        end
        
        -- Convert sets to arrays for faster iteration
        for sub, wordSet in pairs(seen) do
            local arr = {}
            for word in pairs(wordSet) do
                table_insert(arr, word)
            end
            Dictionary.index[sub] = arr
        end
        
        Dictionary.totalWords = count
        Dictionary.indexed = true
        
        TabMain:AddLabel("Dictionary: " .. count .. " words ready")
        OrionLib:MakeNotification({
            Name = "Ready",
            Content = "Dictionary loaded: " .. count .. " words",
            Image = "rbxassetid://7733715400",
            Time = 3
        })
    end)
end

loadDictionary()

-- ═══════════════════════════════════════════════════════════════
--  GC FUNCTION CACHE
-- ═══════════════════════════════════════════════════════════════
local GCCache = {
    fn = nil,
    lastValid = 0,
    lastPrompt = "",
    staleAfter = 2.5,
    scanCount = 0
}

local function isTargetFunction(fn)
    if type(fn) ~= "function" then return false end
    local nameOk, name = pcall(function() return debug_getinfo(fn).name end)
    if not nameOk or name ~= "updateInfoFrame" then return false end
    
    local hasPrompt, hasPlayerID = false, false
    pcall(function()
        for _, upv in pairs(debug_getupvalues(fn)) do
            if type(upv) == "table" then
                if upv.Prompt ~= nil then hasPrompt = true end
                if upv.PlayerID ~= nil then hasPlayerID = true end
            end
        end
    end)
    return hasPrompt and hasPlayerID
end

local function scanGC()
    GCCache.scanCount = GCCache.scanCount + 1
    if not getgc then return nil end
    for _, v in pairs(getgc()) do
        if isTargetFunction(v) then
            GCCache.fn = v
            GCCache.lastValid = os_clock()
            if Config.debugMode then
                print("[GC] Found updateInfoFrame (scan #" .. GCCache.scanCount .. ")")
            end
            return v
        end
    end
    return nil
end

local function getUpdateFn()
    local now = os_clock()
    
    if GCCache.fn then
        local age = now - GCCache.lastValid
        if age > Config.gcCacheTime then
            if Config.debugMode then print("[GC] Cache stale (" .. age .. "s), rescanning...") end
            GCCache.fn = nil
        elseif isTargetFunction(GCCache.fn) then
            return GCCache.fn
        else
            GCCache.fn = nil
        end
    end
    
    return scanGC()
end

-- ═══════════════════════════════════════════════════════════════
--  GAME STATE READERS
-- ═══════════════════════════════════════════════════════════════
local function readPrompt()
    local fn = getUpdateFn()
    if fn then
        local ok, result = pcall(function()
            for _, upv in pairs(debug_getupvalues(fn)) do
                if type(upv) == "table" and upv.Prompt ~= nil then
                    return upv.Prompt
                end
            end
        end)
        if ok and type(result) == "string" and result ~= "" then
            local lower = result:lower()
            if not string_find(lower, "waiting") then
                GCCache.lastValid = os_clock()
                GCCache.lastPrompt = result
                return result
            end
        end
    end
    
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, guiName in ipairs({"GameUI", "DesktopUI", "MobileUI"}) do
            local gui = pg:FindFirstChild(guiName)
            if gui then
                local promptLbl = gui:FindFirstChild("PromptLabel", true) or gui:FindFirstChild("Prompt", true)
                if promptLbl and promptLbl:IsA("TextLabel") and promptLbl.Visible and promptLbl.Text ~= "" then
                    return promptLbl.Text
                end
            end
        end
    end
    return nil
end

local function readTurnOwner()
    local fn = getUpdateFn()
    if fn then
        local ok, result = pcall(function()
            for _, upv in pairs(debug_getupvalues(fn)) do
                if type(upv) == "table" and upv.PlayerID ~= nil then
                    return upv.PlayerID
                end
            end
        end)
        if ok and result ~= nil then return result end
    end
    return nil
end

local function getGameState()
    local rawPrompt = readPrompt()
    if not rawPrompt then return nil, false end
    
    local prompt = rawPrompt:lower():gsub("%s+", "")
    if prompt == "" or prompt == "waiting" or prompt == "waiting..." then
        SessionData.lastPrompt = ""
        return nil, false
    end
    
    local turnOwner = readTurnOwner()
    local isMyTurn = (turnOwner == LocalPlayer.UserId)
    
    if turnOwner == nil then
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, v in pairs(pg:GetDescendants()) do
                if v:IsA("TextLabel") and v.Visible then
                    local txt = v.Text:lower()
                    if string_find(txt, "your turn") or string_find(txt, "quick") or string_find(txt, "ходи") then
                        isMyTurn = true
                        break
                    end
                end
            end
        end
    end
    
    return prompt, isMyTurn
end

local function findTextBox()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, v in pairs(pg:GetDescendants()) do
        if v:IsA("TextBox") and v.Visible and v.Parent and v.Parent.Name ~= "Orion" then
            return v
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
--  WORD SEARCH ENGINE
-- ═══════════════════════════════════════════════════════════════
local SearchCache = {}

local function findWords(prompt)
    if SearchCache[prompt] then return SearchCache[prompt] end
    
    local candidates = Dictionary.index[prompt]
    if not candidates then return {} end
    
    local valid = {}
    for _, word in ipairs(candidates) do
        if #word <= Config.letterCap and not SessionData.usedWords[word] then
            table_insert(valid, word)
        end
    end
    
    SearchCache[prompt] = valid
    return valid
end

local function scoreWord(word, mode)
    if mode == "Rare Words" then
        return calculateRarity(word)
    elseif mode == "Hyphenated / Short" then
        local hasSpecial = string_find(word, "-", 1, true) or string_find(word, "'", 1, true)
        if hasSpecial then return 100000 end
        return 10000 - #word
    elseif mode == "Shortest" then
        return 10000 - #word
    elseif mode == "Longest" then
        return #word
    else
        return math_random(1, 1000)
    end
end

local function pickBestWord(words, mode)
    if #words == 0 then return nil end
    
    local bestWord, bestScore = words[1], scoreWord(words[1], mode)
    for i = 2, #words do
        local s = scoreWord(words[i], mode)
        if s > bestScore then
            bestWord, bestScore = words[i], s
        end
    end
    return bestWord
end

-- ═══════════════════════════════════════════════════════════════
--  TYPING ENGINE
-- ═══════════════════════════════════════════════════════════════
local Alphabet = "abcdefghijklmnopqrstuvwxyz"

local function applyVariation(base)
    if Config.rngVariation <= 0 then return base end
    local factor = 1 + ((math_random() * 2 - 1) * (Config.rngVariation / 100))
    local result = base * factor
    return math_max(result, 0.005)
end

local function typeWord(word, targetPrompt)
    if SessionData.isTyping then return end
    SessionData.isTyping = true
    SessionData.typingSession = SessionData.typingSession + 1
    local sessionId = SessionData.typingSession
    
    if Config.debugMode then print("[Type] Starting: " .. word) end
    
    if not Config.instantType and Config.checkDelay > 0 then
        task_wait(applyVariation(Config.checkDelay))
        if SessionData.typingSession ~= sessionId then
            SessionData.isTyping = false
            return
        end
    end
    
    local currentPrompt, isMyTurn = getGameState()
    if currentPrompt ~= targetPrompt or not isMyTurn then
        SessionData.isTyping = false
        return
    end
    
    local textBox = findTextBox()
    if textBox then
        textBox:CaptureFocus()
        task_wait(0.01)
        textBox.Text = ""
        task_wait(0.01)
    end
    
    local baseDelay = 60 / (Config.typingWPM * 5)
    
    for i = 1, #word do
        if SessionData.typingSession ~= sessionId then break end
        
        local cp, ct = getGameState()
        if cp ~= targetPrompt or not ct then
            if Config.debugMode then print("[Type] Turn lost mid-type") end
            break
        end
        
        local char = string_sub(word, i, i)
        
        if Config.typosEnabled and not Config.instantType and math_random(1, 100) <= Config.typoChance then
            local wrongIdx = math_random(1, 26)
            local wrongChar = string_sub(Alphabet, wrongIdx, wrongIdx)
            if wrongChar ~= char then
                local wrongKey = Enum.KeyCode[wrongChar:upper()]
                if wrongKey then
                    Vim:SendKeyEvent(true, wrongKey, false, nil)
                    task_wait(0.01)
                    Vim:SendKeyEvent(false, wrongKey, false, nil)
                    task_wait(math_random(150, 350) / 1000)
                    Vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
                    task_wait(0.01)
                    Vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
                    task_wait(math_random(80, 200) / 1000)
                end
            end
        end
        
        local keyCode
        if char == "-" then keyCode = Enum.KeyCode.Minus
        elseif char == "'" then keyCode = Enum.KeyCode.Quote
        else keyCode = Enum.KeyCode[char:upper()] end
        
        if keyCode then
            local delay = Config.instantType and 0 or applyVariation(baseDelay)
            
            if Config.jitterEnabled then
                delay = delay + ((math_random() * 2 - 1) * Config.jitterIntensity)
                delay = math_max(delay, 0.003)
            end
            
            Vim:SendKeyEvent(true, keyCode, false, nil)
            if delay > 0 then task_wait(delay / 2) end
            Vim:SendKeyEvent(false, keyCode, false, nil)
            if delay > 0 then task_wait(delay / 2) end
        end
    end
    
    if SessionData.typingSession == sessionId then
        local fp, ft = getGameState()
        if fp == targetPrompt and ft then
            if not Config.instantType then task_wait(0.02) end
            Vim:SendKeyEvent(true, Enum.KeyCode.Return, false, nil)
            if not Config.instantType then task_wait(0.01) end
            Vim:SendKeyEvent(false, Enum.KeyCode.Return, false, nil)
            
            SessionData.totalTurns = SessionData.totalTurns + 1
            table_insert(SessionData.wordsTyped, word)
            SessionData.avgWordLength = (#word + SessionData.avgWordLength * (SessionData.totalTurns - 1)) / SessionData.totalTurns
            if #word > #SessionData.longestWord then SessionData.longestWord = word end
            local rarity = calculateRarity(word)
            if rarity > (SessionData.rarestWord ~= "" and calculateRarity(SessionData.rarestWord) or 0) then
                SessionData.rarestWord = word
            end
            
            if Config.debugMode then print("[Type] Submitted: " .. word) end
            SessionData.lastPrompt = ""
        else
            if textBox then textBox.Text = "" end
        end
    end
    
    SessionData.isTyping = false
end

-- ═══════════════════════════════════════════════════════════════
--  MAIN LOGIC CONTROLLER
-- ═══════════════════════════════════════════════════════════════
local function processTurn(force)
    local prompt, isMyTurn = getGameState()
    
    if not prompt or not isMyTurn then
        SessionData.lastPrompt = ""
        return
    end
    
    if SessionData.isTyping and prompt ~= SessionData.lastPrompt then
        SessionData.typingSession = SessionData.typingSession + 1
        SessionData.isTyping = false
        if Config.debugMode then print("[Logic] Prompt changed, aborting type") end
    end
    
    if SessionData.isTyping then return end
    
    if prompt ~= SessionData.lastPrompt or force then
        SessionData.lastPrompt = prompt
        if Config.debugMode then print("[Logic] New turn: " .. prompt) end
        
        local candidates = findWords(prompt)
        local word = pickBestWord(candidates, Config.wordMode)
        
        if word then
            SessionData.usedWords[word] = true
            if Config.debugMode then print("[Logic] Selected: " .. word .. " (" .. #candidates .. " candidates)") end
            
            if Config.autoType then
                task_spawn(function() typeWord(word, prompt) end)
            end
            
            return word, #candidates
        else
            if Config.debugMode then print("[Logic] No words for: " .. prompt) end
            SessionData.lastPrompt = ""
            return nil, 0
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  ANTI-DUPLICATE SYSTEM
-- ═══════════════════════════════════════════════════════════════
local function setupAntiDupe()
    local network = ReplicatedStorage:FindFirstChild("Network")
    if not network then return end
    
    local gameEvent = network:FindFirstChild("GameEvent", true)
    if not gameEvent then return end
    
    local buffer = ""
    local systemWords = { typingevent = true, changepossessor = true, english = true }
    
    gameEvent.OnClientEvent:Connect(function(...)
        local args = {...}
        local isTyping = false
        
        for i = 1, #args do
            if type(args[i]) == "string" and args[i]:lower() == "typingevent" then
                isTyping = true
                break
            end
        end
        
        if isTyping then
            for i = 1, #args do
                local arg = args[i]
                if type(arg) == "string" then
                    local lower = arg:lower()
                    if not systemWords[lower] and not string_find(lower, "abcdefg") then
                        buffer = lower
                    end
                end
            end
        else
            for i = 1, #args do
                if type(args[i]) == "string" and args[i]:lower() == "changepossessor" then
                    if #buffer > 1 then
                        SessionData.usedWords[buffer] = true
                        buffer = ""
                    end
                    break
                end
            end
        end
    end)
end

setupAntiDupe()

-- ═══════════════════════════════════════════════════════════════
--  UI: MAIN TAB
-- ═══════════════════════════════════════════════════════════════
TabMain:AddSection({ Name = "Controls" })

TabMain:AddToggle({
    Name = "Auto Search",
    Default = false,
    Save = true,
    Flag = "autoSearch",
    Callback = function(v)
        Config.autoSearch = v
        if v then
            task_spawn(function()
                local waitCounter = 0
                while Config.autoSearch do
                    task_wait(0.12)
                    
                    local prompt = readPrompt()
                    if not prompt or prompt:lower():find("waiting") then
                        waitCounter = waitCounter + 1
                        if waitCounter >= 20 then
                            GCCache.fn = nil
                            SessionData.lastPrompt = ""
                            waitCounter = 0
                        end
                    else
                        waitCounter = 0
                    end
                    
                    local ok, err = pcall(processTurn)
                    if not ok and Config.debugMode then warn("[AutoSearch]", err) end
                end
            end)
        end
    end
})

TabMain:AddToggle({
    Name = "Auto Type",
    Default = false,
    Save = true,
    Flag = "autoType",
    Callback = function(v) Config.autoType = v end
})

TabMain:AddToggle({
    Name = "Instant Type",
    Default = false,
    Save = true,
    Flag = "instantType",
    Callback = function(v) Config.instantType = v end
})

TabMain:AddButton({
    Name = "Manual Search",
    Callback = function()
        local word, count = processTurn(true)
        if word then
            OrionLib:MakeNotification({
                Name = "Found Word",
                Content = word:upper() .. " (" .. count .. " candidates)",
                Image = "rbxassetid://7733715400",
                Time = 3
            })
        else
            OrionLib:MakeNotification({
                Name = "No Match",
                Content = "No valid words found",
                Image = "rbxassetid://7733658504",
                Time = 3
            })
        end
    end
})

TabMain:AddSection({ Name = "Quick Stats" })
local lblStatus = TabMain:AddLabel("Status: Idle")
local lblPrompt = TabMain:AddLabel("Prompt: -")
local lblMatch = TabMain:AddLabel("Match: -")
local lblCandidates = TabMain:AddLabel("Candidates: -")

-- ═══════════════════════════════════════════════════════════════
--  UI: DICTIONARY TAB
-- ═══════════════════════════════════════════════════════════════
TabDict:AddSection({ Name = "Word Selection" })

TabDict:AddDropdown({
    Name = "Priority Mode",
    Default = "Hyphenated / Short",
    Options = {"Rare Words", "Hyphenated / Short", "Shortest", "Longest", "Random"},
    Save = true,
    Flag = "wordMode",
    Callback = function(v) Config.wordMode = v end
})

TabDict:AddSlider({
    Name = "Letter Cap",
    Min = 3,
    Max = 45,
    Default = 45,
    Increment = 1,
    ValueName = " chars",
    Save = true,
    Flag = "letterCap",
    Callback = function(v)
        Config.letterCap = (v >= 45) and math_huge or v
    end
})

TabDict:AddButton({
    Name = "Clear Used Words",
    Callback = function()
        SessionData.usedWords = {}
        SearchCache = {}
        OrionLib:MakeNotification({
            Name = "Cleared",
            Content = "Used words cache reset",
            Image = "rbxassetid://7733715400",
            Time = 2
        })
    end
})

-- ═══════════════════════════════════════════════════════════════
--  UI: SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════
TabSettings:AddSection({ Name = "Timing" })

TabSettings:AddSlider({
    Name = "Check Delay",
    Min = 1,
    Max = 20,
    Default = 10,
    Increment = 1,
    ValueName = " x0.1s",
    Save = true,
    Flag = "checkDelay",
    Callback = function(v) Config.checkDelay = v / 10 end
})

TabSettings:AddSlider({
    Name = "Typing WPM",
    Min = 100,
    Max = 500,
    Default = 500,
    Increment = 25,
    ValueName = " WPM",
    Save = true,
    Flag = "typingWPM",
    Callback = function(v) Config.typingWPM = v end
})

TabSettings:AddSection({ Name = "Humanization" })

TabSettings:AddSlider({
    Name = "RNG Variation",
    Min = 0,
    Max = 100,
    Default = 0,
    Increment = 5,
    ValueName = "%",
    Save = true,
    Flag = "rngVar",
    Callback = function(v) Config.rngVariation = v end
})

TabSettings:AddToggle({
    Name = "Human Typos",
    Default = false,
    Save = true,
    Flag = "typos",
    Callback = function(v) Config.typosEnabled = v end
})

-- ═══════════════════════════════════════════════════════════════
--  BACKGROUND SYSTEMS
-- ═══════════════════════════════════════════════════════════════
task_spawn(function()
    while task_wait(0.2) do
        local prompt, isMyTurn = getGameState()
        if prompt then
            lblPrompt:Set("Prompt: " .. prompt:upper())
            lblStatus:Set("Status: " .. (isMyTurn and "YOUR TURN" or "Waiting..."))
            if isMyTurn and SessionData.lastPrompt == prompt then
                local candidates = findWords(prompt)
                lblCandidates:Set("Candidates: " .. #candidates)
                local word = pickBestWord(candidates, Config.wordMode)
                lblMatch:Set("Match: " .. (word and word:upper() or "None"))
            end
        else
            lblPrompt:Set("Prompt: -")
            lblStatus:Set("Status: Idle")
            lblMatch:Set("Match: -")
            lblCandidates:Set("Candidates: -")
        end
    end
end)

OrionLib:Init()
print("[Phantom-Bomb] v2.0 loaded successfully!")
