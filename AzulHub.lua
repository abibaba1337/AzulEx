-- Azul Hub | Exploits: Trade Helper | Visual: Trails, World, Camera, Glow, Stats HUD, Watermark | Settings: Language, Theme, Keys, Config
-- Toggle GUI: RightShift (rebindable in Settings), Unload: End (rebindable)

local CFG = {
    Title        = "Azul Hub",
    WindowSize   = UDim2.fromOffset(600, 400),
    SidebarWidth = 140,
    Theme = { -- active theme colors, mutated in place by Settings > Theme
        Bg      = Color3.fromRGB(14, 14, 20),
        Panel   = Color3.fromRGB(22, 22, 31),
        Element = Color3.fromRGB(32, 32, 45),
        Hover   = Color3.fromRGB(42, 42, 58),
        Accent  = Color3.fromRGB(150, 90, 255),
        Text    = Color3.fromRGB(238, 238, 248),
        SubText = Color3.fromRGB(140, 140, 165),
        Off     = Color3.fromRGB(62, 62, 80),
        Danger  = Color3.fromRGB(215, 65, 80),
    },
    Settings = {
        Theme        = "Purple",     -- string, key of THEMES
        Language     = "en",         -- string, "en" or "ru"
        ToggleKey    = "RightShift", -- string, Enum.KeyCode name
        UnloadKey    = "End",        -- string, Enum.KeyCode name
        Scale        = 1,            -- number, 0.7..1.3
        Transparency = 0,            -- number, 0..0.6, window body
    },
    TradeHelper = {
        Enabled     = false, -- boolean
        IncludeGems = false, -- boolean
        UseSigns    = true,  -- boolean, add sign % to unit value in the verdict
        DebugSign   = false, -- boolean, on-screen dump of hovered slot + nearby texts
    },
    Trails = {
        Enabled      = false, -- boolean
        Lifetime     = 1.5,   -- number, sec
        Width        = 0.6,   -- number, studs
        Transparency = 0.1,   -- number 0..1
        Hue          = 0.75,  -- number 0..1
        Rainbow      = false, -- boolean
    },
    Visual = {
        World = {
            Fullbright = false, -- boolean
            Brightness = 2,     -- number, Lighting.Brightness while fullbright
            NoFog      = false, -- boolean
            CustomTime = false, -- boolean
            Hour       = 14,    -- number 0..24
        },
        Camera = {
            FovEnabled = false, -- boolean
            Fov        = 90,    -- number, degrees
            ZoomUnlock = false, -- boolean
            ZoomMax    = 400,   -- number, studs
        },
        Glow = {
            Enabled          = false, -- boolean, Highlight on own character
            Rainbow          = false, -- boolean
            Hue              = 0.75,  -- number 0..1
            FillTransparency = 0.6,   -- number 0..1
        },
        Hud = {
            Enabled = false, -- boolean
            Fps     = true,  -- boolean
            Ping    = true,  -- boolean
        },
        Watermark = {
            Enabled  = true, -- boolean
            ShowUser = true, -- boolean
            ShowFps  = true, -- boolean
            Scale    = 1,    -- number, 0.5..3
        },
    },
}

local TH = {
    Tick         = 0.004, -- number, sec
    FairPct      = 5,     -- number, % (|diff| <= this -> FAIR)
    GemValue     = 0.8,   -- number, value of 1 gem in list units
    UnknownValue = 0,     -- number, value of units missing from VALUE_LIST
    TipOffsetX   = 25,    -- number, px, hover window shift to the right of cursor
    TipOffsetY   = -120,  -- number, px, negative = window sits above cursor
    SignRescan   = 0.5,   -- number, sec, per-slot sign cache lifetime
    NearbyRadius = 320,   -- number, px, minimum radius around cursor for tooltip text scan
    NearbyScale  = 0.85,  -- number, radius as fraction of viewport height (takes max with NearbyRadius)
    NearbyRescan = 0.15,  -- number, sec, nearby-text scan throttle
    ShortKeyMin  = 5,     -- number, names shorter than this must match the whole text
    DebugLines   = 34,    -- number, max lines in on-screen debug dump
    Colors = {
        Win     = Color3.fromRGB(70, 200, 110),
        Fair    = Color3.fromRGB(235, 190, 60),
        Lose    = Color3.fromRGB(225, 70, 80),
        Neutral = Color3.fromRGB(140, 140, 165),
        Gem     = Color3.fromRGB(90, 200, 255),
        Sign    = Color3.fromRGB(255, 160, 90),
    },
}

local VIS = {
    HudRefresh = 0.25,                  -- number, sec, FPS/ping label refresh
    StepName   = "AzulVisual",           -- string, RenderStep binding name
    FbAmbient  = Color3.new(1, 1, 1),   -- Color3, ambient while fullbright
    FarFog     = 1e9,                   -- number, fog distance when "No fog" is on
    SaveFile   = "AzulHub.json",        -- string, config file in executor workspace
    LegacyFile = "TiffanyHub.json",     -- string, old config, read once if the new one is missing
    WmX        = 10,                    -- number, px, watermark X (top-left)
    WmY        = 50,                    -- number, px, watermark Y (below Roblox topbar buttons; 8 = very corner)
}

-- aliases (paths from the dump, relative to PlayerGui)
local P_TRADE       = { "Main", "Main", "Trade", "TradeFrame" }
local P_MY_ITEMS    = { "TradeMenu", "YourItemsOffer", "Items" }    -- relative to TradeFrame
local P_THEIR_ITEMS = { "TradeMenu", "PlayerItemsOffer", "Items" }  -- relative to TradeFrame
local P_MY_GEMS     = { "TradeMenu", "YourGems", "EditableAmount", "GemAmount", "GemAmount" } -- relative to TradeFrame
local P_THEIR_GEMS  = { "TradeMenu", "PlayerGems", "GemAmount", "GemAmount" }                 -- relative to TradeFrame
local P_INVENTORY   = { "Main", "Main", "Trade", "InventoryFrame", "List", "ScrollingFrame" }
local ATTR_NAME     = "OriginalName"
-- SIGN node MISSING: enable "Sign debug", hover a signed unit, read the on-screen dump, put the node path here (relative to slot)
local P_SIGN_NODE   = nil -- e.g. { "Sign", "Author" }; nil = scan the whole slot subtree

-- vaultedvaluesx.com Cameraman TD: { name, value, demand /10, stability }
local VALUE_LIST = {
    { "Pharaoh Cameraman",           26500, 6.5, "Underpaid / Fluctuating" },
    { "Alliance Cake",               19000, 9,   "Overpaid" },
    { "TV Spider",                   16000, 8.5, "Stable / Fluctuating" },
    { "Engineer Cameraman",          8500,  8.5, "Stable" },
    { "Chaos Cameraman",             7000,  7,   "Unstable | Fluctuating" },
    { "Upgraded Titan TV Man",       4200,  7.5, "Stable" },
    { "Executioner TV Man",          2750,  8,   "Stable / Fluctuating" },
    { "Upgraded Titan Cameraman",    2600,  6,   "Unstable" },
    { "Premium Pass",                2500,  8,   "Overpaid" },
    { "2x Money",                    2000,  8,   "Overpaid" },
    { "Hacked Cameraman",            2000,  7,   "Slowly Dropping" },
    { "x2 Candy",                    2000,  6.5, "Dropping" },
    { "2x Lucky",                    1900,  7.5, "Overpaid" },
    { "Baker Titan Speakerman",      1500,  3,   "Dropping" },
    { "Reinforced Titan Cameraman",  1200,  5,   "Stable" },
    { "2X Speed",                    1050,  7,   "Overpaid / Stable" },
    { "Reinforced Titan Speakerman", 550,   2.5, "Underpaid" },
    { "Scientist Crate",             500,   7,   "Stable" },
    { "Prototype Duo",               450,   3,   "Dropping" },
    { "Sand Coffin Crate",           350,   2,   "Fluctuating" },
    { "Vampire Camera Man",          350,   1,   "Dropping" },
    { "Headless TV Man",             330,   1,   "Unwanted" },
    { "Jetpack Cameraman",           275,   3,   "Stable / Unwanted" },
    { "Large Scientist Cameraman",   275,   3,   "Unstable" },
    { "Camera Attack Helicopter",    200,   3,   "Unstable" },
    { "CinemaMan Titan",             200,   5.5, "Unwanted" },
    { "Large Laser Cameraman",       200,   4,   "Unwanted" },
    { "Large Prototype Titan",       200,   3.5, "Unwanted" },
    { "Glitch Plungerman",           175,   4.5, "Unwanted" },
    { "TV Woman",                    175,   2,   "Unwanted" },
    { "Scientist Cameraman",         150,   7,   "Overpaid" },
    { "Videotaper Titan",            140,   2.5, "Unwanted" },
    { "Upgraded Titan Speakerman",   100,   2,   "Unstable" },
    { "Party Crate",                 80,    7,   "Stable" },
    { "Spider Crate",                70,    4.5, "Stable" },
}

-- in-game name -> list name, if they ever differ
local ALIASES = {
    ["Spider Tv"] = "TV Spider",
}

