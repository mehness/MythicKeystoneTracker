MythicKeystoneTracker = LibStub("AceAddon-3.0"):NewAddon("MythicKeystoneTracker", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local icon = LibStub("LibDBIcon-1.0")

--[[
    Globals
]]
local bagID = 0
local slotNum = 0
local tellTarget = ""
local affixInfo = {}
local affixIDs = {}
local affixDescs = {}
local daisUp = false
local mktracker

--[[
    [1] = overflowing
    [2] = skittish
    [3] = volcanic
    [4] = necrotic
    [5] = teeming
    [6] = raging
    [7] = bolstering
    [8] = sanguine
    [9] = tyrannical
    [10] = fortified
    [11] = bursting
    [12] = greivous
    [13] = explosive
    [14] = quaking
    [15] = relentless
    [16] = infested
]]

local blizzAffixIDs = {
    [1] = "inv_misc_volatilewater",
    [2] = "spell_magic_lesserinvisibilty",
    [3] = "spell_shaman_lavasurge",
    [4] = "spell_deathknight_necroticplague",
    [5] = "spell_nature_massteleport",
    [6] = "ability_warrior_focusedrage",
    [7] = "ability_warrior_battleshout",
    [8] = "spell_shadow_bloodboil",
    [9] = "achievement_boss_archaedas",
    [10] = "ability_toughness",
    [11] = "ability_ironmaidens_whirlofblood",
    [12] = "ability_backstab",
    [13] = "spell_fire_felflamering_red",
    [14] = "spell_nature_earthquake",
    [15] = "inv_chest_plate04",
    [16] = "achievement_nazmir_boss_ghuun",
}

local defaults = {
    global = {
        currIlvl = {},
        currKeystone = {},
        faction = {},
        class = {},
        weeklyBest = {},
        ldbStorage = {
            hide = false,
            showUI = false
		}
    }
}

local REPORT_TARGETS = {
    ['WHISPER'] = 'Whisper',
    ['GUILD'] = 'Guild',
    ['PARTY'] = 'Party',
    ['CHANNEL'] = 'Community'
}


local mythicKeystoneLDBObject = LibStub("LibDataBroker-1.1"):NewDataObject("MythicKeystoneTrackerIcon", {
    type = "launcher",
    text = "Mythic Keystone Tracker",
    icon = "Interface\\Icons\\spell_magic_polymorphchicken",
    OnClick = function()
        MythicKeystoneTracker:ShowApp()
        end,
    OnTooltipShow = function(tooltip) -- tooltip that shows when you hover over the minimap icon
            tooltip:AddLine("|CFFFFFFFF"  .. "Mythic Keystone Tracker" ..  "|r")
            tooltip:AddLine("Click to open")
		end
    })


local options = {
    name = "Mythic Keystone Tracker",
    handler = MythicKeystoneTracker,
    type = "group",
    args = {
        clearData = {
            type = "execute",
            name = "Master Clear",
            desc = "Click here to clear all the data in the addon.",
            func = "ClearKeystones"
        },
        showAddon = {
            type = "execute",
            name = "Show Addon",
            desc = "Click here to bring up the addon.",
            func = "UIBringUp"
        },
    },
}
--[[
    Initialization
]]
function MythicKeystoneTracker:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("MythicKeystoneTrackerDB", defaults, true) --true indicates default sharing for all characters
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MythicKeystoneTracker", options, {"MythicKeystoneTracker", "mkt"})
    self:RegisterChatCommand("mkt", "ChatCommand")
    self:RegisterChatCommand("MythicKeystoneTracker", "ChatCommand")
    self:RegisterChatCommand("mkt_clear", "ClearKeystones")
    self:RegisterChatCommand("mkt_iconshow", "MiniMapButton")
    icon:Register("MythicKeystoneTrackerIcon", mythicKeystoneLDBObject, self.db.global.ldbStorage)
    print("|CFF00FF96 " .. "<MKT>" .. " |r" .. " /mkt -  to bring up if minimap icon is disabled" )
    print("|CFF00FF96 " .. "<MKT>" .. " |r" .. " /mkt_iconshow -  to toggle the minimap icon" )
    print("|CFF00FF96 " .. "<MKT>" .. " |r" .. " /mkt_clear -  to clear the database if something goes wrong" )
    self.db.global.ldbStorage.showUI = false
end

function MythicKeystoneTracker:OnEnable()
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
end

function MythicKeystoneTracker:OnDisable()
    self:AliveToggle()
    if not self.db.global.ldbStorage.showUI then 
        if mktracker then 
            AceGUI:Release(mktracker)
        end
    end
end

--[[
    Events
]]
function MythicKeystoneTracker:CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN()
    if self:FindCurrentKeystone() then
        PickupContainerItem(bagID, slotNum)
        C_ChallengeMode.SlotKeystone()
        C_ChallengeMode.SetKeystoneTooltip(true)
        daisUp = false
    end
end

function MythicKeystoneTracker:UNIT_INVENTORY_CHANGED()
    self:FindCurrentKeystone()
    self:RefreshingTable()
end

function MythicKeystoneTracker:BAG_UPDATE()
    self:FindCurrentKeystone()
    self:UpdateTable(self.ScrollTable)
end

function MythicKeystoneTracker:PLAYER_ENTERING_WORLD()
    --self:UpdateTable(self.ScrollTable)
end

function MythicKeystoneTracker:MiniMapButton()
    self.db.global.ldbStorage.hide = not self.db.global.ldbStorage.hide
    if self.db.global.ldbStorage.hide then
        icon:Hide("MythicKeystoneTrackerIcon")
    else
        icon:Show("MythicKeystoneTrackerIcon")
    end
end

--[[
    Window/UI Creation
]]
function MythicKeystoneTracker:UIBringUp()
    -- Create UI children
    local charLabel, availReward
    local affixOne, affixTwo, affixThree, seasonAffix
    local currKeyLabel, clearBtn, refreshBtn, openBagBtn, reportDd, whisperTarget, sendBtn, closeBtn, MiniMapToggleBox
    
    local affixAcquired = false
    local currKeyInfo = "No Key"

    --print(self:FindCurrentKeystone())

    -- Create a container frame
    mktracker = AceGUI:Create("Window")
    
    self:AliveToggle()

    mktracker:SetCallback("OnClose",function(widget)
        self.db.global.ldbStorage.showUI = false
        AceGUI:Release(widget) 
    end)

    mktracker:SetTitle("Mythic Keystone Tracker")
    mktracker:SetLayout("Flow")
    mktracker:SetWidth(800)
    mktracker:SetHeight(600)
    mktracker:EnableResize(false)

    -- character banner
    charLabel = AceGUI:Create('Label')
    charLabel:SetWidth(300)
    charLabel:SetHeight(20)
    charLabel:SetFont("Fonts\\FRIZQT__.TTF", 20, "REGULAR")
    charLabel:SetText("|CFFEEC300" .. "Current: " .. "|r" .. self:ColorizeMe(self:GetClass(), self:GetName() .. " (+" .. self:WeeklyBest() ..  ")"))
    mktracker:AddChild(charLabel)

    -- weekly chest available
    availReward = AceGUI:Create('Icon')
    if not self:GetWeeklyRewardAvailability() then
        availReward:SetImage("")
        availReward:SetWidth(0)
        availReward:SetDisabled(true)
    else
        availReward:SetImage("Interface\\Icons\\inv_legion_chest_valajar")
        availReward:SetImageSize(45,45)
        availReward:SetWidth(45)
        availReward:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
            GameTooltip:AddLine("Your weekly Grand Challenger's Bounty is available!")
            GameTooltip:Show()
        end)
        availReward:SetCallback("OnLeave", function()
            SetItemSearch("")
            GameTooltip:Hide()
        end)
    end
    mktracker:AddChild(availReward)

    -- weekly affixes
    if affixIDs then
        affixAcquired = true
        affixIDs = self:ClassifyAffixLevels(affixIDs)
        affixInfo, affixDescs = self:GetAffixData(affixIDs)

        affixOne = AceGUI:Create('Icon')
        affixOne:SetImage("Interface\\Icons\\" .. blizzAffixIDs[affixIDs[1]])
        affixOne:SetLabel(affixInfo[1])
        affixOne:SetImageSize(15, 15)
        affixOne:SetWidth(70)
        affixOne:SetCallback("OnEnter", function()
            self:AffixToolTip_Show(1)
        end)
        affixOne:SetCallback("OnLeave", function()
            self:AffixToolTip_Hide()
        end)
        mktracker:AddChild(affixOne)
        
        affixTwo = AceGUI:Create('Icon')
        affixTwo:SetImage("Interface\\Icons\\" .. blizzAffixIDs[affixIDs[2]])
        affixTwo:SetLabel(affixInfo[2])
        affixTwo:SetImageSize(15, 15)
        affixTwo:SetWidth(70)
        affixTwo:SetCallback("OnEnter", function()
            self:AffixToolTip_Show(2)
        end)
        affixTwo:SetCallback("OnLeave", function()
            self:AffixToolTip_Hide()
        end)
        mktracker:AddChild(affixTwo)
        
        affixThree = AceGUI:Create('Icon')
        affixThree:SetImage("Interface\\Icons\\" .. blizzAffixIDs[affixIDs[3]])
        affixThree:SetLabel(affixInfo[3])
        affixThree:SetImageSize(15, 15)
        affixThree:SetWidth(70)
        affixThree:SetCallback("OnEnter", function()
            self:AffixToolTip_Show(3)
        end)
        affixThree:SetCallback("OnLeave", function()
            self:AffixToolTip_Hide()
        end)
        mktracker:AddChild(affixThree)
        
        if affixIDs[4] then
            seasonAffix = AceGUI:Create('Icon')
            seasonAffix:SetImage("Interface\\Icons\\" .. blizzAffixIDs[affixIDs[4]])
            seasonAffix:SetLabel(affixInfo[4])
            seasonAffix:SetImageSize(15, 15)
            seasonAffix:SetWidth(70)
            seasonAffix:SetCallback("OnEnter", function()
                self:AffixToolTip_Show(4)
            end)
            seasonAffix:SetCallback("OnLeave", function()
                self:AffixToolTip_Hide()
            end)
            mktracker:AddChild(seasonAffix)
        end
    end

    -- keystone banner
    currKeyLabel = AceGUI:Create('Label')
    currKeyLabel:SetWidth(300)
    currKeyLabel:SetHeight(45)
    currKeyLabel:SetFont("Fonts\\FRIZQT__.TTF", 20, "REGULAR")

    if self:FindCurrentKeystone() then
        currKeyInfo = self:GetCurrentLoggedKeystone()
    end
    currKeyLabel:SetText(currKeyInfo)
    mktracker:AddChild(currKeyLabel)

    -- table clear button
    clearBtn = AceGUI:Create('Button')
    clearBtn:SetWidth(150)
    clearBtn:SetText('Clear Table')
    clearBtn:SetCallback('OnClick', function()
        self:ClearKeystones()
    end)
    clearBtn:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        GameTooltip:AddLine("Clears the whole table.")
        GameTooltip:Show()
    end)
    clearBtn:SetCallback("OnLeave", function()
        SetItemSearch("")
        GameTooltip:Hide()
    end)
    mktracker:AddChild(clearBtn)
    
    -- table refresh button
    refreshBtn = AceGUI:Create('Button')
    refreshBtn:SetWidth(150)
    refreshBtn:SetText('Refresh Table')
    refreshBtn:SetCallback('OnClick', function()
        self:RefreshingTable()
    end)
    refreshBtn:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        GameTooltip:AddLine("Refreshes the current character's entry.")
        GameTooltip:Show()
    end)
    refreshBtn:SetCallback("OnLeave", function()
        SetItemSearch("")
        GameTooltip:Hide()
    end)
    mktracker:AddChild(refreshBtn)

    -- keystone locate in bag button
    openBagBtn = AceGUI:Create('Icon')
    if not self:FindCurrentKeystone() then
        openBagBtn:SetImage("")
        openBagBtn:SetWidth(0)
        openBagBtn:SetDisabled(true)
    else 
        openBagBtn:SetImage("Interface\\Icons\\inv_relics_hourglass")
        openBagBtn:SetImageSize(45,45)
        openBagBtn:SetWidth(45)
        openBagBtn:SetCallback("OnClick",function()             
            local bagNum = 1
            OpenBag(bagID)
            for i = 0, 4 do
                if IsBagOpen(i) and i ~= bagID then
                    bagNum = bagID + 1
                end
            end
            self:HighlightKeystone(bagNum)
            SetItemSearch("Keystone") 
        end)
        openBagBtn:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(GetContainerItemLink(bagID,slotNum))
            GameTooltip:Show()
        end)
        openBagBtn:SetCallback("OnLeave", function()
            SetItemSearch("")
            GameTooltip:Hide()
        end)
    end
    mktracker:AddChild(openBagBtn)

    -- create table 
    local ScrollingTable = LibStub("ScrollingTable");
    local cols = {
        {
            ['name'] = 'Character',
            ['width'] = 90,
            ['align'] = 'LEFT',
        },
       
        {
            ['name'] = 'Realm',
            ['width'] = 140,
            ['align'] = 'MIDDLE',
        },

        {
            ['name'] = 'Item Level',
            ['width'] = 70,
            ['align'] = 'MIDDLE',
        },

        {
            ['name'] = 'Weekly Best',
            ['width'] = 95,
            ['align'] = 'MIDDLE',
        },

        {
            ['name'] = 'Dungeon',
            ['width'] = 165,
            ['align'] = 'MIDDLE',
        },

        {
            ['name'] = 'Level',
            ['width'] = 35,
            ['align'] = 'MIDDLE',
        },
    }
    self.TestTable = ScrollingTable:CreateST(cols, 16, 20, nil)

    local tableWrapper = AceGUI:Create('lib-st'):WrapST(self.TestTable)

    tableWrapper.head_offset = 20
    mktracker:AddChild(tableWrapper)
    self:UpdateTable(self.TestTable)

    -- report to dropdown
    reportDd = AceGUI:Create('Dropdown')
    reportDd:SetLabel('Send to')
    reportDd:SetList(REPORT_TARGETS)
    reportDd:SetWidth(125)
    reportDd:SetCallback("OnValueChanged", function(self, event, key)
        tellTarget = key
    end)
    mktracker:AddChild(reportDd)

    -- report target box
    whisperTarget = AceGUI:Create('EditBox')
    whisperTarget:SetWidth(195)
    whisperTarget:SetLabel("Community Channel/Whisper Target")
    mktracker:AddChild(whisperTarget)

    -- report send button
    sendBtn = AceGUI:Create('Button')
    sendBtn:SetWidth(100)
    sendBtn:SetText('Send')
    sendBtn:SetCallback("OnClick", function()
        local target = whisperTarget:GetText()
        self:ReportKeys(target)
    end)
    mktracker:AddChild(sendBtn)

    -- window close button
    closeBtn = AceGUI:Create('Button')
    closeBtn:SetWidth(100)
    closeBtn:SetText('Close')
    closeBtn:SetCallback("OnClick",function()
        self.db.global.ldbStorage.showUI = false
        mktracker:ReleaseChildren()
        mktracker:Release()
    end)
    mktracker:AddChild(closeBtn)
    
    -- minimap icon show toggle
    MiniMapToggleBox = AceGUI:Create('CheckBox')
    MiniMapToggleBox:SetWidth(200)
    MiniMapToggleBox:SetLabel('Minimap Icon')
    MiniMapToggleBox:SetValue(not self.db.global.ldbStorage.hide)
    MiniMapToggleBox:SetCallback("OnValueChanged", function()
        self.db.global.ldbStorage.hide = MiniMapToggleBox:GetValue()
        self:MiniMapButton()
    end)
    mktracker:AddChild(MiniMapToggleBox)
    
    -- element hard placement in the UI window
    if affixAcquired then
        affixOne:ClearAllPoints()
        affixOne:SetPoint('BOTTOMLEFT', mktracker.frame, 25, 75)
        affixTwo:ClearAllPoints()
        affixTwo:SetPoint('BOTTOMLEFT', mktracker.frame, 125, 75)
        affixThree:ClearAllPoints()
        affixThree:SetPoint('BOTTOMLEFT', mktracker.frame, 225, 75)
        if affixIDs[4] then
            seasonAffix:ClearAllPoints()
            seasonAffix:SetPoint('BOTTOMLEFT', mktracker.frame, 325, 75)
        end
        affixAcquired = false
    end
    
    charLabel:ClearAllPoints()
    charLabel:SetPoint('CENTER', mktracker.frame, 0, 250)
    currKeyLabel:ClearAllPoints()
    currKeyLabel:SetPoint('CENTER', mktracker.frame, 0, 225)
    clearBtn:ClearAllPoints()
    clearBtn:SetPoint('BOTTOMRIGHT', mktracker.frame, -30, 75)
    refreshBtn:ClearAllPoints()
    refreshBtn:SetPoint('BOTTOMRIGHT', mktracker.frame, -190, 75)
    availReward:ClearAllPoints()
    availReward:SetPoint('TOPLEFT', mktracker.frame, 70, -40)
    openBagBtn:ClearAllPoints()
    openBagBtn:SetPoint('TOPRIGHT', mktracker.frame, -70, -40)
    tableWrapper:ClearAllPoints()
    tableWrapper:SetPoint('CENTER', mktracker.frame, 0, 0)

    reportDd:ClearAllPoints()
    reportDd:SetPoint('BOTTOMLEFT', mktracker.frame, 20, 20)
    whisperTarget:ClearAllPoints()
    whisperTarget:SetPoint('BOTTOMLEFT', mktracker.frame, 150, 20)
    sendBtn:ClearAllPoints()
    sendBtn:SetPoint('BOTTOMLEFT', mktracker.frame, 370, 22)
    MiniMapToggleBox:ClearAllPoints()
    MiniMapToggleBox:SetPoint('BOTTOMRIGHT', mktracker.frame, -90, 22)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint('BOTTOMRIGHT', mktracker.frame, -30, 22)

