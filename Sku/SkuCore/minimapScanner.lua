---------------------------------------------------------------------------------------------------------------------------------------
local MODULE_NAME, MODULE_PART = "SkuCore", "minimapScanner"
local L = Sku.L
local GetNumTrackingTypes = Sku.Compat.GetNumTrackingTypes
local GetTrackingInfo = Sku.Compat.GetTrackingInfo
local SetTracking = Sku.Compat.SetTracking
local _G = _G

-- File-level state that used to leak into _G through a missing "local".
local tRessourceTypes, toptionTypes

SkuCore = SkuCore or LibStub("AceAddon-3.0"):NewAddon("SkuCore", "AceConsole-3.0", "AceEvent-3.0")

-- W4 Phase D: MinimapScanner is a real AceAddon SUBMODULE of SkuCore so it can be
-- turned on/off at runtime. The Core.lua keybind handlers and the OnUpdate frame
-- call its scan methods via the published handle SkuCore.MinimapScanner; the feature
-- turns "off" purely because OnDisable stops the active scan and removes the
-- OnUpdate driver. OnEnable arms it (chat command + OnUpdate frame), replacing the
-- old explicit MinimapScannerOnLogin() call in PLAYER_ENTERING_WORLD (which
-- only ran on the initial login, so the scanner did not re-arm after a /reload —
-- OnEnable fixes that by arming on every load).
-- W4 Phase E (namespace extraction): all of MinimapScanner's own methods and
-- module state now live on the module table `MinimapScanner` itself
-- (function MinimapScanner:Method) instead of on the shared SkuCore god-object.
-- The module mixes in AceConsole-3.0 so its /as + /activeSeekings chat commands
-- resolve their handler (SlashActiveSeekings) on the module. External callers use
-- the published handle SkuCore.MinimapScanner, and the cross-module scan-state
-- flags (IsMMScanning, MinimapScanFastRunning, noMouseOverNotification) are read
-- via SkuCore.MinimapScanner.<field>.
local MinimapScanner = SkuCore:NewModule("MinimapScanner", "AceConsole-3.0")
SkuCore.MinimapScanner = MinimapScanner   -- keep the published handle

-- Make this feature user-toggleable (Features menu + persisted on/off).
SkuCore:RegisterToggleableModule("MinimapScanner", function()
   return Sku.deEn("Minikarten-Scanner", "Minimap scanner", "Scanner de minicarte")
end)

SkuCore.RessourceTypes = {
   chests = {
      [1] = { deDE = "Beschädigte Truhe", enUS = "Damaged Chest", zhCN = "破损的箱子", ruRU = "Повреждённый сундук",},
      [2] = { deDE = "Verbeulte Truhe", enUS = "Dented Chest", zhCN = "凹陷的箱子", ruRU = "Проломленный ящик",},
      [3] = { deDE = "Große ramponierte Truhe", enUS = "Large Battered Chest", zhCN = "破碎的大箱子", ruRU = "Большой побитый сундук",},
      [4] = { deDE = "Große eisenbeschlagene Truhe", enUS = "Large Iron Bound Chest", zhCN = "大型铁箍储物箱", ruRU = "Окованный железом большой сундук",},
      [5] = { deDE = "Große mithrilbeschlagene Truhe", enUS = "Large Mithril Bound Chest", zhCN = "大型秘银储物箱", ruRU = "Окованный мифрилом большой сундук",},
      [6] = { deDE = "Große robuste Truhe", enUS = "Large Solid Chest", zhCN = "兼顾的大宝箱", ruRU = "Большой добротный сундук",},
      [7] = { deDE = "Verschlossene Truhe", enUS = "Locked Chest", zhCN = "锁定的宝箱", ruRU = "Запертый сундук",},
      [8] = { deDE = "Primitive Truhe", enUS = "Primitive Chest", zhCN = "粗糙的箱子", ruRU = "Примитивный сундук",},
      [9] = { deDE = "Rostige Truhe", enUS = "Rusty Chest", zhCN = "生锈的箱子", ruRU = "Ржавый сундук",},
      [10] = { deDE = "Robuste Truhe", enUS = "Solid Chest", zhCN = "兼顾的宝箱", ruRU = "Добротный сундук",},
      [11] = { deDE = "Versunkene Truhe", enUS = "Sunken Chest", zhCN = "沉默的宝箱", ruRU = "Затонувший сундук",},
      [12] = { deDE = "Ramponierte Truhe", enUS = "Tattered Chest", zhCN = "破损的箱子", ruRU = "Побитый сундук",},
      [13] = { deDE = "Abgenutzte Truhe", enUS = "Worn Chest", zhCN = "旧箱子", ruRU = "Подержанный сундук",},
      [14] = { deDE = "Adamantitbeschlagene Truhe", enUS = "Adamantite Bound Chest", zhCN = "加固的精金宝箱", ruRU = "Окованный адамантитом сундук",},
      [15] = { deDE = "Teufelseisentruhe", enUS = "Fel Iron Chest", zhCN = "魔铁宝箱", ruRU = "Окованный оскверненным железом сундук",},
   },
   mining = {
      [1] = { deDE = "Kupfervorkommen", enUS = "Copper Vein", zhCN = "铜矿脉", ruRU = "Медная жила",},
      [2] = { deDE = "Zinnvorkommen", enUS = "Tin Vein", zhCN = "锡矿脉", ruRU = "Оловянная жила",},
      [3] = { deDE = "Silbervorkommen", enUS = "Silver Vein", zhCN = "银矿脉", ruRU = "Серебряная жила",},
      [4] = { deDE = "Brühschlammbedecktes Silbervorkommen", enUS = "Ooze Covered Silver Vein", zhCN = "软泥覆盖的银矿脉", ruRU = "Покрытая слизью серебряная жила",},
      [5] = { deDE = "Eisenvorkommen", enUS = "Iron Deposit", zhCN = "铁矿床", ruRU = "Залежи железа",},
      [6] = { deDE = "Goldvorkommen", enUS = "Gold Vein", zhCN = "金矿脉", ruRU = "Золотая жила",},
      [7] = { deDE = "Brühschlammbedecktes Goldvorkommen", enUS = "Ooze Covered Gold Vein", zhCN = "软泥覆盖的金矿脉", ruRU = "Покрытая слизью золотая жила",},
      [8] = { deDE = "Mithrilablagerung", enUS = "Mithril Deposit", zhCN = "秘银矿床", ruRU = "Мифриловые залежи",},
      [9] = { deDE = "Brühschlammbedeckte Mithrilablagerung", enUS = "Ooze Covered Mithril Deposit", zhCN = "软泥覆盖的秘银矿床", ruRU = "Покрытые слизью мифриловые залежи",},
      [10] = { deDE = "Echtsilberablagerung", enUS = "Truesilver Deposit", zhCN = "真银矿床", ruRU = "Залежи истинного серебра",},
      [11] = { deDE = "Brühschlammbedeckte Echtsilberablagerung", enUS = "Ooze Covered Truesilver Deposit", zhCN = "软泥覆盖的真银矿床", ruRU = "Покрытые слизью залежи истинного серебра",},
      [12] = { deDE = "Kleines Thoriumvorkommen", enUS = "Small Thorium Vein", zhCN = "瑟银矿脉", ruRU = "Малая ториевая жила",},
      [13] = { deDE = "Brühschlammbedecktes Thoriumvorkommen", enUS = "Ooze Covered Thorium Vein", zhCN = "软泥覆盖的瑟银矿脉", ruRU = "Покрытая слизью ториевая жила",},
      [14] = { deDE = "Reiches Thoriumvorkommen", enUS = "Rich Thorium Vein", zhCN = "富瑟银矿脉", ruRU = "Богатая ториевая жила",},
      [15] = { deDE = "Brühschlammbedecktes reiches Thoriumvorkommen", enUS = "Ooze Covered Rich Thorium Vein", zhCN = "软泥覆盖的瑟银矿脉", ruRU = "Покрытая слизью богатая ториевая жила",},
      [16] = { deDE = "Dunkeleisenablagerung", enUS = "Dark Iron Deposit", zhCN = "黑铁矿床", ruRU = "Залежи черного железа",},
      [17] = { deDE = "Teufelseisenvorkommen", enUS = "Fel Iron Deposit", zhCN = "魔铁矿床", ruRU = "Залежи оскверненного железа",},
      [18] = { deDE = "Adamantitablagerung", enUS = "Adamantite Deposit", zhCN = "精金矿床", ruRU = "Залежи адамантита",},
      [19] = { deDE = "Reiche Adamantitablagerung", enUS = "Rich Adamantite Deposit", zhCN = "富精金矿床", ruRU = "Богатые залежи адамантита",},
      [20] = { deDE = "Khoriumvorkommen", enUS = "Khorium Vein", zhCN = "氪金矿脉", ruRU = "Кориевая жила",},
      [21] = { deDE = "Kobaltablagerung", enUS = "Cobalt Deposit", zhCN = "钴矿床", ruRU = "Залежи кобальта",},
      [22] = { deDE = "Reiche Kobaltablagerung", enUS = "Rich Cobalt Deposit", zhCN = "富钴矿床", ruRU = "Богатые залежи кобальта",},
      [23] = { deDE = "Saronitablagerung", enUS = "Saronite Deposit", zhCN = "萨隆邪铁矿床", ruRU = "Залежи саронита",},
      [24] = { deDE = "Reiche Saronitablagerung", enUS = "Rich Saronite Deposit", zhCN = "富萨隆邪铁矿床", ruRU = "Богатые залежи саронита",},
      [25] = { deDE = "Reine Saronitablagerung", enUS = "Pure Saronite Deposit", zhCN = "纯萨隆邪铁矿床", ruRU = "Месторождение чистого саронита",},
      [26] = { deDE = "Titanvorkommen", enUS = "Titanium Vein", zhCN = "钛矿脉", ruRU = "Залежи титана",},
      [27] = { deDE = "Reine Adamantitablagerung", enUS = "Pure Adamantite Deposit", zhCN = "纯钛矿床", ruRU = "missing",},
   },
   gasCollector = {
      [1] = { deDE = "Arkanvortex", enUS = "Arcane Vortex", zhCN = "奥数漩涡", ruRU = "Волшебное завихрение",},
      [2] = { deDE = "Teufelsnebel", enUS = "Felmist", zhCN = "魔物", ruRU = "Туман скверны",},
      [3] = { deDE = "Sumpfgas", enUS = "Swamp Gas", zhCN = "沼泽气体", ruRU = "Болотный газ",},
      [4] = { deDE = "Windige Wolke", enUS = "Windy Cloud", zhCN = "气体云雾", ruRU = "Грозовое облако",},
      [5] = { deDE = "Dampfwolke", enUS = "Steam Cloud", zhCN = "蒸汽云雾", ruRU = "Паровое облако",},
      [6] = { deDE = "Aschewolke", enUS = "Cinder Cloud", zhCN = "灰烬云雾", ruRU = "Облако золы",},
      [7] = { deDE = "Arktische Wolke", enUS = "Arctic Cloud", zhCN = "北极云雾", ruRU = "Снежный шар",},
   },
   herbs = {
      [1] = { deDE = "Friedensblume", enUS = "Peacebloom", zhCN = "宁神花", ruRU = "Мироцвет",},
      [2] = { deDE = "Silberblatt", enUS = "Silverleaf", zhCN = "银叶草", ruRU = "Сребролист",},
      [3] = { deDE = "Erdwurzel", enUS = "Earthroot", zhCN = "地根草", ruRU = "Земляной корень",},
      [4] = { deDE = "Maguskönigskraut", enUS = "Mageroyal", zhCN = "魔皇草", ruRU = "Магороза",},
      [5] = { deDE = "Wilddornrose", enUS = "Briarthorn", zhCN = "石南草", ruRU = "Остротерн",},
      [6] = { deDE = "Würgetang", enUS = "Stranglekelp", zhCN = "荆棘藻", ruRU = "Удавник",},
      [7] = { deDE = "Beulengras", enUS = "Bruiseweed", zhCN = "跌打草", ruRU = "Синячник",},
      [8] = { deDE = "Wildstahlblume", enUS = "Wild Steelbloom", zhCN = "野钢花", ruRU = "Дикий сталецвет",},
      [9] = { deDE = "Grabmoos", enUS = "Grave Moss", zhCN = "墓地苔", ruRU = "Могильный мох",},
      [10] = { deDE = "Königsblut", enUS = "Kingsblood", zhCN = "皇血草", ruRU = "Королевская кровь",},
      [11] = { deDE = "Lebenswurz", enUS = "Liferoot", zhCN = "活根草", ruRU = "Корень жизни",},
      [12] = { deDE = "Blassblatt", enUS = "Fadeleaf", zhCN = "枯叶草", ruRU = "Бледнолист",},
      [13] = { deDE = "Golddorn", enUS = "Goldthorn", zhCN = "荆棘草", ruRU = "Златошип",},
      [14] = { deDE = "Khadgars Schnurrbart", enUS = "Khadgar's Whisker", zhCN = "卡德加的胡须", ruRU = "Кадгаров ус",},
      [15] = { deDE = "Winterbiss", enUS = "Wintersbite", zhCN = "冬刺草", ruRU = "Морозник",},
      [16] = { deDE = "Feuerblüte", enUS = "Firebloom", zhCN = "火焰花", ruRU = "Огнецвет",},
      [17] = { deDE = "Lila Lotus", enUS = "Purple Lotus", zhCN = "紫莲花", ruRU = "Лиловый лотос",},
      [18] = { deDE = "Arthas' Tränen", enUS = "Arthas' Tears", zhCN = "阿尔萨斯之泪", ruRU = "Слезы Артаса",},
      [19] = { deDE = "Sonnengras", enUS = "Sungrass", zhCN = "太阳草", ruRU = "Солнечник",},
      [20] = { deDE = "Blindkraut", enUS = "Blindweed", zhCN = "盲目草", ruRU = "Пастушья сумка",},
      [21] = { deDE = "Geisterpilz", enUS = "Ghost Mushroom", zhCN = "幽灵菇", ruRU = "Призрачный гриб",},
      [22] = { deDE = "Gromsblut", enUS = "Gromsblood", zhCN = "格罗姆之血", ruRU = "Кровь грома",},
      [23] = { deDE = "Goldener Sansam", enUS = "Golden Sansam", zhCN = "黄金参", ruRU = "Золотой сансам",},
      [24] = { deDE = "Traumblatt", enUS = "Dreamfoil", zhCN = "梦叶草", ruRU = "Снолист",},
      [25] = { deDE = "Bergsilbersalbei", enUS = "Mountain Silversage", zhCN = "山鼠草", ruRU = "Горный серебряный шалфей",},
      [26] = { deDE = "Pestblüte", enUS = "Plaguebloom", zhCN = "瘟疫花", ruRU = "Чумоцвет",},
      [27] = { deDE = "Eiskappe", enUS = "Icecap", zhCN = "冰盖草", ruRU = "Ледяной зев",},
      [28] = { deDE = "Schwarzer Lotus", enUS = "Black Lotus", zhCN = "黑莲花", ruRU = "Черный лотос",},
      [29] = { deDE = "Teufelsgras", enUS = "Felweed", zhCN = "魔化藻", ruRU = "Сквернопля",},
      [30] = { deDE = "Traumwinde", enUS = "Dreaming Glory", zhCN = "梦露花", ruRU = "Сияние грез",},
      [31] = { deDE = "Terozapfen", enUS = "Terocone", zhCN = "泰罗果", ruRU = "Терошишка",},
      [32] = { deDE = "Zottelkappe", enUS = "Ragveil", zhCN = "邪雾草", ruRU = "Кисейница",},
      [33] = { deDE = "Urflechte", enUS = "Ancient Lichen", zhCN = "远古苔", ruRU = "Древний лишайник",},
      [34] = { deDE = "Netherblüte", enUS = "Netherbloom", zhCN = "虚空花", ruRU = "Пустоцвет",},
      [35] = { deDE = "Alptraumranke", enUS = "Nightmare Vine", zhCN = "噩梦藤", ruRU = "Ползучий кошмарник",},
      [36] = { deDE = "Manadistel", enUS = "Mana Thistle", zhCN = "法力蓟", ruRU = "Манаполох",},
      [37] = { deDE = "Teufelslotus", enUS = "Fel Lotus", zhCN = "魔莲花", ruRU = "Лотос Скверны",},
      [38] = { deDE = "Goldklee", enUS = "Goldclover", zhCN = "金苜蓿", ruRU = "Золотой клевер",},
      [39] = { deDE = "Tigerlilie", enUS = "Tiger Lily", zhCN = "卷丹", ruRU = "Тигровая лилия",},
      [40] = { deDE = "Schlangenzunge", enUS = "Adder's Tongue", zhCN = "蛇信草", ruRU = "Язык аспида",},
      [41] = { deDE = "Talandras Rose", enUS = "Talandra's Rose", zhCN = "塔兰德拉的玫瑰", ruRU = "Роза Таландры",},
      [42] = { deDE = "Lichblüte", enUS = "Lichbloom", zhCN = "巫妖花", ruRU = "Личецвет",},
      -- [2026-09-01] enUS was "Icethor" -- a typo, the herb is "Icethorn"
      -- (SkuDB.objectResourceNames.enUS and objects.lua both spell it that way).
      -- The scanner matches this string against the tooltip line, so on an
      -- English client Eisdorn/Icethorn was the one Northrend herb that could
      -- never be announced, and the gather route could not find its nodes either.
      [43] = { deDE = "Eisdorn", enUS = "Icethorn", zhCN = "冰极草", ruRU = "Ледошип",},
      [44] = { deDE = "Frostlotus", enUS = "Frost Lotus", zhCN = "雪莲花", ruRU = "Северный лотос",},
      [45] = { deDE = "Blutdistel", enUS = "Bloodthistle", zhCN = "血蓟", ruRU = "Кровопийка",},
   },
}