-- sign partners: { usernames, sign %, display names }
local SIGN_LIST = {
    { { "mastvei124" },                         40,  { "maminapotata" } },
    { { "alexxxxxxxxwwwwwww", "MiniNoobGO" },   170, { "MiniNobikGG" } },
    { { "Itz_sinduchok" },                      65,  {} },
    { { "Meddyson" },                           350, {} },
    { { "RobziGame" },                          450, {} },
    { { "Xx_Pon4ikk" },                         50,  { "Maffiosnik_CTD" } },
    { { "BLITZ_JACKK", "sandy555783" },         40,  { "BLITZ JACK" } },
    { { "denis_old1" },                         30,  {} },
    { { "Gamer_azhumi06" },                     35,  { "MrPumkin" } },
    { { "Platon9123" },                         25,  { "PITOT_CTD" } },
    { { "Dragacer" },                           35,  {} },
    { { "tctttc" },                             35,  { "CAT AKA THE CAR" } },
    { { "BloxBuxters" },                        100, {} },
    { { "mrenderupshadow" },                    45,  { "Terrance Tv Man" } },
    { { "Gertina4" },                           25,  {} },
    { { "akkVbanne" },                          45,  { "Garno" } },
    { { "Whatenix" },                           25,  { "WhatenixTT" } },
    { { "TheStefrim" },                         35,  { "Stefrim" } },
    { { "redcapture_official" },                85,  { "RedCapture" } },
    { { "Mrbog_fly666" },                       45,  { "Foxyhohhj" } },
    { { "TTD_OnlyMy" },                         65,  {} },
    { { "AmirRB_official" },                    50,  { "Amir" } },
    { { "Roblt137" },                           40,  { "kabullet" } },
    { { "Violetbonie_n1k" },                    35,  {} },
    { { "Real_Derk" },                          30,  { "Derk" } },
    { { "Kaptoxa274" },                         110, { "KAPTOSHKA" } },
    { { "000niko111" },                         40,  { "lipton" } },
    { { "chuoiplayrb" },                        45,  {} },
    { { "Gman201144" },                         45,  { "A3DALICE" } },
    { { "uratura" },                            50,  { "SG1" } },
    { { "espaciodiverso" },                     50,  { "Espaciodiverso" } },
    { { "ADL1CX" },                             35,  { "Ru11z" } },
    { { "Cruffycrof" },                         35,  { "Cruffy" } },
}

local THEME_ORDER = { "Purple", "Ocean", "Rose", "Emerald", "Amber", "Crimson", "Mono" }
local THEMES = {
    Purple = {
        Bg = Color3.fromRGB(14, 14, 20), Panel = Color3.fromRGB(22, 22, 31), Element = Color3.fromRGB(32, 32, 45),
        Hover = Color3.fromRGB(42, 42, 58), Accent = Color3.fromRGB(150, 90, 255), Text = Color3.fromRGB(238, 238, 248),
        SubText = Color3.fromRGB(140, 140, 165), Off = Color3.fromRGB(62, 62, 80), Danger = Color3.fromRGB(215, 65, 80),
    },
    Ocean = {
        Bg = Color3.fromRGB(10, 16, 24), Panel = Color3.fromRGB(16, 26, 38), Element = Color3.fromRGB(24, 38, 54),
        Hover = Color3.fromRGB(32, 50, 70), Accent = Color3.fromRGB(50, 160, 255), Text = Color3.fromRGB(232, 242, 252),
        SubText = Color3.fromRGB(125, 150, 175), Off = Color3.fromRGB(52, 70, 90), Danger = Color3.fromRGB(215, 65, 80),
    },
    Rose = {
        Bg = Color3.fromRGB(22, 12, 16), Panel = Color3.fromRGB(32, 18, 24), Element = Color3.fromRGB(46, 26, 34),
        Hover = Color3.fromRGB(60, 34, 45), Accent = Color3.fromRGB(255, 95, 150), Text = Color3.fromRGB(252, 238, 243),
        SubText = Color3.fromRGB(170, 135, 148), Off = Color3.fromRGB(82, 56, 66), Danger = Color3.fromRGB(230, 70, 70),
    },
    Emerald = {
        Bg = Color3.fromRGB(10, 20, 16), Panel = Color3.fromRGB(16, 30, 24), Element = Color3.fromRGB(24, 44, 35),
        Hover = Color3.fromRGB(32, 58, 46), Accent = Color3.fromRGB(60, 210, 130), Text = Color3.fromRGB(234, 250, 242),
        SubText = Color3.fromRGB(128, 165, 148), Off = Color3.fromRGB(52, 80, 66), Danger = Color3.fromRGB(220, 70, 75),
    },
    Amber = {
        Bg = Color3.fromRGB(20, 16, 10), Panel = Color3.fromRGB(30, 24, 14), Element = Color3.fromRGB(44, 35, 20),
        Hover = Color3.fromRGB(58, 47, 28), Accent = Color3.fromRGB(255, 170, 40), Text = Color3.fromRGB(252, 245, 230),
        SubText = Color3.fromRGB(170, 155, 125), Off = Color3.fromRGB(80, 68, 48), Danger = Color3.fromRGB(220, 65, 60),
    },
    Crimson = {
        Bg = Color3.fromRGB(16, 8, 10), Panel = Color3.fromRGB(26, 12, 16), Element = Color3.fromRGB(38, 18, 24),
        Hover = Color3.fromRGB(52, 24, 32), Accent = Color3.fromRGB(230, 40, 60), Text = Color3.fromRGB(250, 236, 238),
        SubText = Color3.fromRGB(165, 125, 132), Off = Color3.fromRGB(74, 44, 50), Danger = Color3.fromRGB(255, 140, 60),
    },
    Mono = {
        Bg = Color3.fromRGB(12, 12, 12), Panel = Color3.fromRGB(20, 20, 20), Element = Color3.fromRGB(30, 30, 30),
        Hover = Color3.fromRGB(42, 42, 42), Accent = Color3.fromRGB(170, 170, 170), Text = Color3.fromRGB(245, 245, 245),
        SubText = Color3.fromRGB(125, 125, 125), Off = Color3.fromRGB(64, 64, 64), Danger = Color3.fromRGB(210, 60, 60),
    },
}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local GuiService       = game:GetService("GuiService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local StatsService     = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local T = CFG.Theme
local V = CFG.Visual
local GUI_NAME     = "AzulHub_UI"
local OVERLAY_NAME = "AzulTrade_Overlay"
local TIP_NAME     = "AzulTrade_Tip"
local HUD_NAME     = "AzulVisual_HUD"
local LEGACY_NAMES = { "TiffanyHub_UI", "TiffanyTrade_Overlay", "TiffanyTrade_Tip", "TiffanyVisual_HUD" }

local ENV = (getgenv and getgenv()) or _G
if ENV.TiffanyUnload then pcall(ENV.TiffanyUnload) end
if ENV.AzulUnload then pcall(ENV.AzulUnload) end

local connections = {}
local function track(c) connections[#connections + 1] = c return c end

----------------------------------------------------------------
-- CONFIG SAVE / LOAD
----------------------------------------------------------------
local function copyInto(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        local cur = dst[k]
        if type(v) == "table" then
            if type(cur) == "table" then copyInto(cur, v) end
        elseif cur ~= nil and type(cur) == type(v) then
            dst[k] = v
        end
    end
end

local function saveConfig()
    if not writefile then return "no writefile" end
    local ok = pcall(function()
        writefile(VIS.SaveFile, HttpService:JSONEncode({
            TradeHelper = CFG.TradeHelper, Trails = CFG.Trails,
            Visual = CFG.Visual, Settings = CFG.Settings,
        }))
    end)
    return ok and "saved" or "save failed"
end

local function loadConfig()
    if not (isfile and readfile) then return "no readfile" end
    local file = VIS.SaveFile
    if not isfile(file) and isfile(VIS.LegacyFile) then file = VIS.LegacyFile end
    if not isfile(file) then return "no file yet" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
    if not ok or type(data) ~= "table" then return "load failed" end
    copyInto(CFG.TradeHelper, data.TradeHelper)
    copyInto(CFG.Trails, data.Trails)
    copyInto(CFG.Visual, data.Visual)
    copyInto(CFG.Settings, data.Settings)
    if not THEMES[CFG.Settings.Theme] then CFG.Settings.Theme = "Purple" end
    return "loaded"
end

loadConfig()
for k, v in pairs(THEMES[CFG.Settings.Theme]) do T[k] = v end

----------------------------------------------------------------
-- GUI PARENT / HELPERS
----------------------------------------------------------------
local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local ok2 = pcall(function() return game:GetService("CoreGui").Name end)
    if ok2 then return game:GetService("CoreGui") end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local parent = getGuiParent()
local stale = { GUI_NAME, OVERLAY_NAME, TIP_NAME, HUD_NAME }
for _, n in ipairs(LEGACY_NAMES) do stale[#stale + 1] = n end
for _, n in ipairs(stale) do
    local old = parent:FindFirstChild(n)
    if old then old:Destroy() end
end

-- localization: English text is the key; any TextLabel/TextButton created with a key text is auto-registered
local RU = {
    ["Exploits"] = "Эксплойты", ["Visual"] = "Визуал", ["Settings"] = "Настройки",
    ["Trade Helper"] = "Помощник трейдов", ["Win / Fair / Lose on the trade screen"] = "Win / Fair / Lose прямо на экране трейда",
    ["Count gems"] = "Считать гемы", ["Count signs (+%)"] = "Считать сигны (+%)", ["Sign debug (on screen)"] = "Дебаг сигны (на экране)",
    ["Trails"] = "Шлейф", ["Trail behind your character"] = "Шлейф за персонажем", ["Rainbow"] = "Радуга", ["Color"] = "Цвет",
    ["Lifetime"] = "Время жизни", ["Width"] = "Ширина", ["Transparency"] = "Прозрачность",
    ["World"] = "Мир", ["Fullbright, fog, time of day"] = "Фулбрайт, туман, время суток", ["Brightness"] = "Яркость",
    ["No fog"] = "Без тумана", ["Custom time of day"] = "Своё время суток", ["Time of day"] = "Время суток",
    ["Camera"] = "Камера", ["FOV and zoom limit"] = "FOV и лимит зума", ["Field of view"] = "Поле зрения",
    ["Unlock zoom"] = "Снять лимит зума", ["Max zoom"] = "Макс. зум",
    ["Character glow"] = "Свечение персонажа", ["Highlight on your own character"] = "Подсветка своего персонажа",
    ["Fill transparency"] = "Прозрачность заливки",
    ["Stats HUD"] = "Статистика", ["FPS and ping in the corner"] = "FPS и пинг в углу экрана",
    ["Show FPS"] = "Показывать FPS", ["Show ping"] = "Показывать пинг",
    ["Watermark"] = "Ватермарка", ["Azul in the top-left corner"] = "Azul в левом верхнем углу",
    ["Size"] = "Размер", ["Show username"] = "Показывать ник",
    ["Language"] = "Язык", ["Interface language"] = "Язык интерфейса",
    ["Theme"] = "Тема", ["Interface color scheme"] = "Цветовая схема интерфейса",
    ["Purple"] = "Фиолетовая", ["Ocean"] = "Океан", ["Rose"] = "Роза", ["Emerald"] = "Изумруд",
    ["Amber"] = "Янтарь", ["Crimson"] = "Багровая", ["Mono"] = "Моно",
    ["Menu"] = "Меню", ["Keys and window look"] = "Клавиши и вид окна",
    ["Hide / show key"] = "Клавиша скрытия", ["Unload key"] = "Клавиша выгрузки",
    ["Window scale"] = "Масштаб окна", ["Window transparency"] = "Прозрачность окна", ["press a key..."] = "нажми клавишу...",
    ["Config"] = "Конфиг", ["Save config"] = "Сохранить конфиг", ["Load config"] = "Загрузить конфиг",
    ["saved"] = "сохранено", ["loaded"] = "загружено", ["no writefile"] = "нет writefile", ["save failed"] = "ошибка сохранения",
    ["no readfile"] = "нет readfile", ["no file yet"] = "файла нет", ["load failed"] = "ошибка загрузки",
    ["WAITING"] = "ОЖИДАНИЕ", ["NO DATA"] = "НЕТ ДАННЫХ", ["add items to the trade"] = "добавь предметы в трейд",
    ["items are not in the value list"] = "предметов нет в списке цен",
    ["WIN"] = "ВЫИГРЫШ", ["FAIR"] = "РОВНО", ["LOSE"] = "ПРОИГРЫШ",
    ["net"] = "итог", ["(with signs)"] = "(с сигнами)", ["give"] = "отдаёшь", ["get"] = "получаешь",
    ["no sign"] = "без сигны", ["with sign"] = "с сигной", ["THEY GIVE"] = "ОНИ ДАЮТ", ["YOU GIVE"] = "ТЫ ДАЁШЬ",
    ["demand"] = "спрос", ["signed"] = "с сигной", ["not in list"] = "нет в списке",
    ["GEMS"] = "ГЕМЫ", ["gem"] = "гем", ["gems"] = "гемов", ["you give"] = "отдаёшь", ["you get"] = "получаешь",
    ["Value"] = "Цена", ["Demand"] = "Спрос", ["Stability"] = "Стабильность", ["Sign"] = "Сигна",
    ["PING"] = "ПИНГ", ["ms"] = "мс", ["hide / show"] = "скрыть / показать", ["unload"] = "выгрузить",
}
RU["Saved to " .. VIS.SaveFile] = "Сохранение в " .. VIS.SaveFile

local function tx(k)
    if CFG.Settings.Language == "ru" then return RU[k] or k end
    return k
end

local locList = {} -- { instance, key }

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if props and type(props.Text) == "string" and RU[props.Text] and (class == "TextLabel" or class == "TextButton") then
        locList[#locList + 1] = { inst, props.Text }
        inst.Text = tx(props.Text)
    end
    return inst
end

local function corner(r) return create("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function stroke(color, transp, th)
    return create("UIStroke", { Color = color, Transparency = transp or 0, Thickness = th or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(l, t, r, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
    })
end
local function tween(obj, time, props)
    TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

----------------------------------------------------------------
-- TRAILS (Visual)
----------------------------------------------------------------
local trail, att0, att1

local function clearTrail()
    if trail then trail:Destroy() trail = nil end
    if att0 then att0:Destroy() att0 = nil end
    if att1 then att1:Destroy() att1 = nil end
end

local function updateTrail()
    if not trail then return end
    trail.Lifetime = CFG.Trails.Lifetime
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, CFG.Trails.Transparency),
        NumberSequenceKeypoint.new(1, 1),
    })
    if not CFG.Trails.Rainbow then
        trail.Color = ColorSequence.new(Color3.fromHSV(CFG.Trails.Hue, 1, 1))
    end
    att0.Position = Vector3.new(0, CFG.Trails.Width / 2, 0)
    att1.Position = Vector3.new(0, -CFG.Trails.Width / 2, 0)
end

local function buildTrail()
    clearTrail()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    att0 = create("Attachment", { Name = "TH_A0", Parent = hrp })
    att1 = create("Attachment", { Name = "TH_A1", Parent = hrp })
    trail = create("Trail", {
        Name = "TH_Trail", Attachment0 = att0, Attachment1 = att1,
        LightEmission = 0.6, FaceCamera = true, Parent = hrp,
    })
    updateTrail()
end

local function applyTrailState()
    if CFG.Trails.Enabled then buildTrail() else clearTrail() end
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    if CFG.Trails.Enabled then buildTrail() end
end))

track(RunService.Heartbeat:Connect(function()
    if trail and CFG.Trails.Rainbow then
        trail.Color = ColorSequence.new(Color3.fromHSV((tick() * 0.25) % 1, 1, 1))
    end
end))

----------------------------------------------------------------
-- VISUAL FX: world / camera / crosshair / glow / HUD
----------------------------------------------------------------
local orig = setmetatable({}, { __mode = "k" }) -- obj -> { prop -> original value }

local function hold(obj, prop, val)
    local o = orig[obj]
    if not o then o = {} orig[obj] = o end
    if o[prop] == nil then o[prop] = obj[prop] end
    if obj[prop] ~= val then obj[prop] = val end
end

local function release(obj, props)
    local o = orig[obj]
    if not o then return end
    for _, p in ipairs(props) do
        if o[p] ~= nil then
            obj[p] = o[p]
            o[p] = nil
        end
    end
end

local function restoreAll()
    for obj, props in pairs(orig) do
        for p, v in pairs(props) do pcall(function() obj[p] = v end) end
    end
    for obj in pairs(orig) do orig[obj] = nil end
end

local FB_PROPS   = { "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows" }
local FOG_PROPS  = { "FogEnd", "FogStart" }
local ATM_PROPS  = { "Density", "Haze" }
local TIME_PROPS = { "ClockTime" }
local FOV_PROPS  = { "FieldOfView" }
local ZOOM_PROPS = { "CameraMaxZoomDistance" }

local hudGui = create("ScreenGui", {
    Name = HUD_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 90, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
})

-- character glow
local hl
local function clearHighlight()
    if hl then hl:Destroy() hl = nil end
end

local function updateHighlight()
    if not hl then return end
    hl.FillTransparency = V.Glow.FillTransparency
    hl.OutlineTransparency = 0
    if not V.Glow.Rainbow then
        local c = Color3.fromHSV(V.Glow.Hue, 1, 1)
        hl.FillColor = c
        hl.OutlineColor = c
    end
end

local function buildHighlight()
    clearHighlight()
    local char = LocalPlayer.Character
    if not char then return end
    hl = create("Highlight", {
        Name = "TH_Glow", DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = char,
    })
    updateHighlight()
end

local function applyHighlightState()
    if V.Glow.Enabled then buildHighlight() else clearHighlight() end
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    if V.Glow.Enabled then buildHighlight() end
end))