end

-- find keystone in bag, store position, and place results into db
function MythicKeystoneTracker:FindCurrentKeystone()
    local itemID = 138019
    local BFAkey = 158923
    local exists = false
    local currChar = self:NameAndRealmAndFaction()

    affixIDs = self:GetAffixIds()

    if not self.db.global.currKeystone then
        self.db.global.currKeystone = {}
        return nil
    end

    if self:GetCharacterLevel() == 120 then
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 0, GetContainerNumSlots(bag) do
                if(GetContainerItemID(bag, slot) == itemID or GetContainerItemID(bag, slot) == BFAkey) then                    
                    bagID = bag
                    slotNum = slot
                    local itemLink = GetContainerItemLink(bag, slot)
                    local info = self:ParseKey(itemLink)

                    self.db.global.currIlvl[currChar] = self:GetItemLevel()
                    --self.db.global.weeklyBest[currChar] = self:WeeklyBest()
                    self.db.global.currKeystone[currChar] = {itemLink, info.dungeonName, info.level}
                    self:UpdateTable(self.ScrollTable)
                    exists = true
                    return itemLink
                    
                end
                if not exists then
                    local itemLink = nil
                    local info = self:ParseKey(itemLink)
                    self.db.global.currIlvl[currChar] = self:GetItemLevel()
                    --self.db.global.weeklyBest[currChar] = self:WeeklyBest()
                    self.db.global.currKeystone[currChar] = {itemLink, dungeonName, level}
                    self:UpdateTable(self.ScrollTable)
                end
            end   
        end
    end    