-- [v42.08] Franzoesische Ressourcennamen nativ ergaenzen (portiert aus Naxedims
-- SkuMinimapScannerFR). Damit erkennt der Scanner die Knoten auf einem frFR-Client am
-- (franzoesischen) Spiel-Tooltip. "frFR" steht jetzt in Sku.LocsPartly (Core.lua), also
-- ist Sku.LocP auf einem frFR-Client "frFR" und genau diese Namen greifen -- auch in
-- gameWorldObjects (Boden-Objekte). Auf deDE/enUS/... ohne Wirkung (nur ein Extra-Key).
do
   local tRessourceNamesFR = {
      chests = {
         [1] = "Coffre endommagé", [2] = "Coffre abîmé", [3] = "Grand coffre endommagé",
         [4] = "Grand coffre cerclé de fer", [5] = "Grand coffre cerclé de mithril",
         [6] = "Grand coffre solide", [7] = "Coffre verrouillé", [8] = "Coffre primitif",
         [9] = "Coffre rouillé", [10] = "Coffre solide", [11] = "Coffre englouti",
         [12] = "Coffre en morceaux", [13] = "Coffre usé",
         [14] = "Coffre cerclé d'adamantite", [15] = "Coffre en gangrefer",
      },
      mining = {
         [1] = "Filon de cuivre", [2] = "Filon d'étain", [3] = "Filon d'argent",
         [4] = "Filon d'argent couvert de limon", [5] = "Gisement de fer",
         [6] = "Filon d'or", [7] = "Filon d'or couvert de limon",
         [8] = "Gisement de mithril", [9] = "Gisement de mithril couvert de vase",
         [10] = "Gisement de vrai-argent", [11] = "Gisement de vrai-argent couvert de vase",
         [12] = "Petit filon de thorium", [13] = "Filon de thorium couvert de limon",
         [14] = "Riche filon de thorium", [15] = "Riche filon de thorium couvert de limon",
         [16] = "Gisement de sombrefer", [17] = "Gisement de gangrefer",
         [18] = "Gisement d'adamantite", [19] = "Riche gisement d'adamantite",
         [20] = "Filon de khorium", [21] = "Gisement de cobalt",
         [22] = "Riche gisement de cobalt", [23] = "Gisement de saronite",
         [24] = "Riche gisement de saronite", [25] = "Gisement de saronite pure",
         [26] = "Veine de titane", [27] = "Gisement d'adamantite pure",
      },
      gasCollector = {
         [1] = "Vortex arcanique", [2] = "Gangrebrume", [3] = "Gaz des marais",
         [4] = "Nuage venteux", [5] = "Nuage de vapeur", [6] = "Nuage de braise",
         [7] = "Nuage arctique",
      },
      herbs = {
         [1] = "Pacifique", [2] = "Feuillargent", [3] = "Terrestrine", [4] = "Mage royal",
         [5] = "Eglantine", [6] = "Etouffante", [7] = "Doulourante", [8] = "Aciérite sauvage",
         [9] = "Tombeline", [10] = "Sang-royal", [11] = "Vietérule", [12] = "Pâlerette",
         [13] = "Dorépine", [14] = "Moustache de Khadgar", [15] = "Hivernale",
         [16] = "Fleur de feu", [17] = "Lotus pourpre", [18] = "Larmes d'Arthas",
         [19] = "Soleillette", [20] = "Aveuglette", [21] = "Champignon fantôme",
         [22] = "Gromsang", [23] = "Sansam doré", [24] = "Feuillerêve",
         [25] = "Sauge-argent des montagnes", [26] = "Fleur de peste", [27] = "Calot de glace",
         [28] = "Lotus noir", [29] = "Gangrelette", [30] = "Glaurier",
         [31] = "Terocône", [32] = "Voile-misère", [33] = "Lichen ancien",
         [34] = "Néantine", [35] = "Cauchemardelle", [36] = "Chardon de mana",
         [37] = "Gangrelotus", [38] = "Trèfle doré", [39] = "Lys tigré",
         [40] = "Langue de serpent", [41] = "Rose de Talandra", [42] = "Fleur-de-liche",
         [43] = "Glacépine", [44] = "Lotus givré", [45] = "Chardon sanglant",
      },
   }
   for tCat, tNames in pairs(tRessourceNamesFR) do
      local tTarget = SkuCore.RessourceTypes[tCat]
      if tTarget then
         for i, tName in pairs(tNames) do
            if tTarget[i] then tTarget[i].frFR = tName end
         end
      end
   end
   -- Sicherheitsnetz: JEDER Eintrag der gescannten Kategorien braucht einen frFR-Wert,
   -- sonst wuerde string.gmatch(nil, ...) den frFR-Scan abstuerzen lassen. Fehlt einer
   -- (kuenftig neuer Knoten ohne FR-Name), auf enUS/deDE zurueckfallen.
   for _, tCat in ipairs({"chests", "mining", "gasCollector", "herbs"}) do
      local tTarget = SkuCore.RessourceTypes[tCat]
      if tTarget then
         for i = 1, #tTarget do
            if tTarget[i] and not tTarget[i].frFR then
               tTarget[i].frFR = tTarget[i].enUS or tTarget[i].deDE
            end
         end
      end
   end