-- stats HUD
local statsLabel = create("TextLabel", {
    Size = UDim2.fromOffset(112, 46), Position = UDim2.new(1, -122, 0, 8),
    BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Text, Text = "",
    Visible = false, Parent = hudGui,
}, { corner(8), stroke(T.Accent, 0.5, 1), pad(10, 6, 10, 6) })

local fps = 60
local function getPing()
    local ok, v = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v + 0.5) or 0
end

local function updateHud()
    local H = V.Hud
    local lines = {}
    if H.Fps then lines[#lines + 1] = "FPS  " .. math.floor(fps + 0.5) end
    if H.Ping then lines[#lines + 1] = tx("PING") .. " " .. getPing() .. " " .. tx("ms") end
    if not H.Enabled or #lines == 0 then
        statsLabel.Visible = false
        return
    end
    statsLabel.Text = table.concat(lines, "\n")
    statsLabel.Size = UDim2.fromOffset(122, #lines * 17 + 12)
    statsLabel.Visible = true
end

-- watermark (top-left)
local wmLabel = create("TextLabel", {
    Size = UDim2.fromOffset(160, 26), Position = UDim2.fromOffset(VIS.WmX, VIS.WmY),
    BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
    RichText = true, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Text,
    Text = "", Visible = false, Parent = hudGui,
}, { corner(8), stroke(T.Accent, 0.5, 1) })

local function updateWatermark()
    local W = V.Watermark
    if not W.Enabled then
        wmLabel.Visible = false
        return
    end
    local sc = W.Scale
    local sep = string.format(' <font color="#%s">|</font> ', T.SubText:ToHex())
    local txt = string.format('<font color="#%s">Azul</font>', T.Accent:ToHex())
    if W.ShowUser then txt ..= sep .. LocalPlayer.Name end
    if W.ShowFps then txt ..= sep .. math.floor(fps + 0.5) .. " fps" end
    wmLabel.TextSize = math.floor(13 * sc + 0.5)
    wmLabel.Text = txt
    wmLabel.Size = UDim2.fromOffset(wmLabel.TextBounds.X + 22 * sc, math.floor(26 * sc + 0.5))
    wmLabel.Visible = true
end

local hudAcc = 0
local function visualStep(dt)
    local W, Cm = V.World, V.Camera

    if W.Fullbright then
        hold(Lighting, "Brightness", W.Brightness)
        hold(Lighting, "Ambient", VIS.FbAmbient)
        hold(Lighting, "OutdoorAmbient", VIS.FbAmbient)
        hold(Lighting, "GlobalShadows", false)
    else
        release(Lighting, FB_PROPS)
    end

    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    if W.NoFog then
        hold(Lighting, "FogEnd", VIS.FarFog)
        hold(Lighting, "FogStart", VIS.FarFog)
        if atm then
            hold(atm, "Density", 0)
            hold(atm, "Haze", 0)
        end
    else
        release(Lighting, FOG_PROPS)
        if atm then release(atm, ATM_PROPS) end
    end

    if W.CustomTime then hold(Lighting, "ClockTime", W.Hour) else release(Lighting, TIME_PROPS) end

    local cam = workspace.CurrentCamera
    if cam then
        if Cm.FovEnabled then hold(cam, "FieldOfView", Cm.Fov) else release(cam, FOV_PROPS) end
    end
    if Cm.ZoomUnlock then hold(LocalPlayer, "CameraMaxZoomDistance", Cm.ZoomMax) else release(LocalPlayer, ZOOM_PROPS) end

    if hl and V.Glow.Rainbow then
        local c = Color3.fromHSV((tick() * 0.25) % 1, 1, 1)
        hl.FillColor = c
        hl.OutlineColor = c
    end

    if dt > 0 then fps = fps * 0.9 + (1 / dt) * 0.1 end
    hudAcc += dt
    if hudAcc >= VIS.HudRefresh then
        hudAcc = 0
        updateHud()
        updateWatermark()
    end
end

pcall(function() RunService:UnbindFromRenderStep(VIS.StepName) end)
RunService:BindToRenderStep(VIS.StepName, Enum.RenderPriority.Camera.Value + 1, visualStep)

----------------------------------------------------------------
-- TRADE HELPER (logic)
----------------------------------------------------------------
local function norm(s) return (tostring(s):lower():gsub("[^%w]", "")) end

local LOOKUP = {}
for _, e in ipairs(VALUE_LIST) do LOOKUP[norm(e[1])] = { n = e[1], v = e[2], d = e[3], s = e[4] } end
for gameName, listName in pairs(ALIASES) do
    local e = LOOKUP[norm(listName)]
    if e then LOOKUP[norm(gameName)] = e end
end

-- normalized username / display name -> { pct, name }
local SIGN_LOOKUP = {}
for _, e in ipairs(SIGN_LIST) do
    for _, u in ipairs(e[1]) do SIGN_LOOKUP[norm(u)] = { pct = e[2], name = u } end
    for _, d in ipairs(e[3]) do
        local k = norm(d)
        if k ~= "" and not SIGN_LOOKUP[k] then SIGN_LOOKUP[k] = { pct = e[2], name = e[1][1] } end
    end
end

local function fmt(n)
    local s, k = tostring(math.floor(n + 0.5)), nil
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

-- one decimal when needed (gem conversions like 2.4)
local function fmt1(n)
    local r = math.floor(n * 10 + 0.5) / 10
    local whole = math.floor(r)
    local frac = math.floor((r - whole) * 10 + 0.5)
    if frac == 0 then return fmt(whole) end
    return fmt(whole) .. "." .. frac
end

-- "THEY GIVE  no sign 1,234  |  with sign 1,580  (+346)"
local function signLine(tag, raw, sgn)
    local d = sgn - raw
    local tail = d > 0.5 and string.format("  (+%s)", fmt(d)) or ""
    return string.format("%s   %s %s   |   %s %s%s", tag, tx("no sign"), fmt(raw), tx("with sign"), fmt(sgn), tail)
end

local function dig(root, path)
    for _, n in ipairs(path) do
        if not root then return nil end
        root = root:FindFirstChild(n)
    end
    return root
end

local MULT = { K = 1e3, M = 1e6, B = 1e9, T = 1e12 }
local function parseNum(s)
    s = tostring(s or ""):gsub(",", "")
    local n, suf = s:match("([%d%.]+)%s*([KkMmBbTt]?)")
    if not n then return 0 end
    return (tonumber(n) or 0) * (MULT[(suf or ""):upper()] or 1)
end

local function isShown(g)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local cur = g
    while cur and cur ~= pg do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return cur ~= nil
end

-- sign detection
local signCache  = setmetatable({}, { __mode = "k" })
local hoverCache = setmetatable({}, { __mode = "k" })
local signMem    = setmetatable({}, { __mode = "k" }) -- sign found via hover popup, remembered per slot

local function matchSign(s)
    if s == nil then return nil end
    local n = norm((tostring(s):gsub("<[^>]*>", "")))
    if n == "" then return nil end
    local bestKey, bestInfo
    for key, info in pairs(SIGN_LOOKUP) do
        local hit
        if #key >= TH.ShortKeyMin then hit = n:find(key, 1, true) ~= nil else hit = (n == key) end
        if hit and (not bestKey or #key > #bestKey) then bestKey, bestInfo = key, info end
    end
    return bestInfo
end

local function hasSignWord(s) return tostring(s):lower():find("sign", 1, true) ~= nil end

local function pctFromText(s)
    local n = tostring(s):gsub("<[^>]*>", ""):match("(%d+%.?%d*)%s*%%")
    return n and tonumber(n) or nil
end

local function scanNode(node, checkName)
    for k, v in pairs(node:GetAttributes()) do
        if k ~= ATTR_NAME then
            if type(v) == "string" then
                local m = matchSign(v)
                if m then return m end
                if hasSignWord(k) then
                    local p = pctFromText(v)
                    if p then return { pct = p, name = k } end
                end
            elseif type(v) == "number" and hasSignWord(k) and v > 0 then
                return { pct = v, name = k }
            end
        end
    end
    if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
        local m = matchSign(node.Text)
        if m then return m end
        if hasSignWord(node.Name) then
            local p = pctFromText(node.Text)
            if p then return { pct = p, name = node.Name } end
        end
    end
    if node:IsA("StringValue") then
        local m = matchSign(node.Value)
        if m then return m end
    end
    if (node:IsA("NumberValue") or node:IsA("IntValue")) and hasSignWord(node.Name) and node.Value > 0 then
        return { pct = node.Value, name = node.Name }
    end
    if checkName then
        local m = matchSign(node.Name)
        if m then return m end
    end
    return nil
end

local function scanSlot(slot)
    local info = scanNode(slot, false)
    if info then return info end
    for _, d in ipairs(slot:GetDescendants()) do
        info = scanNode(d, true)
        if info then return info end
    end
    return nil
end

local signKeyMem = {} -- "container|unit|n" -> sign info, survives slot re-creation by the game

local function slotKey(slot)
    local par = slot.Parent
    if not par then return nil end
    local nm = tostring(slot:GetAttribute(ATTR_NAME) or slot.Name)
    local n = 0
    for _, s in ipairs(par:GetChildren()) do
        if s:IsA("Frame") and tostring(s:GetAttribute(ATTR_NAME) or s.Name) == nm then
            n += 1
            if s == slot then break end
        end
    end
    return par:GetFullName() .. "|" .. nm .. "|" .. n
end

local function rememberSign(slot, info)
    signMem[slot] = info
    local k = slotKey(slot)
    if k then signKeyMem[k] = info end
end

local function recallSign(slot)
    local m = signMem[slot]
    if m then return m end
    local k = slotKey(slot)
    return k and signKeyMem[k] or nil
end

local function resetSignMem()
    if not next(signKeyMem) and not next(signMem) then return end
    for k in pairs(signKeyMem) do signKeyMem[k] = nil end
    for k in pairs(signMem) do signMem[k] = nil end
    for k in pairs(signCache) do signCache[k] = nil end
    for k in pairs(hoverCache) do hoverCache[k] = nil end
end

local function getSign(slot)
    local now = tick()
    local c = signCache[slot]
    if c and now - c.t < TH.SignRescan then return c.info end
    local info
    if P_SIGN_NODE then
        local node = dig(slot, P_SIGN_NODE)
        info = node and scanNode(node, true) or nil
    else
        info = scanSlot(slot)
    end
    if info then rememberSign(slot, info) end
    info = info or recallSign(slot)
    signCache[slot] = { t = now, info = info }
    return info
end

-- cursor in both coordinate spaces (with / without GuiInset)
local function mouseSpaces()
    local m = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    return m, Vector2.new(m.X - inset.X, m.Y - inset.Y)
end

local function viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

-- visible text nodes around the cursor (the game's own hover popup), with distance
local function nearbyTexts(pg)
    local m, mg = mouseSpaces()
    local radius = math.max(TH.NearbyRadius, viewport().Y * TH.NearbyScale)
    local out = {}
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and isShown(d) then
            local c = d.AbsolutePosition + d.AbsoluteSize / 2
            local dist = math.min((c - mg).Magnitude, (c - m).Magnitude)
            if dist <= radius then out[#out + 1] = { node = d, dist = dist } end
        end
    end
    return out
end

local function getHoverSign(pg, slot)
    local now = tick()
    local c = hoverCache[slot]
    if c and now - c.t < TH.NearbyRescan then return c.info end
    local info = getSign(slot)
    if not info then
        local bestDist
        for _, o in ipairs(nearbyTexts(pg)) do
            local mt = matchSign(o.node.Text)
            if mt and (not bestDist or o.dist < bestDist) then info, bestDist = mt, o.dist end
        end
        if info then rememberSign(slot, info) end
    end
    info = info or recallSign(slot)
    hoverCache[slot] = { t = now, info = info }
    return info
end

-- on-screen debug dump (slot subtree + texts near cursor); also copied to clipboard
local function buildDump(pg, slot)
    local lines = { "SLOT " .. slot:GetFullName() }
    local function line(node, depth)
        local parts = { string.rep("  ", depth) .. node.Name .. " <" .. node.ClassName .. ">" }
        if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
            parts[#parts + 1] = 'Text="' .. node.Text .. '"'
        end
        if node:IsA("StringValue") then parts[#parts + 1] = 'Value="' .. node.Value .. '"' end
        for k, v in pairs(node:GetAttributes()) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        lines[#lines + 1] = table.concat(parts, " ")
    end
    for _, d in ipairs(slot:GetDescendants()) do
        local depth, cur = 1, d.Parent
        while cur and cur ~= slot do depth += 1 cur = cur.Parent end
        line(d, depth)
    end
    lines[#lines + 1] = "NEAR CURSOR:"
    for _, o in ipairs(nearbyTexts(pg)) do
        lines[#lines + 1] = string.format('  [%d px] %s = "%s"', o.dist,
            (o.node:GetFullName():gsub("^.-PlayerGui%.", "")), o.node.Text)
    end
    return lines
end

local function slotValue(slot, e, sign)
    local base = e.v
    if CFG.TradeHelper.UseSigns then
        local s = sign
        if s == nil then s = getSign(slot) end
        if s then return base * (1 + s.pct / 100), s end
    end
    return base, nil
end

-- total = verdict basis (respects UseSigns); raw = no signs; sgn = always with signs
local function readOffer(container)
    local r = { total = 0, raw = 0, sgn = 0, count = 0, unknown = 0, dw = 0, signed = 0 }
    if not container then return r end
    for _, it in ipairs(container:GetChildren()) do
        if it:IsA("Frame") then
            local e = LOOKUP[norm(it:GetAttribute(ATTR_NAME) or it.Name)]
            r.count += 1
            if e then
                local s = getSign(it)
                local sv = s and e.v * (1 + s.pct / 100) or e.v
                if s then r.signed += 1 end
                local v = CFG.TradeHelper.UseSigns and sv or e.v
                r.raw += e.v
                r.sgn += sv
                r.total += v
                r.dw += e.d * v
            else
                r.unknown += 1
                r.raw += TH.UnknownValue
                r.sgn += TH.UnknownValue
                r.total += TH.UnknownValue
            end
        end
    end
    return r
end

-- unit slot under the cursor (trade offers + inventory)
local function itemUnderMouse(pg, tf)
    local _, mg = mouseSpaces()
    local objs = pg:GetGuiObjectsAtPosition(mg.X, mg.Y)
    local c1, c2, c3 = dig(tf, P_MY_ITEMS), dig(tf, P_THEIR_ITEMS), dig(pg, P_INVENTORY)
    for _, o in ipairs(objs) do
        local cur = o
        while cur and cur ~= pg do
            local p = cur.Parent
            if p and cur:IsA("Frame") and (p == c1 or p == c2 or p == c3) then
                return cur
            end
            cur = p
        end
    end
    return nil
end

-- verdict + gem window live here
local overlayGui = create("ScreenGui", {
    Name = OVERLAY_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
})

local OVERLAY_W    = 400 -- number, px
local OVERLAY_H    = 142 -- number, px
local OVERLAY_LIFT = 79  -- number, px, overlay center above TradeFrame top (H/2 + 8)
local overlay = create("Frame", {
    Size = UDim2.fromOffset(OVERLAY_W, OVERLAY_H), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = T.Bg, BorderSizePixel = 0, Visible = false, Parent = overlayGui,
}, { corner(12) })
local ovStroke = create("UIStroke", { Color = TH.Colors.Neutral, Thickness = 2, Parent = overlay })
local function ovLabel(y, h, font, size, color)
    return create("TextLabel", {
        Size = UDim2.new(1, 0, 0, h), Position = UDim2.new(0, 0, 0, y),
        BackgroundTransparency = 1, Font = font, TextSize = size, TextColor3 = color, Text = "", Parent = overlay,
    })
end
local ovTitle = ovLabel(4,   34, Enum.Font.GothamBold,   24, TH.Colors.Neutral)
local ovNet   = ovLabel(38,  20, Enum.Font.GothamBold,   15, TH.Colors.Neutral)
local ovLine1 = ovLabel(62,  16, Enum.Font.GothamMedium, 12, T.Text)
local ovThey  = ovLabel(80,  16, Enum.Font.GothamMedium, 12, TH.Colors.Win)
local ovYou   = ovLabel(98,  16, Enum.Font.GothamMedium, 12, TH.Colors.Lose)
local ovLine2 = ovLabel(118, 16, Enum.Font.Gotham,       11, T.SubText)

-- separate gem window
local gemWin = create("Frame", {
    Size = UDim2.fromOffset(250, 80), AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = T.Bg, BorderSizePixel = 0, Visible = false, Parent = overlayGui,
}, { corner(12), stroke(TH.Colors.Gem, 0.3, 2) })
local gemTitle = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 6),
    BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TH.Colors.Gem, Text = "", Parent = gemWin,
})
local gemGive = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 30),
    BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Text, Text = "", Parent = gemWin,
})
local gemGet = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 52),
    BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Text, Text = "", Parent = gemWin,
})

-- hover window (Value / Demand / Stability / Sign)
local tipGui = create("ScreenGui", {
    Name = TIP_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 110, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
})
local TIP_SIZE = Vector2.new(270, 120)
local tip = create("Frame", {
    Size = UDim2.fromOffset(TIP_SIZE.X, TIP_SIZE.Y), BackgroundColor3 = T.Bg,
    BorderSizePixel = 0, Visible = false, Parent = tipGui,
}, { corner(10), stroke(T.Accent, 0.2, 2) })
local function tipLabel(y, h, font, size, color)
    return create("TextLabel", {
        Size = UDim2.new(1, -20, 0, h), Position = UDim2.new(0, 10, 0, y),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Font = font, TextSize = size,
        TextColor3 = color, Text = "", Parent = tip,
    })
end
local tipName      = tipLabel(6,  22, Enum.Font.GothamBold,   14, T.Text)
local tipValue     = tipLabel(29, 18, Enum.Font.GothamMedium, 13, T.Accent)
local tipDemand    = tipLabel(50, 18, Enum.Font.GothamMedium, 13, T.Text)
local tipStability = tipLabel(71, 18, Enum.Font.GothamMedium, 13, T.Text)
local tipSign      = tipLabel(92, 18, Enum.Font.GothamMedium, 13, T.SubText)

-- on-screen debug window
local dbgWin = create("Frame", {
    Size = UDim2.fromOffset(560, 420), Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, BorderSizePixel = 0,
    Visible = false, Parent = tipGui,
}, { corner(8), stroke(TH.Colors.Sign, 0.2, 1), pad(8, 8, 8, 8) })
local dbgText = create("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Code, TextSize = 12, TextColor3 = T.Text, Text = "", Parent = dbgWin,
})