end

-- extract meaningful data from the keystone itemlink
function MythicKeystoneTracker:ParseKey(link)
	if not link then
		return nil
	end

	local parts = { strsplit(':', link) }

	local dungeonId = tonumber(parts[3])
	local level = tonumber(parts[4])
    
    local dungeonName, _, _, _, _ = C_ChallengeMode.GetMapUIInfo(dungeonId)

	return {
		dungeonId = dungeonId,
		dungeonName = dungeonName,
		level = level
    }
    
end

-- find the weekly best completed and store in the db
function MythicKeystoneTracker:WeeklyBest() --compare query to stored value
    local currChar = self:NameAndRealmAndFaction()
	if not self.db.global.weeklyBest then
		self.db.global.weeklyBest = {}
	end
    
    local best = 0
   
    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestRewards()

    local mapTable = C_ChallengeMode.GetMapTable()

    for i, mapId in pairs(mapTable) do
        local _, weeklyBestLevel, _, _, _ = C_MythicPlus.GetWeeklyBestForMap(mapId)

        if weeklyBestLevel and weeklyBestLevel > best then
            best = weeklyBestLevel
        end
    end
        
	self.db.global.weeklyBest[currChar] = best
	return best
end

-- key report out function
function MythicKeystoneTracker:ReportKeys(target)
    for char, keystone in pairs(self.db.global.currKeystone) do
        local info = self:ParseKey(keystone[1])
        local factionExtract = self:CharPortionGrab(char, 3)
        local classExtract = self:CharPortionGrab(char, 4)    
        local faction = UnitFactionGroup("player")

        if string.find(factionExtract, faction) then
            if info then
                SendChatMessage(self:CharPortionGrab(char, 1) .. ' - ' .. keystone[1],
                    tellTarget,
                    nil,
                    target)
            end
        end
    end