end



local tMinimapYardsMod = 3.125
local tScanResults = {}
local tMinimapStore = {}
local tMinimapDefaults = {}
local tRange = 15
local tCurrentMMPosX, tCurrentMMPosY = -(tRange / 2), -(tRange / 2)

-- WoW Forever (since the client build of 13.11.2026): the names the minimap puts
-- in the tooltip arrive as SECRET strings. Lowering, finding or comparing them
-- throws ("attempt to perform string conversion on a secret string value"), so
-- they can no longer be matched against SkuCore.RessourceTypes. What still works:
-- truthiness, string.format and Sku's speech path SkuVoice:SpeakSecretText. So a
-- secret line is taken as "a tracked dot is here": the active scan groups such
-- hits by position and speaks every group's name through SpeakSecretText, the
-- passive notifier speaks the name when a dot appears under the cursor. The
-- per-resource filters cannot apply to secret names; the tracking spells (find
-- herbs / minerals) decide what shows, all other tracking is off while scanning.
local function tIsSecret(aValue)
   return Sku.IsSecret ~= nil and Sku.IsSecret(aValue) == true
end
local SECRET_KEY_PREFIX = "\001secret"
local tSecretCount = 0

-- Leaves only spell tracking (find herbs, find minerals, ...) on, so the dots
-- under the cursor are resources; tApplyMinimapState switches the rest back on.
local function tSpellTrackingOnly()
   pcall(function()
      local tCount = GetNumTrackingTypes()
      for i = 1, tCount do
         local result = GetTrackingInfo(i)
         local category
         if type(result) == "table" then
            category = result.type or result.category
         else
            local _, _, _, c = GetTrackingInfo(i)
            category = c
         end
         if category ~= "spell" then
            SetTracking(i, false)
         end
      end
   end)
end

-- Telling resources from other dots without their names (they are secret):
-- some dots stay on the minimap whatever the tracking (an NPC the game shows
-- for a quest, for one). WowVision sorts its dots the same way, by switching
-- tracking types. Here the gathering searches are switched off for a moment
-- and the place is read again: what is still named there is not a resource.
-- Find Herbs, Find Minerals, Find Treasure, Find Fish.
local GATHER_TRACKING_SPELLS = { [2383] = true, [2580] = true, [2481] = true, [43308] = true }