local function demandColor(d)
    if d >= 7 then return TH.Colors.Win end
    if d >= 4 then return TH.Colors.Fair end
    return TH.Colors.Lose
end

local function stabilityColor(s)
    local l = tostring(s):lower()
    if l:find("unwanted") or l:find("dropping") or l:find("unstable") then return TH.Colors.Lose end
    if l:find("fluctuat") or l:find("paid") then return TH.Colors.Fair end
    if l:find("stable") then return TH.Colors.Win end
    return TH.Colors.Neutral
end

local lastDumped, lastDumpT = nil, 0

local function updateDebug(pg, it)
    if not (CFG.TradeHelper.DebugSign and it) then
        dbgWin.Visible = false
        lastDumped = nil
        return
    end
    local now = tick()
    if lastDumped == it and now - lastDumpT < 0.6 then return end
    lastDumped, lastDumpT = it, now
    local lines = buildDump(pg, it)
    if setclipboard then pcall(setclipboard, table.concat(lines, "\n")) end
    local shown = {}
    for i = 1, math.min(#lines, TH.DebugLines) do shown[i] = lines[i] end
    if #lines > TH.DebugLines then shown[#shown + 1] = "... +" .. (#lines - TH.DebugLines) .. " lines (full dump in clipboard)" end
    dbgText.Text = table.concat(shown, "\n")
    dbgWin.Visible = true
end

local function updateTip(pg, tf)
    local it = itemUnderMouse(pg, tf)
    updateDebug(pg, it)
    if not it then
        tip.Visible = false
        return
    end
    local rawName = it:GetAttribute(ATTR_NAME) or it.Name
    local e = LOOKUP[norm(rawName)]
    tipName.Text = e and e.n or tostring(rawName)
    local lV, lD, lS, lG = tx("Value"), tx("Demand"), tx("Stability"), tx("Sign")
    if e then
        local sign = CFG.TradeHelper.UseSigns and getHoverSign(pg, it) or false
        local v, s = slotValue(it, e, sign)
        if s then
            tipValue.Text = lV .. ": " .. fmt(e.v) .. " → " .. fmt(v)
            tipSign.Text = string.format("%s: +%s%%  (%s)", lG, tostring(s.pct), s.name)
            tipSign.TextColor3 = TH.Colors.Sign
        else
            tipValue.Text = lV .. ": " .. fmt(e.v)
            tipSign.Text = lG .. ": -"
            tipSign.TextColor3 = T.SubText
        end
        tipDemand.Text = lD .. ": " .. tostring(e.d) .. "/10"
        tipDemand.TextColor3 = demandColor(e.d)
        tipStability.Text = lS .. ": " .. tostring(e.s or "-")
        tipStability.TextColor3 = stabilityColor(e.s or "")
    else
        tipValue.Text = lV .. ": " .. tx("not in list")
        tipDemand.Text = lD .. ": -"
        tipDemand.TextColor3 = T.SubText
        tipStability.Text = lS .. ": -"
        tipStability.TextColor3 = T.SubText
        tipSign.Text = lG .. ": -"
        tipSign.TextColor3 = T.SubText
    end
    local m = UserInputService:GetMouseLocation()
    local vp = viewport()
    local x = m.X + TH.TipOffsetX
    if x + TIP_SIZE.X > vp.X - 6 then x = m.X - TH.TipOffsetX - TIP_SIZE.X end
    local y = math.max(math.min(m.Y + TH.TipOffsetY, vp.Y - TIP_SIZE.Y - 6), 6)
    tip.Position = UDim2.fromOffset(math.max(x, 6), y)
    tip.Visible = true
end

local function hideAll()
    overlay.Visible = false
    gemWin.Visible = false
    tip.Visible = false
    dbgWin.Visible = false
end

local function syncInset(tf)
    local tradeGui = tf:FindFirstAncestorWhichIsA("ScreenGui")
    if tradeGui then
        if overlayGui.IgnoreGuiInset ~= tradeGui.IgnoreGuiInset then
            overlayGui.IgnoreGuiInset = tradeGui.IgnoreGuiInset
        end
    end
end

local acc = 0
track(RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < TH.Tick then return end
    acc = 0

    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local tf = pg and dig(pg, P_TRADE)
    if not tf or not isShown(tf) then resetSignMem() end
    if not CFG.TradeHelper.Enabled or not tf or not isShown(tf) then
        hideAll()
        return
    end

    syncInset(tf)
    local ap, as = tf.AbsolutePosition, tf.AbsoluteSize
    local cx = ap.X + as.X / 2
    local vp = viewport()
    local ovY = math.max(ap.Y - OVERLAY_LIFT, 60)

    -- hover window
    updateTip(pg, tf)

    local mine  = readOffer(dig(tf, P_MY_ITEMS))
    local their = readOffer(dig(tf, P_THEIR_ITEMS))
    local give, get = mine.total, their.total
    local myRaw, mySgn, thRaw, thSgn = mine.raw, mine.sgn, their.raw, their.sgn

    -- gem window
    if CFG.TradeHelper.IncludeGems then
        local mg, tg = dig(tf, P_MY_GEMS), dig(tf, P_THEIR_GEMS)
        local myGems    = mg and parseNum(mg.Text) or 0
        local theirGems = tg and parseNum(tg.Text) or 0
        local myConv    = myGems * TH.GemValue
        local theirConv = theirGems * TH.GemValue
        give += myConv
        get  += theirConv
        myRaw += myConv
        mySgn += myConv
        thRaw += theirConv
        thSgn += theirConv

        gemTitle.Text = string.format("%s   1 %s = %s", tx("GEMS"), tx("gem"), tostring(TH.GemValue))
        gemGive.Text  = string.format("%s: %s %s = %s", tx("you give"), fmt(myGems), tx("gems"), fmt1(myConv))
        gemGet.Text   = string.format("%s: %s %s = %s", tx("you get"), fmt(theirGems), tx("gems"), fmt1(theirConv))
        gemWin.Position = UDim2.fromOffset(cx, math.min(ap.Y + as.Y + 8, vp.Y - 88))
        gemWin.Visible = true
    else
        gemWin.Visible = false
    end

    -- verdict
    local unknown = mine.unknown + their.unknown
    local signed  = mine.signed + their.signed

    if give == 0 and get == 0 then
        local empty = (mine.count + their.count) == 0
        ovTitle.Text = empty and tx("WAITING") or tx("NO DATA")
        ovTitle.TextColor3 = TH.Colors.Neutral
        ovNet.Text = ""
        ovStroke.Color = TH.Colors.Neutral
        ovLine1.Text = empty and tx("add items to the trade") or tx("items are not in the value list")
        ovThey.Text = ""
        ovYou.Text = ""
        ovLine2.Text = ""
        overlay.Position = UDim2.fromOffset(cx, ovY)
        overlay.Visible = true
        return
    end

    local diff = get - give
    local pct = diff / math.max(give, get) * 100
    local verdict, col
    if math.abs(pct) <= TH.FairPct then
        verdict, col = "FAIR", TH.Colors.Fair
    elseif pct > 0 then
        verdict, col = "WIN", TH.Colors.Win
    else
        verdict, col = "LOSE", TH.Colors.Lose
    end

    local dMine  = mine.dw  > 0 and string.format("%.1f", mine.dw  / mine.total)  or "-"
    local dTheir = their.dw > 0 and string.format("%.1f", their.dw / their.total) or "-"

    ovTitle.Text = string.format("%s  %+.0f%%", tx(verdict), pct)
    ovTitle.TextColor3 = col
    ovNet.Text = string.format("%s %s%s%s", tx("net"), diff >= 0 and "+" or "-", fmt(math.abs(diff)),
        (CFG.TradeHelper.UseSigns and signed > 0) and ("  " .. tx("(with signs)")) or "")
    ovNet.TextColor3 = col
    ovStroke.Color = col
    ovLine1.Text = string.format("%s %s   |   %s %s", tx("give"), fmt(give), tx("get"), fmt(get))
    ovThey.Text = signLine(tx("THEY GIVE"), thRaw, thSgn)
    ovYou.Text = signLine(tx("YOU GIVE"), myRaw, mySgn)
    ovLine2.Text = string.format("%s %s → %s", tx("demand"), dMine, dTheir)
        .. (signed > 0 and ("   |   " .. signed .. " " .. tx("signed")) or "")
        .. (unknown > 0 and ("   |   " .. unknown .. " " .. tx("not in list")) or "")
    overlay.Position = UDim2.fromOffset(cx, ovY)
    overlay.Visible = true
end))

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
local screen = create("ScreenGui", {
    Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
})