end

-- populate the table
function MythicKeystoneTracker:UpdateTable(table)
    if not table then
		return
    end
    local tableData = { }
    if self.db.global.currKeystone then
        for char, keystone in pairs(self.db.global.currKeystone) do
            local info = self:ParseKey(keystone[1])
            local weekly = self.db.global.weeklyBest[char]
            local factionExtract = self:CharPortionGrab(char, 3)
            local classExtract = self:CharPortionGrab(char, 4)    
            local na = "-"        
            local ilvl = self.db.global.currIlvl[char]
            ilvl = math.floor(ilvl)
            
            if info then
                tinsert(tableData, {
                    self:ColorizeMe(classExtract, self:CharPortionGrab(char, 1)),
                    self:ColorizeMe(factionExtract, self:CharPortionGrab(char, 2)),
                    ilvl,
                    weekly,
                    info.dungeonName,
                    info.level
                })
            else
                tinsert(tableData, {
                    self:ColorizeMe(classExtract, self:CharPortionGrab(char, 1)),
                    self:ColorizeMe(factionExtract, self:CharPortionGrab(char, 2)),
                    ilvl,
                    weekly,
                    na,
                    na
                })
            end
        end
        table:SetData(tableData, true);
    end
end

-- color text for faction and class
function MythicKeystoneTracker:ColorizeMe(faction, stringToColor)
    if string.find(faction, "Warrior") then
        return "|CFFC79C6E " .. stringToColor .. " |r" -- Warrior colors
    elseif string.find(faction, "Paladin") then
        return "|CFFF58CBA " .. stringToColor .. " |r" -- Paladin colors
    elseif string.find(faction, "Demon Hunter") then
        return "|CFFA330C9 " .. stringToColor .. " |r" -- Demon Hunter colors
    elseif string.find(faction, "Hunter") then
        return "|CFFABD473 " .. stringToColor .. " |r" -- Hunter colors
    elseif string.find(faction, "Rogue") then
        return "|CFFFFF569 " .. stringToColor .. " |r" -- Rogue colors
    elseif string.find(faction, "Priest") then
        return "|CFFFFFFFF " .. stringToColor .. " |r" -- Priest colors
    elseif string.find(faction, "Death Knight") then
        return "|CFFC41F3B " .. stringToColor .. " |r" -- Death Knight colors
    elseif string.find(faction, "Shaman") then
        return "|CFF0070DE " .. stringToColor .. " |r" -- Shaman colors
    elseif string.find(faction, "Mage") then
        return "|CFF69CCF0 " .. stringToColor .. " |r" -- Mage colors
    elseif string.find(faction, "Warlock") then
        return "|CFF9482C9 " .. stringToColor .. " |r" -- Warlock colors
    elseif string.find(faction, "Monk") then
        return "|CFF00FF96 " .. stringToColor .. " |r" -- Monk colors
    elseif string.find(faction, "Druid") then
        return "|CFFFF7D0A " .. stringToColor .. " |r" -- Druid colors

    elseif string.find(faction, "Horde") then
        return "|CFFFF0000 " .. stringToColor .. " (H) |r" -- horde colors
    elseif string.find(faction, "Alliance") then      
        return "|CFF00CCFF " .. stringToColor .. " (A) |r" -- alliance colors

    else 
        return "|CFFFFFFFF " .. stringToColor .. " |r" -- default white
    end