-- The active gathering searches; without a known spell id every active
-- spell search counts.
local function tActiveGatherTracking()
   local tKnown, tSpells = {}, {}
   pcall(function()
      for i = 1, GetNumTrackingTypes() do
         local info = C_Minimap and C_Minimap.GetTrackingInfo and C_Minimap.GetTrackingInfo(i)
         if type(info) == "table" and info.active and info.type == "spell" then
            tSpells[#tSpells + 1] = i
            if info.spellID and GATHER_TRACKING_SPELLS[info.spellID] then tKnown[#tKnown + 1] = i end
         end
      end
   end)
   return (#tKnown > 0) and tKnown or tSpells
end

local function tSetTrackingList(aList, aOn)
   for _, i in ipairs(aList) do pcall(SetTracking, i, aOn) end
end

-- What the game names under the cursor right now, without reading a name:
--   present: anything named (either channel: the minimap tooltip data or the
--            shown GameTooltip);
--   size:    how big the name text is, as a measure of HOW MANY names. The
--            game puts every name into ONE tooltip line (WowVision measured
--            it, 2026-11-10), so the number of lines says nothing; the
--            rendered line count of that text, or its height, does. nil when
--            the game keeps that secret too.
local function tPlainNumber(aFn)
   local ok, v = pcall(aFn)
   if ok and type(v) == "number" and not tIsSecret(v) then return v end
   return nil
end

local function tReadState()
   local tPresent = false
   if C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover then
      local ok, n = pcall(function()
         local data = C_TooltipInfo.GetMinimapMouseover()
         if type(data) == "table" and type(data.lines) == "table" then return #data.lines end
         return 0
      end)
      if ok and type(n) == "number" and not tIsSecret(n) and n > 0 then tPresent = true end
   end
   local tSize
   if GameTooltip:IsShown() then
      local n = tPlainNumber(function() return GameTooltip:NumLines() end)
      if n and n > 0 then
         tPresent = true
         local fs = _G["GameTooltipTextLeft1"]
         if fs then
            tSize = tPlainNumber(function() return fs:GetNumLines() end)
            if not tSize or tSize < 1 then tSize = tPlainNumber(function() return fs:GetStringHeight() end) end
         end
      end
   end
   return { present = tPresent, size = tSize }
end

-- The verdict for one place from the read with the gathering searches on
-- and the one with them off:
--   "resource": nothing stays named, every name there is a resource;
--   "mixed":    something stays, but fewer names: a resource and another dot;
--   "other":    the same stays named: no resource (an NPC, your pet, ...);
--   nil:        no check was possible.
local function tVerdict(aOn, aOff)
   if not aOn or not aOff then return nil end
   if not aOff.present then return "resource" end
   if aOn.size and aOff.size and aOff.size < aOn.size then return "mixed" end
   return "other"
end

local function tStateText(a)
   if not a then return "nil" end
   return (a.present and "da" or "leer") .. "/" .. tostring(a.size)
end

-- The game works out the mouseover when something moves under the cursor:
-- shift the minimap by one pixel, back and forth.
local tNudged = false
local function tNudge()
   local point, relativeTo, relativePoint, x, y = Minimap:GetPoint(1)
   if not point then return end
   tNudged = not tNudged
   Minimap:ClearAllPoints()
   Minimap:SetPoint(point, relativeTo, relativePoint, x + (tNudged and 1 or -1), y)
end

-- For each place (aPlace(i) puts place i under the cursor): what is still
-- named with the gathering searches off (a read state, see tReadState).
-- aDone(states) gets nil when no check was possible (no gathering search
-- active, combat). The searches always come back on, also after an error
-- (5 s safety net).
local function tCountWithoutGathering(aCount, aPlace, aDone)
   -- SWITCHED OFF (14.11.2026): the game lets an addon switch a tracking SPELL
   -- (find herbs, find minerals) off, but not back on outside a key press, so the
   -- check left the player's herb search off. Until there is a safe way it does
   -- nothing and reports "no check possible".
   if true then
      aDone(nil)
      return
   end
   local tGather = tActiveGatherTracking()
   if #tGather == 0 or aCount == 0 or InCombatLockdown() then
      aDone(nil)
      return
   end
   local tFinished = false
   local tOff = {}
   local tIdx = 1
   local function finish()
      if tFinished then return end
      tFinished = true
      tSetTrackingList(tGather, true)
      pcall(aDone, tOff)
   end
   C_Timer.After(5, function()
      if not tFinished then
         tFinished = true
         tSetTrackingList(tGather, true)
      end
   end)
   tSetTrackingList(tGather, false)
   local function frames(n, fn)
      if n <= 0 then fn() else C_Timer.After(0, function() frames(n - 1, fn) end) end
   end
   local nextPlace
   -- Three reads, each after a nudge. The last says whether something stays
   -- (an earlier one may still show the dots of the search just switched off);
   -- the size is the smallest seen while something stayed.
   local function read(k, aState)
      pcall(tNudge)
      C_Timer.After(0, function()
         if tFinished then return end
         local c = tReadState()
         if aState and aState.size and c.size and aState.size < c.size then c.size = aState.size end
         if k < 3 then
            read(k + 1, c)
         else
            tOff[tIdx] = c
            tIdx = tIdx + 1
            nextPlace()
         end
      end)
   end
   nextPlace = function()
      if tFinished then return end
      if tIdx > aCount or InCombatLockdown() then
         finish()
         return
      end
      local ok = pcall(aPlace, tIdx)
      if not ok then
         finish()
         return
      end
      frames(4, function()
         if tFinished then return end
         read(1, nil)
      end)
   end
   nextPlace()
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Minimap-State save/restore helpers — werden von allen Scan-Pfaden
-- benutzt, damit Zoom-Level und Rotation NACH dem Scan wieder dem
-- Vor-Scan-Zustand entsprechen. Zuvor wurde der Zoom in einigen Pfaden
-- nicht restauriert → Minimap konnte "stecken bleiben".
local function tCaptureMinimapState()
   local tracking = {}
   pcall(function()
      local tCount = GetNumTrackingTypes()
      for i = 1, tCount do
         local result = GetTrackingInfo(i)
         local active, category
         -- C_Minimap.GetTrackingInfo gibt auf TBC Anniversary eine Tabelle
         -- zurueck, nicht einzelne Rueckgabewerte.
         if type(result) == "table" then
            active   = result.active
            category = result.type or result.category
         else
            local _, _, a, c = GetTrackingInfo(i)
            active   = a
            category = c
         end
         if category ~= "spell" then
            tracking[i] = active and true or false
         end
      end
   end)
   return {
      zoom     = Minimap:GetZoom(),
      rotate   = GetCVar("rotateMinimap"),
      altMode  = GetCVar("minimapAltitudeHintMode"),
      tracking = tracking,
   }
end

local function tApplyMinimapState(s)
   if not s then return end
   if InCombatLockdown() then return end
   pcall(Minimap.SetZoom, Minimap, s.zoom or 0)
   if s.rotate == "1" and GetCVar("rotateMinimap") ~= "1" then
      ToggleMiniMapRotation()
   elseif s.rotate == "0" and GetCVar("rotateMinimap") == "1" then
      ToggleMiniMapRotation()
   end
   if s.altMode then SetCVar("minimapAltitudeHintMode", s.altMode) end
   -- Tracking-Zustand wiederherstellen (Kraeutersuche, Bergbau, etc.)
   if s.tracking then
      pcall(function()
         for i, wasActive in pairs(s.tracking) do
            if wasActive then
               SetTracking(i, true)
            end
         end
      end)
   end
end

-- Setzt die Minimap auf den scan-tauglichen Zustand:
--   * Zoom 0 (maximal raus, alle Blips sichtbar)
--   * Rotation aus (sonst stimmen Blip-Positionen nicht)
--   * Höhen-Hint-Modus aus
local function tEnterScanState()
   pcall(Minimap.SetZoom, Minimap, 0)
   if GetCVar("rotateMinimap") == "1" then
      ToggleMiniMapRotation()
   end
   SetCVar("minimapAltitudeHintMode", 0)
end

---------------------------------------------------------------------------------------------------------------------------------------
local function PrepareMinimap()
   MinimapCluster:SetFrameLevel(9002)
   MinimapCluster:SetFrameStrata("HIGH")
   -- WICHTIG: SetZoom(0) (nicht GetZoom — der ehemalige Code tat hier
   -- nichts). Maximaler Rauszoom garantiert, dass alle Ressourcen-Blips
   -- als Minimap-Kinder sichtbar sind und vom Scan erfasst werden.
   pcall(Minimap.SetZoom, Minimap, 0)
   Minimap:SetMouseClickEnabled(false)
   MinimapCluster:SetMouseClickEnabled(false)
end

---------------------------------------------------------------------------------------------------------------------------------------
local function SetMinimapPosition(xOffset, yOffset)
   PrepareMinimap()
   local xOffset = xOffset or 0
   local yOffset = yOffset or 0
   local x, y = GetCursorPosition()
   local uiScale = Minimap:GetEffectiveScale()
   Minimap:ClearAllPoints()
   Minimap:SetPoint('CENTER', nil, 'BOTTOMLEFT', xOffset + x / uiScale, yOffset + y / uiScale)
   GameTooltip:SetScale(300)
end

---------------------------------------------------------------------------------------------------------------------------------------
local tFoundPositions = {}
toptionTypes = {
   "miningNodes",
   "herbs",
   "gasCollector",
}

local tChildRessourceTypes = {
   SkuCore.RessourceTypes.mining,
   SkuCore.RessourceTypes.herbs,
   SkuCore.RessourceTypes.gasCollector,
}

-- Scans minimap child frames by calling their OnEnter scripts directly.
-- Returns a table {resourceName = {dx, dy}} where dx/dy are pixel offsets from minimap center.
function MinimapScanner:MinimapScanChildFrames()
   local tResults = {}
   local mmCX, mmCY = Minimap:GetCenter()
   if not mmCX then return tResults end

   local mmChildren = { Minimap:GetChildren() }
   for _, child in ipairs(mmChildren) do
      if child:IsShown() then
         local script = child:GetScript("OnEnter")
         if script then
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            local ok = pcall(script, child)
            if ok then
               for i = 1, GameTooltip:NumLines() do
                  local lineFrame = _G['GameTooltipTextLeft' .. i]
                  local lineRaw = lineFrame and lineFrame:GetText()
                  if lineRaw and not tIsSecret(lineRaw) then
                     local line = string.lower(lineRaw)
                     for r = 1, #tChildRessourceTypes do
                        for x = 1, #tChildRessourceTypes[r] do
                           if SkuSettings:Sub("SkuCore").ressourceScanning[toptionTypes[r]][x] ~= false then
                              local resourceName = tChildRessourceTypes[r][x][Sku.LocP]
                              if resourceName and string.find(line, string.lower(resourceName), 1, true) then
                                 local cx, cy = child:GetCenter()
                                 if cx and cy then
                                    local dx = cx - mmCX
                                    local dy = cy - mmCY
                                    if not tResults[resourceName] then
                                       tResults[resourceName] = {dx = dx, dy = dy}
                                    end
                                 end
                              end
                           end
                        end
                     end
                  end
               end
            end
         end
      end
   end
   GameTooltip:Hide()
   return tResults
end

function MinimapScanner:MinimapScanFindActiveRessource(aX, aY)
    tRessourceTypes = {
      SkuCore.RessourceTypes.mining,
      SkuCore.RessourceTypes.herbs,
      SkuCore.RessourceTypes.gasCollector,
   }

   for i = 1, GameTooltip:NumLines() do
      local lineFrame = _G['GameTooltipTextLeft' .. i]
      local lineRaw = lineFrame and lineFrame:GetText()
      if lineRaw and tIsSecret(lineRaw) then
         -- A secret name: group the hit with an earlier one close by (same box
         -- rule as the named path below), else open a new group. The group keeps
         -- the first hit's text for the announcement.
         local tRangeNew = 20
         for tKey, tBoxes in pairs(tFoundPositions) do
            local b = tBoxes[1]
            if b and b.secretText and math.abs(b.xMax - aX) < tRangeNew and math.abs(b.yMax - aY) < tRangeNew
               and math.abs(b.xMin - aX) < tRangeNew and math.abs(b.yMin - aY) < tRangeNew then
               if b.xMin > aX then b.xMin = aX end
               if b.xMax < aX then b.xMax = aX end
               if b.yMin > aY then b.yMin = aY end
               if b.yMax < aY then b.yMax = aY end
               return tKey
            end
         end
         tSecretCount = tSecretCount + 1
         local tKey = SECRET_KEY_PREFIX .. tSecretCount
         tFoundPositions[tKey] = { { xMin = aX - 1, xMax = aX + 1, yMin = aY - 1, yMax = aY + 1, secretText = lineRaw,
            hitX = aX, hitY = aY, onState = tReadState() } }
         return tKey
      end
      if lineRaw then
         local line = string.lower(lineRaw)
         for r = 1, #tRessourceTypes do
            for x = 1, #tRessourceTypes[r] do
               if SkuSettings:Sub("SkuCore").ressourceScanning[toptionTypes[r]][x] ~= false then
                  for w in string.gmatch(tRessourceTypes[r][x][Sku.LocP], ".+") do
                     if string.find(line, string.lower(w), 1, true) and not string.find(line, string.lower(w .. '|'), 1, true) then
                        if not tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ] then
                           tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ] = {}
                        end
                        if #tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ] == 0 then
                           tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][1] = {
                              xMin = aX - 1,
                              xMax = aX + 1,
                              yMin = aY - 1,
                              yMax = aY + 1,
                           }
                        else
                           local tFoundIndex
                           for q = 1, #tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ] do
                              dprint("q", q, #tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ],
                                 tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][q])
                              local xmax = tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][q].xMax - aX
                              local ymax = tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][q].yMax - aY
                              local xmin = tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][q].xMin - aX
                              local ymin = tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][q].yMin - aY
                              if xmax < 0 then xmax = xmax * -1 end
                              if ymax < 0 then ymax = ymax * -1 end
                              if xmin < 0 then xmin = xmin * -1 end
                              if ymin < 0 then ymin = ymin * -1 end

                              dprint("  ", xmax, ymax, xmin, ymin)
                              local tRangeNew = 20
                              if xmax < tRangeNew and ymax < tRangeNew and xmin < tRangeNew and ymin < tRangeNew then
                                 tFoundIndex = q
                              end
                           end
                           if tFoundIndex then
                              dprint("found", tFoundIndex)
                              if tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].xMin > aX then
                                 tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].xMin = aX
                              end
                              if tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].xMax < aX then
                                 tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].xMax = aX
                              end
                              if tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].yMin > aY then
                                 tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].yMin = aY
                              end
                              if tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].yMax < aY then
                                 tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][tFoundIndex].yMax = aY
                              end
                           else
                              dprint("new", tRessourceTypes[r][x][Sku.LocP],
                                 #tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ] + 1)
                              tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ][
                                  #tFoundPositions[ tRessourceTypes[r][x][Sku.LocP] ] + 1] = {
                                 xMin = aX - 1,
                                 xMax = aX + 1,
                                 yMin = aY - 1,
                                 yMax = aY + 1,
                              }
                           end
                        end

                        return tRessourceTypes[r][x][Sku.LocP]
                     end
                  end
               end
            end
         end
      end
   end

   return
end

---------------------------------------------------------------------------------------------------------------------------------------
local tNotificationTicker
local function MinimapScanStep()
   if MinimapScanner.IsMMScanning == false and SkuCore.inCombat ~= true then
      MinimapScanner:RestoreMinimap()
      MinimapScanner.noMouseOverNotification = nil
      C_Timer.After(1.1, function()
         MinimapScanner.noMouseOverNotification = nil
      end)
      return
   end

   tCurrentMMPosX = tCurrentMMPosX + SkuSettings:Sub("SkuCore").ressourceScanning.scanAccuracyS
   if tCurrentMMPosX > (tRange / 2) then
      tCurrentMMPosX = -(tRange / 2)
      tCurrentMMPosY = tCurrentMMPosY + SkuSettings:Sub("SkuCore").ressourceScanning.scanAccuracyS
   end

   if tCurrentMMPosY > (tRange / 2) then
      tCurrentMMPosX, tCurrentMMPosY = -(tRange / 2), -(tRange / 2)
      MinimapScanner:FinishGridScan()
      return
   end

   SetMinimapPosition(tCurrentMMPosX, tCurrentMMPosY)

   C_Timer.After(0, function()
      -- Under pcall: an error here used to break the step chain, and the minimap
      -- stayed moved and shrunk under the cursor.
      local tReadOk, tResultString = pcall(MinimapScanner.MinimapScanFindActiveRessource, MinimapScanner, tCurrentMMPosX, tCurrentMMPosY)
      if not tReadOk then
         dprint("MinimapScanStep: read failed", tostring(tResultString))
         tResultString = nil
      end
      if tResultString then
         if not tScanResults[tResultString] then
            tScanResults[tResultString] = 0
         end
         tScanResults[tResultString] = tScanResults[tResultString] + 1
      end
      if SkuCore.inCombat ~= true then
         MinimapScanStep()
      end
   end)
end