local main = create("Frame", {
    Name = "Main", Size = CFG.WindowSize, Active = true,
    Position = UDim2.new(0.5, -CFG.WindowSize.X.Offset / 2, 0.5, -CFG.WindowSize.Y.Offset / 2),
    BackgroundColor3 = T.Bg, BackgroundTransparency = CFG.Settings.Transparency,
    BorderSizePixel = 0, ClipsDescendants = true, Parent = screen,
}, { corner(12), stroke(T.Accent, 0.55, 1) })
local uiScale = create("UIScale", { Scale = CFG.Settings.Scale, Parent = main })

local titleBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = main,
}, { corner(12) })
create("Frame", {
    Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = titleBar,
})

-- drag zone is separate from the buttons, so clicking the close / minimize buttons never starts a drag
local dragZone = create("TextButton", {
    Size = UDim2.new(1, -84, 1, 0), BackgroundTransparency = 1, Text = "",
    AutoButtonColor = false, Parent = titleBar,
})
create("TextLabel", {
    Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1, Text = CFG.Title, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Text, Parent = titleBar,
})

local function titleButton(icon, xOff, hoverKey)
    local b = create("TextButton", {
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, xOff, 0.5, -14),
        BackgroundColor3 = T.Element, Text = "", AutoButtonColor = false, ZIndex = 5, Parent = titleBar,
    }, { corner(8) })
    local function bar(w, rot)
        create("Frame", {
            Size = UDim2.fromOffset(w, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Rotation = rot, BackgroundColor3 = T.Text, BorderSizePixel = 0, ZIndex = 6, Parent = b,
        }, { corner(1) })
    end
    if icon == "x" then bar(14, 45) bar(14, -45) else bar(12, 0) end
    track(b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = T[hoverKey] }) end))
    track(b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.Element }) end))
    return b