end

-- parse the stored character info
function MythicKeystoneTracker:CharPortionGrab(char,pos)
    local parts = { 
        strsplit('-', char) 
    }
    return parts[pos]
end

-- get this week's affix ID tuple from client
function MythicKeystoneTracker:GetAffixIds()
    return C_MythicPlus.GetCurrentAffixes()
end

-- extract names from affix tuple
function MythicKeystoneTracker:GetAffixData(affixID)
    if not affixID then 
        return
    else
        local affixData = {}
        local affixDesc = {}
        for i = 1, 3 do
            affixData[i], affixDesc[i] = C_ChallengeMode.GetAffixInfo(affixID[i])
        end
        return affixData, affixDesc
    end
end

-- reorder the affixes into +4, +7, +10 and seasonal
function MythicKeystoneTracker:ClassifyAffixLevels(affixID)
    affLevel = {}

    for i = 1, 4 do
        if affixID[i] == 9 or affixID[i] == 10 then
            affLevel[1] = affixID[i]
        end

        if affixID[i] == 5 or affixID[i] == 6 or affixID[i] == 7 or affixID[i] == 8 or affixID[i] == 11 then
            affLevel[2] = affixID[i]
        end

        if affixID[i] == 2 or affixID[i] == 3 or affixID[i] == 4 or affixID[i] == 12 or affixID[i] == 13 or affixID[i] == 14 then
            affLevel[3] = affixID[i]
        end

        if affixID[i] == 15 or affixID[i] == 16 then
            affLevel[4] = affixID[i]
        end
    end
    return affLevel