---------------------------------------------------------------------------------------------------------------------------------------
-- End of the grid scan: groups with secret names are checked with the
-- gathering searches off (see tCountWithoutGathering); a group whose place
-- stays just as named is no resource and is dropped, so it is neither
-- announced nor set as a quick waypoint. Then the results as before.
local PET_DROP_METERS = 10
function MinimapScanner:FinishGridScan()
   local tKeys = {}
   for k, boxes in pairs(tFoundPositions) do
      if boxes[1] and boxes[1].secretText and tScanResults[k] then tKeys[#tKeys + 1] = k end
   end
   local function done(aOff)
      -- Your pet follows you and its dot sits on the minimap's centre; a group
      -- that close to you is taken for it and dropped while a pet is out.
      if UnitExists and UnitExists("pet") then
         for _, k in ipairs(tKeys) do
            local b = tFoundPositions[k] and tFoundPositions[k][1]
            if b then
               local xC = b.xMin + math.abs(b.xMax - b.xMin) / 2 + 2.5
               local yC = b.yMin + math.abs(b.yMax - b.yMin) / 2 + 0.5
               local tMeters = math.sqrt(xC * xC + yC * yC) * tMinimapYardsMod
               dprint("MinimapScan: group", k, "distance", math.floor(tMeters))
               if tMeters < PET_DROP_METERS then
                  tScanResults[k] = nil
                  tFoundPositions[k] = nil
               end
            end
         end
      end
      if aOff then
         for n, k in ipairs(tKeys) do
            local b = tFoundPositions[k] and tFoundPositions[k][1]
            local tV = b and tVerdict(b.onState, aOff[n])
            dprint("MinimapVerify: group", n, "on", tStateText(b and b.onState), "off", tStateText(aOff[n]), "->", tostring(tV))
            if tV == "other" then
               tScanResults[k] = nil
               tFoundPositions[k] = nil
            end
         end
      end
      MinimapScanner.IsMMScanning = false
      C_Timer.After(1, function()
         MinimapScanner.noMouseOverNotification = true
      end)
      pcall(MinimapScanner.MinimapScanProcessResults, MinimapScanner)
      -- IsMMScanning is false now: this step puts the minimap back.
      MinimapScanStep()
   end
   tCountWithoutGathering(#tKeys, function(n)
      local b = tFoundPositions[tKeys[n]][1]
      SetMinimapPosition(b.hitX, b.hitY)
   end, done)
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:StoreMinimap()
   tMinimapStore.point, tMinimapStore.relativeTo, tMinimapStore.relativePoint, tMinimapStore.x, tMinimapStore.y = Minimap:GetPoint()
   tMinimapStore.parent = Minimap:GetParent()
   tMinimapStore.scale = Minimap:GetScale()
   tMinimapStore.zoom = Minimap:GetZoom()
   tMinimapStore.alpha = Minimap:GetAlpha()
   tMinimapStore.GameTooltipScale = GameTooltip:GetScale()
   tMinimapStore.frameLevel = MinimapCluster:GetFrameLevel()
   tMinimapStore.frameStrata = MinimapCluster:GetFrameStrata()

   MinimapScanner.minimapChildren = { Minimap:GetChildren() }
   for k, v in pairs(MinimapScanner.minimapChildren) do
      v.MMA_VISIBLE = v:IsVisible()
      v.MMA_FRAME_LEVEL = v:GetFrameLevel()
      v.MMA_FRAME_STRATA = v:GetFrameStrata()
   end
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:RestoreMinimap()
   if InCombatLockdown() == true then
      return
   end
   local s = (tMinimapStore.point == nil or tMinimapStore.relativeTo == nil) and tMinimapDefaults or tMinimapStore
   Minimap:SetParent(s.parent)
   Minimap:SetScale(s.scale or 1)
   Minimap:SetZoom(s.zoom or 0)
   Minimap:SetAlpha(s.alpha or 1)
   Minimap:ClearAllPoints()
   Minimap:SetPoint(s.point, s.relativeTo, s.relativePoint, s.x, s.y)
   MinimapCluster:SetFrameLevel(s.frameLevel)
   MinimapCluster:SetFrameStrata(s.frameStrata)
   GameTooltip:SetScale(s.GameTooltipScale)
   Minimap:SetMouseClickEnabled(true)
   MinimapCluster:SetMouseClickEnabled(true)

   for k, v in pairs(MinimapScanner.minimapChildren) do
      if v.MMA_VISIBLE then
         v:Show()
      end
      v:SetFrameStrata(v.MMA_FRAME_STRATA)
      v:SetFrameLevel(v.MMA_FRAME_LEVEL)
   end
   --SkuCore.noMouseOverNotification = nil
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:MinimapStopScan()
   SkuOptions:StartStopBackgroundSound(false)
   MinimapScanner:RestoreMinimap()
   MinimapScanner.noMouseOverNotification = nil
   MinimapScanner.IsMMScanning = false
   -- [v43.0] Auch den Schnellscan-Lock lösen. Bisher wurde hier nur IsMMScanning
   -- zurückgesetzt; blieb MinimapScanFastRunning stehen (abgebrochener Tail),
   -- half kein einziger Stop-Pfad mehr heraus - weder PLAYER_STARTED_MOVING noch
   -- Kampfbeginn noch das Abschalten des Moduls. "Scan anhalten" muss ALLE Locks
   -- lösen, sonst ist es kein Stop.
   MinimapScanner.MinimapScanFastRunning = false
   MinimapScanner.MinimapScanFastStartedAt = nil
   -- [2026-09-01] The gather route's "this scan is mine, stay silent" flag is
   -- normally cleared in MinimapScanFastStop. A hard stop skips that tail, and a
   -- flag left standing would silence the NEXT ambient announcement instead.
   MinimapScanner.routeScanSilent = nil
   MinimapScanner:RestoreMinimap()
   MinimapScanner.noMouseOverNotification = nil
   -- Auch Zoom/Rotation/Altitude-Hint zurücksetzen, falls vor dem Scan
   -- erfasst (sonst bleibt Minimap in Scan-Konfiguration zoom=0 etc.).
   if MinimapScanner.tMinimapScanPrevState then
      pcall(tApplyMinimapState, MinimapScanner.tMinimapScanPrevState)
      MinimapScanner.tMinimapScanPrevState = nil
   end
   if tNotificationTicker then
      tNotificationTicker:Cancel()
   end
   MinimapScanner.noMouseOverNotification = nil
   SkuOptions.Voice:StopOutputEmptyQueue(true, nil)
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:MinimapScan(aRange)
   if not MinimapScanner:IsEnabled() then return end
   dprint("MinimapScan", aRange)
   if Questie then
      Questie.db.global.enableMiniMapIcons = false
   end

   SkuCore.GameWorldObjects:GameWorldObjectsCenterMouseCursor(0.5)
   -- Vor-Scan-Zustand merken — wird wieder hergestellt, sobald der
   -- Child-Frame-Scan Treffer liefert oder der Grid-Scan endet.
   MinimapScanner.tMinimapScanPrevState = tCaptureMinimapState()
   -- Scan-Zustand erzwingen: Zoom 0, keine Rotation, kein Höhenmodus.
   pcall(tEnterScanState)

   aRange = aRange or 20
   tScanResults = {}
   tFoundPositions = {}
   tSecretCount = 0
   MinimapScanner.noMouseOverNotification = true
   -- Only the tracking spells' dots (herbs, ore, ...): secret names cannot be
   -- filtered afterwards. The captured state above switches the rest back on.
   tSpellTrackingOnly()

   -- Try fast child-frame scan first (works if blips are interactive frames)
   local ok, tChildResults = pcall(MinimapScanner.MinimapScanChildFrames, MinimapScanner)
   if not ok then tChildResults = {} end
   if next(tChildResults) then
      for name, pos in pairs(tChildResults) do
         tScanResults[name] = 1
         -- WICHTIG: Achsen müssen invertiert werden, damit die
         -- nachfolgende Welt-Koordinaten-Umrechnung in
         -- MinimapScanProcessResults korrekt arbeitet.
         --
         -- Der Grid-Scan liefert Werte mit umgekehrter Konvention:
         --   * tCurrentMMPosX > 0 → Cursor scannt links der Mitte → Blip im WESTEN
         --   * tCurrentMMPosY > 0 → Cursor scannt unter der Mitte → Blip im SÜDEN
         -- Der Child-Frame-Pfad liefert dagegen die natürliche
         -- Bildschirm-Konvention:
         --   * dx > 0 → Blip rechts der Mitte (OSTEN)
         --   * dy > 0 → Blip oberhalb der Mitte (NORDEN)
         -- Ohne Negation würde der Quick-Waypoint im falschen
         -- Quadranten landen → der User läuft hin und findet nichts.
         local nx, ny = -pos.dx, -pos.dy
         tFoundPositions[name] = {{xMin=nx-1, xMax=nx+1, yMin=ny-1, yMax=ny+1}}
      end
      -- Vor-Scan-Zustand wiederherstellen, weil wir gar nicht in den
      -- disruptiven Grid-Scan-Pfad einsteigen.
      pcall(tApplyMinimapState, MinimapScanner.tMinimapScanPrevState)
      MinimapScanner.tMinimapScanPrevState = nil
      MinimapScanner:MinimapScanProcessResults()
      return
   end

   -- Fallback: slow grid scan via minimap tooltip
   SkuOptions:StartStopBackgroundSound(true, SkuSettings:Sub("SkuCore").scanBackgroundSound)
   tRange = aRange
   MinimapScanner:StoreMinimap()
   tCurrentMMPosX, tCurrentMMPosY = (aRange / 2) * -1, (aRange / 2) * -1
   MinimapScanner.IsMMScanning = true

   print(L["Ressourcen-Scan gestartet ("] .. aRange .. L[" Einheiten)"])
   MinimapScanStep()
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:MinimapScanProcessResults()
   if tNotificationTicker then
      tNotificationTicker:Cancel()
   end

   SkuOptions.Voice:StopOutputEmptyQueue(true, nil)
   SkuOptions:StartStopBackgroundSound(false)

   -- Falls noch ein gespeicherter Vor-Scan-Minimap-Zustand existiert
   -- (manueller Scan via Hotkey), zurückspielen — verhindert, dass die
   -- Minimap in zoom=0/no-rotation hängenbleibt.
   if MinimapScanner.tMinimapScanPrevState then
      pcall(tApplyMinimapState, MinimapScanner.tMinimapScanPrevState)
      MinimapScanner.tMinimapScanPrevState = nil
   end

   if next(tScanResults) == nil then
      print(L["Ressourcen-Scan: Nichts gefunden"])
      SkuOptions.Voice:OutputStringBTtts(L["Nichts gefunden"], false, true, 0.2)
      return
   end

   local tQuickWpNumber = 1
   -- Secret names cannot be queued one by one (SpeakSecretText replaces what is
   -- queued), so their lines are collected into ONE format string with the
   -- names as arguments and spoken at the end.
   local tSecretFormat, tSecretArgs = {}, {}
   for i, v in pairs(tScanResults) do
      local xCenter, yCenter
      if tFoundPositions[i] and tFoundPositions[i][1] and tFoundPositions[i][1].secretText then
         local b = tFoundPositions[i][1]
         local tempX = math.abs(b.xMax - b.xMin)
         local tempY = math.abs(b.yMax - b.yMin)
         xCenter = b.xMin + (tempX / 2) + 2.5
         yCenter = b.yMin + (tempY / 2) + 0.5
         local xa, ya = UnitPosition("player")
         if xa then
            xa = xa + (yCenter * -1)
            ya = ya + xCenter
            local tDistance = SkuNav.Geo:Distance(0, 0, xCenter, yCenter)
            local tPlain = SkuNav.Geo:GetDirectionToAsString(xa, ya) .. " " .. math.floor(tDistance * tMinimapYardsMod) .. " " .. L["Meter"]
            local tNr = string.gsub(tostring(tQuickWpNumber or ""), "%%", "%%%%")
            tSecretFormat[#tSecretFormat + 1] = tNr .. " %s " .. string.gsub(tPlain, "%%", "%%%%")
            tSecretArgs[#tSecretArgs + 1] = b.secretText
            if tQuickWpNumber then
               local tAreaId = SkuNav.Geo:GetCurrentAreaId()
               local worldx, worldy = UnitPosition("player")
               local tPlayerContintentId = select(3, SkuNav.Geo:GetAreaData(SkuNav.Geo:GetCurrentAreaId())) or -1
               SkuNav:SetWaypoint(L["Quick waypoint"] .. ";" .. tQuickWpNumber, {
                  ["contintentId"] = tPlayerContintentId,
                  ["areaId"] = tAreaId,
                  ["worldX"] = worldx + ((yCenter * tMinimapYardsMod)) * -1,
                  ["worldY"] = worldy + ((xCenter * tMinimapYardsMod)),
                  ["createdAt"] = GetTime(),
                  ["createdBy"] = "SkuCore",
                  ["size"] = 1,
               })
               tQuickWpNumber = tQuickWpNumber + 1
               if tQuickWpNumber > 4 then tQuickWpNumber = nil end
            end
         else
            tSecretFormat[#tSecretFormat + 1] = "%s"
            tSecretArgs[#tSecretArgs + 1] = b.secretText
         end
      elseif tFoundPositions[i] then
         for q = 1, #tFoundPositions[i] do
            local tempX = (tFoundPositions[i][q].xMax + 1000) - (tFoundPositions[i][q].xMin + 1000)
            if tempX < 0 then
               tempX = tempX * -1
            end
            local tempY = (tFoundPositions[i][q].yMax + 1000) - (tFoundPositions[i][q].yMin + 1000)
            if tempY < 0 then
               tempY = tempY * -1
            end
            xCenter = tFoundPositions[i][q].xMin + (tempX / 2) + 2.5
            yCenter = tFoundPositions[i][q].yMin + (tempY / 2) + 0.5
            local xa, ya = UnitPosition("player")
            if xa then
               xa = xa + (yCenter * -1)
               ya = ya + xCenter
               local tDistance = SkuNav.Geo:Distance(0, 0, xCenter, yCenter)
               if i == "Kobaltablagerung" then
                  i = "Kobaltvorkommen"
               end
               if i == "Reiche Kobaltablagerung" then
                  i = "Reiches Kobaltvorkommen"
               end
               print((tQuickWpNumber or "").." "..i.." "..SkuNav.Geo:GetDirectionToAsString(xa, ya).." "..math.floor(tDistance * tMinimapYardsMod) .. " " .. L["Meter"])
               SkuOptions.Voice:OutputStringBTtts((tQuickWpNumber or "").." "..i.." "..SkuNav.Geo:GetDirectionToAsString(xa, ya).." "..math.floor(tDistance * tMinimapYardsMod).." ".. L["Meter"], false, true, 0.2)

               if tQuickWpNumber then
                  local tAreaId = SkuNav.Geo:GetCurrentAreaId()
                  local worldx, worldy = UnitPosition("player")
                  local tPlayerContintentId = select(3, SkuNav.Geo:GetAreaData(SkuNav.Geo:GetCurrentAreaId())) or -1
                  local tTime = GetTime()
                  SkuNav:SetWaypoint(L["Quick waypoint"] .. ";" .. tQuickWpNumber, {
                     ["contintentId"] = tPlayerContintentId,
                     ["areaId"] = tAreaId,
                     ["worldX"] = worldx + ((yCenter * tMinimapYardsMod)) * -1,
                     ["worldY"] = worldy + ((xCenter * tMinimapYardsMod)),
                     ["createdAt"] = tTime,
                     ["createdBy"] = "SkuCore",
                     ["size"] = 1,
                  })
               end

               tQuickWpNumber = tQuickWpNumber + 1
               if tQuickWpNumber > 4 then
                  tQuickWpNumber = nil
               end
            else
               print(i)
               SkuOptions.Voice:OutputStringBTtts(i, false, true, 0.2)

            end
         end
      end
   end
   if #tSecretFormat > 0 then
      print(#tSecretFormat .. " " .. Sku.deEn("Ressourcen gefunden, die Namen nur per Sprachausgabe",
         "resources found, names by speech only", "ressources trouvées, noms seulement par la voix"))
      pcall(function()
         SkuOptions.Voice:SpeakSecretText(table.concat(tSecretFormat, ", "), unpack(tSecretArgs))
      end)
   end
end

---------------------------------------------------------------------------------------------------------------------------------------
local tRessourceTypes = {
   SkuCore.RessourceTypes.mining,
   SkuCore.RessourceTypes.herbs,
   SkuCore.RessourceTypes.gasCollector,
}
local tInitialCenterMouse
local tPrevResult = ""
-- Passive notifier with secret names: the size of the name text last seen
-- (baseline), a pause for the check, and how many empty reads in a row.
local tPassiveSize, tPassiveBlockedUntil
local tEmptyStreak = 0
local mmx, mmy

-- [v43.0] Tooltip-Auswertung des Schnellscans, herausgezogen aus dem
-- C_Timer-Tail von MinimapScanFast, damit sie EINZELN unter pcall laufen kann.
--
-- Das war der einzige ungeschützte Teil des Tails, und der Tail ist der einzige
-- Ort, der den Scan-Lock (MinimapScanFastRunning) wieder freigibt. Jeder Fehler
-- hier - GameTooltip liefert nichts, Sku.LocP ist nil, ein Settings-Zweig fehlt,
-- oder die Ausführung wird abgebrochen - sprang aus dem Callback heraus, BEVOR
-- MinimapScanFastStop lief. Und MinimapStopScan setzt den Lock nicht zurück
-- (nur IsMMScanning), also blieb er für den Rest der Sitzung stehen: der Guard
-- am Kopf von MinimapScanFast kehrte ab da sofort zurück, die passive
-- Ressourcenansage schwieg bis zum nächsten /reload, und die Minimap blieb auf
-- 15x15 mit Alpha 0 am Mauszeiger hängen. Genau dieser Fall wurde gemeldet.
local function tScanFastScrapeTooltip()
   local foundResult = nil
   for i = 1, GameTooltip:NumLines() do
      local lineFrame = _G['GameTooltipTextLeft' .. i]
      local lineRaw = lineFrame and lineFrame:GetText()
      if lineRaw and tIsSecret(lineRaw) then
         -- Only spell tracking is on during this scan: a named dot here is a resource.
         return { secret = lineRaw }
      end
      if lineRaw then
         lineRaw = SkuUtil:Unescape(lineRaw)
         local line = string.lower(lineRaw)
         for r = 1, #tRessourceTypes do
            for x = 1, #tRessourceTypes[r] do
               if SkuSettings:Sub("SkuCore").ressourceScanning[toptionTypes[r]][x] ~= false then
                  for w in string.gmatch(tRessourceTypes[r][x][Sku.LocP], ".+") do
                     if string.find(line, string.lower(w), 1, true)
                        and not string.find(line, string.lower(w .. "|"), 1, true) then
                        local hit = lineRaw
                        if hit == "Kobaltablagerung" then hit = "Kobaltvorkommen" end
                        if hit == "Reiche Kobaltablagerung" then hit = "Reiches Kobaltvorkommen" end
                        foundResult = hit
                        break
                     end
                  end
               end
               if foundResult then break end
            end
            if foundResult then break end
         end
      end
      if foundResult then break end
   end
   return foundResult
end

function MinimapScanner:MinimapScanFast()
   if not MinimapScanner:IsEnabled() then return end
   if MinimapScanner.MinimapScanFastRunning == true then return end
   if Questie then Questie.db.global.enableMiniMapIcons = false end

   MinimapScanner.noMouseOverNotification = true
   MinimapScanner.MinimapScanFastRunning = true
   -- [v43.0] Zeitstempel des Locks. Der Lock wird erst am ENDE eines
   -- C_Timer-Tails wieder freigegeben (MinimapScanFastStop); erreicht der Tail
   -- sein Ende nicht, blieb er bisher für den Rest der Sitzung stehen und die
   -- passive Ressourcenansage war tot. Siehe die Deadline im OnUpdate-Treiber.
   MinimapScanner.MinimapScanFastStartedAt = GetTime()
   tFoundPositions = {}

   -- Vor-Scan-Zustand sichern, damit wir nach dem Scan exakt zurück-
   -- stellen können (verhindert "Minimap bleibt rein-gezoomt"-Bug).
   local tPrevState = tCaptureMinimapState()
   -- Sicherheits-Reset des Locks im Fehlerfall: zwingend einen Restore
   -- durchführen, sonst bleibt das Addon hängen.
   local function tFinalize(aResultName)
      pcall(tApplyMinimapState, tPrevState)
      pcall(MinimapScanner.MinimapScanFastStop, MinimapScanner, aResultName)
   end

   -- ── Schnellpfad: Child-Frame-Scan ───────────────────────────────────────
   -- Vor dem Scan zwingend Zoom 0 + Rotation aus, damit alle Blips als
   -- Children sichtbar sind und ihre Center-Koordinaten stabil bleiben.
   pcall(tEnterScanState)
   local ok, tChildResults = pcall(MinimapScanner.MinimapScanChildFrames, MinimapScanner)
   if not ok then tChildResults = {} end
   local nChild = 0
   for _ in pairs(tChildResults) do nChild = nChild + 1 end

   if nChild > 0 then
      local aResult = nil
      for name in pairs(tChildResults) do aResult = name; break end
      tFinalize(aResult)
      return
   end

   -- ── Fallback: Vorlage-Pfad ──────────────────────────────────────────────
   -- Auf Anniversary/Classic sind die nativen Ressourcen-Blips keine
   -- adressierbaren Child-Frames mit OnEnter-Skripten — der Child-Scan
   -- findet sie deshalb nicht. Stattdessen den bewährten Vorlage-Trick
   -- verwenden: Minimap auf alpha=0 setzen, auf 15x15 schrumpfen und
   -- exakt unter den (vorher in der Bildschirmmitte fixierten) Cursor
   -- legen. Der WoW-Client zeigt dann im GameTooltip automatisch den
   -- Namen des Blips, über dem der Cursor steht — wir lesen ihn aus
   -- und gleichen ihn gegen die aktivierten Ressourcen ab.
   if not tInitialCenterMouse then
      tInitialCenterMouse = true
      pcall(SkuCore.GameWorldObjects.GameWorldObjectsCenterMouseCursor, SkuCore.GameWorldObjects, 0.5)
   end

   if Questie then Questie.db.global.enableMiniMapIcons = false end

   -- Tracking-Optionen außer Spell-Tracking deaktivieren — sonst können
   -- konkurrierende Tracking-Symbole den Tooltip übersteuern.
   pcall(function()
      local tCount = GetNumTrackingTypes()
      for i = 1, tCount do
         local result = GetTrackingInfo(i)
         local category
         -- C_Minimap.GetTrackingInfo gibt auf TBC Anniversary eine Tabelle
         -- zurueck, nicht einzelne Rueckgabewerte.
         if type(result) == "table" then
            category = result.type or result.category
         else
            local _, _, _, c = GetTrackingInfo(i)
            category = c
         end
         if category ~= "spell" then
            SetTracking(i, false)
         end
      end
   end)

   pcall(MinimapScanner.StoreMinimap, MinimapScanner)

   -- Schutz gegen Klick-Abfangen: Alle Minimap-Kinder verstecken,
   -- solange die Minimap unter dem Cursor liegt. Ohne das fangen
   -- Kind-Frames (z.B. MiniMapTrackingFrame) Klicks ab und erzeugen
   -- ein Ping-Geraeusch. Portiert aus 1.x (Zeilen 479-484).
   -- RestoreMinimap stellt die Sichtbarkeit per MMA_VISIBLE her.
   for k, v in pairs(MinimapScanner.minimapChildren) do
      if v:IsShown() then
         pcall(v.Hide, v)
      end
   end
   -- MiniMapTrackingFrame sicherheitshalber auch einzeln verstecken,
   -- falls es nicht in minimapChildren enthalten ist.
   if _G["MiniMapTrackingFrame"] then
      pcall(_G["MiniMapTrackingFrame"].Hide, _G["MiniMapTrackingFrame"])
   end

   -- The minimap on top of every other frame and without clicks while it lies
   -- under the cursor, as in the active scan (PrepareMinimap): otherwise another
   -- frame can hold the mouse focus and the game names nothing. RestoreMinimap
   -- puts strata, level and clicks back (StoreMinimap captured them).
   pcall(function()
      MinimapCluster:SetFrameStrata("HIGH")
      MinimapCluster:SetFrameLevel(9002)
      Minimap:SetMouseClickEnabled(false)
   end)
   mmx, mmy = Minimap:GetSize()
   Minimap:SetAlpha(0)
   Minimap:SetSize(15, 15)
   Minimap:ClearAllPoints()
   local cx, cy = GetCursorPosition()
   Minimap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / UIParent:GetScale(), cy / UIParent:GetScale())

   C_Timer.After(0.1, function()
      GameTooltip:SetAlpha(0)

      -- Tooltip-Zeilen auslesen und gegen aktivierte Ressourcen matchen.
      -- Verwendet denselben string.find-Substring-Match wie der aktive Scan
      -- (MinimapScanFindActiveRessource). Die alte Logik (gmatch-Zerlegung
      -- + exakte Gleichheit) konnte Ressourcen mit Sonderzeichen nie finden
      -- und war an Unescape gekoppelt — fiel SkuChat weg, wurden alle Zeilen
      -- still uebersprungen. Unescape lebt jetzt in SkuUtil (laedt immer zuerst),
      -- daher braucht es keinen SkuChat-Vorhandensein-Guard mehr.
      -- [v43.0] Unter pcall: alles ab hier bis MinimapScanFastStop MUSS laufen,
      -- sonst bleibt der Scan-Lock stehen (siehe tScanFastScrapeTooltip). Ein
      -- fehlgeschlagener Scrape heißt "nichts gefunden", nicht "Scanner tot".
      local tScrapeOk, foundResult = pcall(tScanFastScrapeTooltip)
      if not tScrapeOk then
         dprint("MinimapScanFast: Tooltip-Auswertung fehlgeschlagen:", tostring(foundResult))
         if SkuErrorLog and SkuErrorLog.Log then
            pcall(function() SkuErrorLog:Log("minimapScanner", "MinimapScanFast scrape: " .. tostring(foundResult)) end)
         end
         foundResult = nil
      end

      local function tFinishTail(aResult)
         -- Größe wiederherstellen, dann normalen Restore-Pfad gehen.
         if mmx and mmy then
            pcall(Minimap.SetSize, Minimap, mmx, mmy)
         end
         pcall(MinimapScanner.RestoreMinimap, MinimapScanner)
         Minimap:SetAlpha(1)
         C_Timer.After(0.1, function() GameTooltip:SetAlpha(1) end)
         pcall(tApplyMinimapState, tPrevState)
         pcall(MinimapScanner.MinimapScanFastStop, MinimapScanner, aResult)
      end

      -- Secret names (see tIsSecret). The shrunk minimap names everything in
      -- range at once, so your pet or a quest NPC can be in the same read as a
      -- herb. Checked with the gathering searches off while the shrunk minimap
      -- still lies under the cursor, but only when something NEW may be there:
      -- nothing was named before, or the name text grew. A dot that is no
      -- resource is remembered as the baseline and not checked again.
      if type(foundResult) == "table" and foundResult.secret then
         -- 14.11.2026: herb and ore names are secret too, so nothing in a secret
         -- read can be identified as a resource. The passive notifier only speaks
         -- what it can identify: a secret read stays silent.
         if true then
            tFinishTail(foundResult)
            return
         end
         local tOn = tReadState()
         local tNew
         if tPrevResult == "" then
            tNew = true
         elseif tOn.size and tPassiveSize and tOn.size > tPassiveSize then
            tNew = true
         end
         if tNew and tPassiveBlockedUntil and GetTime() < tPassiveBlockedUntil then tNew = false end
         if not tNew then
            if tOn.size and (not tPassiveSize or tOn.size < tPassiveSize) then tPassiveSize = tOn.size end
            tFinishTail(foundResult)
            return
         end
         tCountWithoutGathering(1, function() end, function(aOff)
            local tV = tVerdict(tOn, aOff and aOff[1])
            dprint("MinimapVerify: passive on", tStateText(tOn), "off", tStateText(aOff and aOff[1]), "->", tostring(tV))
            tPassiveSize = tOn.size
            if tV == "resource" or tV == nil then
               foundResult.say = "name"
            elseif tV == "mixed" then
               foundResult.say = "generic"
            elseif not tOn.size then
               -- No resource, and no way to see new names next to it: no
               -- further checks for a while (each one switches the searches).
               tPassiveBlockedUntil = GetTime() + 15
            end
            tFinishTail(foundResult)
         end)
         return
      end
      tFinishTail(foundResult)
   end)
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Key "minikarte vorlesen" (SKU_KEY_MMREAD, default Ctrl+F): what the passive
-- notifier used to do, once, on demand. The minimap is shrunk to a few pixels
-- under the centred cursor, so every dot in range lies under it, and the game
-- names them all in its minimap tooltip. Everything named is spoken as it
-- comes, quests and NPCs included: the names are secret on WoW Forever and
-- cannot be filtered. Tracking and zoom are left as they are (zoom goes to the
-- widest view for the read and back). Out of combat only.
function MinimapScanner:MinimapReadAll()
   if not MinimapScanner:IsEnabled() then return end
   if InCombatLockdown() or SkuCore.inCombat == true then
      SkuOptions.Voice:OutputStringBTtts(Sku.deEn("Nicht im Kampf", "Not in combat", "Pas en combat"), true, true, 0.2)
      return
   end
   if MinimapScanner.MinimapScanFastRunning == true or MinimapScanner.IsMMScanning == true then return end
   MinimapScanner.MinimapScanFastRunning = true
   MinimapScanner.MinimapScanFastStartedAt = GetTime()
   MinimapScanner.noMouseOverNotification = true

   local tPrevState = tCaptureMinimapState()
   local tSize = {}
   local tDone = false

   local function tRelease()
      MinimapScanner.noMouseOverNotification = nil
      MinimapScanner.MinimapScanFastRunning = false
      MinimapScanner.MinimapScanFastStartedAt = nil
      MinimapScanner.IsMMScanning = false
   end

   local function tRestore()
      if tSize.w and tSize.h then pcall(Minimap.SetSize, Minimap, tSize.w, tSize.h) end
      pcall(MinimapScanner.RestoreMinimap, MinimapScanner)
      pcall(Minimap.SetAlpha, Minimap, 1)
      C_Timer.After(0.1, function() GameTooltip:SetAlpha(1) end)
      pcall(tApplyMinimapState, tPrevState)
   end

   -- Every text the game names under the cursor: from the minimap tooltip data,
   -- else from the shown GameTooltip. Secret texts stay untouched.
   local function tReadTexts()
      local tTexts = {}
      if C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover then
         pcall(function()
            local data = C_TooltipInfo.GetMinimapMouseover()
            if type(data) == "table" and type(data.lines) == "table" then
               for _, line in ipairs(data.lines) do
                  if type(line) == "table" and line.leftText ~= nil then tTexts[#tTexts + 1] = line.leftText end
               end
            end
         end)
      end
      if #tTexts == 0 and GameTooltip:IsShown() then
         pcall(function()
            for i = 1, GameTooltip:NumLines() do
               local fs = _G["GameTooltipTextLeft" .. i]
               local t = fs and fs:GetText()
               if t ~= nil then tTexts[#tTexts + 1] = t end
            end
         end)
      end
      return tTexts
   end

   local function tSpeak(aTexts)
      if #aTexts == 0 then
         SkuOptions.Voice:OutputStringBTtts(Sku.deEn("Nichts auf der Minikarte", "Nothing on the minimap", "Rien sur la minicarte"), true, true, 0.2)
         return
      end
      local tAnySecret = false
      for _, t in ipairs(aTexts) do
         if tIsSecret(t) then tAnySecret = true end
      end
      if not tAnySecret then
         local tParts = {}
         for _, t in ipairs(aTexts) do
            local c = tostring(t):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", ", ")
            if c ~= "" then tParts[#tParts + 1] = c end
         end
         SkuOptions.Voice:OutputStringBTtts(table.concat(tParts, ", "), true, true, 0.2)
         return
      end
      local tFormat = {}
      for i = 1, #aTexts do tFormat[i] = "%s" end
      pcall(function() SkuOptions.Voice:SpeakSecretText(table.concat(tFormat, ", "), unpack(aTexts)) end)
   end

   local function tFinish(aTexts)
      if tDone then return end
      tDone = true
      pcall(tRestore)
      tRelease()
      pcall(tSpeak, aTexts or {})
   end

   -- safety net: whatever happens, the minimap comes back
   C_Timer.After(4, function() if not tDone then tFinish({}) end end)

   pcall(SkuCore.GameWorldObjects.GameWorldObjectsCenterMouseCursor, SkuCore.GameWorldObjects, 0.5)
   C_Timer.After(0.35, function()
      if tDone then return end
      if InCombatLockdown() then tFinish({}) return end
      local ok = pcall(function()
         pcall(tEnterScanState)
         MinimapScanner:StoreMinimap()
         for _, v in pairs(MinimapScanner.minimapChildren) do
            if v:IsShown() then pcall(v.Hide, v) end
         end
         MinimapCluster:SetFrameStrata("HIGH")
         MinimapCluster:SetFrameLevel(9002)
         Minimap:SetMouseClickEnabled(false)
         tSize.w, tSize.h = Minimap:GetSize()
         GameTooltip:SetAlpha(0)
         Minimap:SetAlpha(0)
         Minimap:SetSize(15, 15)
         Minimap:ClearAllPoints()
         local cx, cy = GetCursorPosition()
         Minimap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / UIParent:GetScale(), cy / UIParent:GetScale())
      end)
      if not ok then tFinish({}) return end
      -- up to six reads, each after a one-pixel nudge, until the game names something
      local tTries = 0
      local function tAttempt()
         if tDone then return end
         tTries = tTries + 1
         local tTexts = tReadTexts()
         if #tTexts > 0 or tTries >= 6 then
            tFinish(tTexts)
         else
            pcall(tNudge)
            C_Timer.After(0.05, tAttempt)
         end
      end
      C_Timer.After(0.1, tAttempt)
   end)
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:MinimapScanFastStop(aResult)
   -- [2026-09-01] THE choke point every scan path funnels through -- the passive
   -- "bei Ressourcen benachrichtigen" notifier, the manual scan, and the gather
   -- route's own presence check (SkuCore/gatherRoute.lua). The route reads its
   -- answer here instead of scanning on a schedule of its own: while the passive
   -- notifier is on, the ambient 0.5 s scans already produce exactly the result
   -- it needs, so the route schedules nothing and costs nothing.
   --
   -- The hook gets the RAW result, before the "\" / "|" escaping below, because
   -- it matches the name against SkuCore.RessourceTypes -- the very table this
   -- scan matched to produce it, so the two agree by construction.
   local tRouteScan = MinimapScanner.routeScanSilent
   MinimapScanner.routeScanSilent = nil
   -- A secret name cannot be compared with the route's node: it proves nothing
   -- either way, so the route is not told.
   local tSecretInfo = type(aResult) == "table" and aResult or nil
   local tSecret = tSecretInfo and tSecretInfo.secret or nil
   if tSecretInfo then aResult = nil end
   if not tSecret and SkuCore.GatherRoute and SkuCore.GatherRoute.OnMinimapScanResult then
      pcall(SkuCore.GatherRoute.OnMinimapScanResult, SkuCore.GatherRoute, aResult, tRouteScan)
   end

   if tRouteScan then
      -- A scan the ROUTE asked for: the route speaks its own outcome ("nicht
      -- vorhanden", "übersprungen", ...), so the bare resource name must not also
      -- be announced -- with the passive notifier off the user would otherwise
      -- start hearing ore names they never asked for. tPrevResult is left
      -- untouched on purpose: it is the announce path's dedup state, and a silent
      -- scan writing to it would swallow the NEXT ambient announcement.
   elseif tSecret then
      -- The tail decided (see MinimapScanFast): "name" speaks the names,
      -- "generic" says a resource is near (it shares the read with another dot,
      -- and which name is which cannot be told), nothing stays quiet.
      if tSecretInfo.say == "name" then
         pcall(function() SkuOptions.Voice:SpeakSecretText("%s", tSecret) end)
      elseif tSecretInfo.say == "generic" then
         SkuOptions.Voice:OutputStringBTtts(Sku.deEn("Ressource in der Nähe", "Resource nearby", "Ressource à proximité"), false, true, 0.2)
      end
      tPrevResult = SECRET_KEY_PREFIX
      tEmptyStreak = 0
   elseif aResult then
      if tPrevResult ~= aResult then
         aResult = string.gsub(aResult, "\\", " slash")
         aResult = string.gsub(aResult, "|", " slash")
         SkuOptions.Voice:OutputStringBTtts(aResult, false, true, 0.2)
         tPrevResult = aResult
      end
      tEmptyStreak = 0
   else
      -- Only three empty reads in a row count as "gone": a single read that
      -- names nothing must not make the same dot be announced again.
      tEmptyStreak = tEmptyStreak + 1
      if tEmptyStreak >= 3 then
         tPrevResult = ""
         tPassiveSize = nil
      end
   end
   MinimapScanner.noMouseOverNotification = nil
   MinimapScanner.IsMMScanning = false
   MinimapScanner.MinimapScanFastRunning = false
   MinimapScanner.MinimapScanFastStartedAt = nil
   -- Timer zurücksetzen, damit der nächste Scan erst nach vollem Intervall startet
   if MinimapScanner.minimapScannerFrame then
      MinimapScanner.minimapScannerFrame.timeCounter = 0
   end
end

---------------------------------------------------------------------------------------------------------------------------------------
function MinimapScanner:MinimapScannerOnLogin()
   tMinimapDefaults.point, tMinimapDefaults.relativeTo, tMinimapDefaults.relativePoint, tMinimapDefaults.x, tMinimapDefaults.y = Minimap:GetPoint()
   tMinimapDefaults.parent = Minimap:GetParent()
   tMinimapDefaults.scale = Minimap:GetScale()
   tMinimapDefaults.zoom = Minimap:GetZoom()
   tMinimapDefaults.alpha = Minimap:GetAlpha()
   tMinimapDefaults.GameTooltipScale = GameTooltip:GetScale()
   tMinimapDefaults.frameLevel = MinimapCluster:GetFrameLevel()
   tMinimapDefaults.frameStrata = MinimapCluster:GetFrameStrata()

   MinimapScanner.minimapChildren = { Minimap:GetChildren() }
   for k, v in pairs(MinimapScanner.minimapChildren) do
      v.MMA_VISIBLE = v:IsVisible()
      v.MMA_FRAME_LEVEL = v:GetFrameLevel()
      v.MMA_FRAME_STRATA = v:GetFrameStrata()
   end


   MinimapScanner:RegisterChatCommand("activeSeekings", "SlashActiveSeekings")
   MinimapScanner:RegisterChatCommand("as", "SlashActiveSeekings")

   -- Normaler Frame (kein SecureActionButtonTemplate) – verhindert Lua-Taint
   -- beim Manipulieren von Minimap und MinimapCluster aus dem OnUpdate heraus.
   if MinimapScanner.minimapScannerFrame then
      MinimapScanner.minimapScannerFrame:SetScript("OnUpdate", nil)
   end
   MinimapScanner.minimapScannerFrame = CreateFrame("Frame", nil, UIParent)
   local a = MinimapScanner.minimapScannerFrame
   a.timeCounter = 0
   a:SetScript("OnUpdate", function(self, atime)
      -- [v43.0] Deadline gegen einen hängenden Schnellscan-Lock. Der Lock wird
      -- im C_Timer-Tail freigegeben (nominell nach 0,1 s); läuft dieser Tail gar
      -- nicht erst an - abgebrochene Ausführung, gelöschter Timer -, greift der
      -- pcall im Tail nicht, weil er nie erreicht wird. Dann räumt das hier auf.
      -- Ein Vergleich pro Frame, und nur solange ein Scan als laufend gilt.
      --
      -- [2026-09-01] Steht VOR dem notifyOnRessources-Tor. Der Lock gehoerte
      -- frueher allein der passiven Ansage, also war "Ansage aus" gleichbedeutend
      -- mit "niemand kann ihn nehmen". Seit die Sammelroute selbst scannt
      -- (SkuCore/gatherRoute.lua, Praesenzpruefung) gilt das nicht mehr: ein
      -- haengender Lock aus einem Routen-Scan wurde hinter dem Tor nie wieder
      -- freigegeben und die Praesenzpruefung blieb bis zum /reload tot.
      if MinimapScanner.MinimapScanFastRunning == true
         and MinimapScanner.MinimapScanFastStartedAt
         and GetTime() - MinimapScanner.MinimapScanFastStartedAt > 5 then
         dprint("MinimapScanFast: Lock nach 5 s ohne Abschluss freigegeben")
         pcall(MinimapScanner.MinimapStopScan, MinimapScanner)
         MinimapScanner.MinimapScanFastRunning = false
         MinimapScanner.MinimapScanFastStartedAt = nil
         MinimapScanner.IsMMScanning = false
         MinimapScanner.routeScanSilent = nil
         self.timeCounter = 0
         return
      end
      -- 14.11.2026: the passive notifier is replaced by the key "minikarte
      -- vorlesen" (MinimapReadAll): the minimap names are secret on WoW Forever
      -- and cannot be filtered, so it would announce every dot while walking.
      if true then
         return
      end
      if SkuCore.inCombat == true then
         return
      end
      if (Sku.UnitSpeed("player") or 0) <= 0 then
         self.timeCounter = 0   -- Zähler beim Stehenbleiben zurücksetzen
         return
      end
      self.timeCounter = self.timeCounter + atime
      if self.timeCounter > 0.5 then   -- wie Vorlage: alle 0,5 s scannen
         if MinimapScanner.IsMMScanning ~= true then
            MinimapScanner.IsMMScanning = true
            local ok = pcall(MinimapScanner.MinimapScanFast, MinimapScanner)
            if not ok then
               MinimapScanner.IsMMScanning = false
               MinimapScanner.MinimapScanFastRunning = false
            end
            self.timeCounter = 0
         end
      end
   end)
end

function MinimapScanner:MinimapScannerCURSOR_CHANGED(aEvent, isDefault, newCursorType, oldCursorType, oldCursorVirtualID)
   --print("CURSOR_CHANGED", aEvent, isDefault, newCursorType, oldCursorType, oldCursorVirtualID)

end

---------------------------------------------------------------------------------------------------------------------------------------
-- /activeSeekings – gibt aktive Minimap-Suchen (Mineralien, Kräuter, ...) im Chat aus und per TTS
function MinimapScanner:SlashActiveSeekings()
   local found = false
   local numTypes = GetNumTrackingTypes and GetNumTrackingTypes() or 0
   for i = 1, numTypes do
      local name, _, active = GetTrackingInfo(i)
      -- C_Minimap.GetTrackingInfo gibt auf neueren Clients eine Tabelle zurück
      if type(name) == "table" then
         local t = name
         name   = t.name
         active = t.active
      end
      if active then
         print("|cff00ff00[Aktiv]|r " .. (name or "?"))
         SkuOptions.Voice:OutputStringBTtts(name or "unbekannt", false, true, 0.2)
         found = true
      end
   end
   if not found then
      print("Keine Suche aktiv.")
      SkuOptions.Voice:OutputStringBTtts("Keine Suche aktiv", false, true, 0.2)
   end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Arm the feature. Called automatically by AceAddon when the module is enabled
-- (at SkuCore enable, and again whenever the user toggles it back on). Replaces
-- the old explicit SkuCore:MinimapScannerOnLogin() call in PLAYER_ENTERING_WORLD;
-- the arming body is unchanged (it lives in MinimapScannerOnLogin, which we call
-- here so the method stays exactly where external callers expect it).
function MinimapScanner:OnEnable()
   MinimapScanner:MinimapScannerOnLogin()
end

-- Disarm the feature: stop any in-progress scan and remove the OnUpdate driver so
-- a disabled MinimapScanner does nothing (no passive resource notifications, no
-- manual scan). The chat command stays registered (AceConsole cannot unregister),
-- but MinimapScan/MinimapScanFast no-op via their IsEnabled guards.
function MinimapScanner:OnDisable()
   MinimapScanner:MinimapStopScan()
   if MinimapScanner.minimapScannerFrame then
      MinimapScanner.minimapScannerFrame:SetScript("OnUpdate", nil)
   end
end