end

local closeBtn = titleButton("x", -38, "Danger")
local minBtn   = titleButton("min", -72, "Hover")

local body = create("Frame", {
    Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0, 0, 0, 40),
    BackgroundTransparency = 1, Parent = main,
})

local sidebar = create("Frame", {
    Size = UDim2.new(0, CFG.SidebarWidth, 1, 0), BackgroundColor3 = T.Panel,
    BorderSizePixel = 0, Parent = body,
})
create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 14, 0, 10),
    BackgroundTransparency = 1, Text = "AZUL", TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = T.Accent, Parent = sidebar,
})
local tabList = create("Frame", {
    Size = UDim2.new(1, -16, 1, -96), Position = UDim2.new(0, 8, 0, 50),
    BackgroundTransparency = 1, Parent = sidebar,
}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local hintLbl = create("TextLabel", {
    Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 14, 1, -38),
    BackgroundTransparency = 1, Text = "", TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.SubText, Parent = sidebar,
})
local function applyHint()
    hintLbl.Text = CFG.Settings.ToggleKey .. " — " .. tx("hide / show") .. "\n" .. CFG.Settings.UnloadKey .. " — " .. tx("unload")
end
applyHint()

local content = create("Frame", {
    Size = UDim2.new(1, -CFG.SidebarWidth, 1, 0), Position = UDim2.new(0, CFG.SidebarWidth, 0, 0),
    BackgroundTransparency = 1, Parent = body,
})

do
    local dragging, dragStart, startPos = false, nil, nil
    track(dragZone.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local minimized = false
track(minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        body.Visible = false
        tween(main, 0.18, { Size = UDim2.fromOffset(CFG.WindowSize.X.Offset, 40) })
    else
        tween(main, 0.18, { Size = CFG.WindowSize })
        body.Visible = true
    end
end))

local function unload()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    pcall(function() RunService:UnbindFromRenderStep(VIS.StepName) end)
    restoreAll()
    clearTrail()
    clearHighlight()
    pcall(function() overlayGui:Destroy() end)
    pcall(function() tipGui:Destroy() end)
    pcall(function() hudGui:Destroy() end)
    pcall(function() screen:Destroy() end)
    ENV.AzulUnload = nil