end

-- track and store window showing status in db
function MythicKeystoneTracker:AliveToggle()
    self.db.global.ldbStorage.showUI = not self.db.global.ldbStorage.showUI
end

-- refresh and show the UI
function MythicKeystoneTracker:ShowApp()
    if not self.db.global.ldbStorage.showUI then
        self:RefreshingTable()
        self:UIBringUp()
    else
        self:OnDisable()
    end
end

-- grab the text from the command line to show the addon
function MythicKeystoneTracker:ChatCommand(input)
    if not input or input:trim() == "" then
        self:ShowApp()
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("mkt", "MythicKeystoneTracker", input)
    end
end

-- clear the data in the db
function MythicKeystoneTracker:ClearKeystones()
	self.db.global.currKeystone = {}
	self.db.global.weeklyBest = {}
    self:UpdateTable(self.TestTable)
end

-- refesh the data for the current character in the db
function MythicKeystoneTracker:RefreshingTable()
    self:FindCurrentKeystone()
    self:WeeklyBest()
    self:UpdateTable(self.TestTable)
end

-- make the keystone flash like a new item
function MythicKeystoneTracker:HighlightKeystone(bagNum)
    local frame = _G["ContainerFrame" .. bagNum]
    local slot = 0
    
    slot = GetContainerNumSlots(bagID) - slotNum + 1
    
    name = frame:GetName()

    newItemTexture = _G[name .. "Item" .. slot].NewItemTexture
    newItemAnim = _G[name .. "Item" .. slot].newitemglowAnim
    flash = _G[name .. "Item" .. slot].flashAnim
    
    newItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[4])
    newItemTexture:Show()
    
    flash:Play()
    newItemAnim:Play()