end
ENV.AzulUnload = unload

track(closeBtn.MouseButton1Click:Connect(unload))

local rebinding = nil -- function(KeyCode) while waiting for a key in Settings
track(UserInputService.InputBegan:Connect(function(i, gp)
    if rebinding then
        if i.UserInputType == Enum.UserInputType.Keyboard then
            local cb = rebinding
            rebinding = nil
            cb(i.KeyCode)
        end
        return
    end
    if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local n = i.KeyCode.Name
    if n == CFG.Settings.UnloadKey then unload() return end
    if n == CFG.Settings.ToggleKey then screen.Enabled = not screen.Enabled end
end))

----------------------------------------------------------------
-- COMPONENTS
----------------------------------------------------------------
local refreshers = {} -- re-render callbacks, run after config load

local function newPage()
    return create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, Parent = content,
    }, {
        pad(14, 14, 14, 14),
        create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
end

-- segmented OFF | ON switch, highlight slides to the active half
local function makeSwitch(parentObj, pos, get, set)
    local sw = create("TextButton", {
        Size = UDim2.fromOffset(64, 24), Position = pos, Text = "", AutoButtonColor = false,
        BorderSizePixel = 0, BackgroundColor3 = T.Bg, ZIndex = 5, Parent = parentObj,
    }, { corner(7), stroke(T.Off, 0.2, 1) })
    local hlBar = create("Frame", {
        Size = UDim2.new(0.5, -3, 1, -6), BorderSizePixel = 0, ZIndex = 6, Parent = sw,
        Position = get() and UDim2.new(0.5, 0, 0, 3) or UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = get() and T.Accent or T.Off,
    }, { corner(5) })
    local function half(txt, x)
        return create("TextLabel", {
            Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(x, 0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 10, Text = txt, TextColor3 = T.SubText, ZIndex = 7, Parent = sw,
        })
    end
    local lblOff, lblOn = half("OFF", 0), half("ON", 0.5)
    local function render()
        local on = get()
        tween(hlBar, 0.15, {
            Position = on and UDim2.new(0.5, 0, 0, 3) or UDim2.new(0, 3, 0, 3),
            BackgroundColor3 = on and T.Accent or T.Off,
        })
        lblOn.TextColor3 = on and T.Text or T.SubText
        lblOff.TextColor3 = on and T.SubText or T.Text
    end
    render()
    track(sw.MouseButton1Click:Connect(function()
        set(not get())
        render()
    end))
    refreshers[#refreshers + 1] = render
    return sw, render
end

-- whole row is clickable, not only the switch
local function addToggle(parentFrame, label, get, set)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Element, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, Parent = parentFrame,
    }, { corner(8) })
    create("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1, Text = label, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text, Parent = row,
    })
    local _, render = makeSwitch(row, UDim2.new(1, -76, 0.5, -12), get, set)
    track(row.MouseButton1Click:Connect(function()
        set(not get())
        render()
    end))
    track(row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = T.Hover }) end))
    track(row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = T.Element }) end))
end

local function bindDrag(bar, onX)
    local dragging = false
    track(bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            onX(i.Position.X)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            onX(i.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function sliderRow(parentFrame, label)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.Element, BorderSizePixel = 0, Parent = parentFrame,
    }, { corner(8) })
    create("TextLabel", {
        Size = UDim2.new(1, -90, 0, 28), Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1, Text = label, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text, Parent = row,
    })
    return row
end

local function addSlider(parentFrame, label, min, max, step, get, set, suffix)
    suffix = suffix or ""
    local row = sliderRow(parentFrame, label)
    local valLbl = create("TextLabel", {
        Size = UDim2.fromOffset(70, 28), Position = UDim2.new(1, -82, 0, 0),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.SubText, Parent = row,
    })
    local bar = create("Frame", {
        Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 35),
        BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = row,
    }, { corner(3) })
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar,
    }, { corner(3) })
    local function render()
        local v = get()
        fill.Size = UDim2.new(math.clamp((v - min) / (max - min), 0, 1), 0, 1, 0)
        valLbl.Text = tostring(v) .. suffix
    end
    bindDrag(bar, function(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = min + a * (max - min)
        v = math.floor(v / step + 0.5) * step
        v = math.floor(v * 1000 + 0.5) / 1000
        set(math.clamp(v, min, max))
        render()
    end)
    refreshers[#refreshers + 1] = render
    render()
end

local function addColorBar(parentFrame, label, get, set)
    local row = sliderRow(parentFrame, label)
    local preview = create("Frame", {
        Size = UDim2.fromOffset(24, 14), Position = UDim2.new(1, -36, 0, 7),
        BackgroundColor3 = Color3.fromHSV(get(), 1, 1), BorderSizePixel = 0, Parent = row,
    }, { corner(4) })
    preview:SetAttribute("NoTheme", true)
    local bar = create("Frame", {
        Size = UDim2.new(1, -24, 0, 8), Position = UDim2.new(0, 12, 0, 34),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = row,
    }, {
        corner(4),
        create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
                ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
                ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
                ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
                ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
                ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
                ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
            }),
        }),
    })
    bar:SetAttribute("NoTheme", true)
    bindDrag(bar, function(x)
        local h = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        set(h)
        preview.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    end)
    refreshers[#refreshers + 1] = function() preview.BackgroundColor3 = Color3.fromHSV(get(), 1, 1) end
end

local function addButton(parentFrame, label, fn)
    local b = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.Element, BorderSizePixel = 0,
        AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = T.Text, Text = label, Parent = parentFrame,
    }, { corner(8) })
    track(b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.Hover }) end))
    track(b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.Element }) end))
    track(b.MouseButton1Click:Connect(function()
        local msg = fn()
        if msg then
            b.Text = tx(msg)
            task.delay(1.5, function()
                if b.Parent then b.Text = tx(label) end
            end)
        end
    end))
    return b
end

local function addKeybind(parentFrame, label, get, set)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Element, BorderSizePixel = 0, Parent = parentFrame,
    }, { corner(8) })
    create("TextLabel", {
        Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1, Text = label, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text, Parent = row,
    })
    local btn = create("TextButton", {
        Size = UDim2.fromOffset(104, 26), Position = UDim2.new(1, -114, 0.5, -13),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0, AutoButtonColor = false,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Accent, Text = get(), Parent = row,
    }, { corner(6), stroke(T.Accent, 0.6, 1) })
    local function render() btn.Text = get() end
    track(btn.MouseButton1Click:Connect(function()
        btn.Text = tx("press a key...")
        rebinding = function(key)
            if key and key ~= Enum.KeyCode.Escape and key ~= Enum.KeyCode.Unknown then set(key.Name) end
            render()
        end
    end))
    refreshers[#refreshers + 1] = render
end

-- expandable section; header has its own ON/OFF switch so the function can be toggled while collapsed
local function addSection(page, title, subtitle, getOn, setOn)
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = page,
    }, {
        corner(10), stroke(T.Accent, 0.8, 1),
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, LayoutOrder = 1, Parent = holder,
    })
    create("TextLabel", {
        Size = UDim2.new(1, -140, 0, 22), Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1, Text = title, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.Text, Parent = header,
    })
    create("TextLabel", {
        Size = UDim2.new(1, -140, 0, 14), Position = UDim2.new(0, 14, 0, 29),
        BackgroundTransparency = 1, Text = subtitle, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.SubText, Parent = header,
    })
    local arrow = create("TextLabel", {
        Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -34, 0.5, -12),
        BackgroundTransparency = 1, Text = "›", Font = Enum.Font.GothamBold,
        TextSize = 22, TextColor3 = T.Accent, Parent = header,
    })
    if getOn then
        makeSwitch(header, UDim2.new(1, -106, 0.5, -12), getOn, setOn)
    end
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = false, LayoutOrder = 2, Parent = holder,
    }, {
        pad(10, 0, 10, 10),
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local open = false
    track(header.MouseButton1Click:Connect(function()
        open = not open
        inner.Visible = open
        tween(arrow, 0.15, { Rotation = open and 90 or 0 })
    end))
    return inner
end

-- themes: swap colors in place, then recolor every themed instance by matching its old color
local function ckey(c)
    return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end

local function recolor(root, map)
    local function fix(o, prop)
        local n = map[ckey(o[prop])]
        if n then o[prop] = n end
    end
    local list = root:GetDescendants()
    list[#list + 1] = root
    for _, o in ipairs(list) do
        if not o:GetAttribute("NoTheme") then
            if o:IsA("GuiObject") then fix(o, "BackgroundColor3") end
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then fix(o, "TextColor3") end
            if o:IsA("ScrollingFrame") then fix(o, "ScrollBarImageColor3") end
            if o:IsA("UIStroke") then fix(o, "Color") end
        end
    end
end

local themeChecks = {}
local function applyTheme(name)
    local preset = THEMES[name]
    if not preset then return end
    local map = {}
    for k, v in pairs(preset) do
        if T[k] and ckey(T[k]) ~= ckey(v) then map[ckey(T[k])] = v end
    end
    for k, v in pairs(preset) do T[k] = v end
    CFG.Settings.Theme = name
    if next(map) then
        for _, root in ipairs({ screen, overlayGui, tipGui, statsLabel, wmLabel }) do recolor(root, map) end
    end
    for n, c in pairs(themeChecks) do c.Visible = (n == name) end
end

local function addChoiceList(parentFrame, items, isCurrent, onPick, checks)
    for _, it in ipairs(items) do
        local row = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.Element, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "", Parent = parentFrame,
        }, { corner(8) })
        if it.color then
            local swatch = create("Frame", {
                Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 10, 0.5, -9),
                BackgroundColor3 = it.color, BorderSizePixel = 0, Parent = row,
            }, { corner(9) })
            swatch:SetAttribute("NoTheme", true)
        end
        create("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, it.color and 38 or 14, 0, 0),
            BackgroundTransparency = 1, Text = it.label, TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text, Parent = row,
        })
        checks[it.id] = create("Frame", {
            Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -26, 0.5, -5),
            BackgroundColor3 = T.Accent, BorderSizePixel = 0, Visible = isCurrent(it.id), Parent = row,
        }, { corner(5) })
        track(row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = T.Hover }) end))
        track(row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = T.Element }) end))
        track(row.MouseButton1Click:Connect(function() onPick(it.id) end))
    end
end

----------------------------------------------------------------
-- TABS
----------------------------------------------------------------
local tabs = {}
local function selectTab(target)
    for _, t in ipairs(tabs) do
        local active = t == target
        t.page.Visible = active
        t.bar.Visible = active
        tween(t.btn, 0.15, { BackgroundTransparency = active and 0 or 1, BackgroundColor3 = T.Element })
        tween(t.lbl, 0.15, { TextColor3 = active and T.Text or T.SubText })
    end
end

local function addTab(name)
    local page = newPage()
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Element, BackgroundTransparency = 1,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        LayoutOrder = #tabs + 1, Parent = tabList,
    }, { corner(8) })
    local bar = create("Frame", {
        Size = UDim2.fromOffset(3, 18), Position = UDim2.new(0, 5, 0.5, -9),
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, Visible = false, Parent = btn,
    }, { corner(2) })
    local lbl = create("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1, Text = name, TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.SubText, Parent = btn,
    })
    local tab = { page = page, btn = btn, bar = bar, lbl = lbl }
    tabs[#tabs + 1] = tab
    track(btn.MouseButton1Click:Connect(function() selectTab(tab) end))
    return page, tab
end

local exploitsPage, exploitsTab = addTab("Exploits")
local visualPage = addTab("Visual")
local settingsPage = addTab("Settings")

----------------------------------------------------------------
-- EXPLOITS > Trade Helper
----------------------------------------------------------------
local th = addSection(exploitsPage, "Trade Helper", "Win / Fair / Lose on the trade screen",
    function() return CFG.TradeHelper.Enabled end,
    function(v) CFG.TradeHelper.Enabled = v end)
addToggle(th, "Count gems",
    function() return CFG.TradeHelper.IncludeGems end,
    function(v) CFG.TradeHelper.IncludeGems = v end)
addToggle(th, "Count signs (+%)",
    function() return CFG.TradeHelper.UseSigns end,
    function(v) CFG.TradeHelper.UseSigns = v end)
addToggle(th, "Sign debug (on screen)",
    function() return CFG.TradeHelper.DebugSign end,
    function(v) CFG.TradeHelper.DebugSign = v lastDumped = nil end)

----------------------------------------------------------------
-- VISUAL
----------------------------------------------------------------
local tr = addSection(visualPage, "Trails", "Trail behind your character",
    function() return CFG.Trails.Enabled end,
    function(v) CFG.Trails.Enabled = v applyTrailState() end)
addToggle(tr, "Rainbow",
    function() return CFG.Trails.Rainbow end,
    function(v) CFG.Trails.Rainbow = v if not v then updateTrail() end end)
addColorBar(tr, "Color",
    function() return CFG.Trails.Hue end,
    function(v) CFG.Trails.Hue = v updateTrail() end)
addSlider(tr, "Lifetime", 0.2, 5, 0.1,
    function() return CFG.Trails.Lifetime end,
    function(v) CFG.Trails.Lifetime = v updateTrail() end, "s")
addSlider(tr, "Width", 0.1, 3, 0.1,
    function() return CFG.Trails.Width end,
    function(v) CFG.Trails.Width = v updateTrail() end)
addSlider(tr, "Transparency", 0, 1, 0.05,
    function() return CFG.Trails.Transparency end,
    function(v) CFG.Trails.Transparency = v updateTrail() end)

local secWorld = addSection(visualPage, "World", "Fullbright, fog, time of day",
    function() return V.World.Fullbright end,
    function(v) V.World.Fullbright = v end)
addSlider(secWorld, "Brightness", 1, 6, 0.5,
    function() return V.World.Brightness end,
    function(v) V.World.Brightness = v end)
addToggle(secWorld, "No fog",
    function() return V.World.NoFog end,
    function(v) V.World.NoFog = v end)
addToggle(secWorld, "Custom time of day",
    function() return V.World.CustomTime end,
    function(v) V.World.CustomTime = v end)
addSlider(secWorld, "Time of day", 0, 24, 0.5,
    function() return V.World.Hour end,
    function(v) V.World.Hour = v end, "h")

local secCam = addSection(visualPage, "Camera", "FOV and zoom limit",
    function() return V.Camera.FovEnabled end,
    function(v) V.Camera.FovEnabled = v end)
addSlider(secCam, "Field of view", 30, 120, 1,
    function() return V.Camera.Fov end,
    function(v) V.Camera.Fov = v end, "°")
addToggle(secCam, "Unlock zoom",
    function() return V.Camera.ZoomUnlock end,
    function(v) V.Camera.ZoomUnlock = v end)
addSlider(secCam, "Max zoom", 50, 1000, 25,
    function() return V.Camera.ZoomMax end,
    function(v) V.Camera.ZoomMax = v end)

local secGlow = addSection(visualPage, "Character glow", "Highlight on your own character",
    function() return V.Glow.Enabled end,
    function(v) V.Glow.Enabled = v applyHighlightState() end)
addToggle(secGlow, "Rainbow",
    function() return V.Glow.Rainbow end,
    function(v) V.Glow.Rainbow = v updateHighlight() end)
addColorBar(secGlow, "Color",
    function() return V.Glow.Hue end,
    function(v) V.Glow.Hue = v updateHighlight() end)
addSlider(secGlow, "Fill transparency", 0, 1, 0.05,
    function() return V.Glow.FillTransparency end,
    function(v) V.Glow.FillTransparency = v updateHighlight() end)

local secHud = addSection(visualPage, "Stats HUD", "FPS and ping in the corner",
    function() return V.Hud.Enabled end,
    function(v) V.Hud.Enabled = v updateHud() end)
addToggle(secHud, "Show FPS",
    function() return V.Hud.Fps end,
    function(v) V.Hud.Fps = v updateHud() end)
addToggle(secHud, "Show ping",
    function() return V.Hud.Ping end,
    function(v) V.Hud.Ping = v updateHud() end)

local secWm = addSection(visualPage, "Watermark", "Azul in the top-left corner",
    function() return V.Watermark.Enabled end,
    function(v) V.Watermark.Enabled = v updateWatermark() end)
addSlider(secWm, "Size", 0.5, 3, 0.1,
    function() return V.Watermark.Scale end,
    function(v) V.Watermark.Scale = v updateWatermark() end, "x")
addToggle(secWm, "Show username",
    function() return V.Watermark.ShowUser end,
    function(v) V.Watermark.ShowUser = v updateWatermark() end)
addToggle(secWm, "Show FPS",
    function() return V.Watermark.ShowFps end,
    function(v) V.Watermark.ShowFps = v updateWatermark() end)

----------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------
local langChecks = {}
local function applyLanguage()
    for _, e in ipairs(locList) do
        if e[1].Parent then e[1].Text = tx(e[2]) end
    end
    applyHint()
    for id, c in pairs(langChecks) do c.Visible = (id == CFG.Settings.Language) end
end

local secLang = addSection(settingsPage, "Language", "Interface language")
addChoiceList(secLang, { { id = "en", label = "English" }, { id = "ru", label = "Русский" } },
    function(id) return CFG.Settings.Language == id end,
    function(id) CFG.Settings.Language = id applyLanguage() end,
    langChecks)

local secTheme = addSection(settingsPage, "Theme", "Interface color scheme")
local themeItems = {}
for _, name in ipairs(THEME_ORDER) do
    themeItems[#themeItems + 1] = { id = name, label = name, color = THEMES[name].Accent }
end
addChoiceList(secTheme, themeItems,
    function(id) return CFG.Settings.Theme == id end,
    applyTheme, themeChecks)

local secMenu = addSection(settingsPage, "Menu", "Keys and window look")
addKeybind(secMenu, "Hide / show key",
    function() return CFG.Settings.ToggleKey end,
    function(n) CFG.Settings.ToggleKey = n applyHint() end)
addKeybind(secMenu, "Unload key",
    function() return CFG.Settings.UnloadKey end,
    function(n) CFG.Settings.UnloadKey = n applyHint() end)
addSlider(secMenu, "Window scale", 0.7, 1.3, 0.05,
    function() return CFG.Settings.Scale end,
    function(v) CFG.Settings.Scale = v uiScale.Scale = v end, "x")
addSlider(secMenu, "Window transparency", 0, 0.6, 0.05,
    function() return CFG.Settings.Transparency end,
    function(v) CFG.Settings.Transparency = v main.BackgroundTransparency = v end)

local function applyAll()
    applyTheme(CFG.Settings.Theme)
    uiScale.Scale = CFG.Settings.Scale
    main.BackgroundTransparency = CFG.Settings.Transparency
    applyTrailState()
    updateTrail()
    applyHighlightState()
    updateHud()
    updateWatermark()
    for _, r in ipairs(refreshers) do r() end
    applyLanguage()
end

local secCfg = addSection(settingsPage, "Config", "Saved to " .. VIS.SaveFile)
addButton(secCfg, "Save config", saveConfig)
addButton(secCfg, "Load config", function()
    local msg = loadConfig()
    applyAll()
    return msg
end)

applyAll()
selectTab(exploitsTab)