end

-- extract keystone info for the banner
function MythicKeystoneTracker:GetCurrentLoggedKeystone()
    if self.db.global.currKeystone[self:NameAndRealmAndFaction()] then
        keyInfo = self.db.global.currKeystone[self:NameAndRealmAndFaction()]
        
        currKey = self:ParseKey(keyInfo[1])
        keyName = currKey.dungeonName
        keyLevel = currKey.level
        
        keyBannerString = keyName .. " +" .. keyLevel

        return keyBannerString
    end
end

function MythicKeystoneTracker:AffixToolTip_Show(number)
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:AddLine(affixInfo[number])
    GameTooltip:AddLine(affixDescs[number], 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function MythicKeystoneTracker:AffixToolTip_Hide()
    GameTooltip:Hide()
end

function MythicKeystoneTracker:NameAndRealmAndFaction()
    return self:GetName() .. '-' .. self:GetRealm() .. '-' .. self:GetFaction() .. '-' .. self:GetClass()
end

function MythicKeystoneTracker:SetName(name)
    self.db.global.charName = name
end

function MythicKeystoneTracker:GetRealm()
    return GetRealmName()
end

function MythicKeystoneTracker:GetName()
    return UnitName("player")
end

function MythicKeystoneTracker:GetCharacterLevel()
    return UnitLevel("player")
end

function MythicKeystoneTracker:GetClass()
    return UnitClass("player")
end

function MythicKeystoneTracker:GetFaction()
    return UnitFactionGroup("player") 
end

function MythicKeystoneTracker:GetItemLevel()
    local _, equipped = GetAverageItemLevel()
    return equipped
end

function MythicKeystoneTracker:GetWeeklyRewardAvailability()
    return C_MythicPlus.IsWeeklyRewardAvailable()
end