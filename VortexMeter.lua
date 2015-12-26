---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

VortexMeter = {
	name = "VortexMeter",
	version = {1,3,5},

	combats = {},
	Units = {},
	Abilities = {},
	
	CurrentCombat = {},
	
	settings = {
		windows = {},
		lock = false,
		alwaysShowPlayer = false,
		showOnlyBoss = false,
		showRankNumber = true,
		showPercent = true,
		showAbsolute = true,
		showShortNumber = false,
		opacity = 0,
		tooltips = true,
		enabled = true,
		updaterate = 0.1,
		mousetransparancy = 0.5,
	},
	
	-- Class colors taken directly from website
	classColors = {
		[GameLib.CodeEnumClass.Warrior]      = {0.8,  0.1,  0.1},
		[GameLib.CodeEnumClass.Engineer]     = {0.65, 0.65, 0},
		[GameLib.CodeEnumClass.Esper]        = {0.1,  0.5,  0.7},
		[GameLib.CodeEnumClass.Medic]        = {0.2,  0.6,  0.1},
		[GameLib.CodeEnumClass.Stalker]      = {0.5,  0.1,  0.8},
		[GameLib.CodeEnumClass.Spellslinger] = {0.9,  0.4,  0},
	},

	abilityTypeColors = {
		[GameLib.CodeEnumDamageType.Magic] = {0.5, 0.1, 0.8},
		[GameLib.CodeEnumDamageType.Tech] = {0.2, 0.6, 0.1},
		[GameLib.CodeEnumDamageType.Physical] = {0.6, 0.6, 0.6},
		[GameLib.CodeEnumDamageType.HealShields] = {0.1, 0.5, 0.7},
		[GameLib.CodeEnumDamageType.Heal] = {0, 0.8, 0},
		[GameLib.CodeEnumDamageType.Fall] = {0.6, 0.6, 0.6},
		[GameLib.CodeEnumDamageType.Suffocate] = {0.6, 0.6, 0.6},
	},

	Meta = {
		Ability = {},
		Player = {},
	},

	L = setmetatable({}, {__index = function(self, key) return tostring(key) end})
}

local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local tempty = function(t) for k in pairs(t) do t[k] = nil end end
local max = math.max
local min = math.min
local round = function(val) return math.floor(val + .5) end
local setmetatable = setmetatable
local VortexMeter = VortexMeter

local Units = VortexMeter.Units
local Abilities = VortexMeter.Abilities

local LastUpdate = 0
local LastTimerUpdate = 0
local InCombat = false
local NeedsUpdate = false
local Permanent = false -- manual combat start

local L = VortexMeter.L
local Ability = VortexMeter.Meta.Ability
local Player = VortexMeter.Meta.Player

function VortexMeter.GetDefaultWindowSettings()
	local defaults = {
		sort = "damage",
		rows = 8,
		width = 300,
		rowHeight = 18,
	}
	defaults.x = (Apollo.GetDisplaySize().nWidth - defaults.width) / 2
	defaults.y = Apollo.GetDisplaySize().nHeight / 2
	return defaults
end


local Combat = {}
Combat.__index = Combat
function Combat:new(overall)
	local self = {}
	self.startTime = GameLib.GetGameTime()
	self.overall = overall
	self.duration = 0
	self.previousDuration = 0
	self.lastDamageAction = 0
	self.players = {}
	self.hostiles = {}
	self.hasBoss = false
	return setmetatable(self, Combat)
end
function Combat:End()
	-- snap duration back to time of last recorded event
	self.duration = self.lastDamageAction - self.startTime
end
function Combat:getPreparedPlayerData(sort, showNpcs)
	local data = {
		players = {},
		count = 0,
		max = 0,
		total = 0
	}
	
	local players = {}
	for _, player in pairs(self.players) do
		if not player.detail.isPet and (not showNpcs == player.detail.player) then
			tinsert(players, player)
		end
	end
	
	-- Players and pets > other units + sort by stat desc
	tsort(players, function (a, b)
		return a:getStat(sort) > b:getStat(sort)
	end)
	
	for i, player in ipairs(players) do
		local value = player[sort]
		local valuePlusPets = player:getStat(sort)
		if valuePlusPets > 0 then
			local name
			if player.linkedToOwner then
				name = ("%s (%s)"):format(player.detail.name, player.detail.owner.name)
			else
				name = player.detail.name
			end
			
			tinsert(data.players, {
				name = name,
				value = valuePlusPets,
				ref = player
			})
			
			data.total = data.total + valuePlusPets
			data.count = data.count + 1
		end
	end
	
	data.total = data.total
	if data.count > 0 then
		data.max = data.players[1].value
	end
	
	return data
end
function Combat:getHostile()
	local players = {}
	
	if self.overall then
		return L["Total"]
	end
	
	for _, player in pairs(self.players) do
		tinsert(players, player)
	end
	
	-- other units > Players and pets + sort by damage taken desc
	tsort(players, function (a, b)
		local aCond = not (a.detail.player or a.detail.isPet)
		local bCond = not (b.detail.player or b.detail.isPet)
		if aCond and bCond then
			return a.damageTaken > b.damageTaken
		end
		return aCond and not bCond
	end)
	
	if #players > 0 then
		return players[1].detail.name
	end
	
	return ""
end
function Combat:addPlayer(unit)
	local player = self.players[unit]
	if not player then
		player = Player:new(unit, false)
		self.players[unit] = player
	end
	if player.detail.isPet then
		self:linkPetToOwner(player)
	end
	
	return player
end
function Combat:linkPetToOwner(pet)
	if not pet.linkedToOwner then
		local owner = self.players[pet.detail.owner]
		if owner then
			pet.linkedToOwner = true
			tinsert(owner.pets, pet)
		end
	end
end

--

local function AddGlobalAbility(info)
	local key = info.ability:GetId() .. (info.periodic and "1" or "0")
	local ability = Abilities[key]
	if not ability then
		Abilities[key] = {
			name = info.ability:GetName(),
			icon = info.ability:GetIcon(),
		}
	end
	return ability
end

local function AddGlobalUnit(detail, owner)
	local id = detail:GetId() or (owner and (owner:GetId().."pet")) or -1
	local unit = Units[id]
	
	if not unit then
		unit = {
			name = detail:GetName(),
			player = detail:IsACharacter(),
			id = detail:GetId(),
			--inGroup = detail:IsInYourGroup() or detail:IsThePlayer(),
			self = detail:IsThePlayer(),
			class = detail:GetClassId(),
			hostile = (GameLib.GetPlayerUnit() and GameLib.GetPlayerUnit():GetDispositionTo(detail) ~= Unit.CodeEnumDisposition.Friendly),
		}
	
		Units[id] = unit
	end

	if owner and not unit.isPet then
		unit.isPet = true
		unit.owner = AddGlobalUnit(owner, nil)
	end
	
	return unit
end

local function CombatEventsHandler(info, statType, damageAction)
	-- Sometimes the API gives us a nil target or caster, ignore these cases.
	if not info.caster or not info.target then return end
	
	local target = AddGlobalUnit(info.target, nil)
	local caster = AddGlobalUnit(info.caster, info.owner)
	
	AddGlobalAbility(info)
	
	local selfAction = info.caster == info.target
	if not selfAction then
		if statType == "damage" or statType == "interrupts" then
			if not InCombat then --and caster.inGroup then
				VortexMeter.NewCombat()
			end
		end
	else
		-- self damage action, e.g. fall damage
		if statType == "damage" then
			statType = "damageTaken"
		end
	end
	
	if InCombat then
		if damageAction then-- and caster.inGroup then
			VortexMeter.CurrentCombat.lastDamageAction = GameLib.GetGameTime()
			NeedsUpdate = true
		end
	else
		return
	end
	
	if info.caster:GetRank() == Unit.CodeEnumRank.Elite or
	   info.target:GetRank() == Unit.CodeEnumRank.Elite then
		VortexMeter.CurrentCombat.hasBoss = true
	end
	
	local amount = info[statType] or 0
	
	if info.owner then
		VortexMeter.overallCombat:addPlayer(caster.owner)
		VortexMeter.CurrentCombat:addPlayer(caster.owner)
	end
	
	local overallCasterInCombat = VortexMeter.overallCombat:addPlayer(caster)
	local casterInCombat = VortexMeter.CurrentCombat:addPlayer(caster)
	
	-- Add stat to caster
	local stat
	if statType == "damageTaken" then
		stat = "damageTaken"
		amount = info.damage or 0
	elseif damageAction then
		stat = "damage"
	else
		stat = "heal"
	end
	
	overallCasterInCombat:addStat(target, stat, statType, amount, info)
	casterInCombat:addStat(target, stat, statType, amount, info)
	
	-- Add Overheal/Overkill
	local key
	if info.overkill and info.overkill > 0 then
		key = "overkill"
	elseif info.overheal and info.overheal > 0 then
		key = "overheal"
	elseif info.interrupts and info.interrupts > 0 then
	  key = "interrupts"
	end
	
	if key then
		overallCasterInCombat:addStat(target, key, key, info[key], info)
		casterInCombat:addStat(target, key, key, info[key], info)
	end
	
	-- Add targets equivalent damage/heal taken
	if target then
		local overallTargetInCombat = VortexMeter.overallCombat:addPlayer(target)
		local targetInCombat = VortexMeter.CurrentCombat:addPlayer(target)
		
		local taken
		if damageAction then
			taken = "damageTaken"
		elseif statType == "heal" then
			taken = "healTaken"
		end
		
		if taken then
			overallTargetInCombat:addStat(caster, taken, taken, amount, info)
			targetInCombat:addStat(caster, taken, taken, amount, info)
		end
	end
end

function VortexMeter:OnLoad()
	Apollo.LoadSprites("VortexMeterSprites.xml", "VortexMeterSprites")
	self.xmlMainDoc = XmlDoc.CreateFromFile("VortexMeter.xml")
	Event_FireGenericEvent("OneVersion_ReportAddonInfo", self.name, unpack(self.version))

	-- Add interface button
	Apollo.RegisterEventHandler("VortexMeter_Toggle", "Toggle", self)
	self:OnInterfaceMenuList()
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuList", self)
	
	-- Register slash handler
	Apollo.RegisterSlashCommand("vm", "SlashHandler", self)
	Apollo.RegisterSlashCommand("vortex", "SlashHandler", self)
	Apollo.RegisterSlashCommand("vortexmeter", "SlashHandler", self)

	-- Add default window
	tinsert(VortexMeter.settings.windows, VortexMeter.GetDefaultWindowSettings())

	-- Wait 0s to let OnRestore() fire
	self.tmrDelayedInit = ApolloTimer.Create(0, false, "DelayedInit", self)
end

function VortexMeter:DelayedInit()
	self.tmrDelayedInit = nil

	-- First-load-ever init stuff
	if not self.bSettingsLoaded then
		-- Set game variable to log other players
		Apollo.SetConsoleVariable("cmbtlog.disableOtherPlayers", false)
	end
	self.bSettingsLoaded = nil
	
	-- Create update timer
	self.timerPulse = ApolloTimer.Create(self.settings.updaterate, true, "Update", self)
	self.timerPulse:Stop()
	
	VortexMeter.UI.Init()
	if self.settings.enabled then
		VortexMeter.On()
	end
end

function VortexMeter:OnInterfaceMenuList()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "Vortex Meter", {"VortexMeter_Toggle", "", "VortexMeterSprites:VortexIcon"})
end

function VortexMeter:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	return VortexMeter.deepcopy(self.settings)
end

function VortexMeter:OnRestore(eType, tSavedSettings)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	for key, value in pairs(tSavedSettings) do
		if self.settings[key] ~= nil then
			self.settings[key] = value
		end
	end
	self.bSettingsLoaded = true
end

function VortexMeter:OnCombatLogHeal(tEventArgs)
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		damagetype = GameLib.CodeEnumDamageType.Heal,
		heal = tEventArgs.nHealAmount,
		overheal = tEventArgs.nOverheal,
		crit = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical,
	}
	
	CombatEventsHandler(info, "heal", false)
end

function VortexMeter:OnCombatLogMultiHeal(tEventArgs)
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		damagetype = GameLib.CodeEnumDamageType.Heal,
		heal = tEventArgs.nHealAmount,
		periodic = tEventArgs.bPeriodic,
		overheal = tEventArgs.nOverheal,
		crit = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical,
		multihit = true,
	}
	
	CombatEventsHandler(info, "heal", false)
end

function VortexMeter:OnCombatLogCCState(tEventArgs)
	if tEventArgs.nInterruptArmorHit > 0 then
		local info = {
			target = tEventArgs.unitTarget,
			caster = tEventArgs.unitCaster,
			owner = tEventArgs.unitCasterOwner,
			ability = tEventArgs.splCallingSpell,
			interrupts = tEventArgs.nInterruptArmorHit,
		}
		
		CombatEventsHandler(info, "interrupts", true)
	end
end

function VortexMeter:OnCombatLogDeflect(tEventArgs)
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		multihit = tEventArgs.bMultiHit,
	}
	
	CombatEventsHandler(info, "deflects", true)
end

function VortexMeter:OnCombatLogTransference(tEventArgs)
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		damagetype = tEventArgs.eDamageType,
		damage = tEventArgs.nDamageAmount + tEventArgs.nAbsorption + tEventArgs.nShield,
		periodic = tEventArgs.bPeriodic,
		overkill = tEventArgs.nOverkill,
		crit = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical,
	}
	
	CombatEventsHandler(info, "damage", true)
	
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		damagetype = GameLib.CodeEnumDamageType.Heal,
		heal = tEventArgs.tHealData[1].nHealAmount,
		overheal = tEventArgs.tHealData[1].nOverheal,
		crit = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical,
	}
	
	CombatEventsHandler(info, "heal", false)
end

function VortexMeter:OnCombatLogDamage(tEventArgs)
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		damagetype = tEventArgs.eDamageType,
		damage = tEventArgs.nDamageAmount + tEventArgs.nAbsorption + tEventArgs.nShield,
		periodic = tEventArgs.bPeriodic,
		overkill = tEventArgs.nOverkill,
		crit = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical,
	}
	
	CombatEventsHandler(info, "damage", true)
end

function VortexMeter:OnCombatLogMultiHit(tEventArgs)
	local info = {
		target = tEventArgs.unitTarget,
		caster = tEventArgs.unitCaster,
		owner = tEventArgs.unitCasterOwner,
		ability = tEventArgs.splCallingSpell,
		damagetype = tEventArgs.eDamageType,
		damage = tEventArgs.nDamageAmount + tEventArgs.nAbsorption + tEventArgs.nShield,
		periodic = tEventArgs.bPeriodic,
		crit = tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical,
		multihit = true,
	}
	
	CombatEventsHandler(info, "damage", true)
end


function VortexMeter:Update()
	local now = GameLib.GetGameTime()
	--local player = GameLib.GetPlayerUnit()
	--local PlayerIsInCombat = player:IsInCombat()
	
	if InCombat then
		if now - VortexMeter.CurrentCombat.lastDamageAction >= 2 and not Permanent then
			if not VortexMeter.GroupInCombat() then
				VortexMeter.EndCombat()
			end
		end
		
		if now - LastTimerUpdate > 1 then
			LastTimerUpdate = now
			VortexMeter.UI.TimerUpdate(now - VortexMeter.CurrentCombat.startTime)
		end
	end
	
	if not NeedsUpdate and not Permanent then return end
	
	if now - LastUpdate > 0.3 then
		VortexMeter.overallCombat.duration = VortexMeter.overallCombat.previousDuration + now - VortexMeter.CurrentCombat.startTime
		VortexMeter.CurrentCombat.duration = now - VortexMeter.CurrentCombat.startTime
		LastUpdate = now
		NeedsUpdate = false
		
		VortexMeter.UI.Update()
	end
	
end

function VortexMeter.GroupInCombat()
	local player = GameLib.GetPlayerUnit()

	if player and player:IsInCombat() then return true end
	
	for i=1, GroupLib.GetMemberCount() do
		local tUnit = GroupLib.GetUnitForGroupMember(i)
		if tUnit and tUnit:IsInCombat() then return true end
	end

	return false
end

-- VortexMeter API

function VortexMeter.On()
	if VortexMeter.enabled then return end
	VortexMeter.enabled = true
	VortexMeter.settings.enabled = true
	VortexMeter.UI.Visible(true)
	
	Apollo.RegisterEventHandler("CombatLogDamage",          "OnCombatLogDamage",       VortexMeter)
	Apollo.RegisterEventHandler("CombatLogDamageShields",   "OnCombatLogDamage",       VortexMeter)
	Apollo.RegisterEventHandler("CombatLogReflect",         "OnCombatLogDamage",       VortexMeter)
	Apollo.RegisterEventHandler("CombatLogMultiHit",        "OnCombatLogMultiHit",     VortexMeter)
	Apollo.RegisterEventHandler("CombatLogMultiHitShields", "OnCombatLogMultiHit",     VortexMeter)
	Apollo.RegisterEventHandler("CombatLogHeal",            "OnCombatLogHeal",         VortexMeter)
	Apollo.RegisterEventHandler("CombatLogMultiHeal",       "OnCombatLogMultiHeal",    VortexMeter)
	Apollo.RegisterEventHandler("CombatLogDeflect",         "OnCombatLogDeflect",      VortexMeter)
	Apollo.RegisterEventHandler("CombatLogTransference",    "OnCombatLogTransference", VortexMeter)
	Apollo.RegisterEventHandler("CombatLogCCState",         "OnCombatLogCCState",      VortexMeter)
	
	VortexMeter.timerPulse:Start()
end

function VortexMeter.Off()
	VortexMeter.enabled = false
	VortexMeter.settings.enabled = false
	VortexMeter.UI.Visible(false)
	
	Apollo.RemoveEventHandler("CombatLogDamage",          VortexMeter)
	Apollo.RemoveEventHandler("CombatLogDamageShields",   VortexMeter)
	Apollo.RemoveEventHandler("CombatLogReflect",         VortexMeter)
	Apollo.RemoveEventHandler("CombatLogMultiHit",        VortexMeter)
	Apollo.RemoveEventHandler("CombatLogMultiHitShields", VortexMeter)
	Apollo.RemoveEventHandler("CombatLogHeal",            VortexMeter)
	Apollo.RemoveEventHandler("CombatLogMultiHeal",       VortexMeter)
	Apollo.RemoveEventHandler("CombatLogDeflect",         VortexMeter)
	Apollo.RemoveEventHandler("CombatLogTransference",    VortexMeter)
	Apollo.RemoveEventHandler("CombatLogCCState",         VortexMeter)
	
	VortexMeter.timerPulse:Stop()
end

function VortexMeter.Toggle()
	if VortexMeter.settings.enabled then
		VortexMeter.Off()
	else
		VortexMeter.On()
	end
end

function VortexMeter.Clear()
	VortexMeter.EndCombat()
	
	tempty(Units)
	tempty(Abilities)
	VortexMeter.CurrentCombat = {}
	VortexMeter.overallCombat = nil
	
	InCombat = false
	NeedsUpdate = false
	
	VortexMeter.combats = {}
	
	VortexMeter.UI.Clear()
end

function VortexMeter.Default()
	VortexMeter.Off()
	VortexMeter.UI.Destroy()
	VortexMeter.UI.NewWindow()
	VortexMeter.On()
end

function VortexMeter.NewCombat(permanent)
	if InCombat then
		return
	end
	
	if not VortexMeter.overallCombat then
		VortexMeter.overallCombat = Combat:new(true)
		tinsert(VortexMeter.combats, VortexMeter.overallCombat)
	end
	
	VortexMeter.CurrentCombat = Combat:new(false)
	InCombat = true
	Permanent = not not permanent
	tinsert(VortexMeter.combats, VortexMeter.CurrentCombat)
	
	VortexMeter.UI.NewCombat()
end

function VortexMeter.EndCombat()
	if not InCombat then
		return
	end
	
	VortexMeter.CurrentCombat:End()
	VortexMeter.overallCombat.previousDuration = VortexMeter.overallCombat.previousDuration + VortexMeter.CurrentCombat.duration
	VortexMeter.overallCombat.duration = VortexMeter.overallCombat.previousDuration
	InCombat = false
	Permanent = false
	
	VortexMeter.UI.Update()
	VortexMeter.UI.EndCombat()
end

-- Slash commands

VortexMeter.SlashCommands = setmetatable({
	show    = function() VortexMeter.On() end,
	hide    = function() VortexMeter.Off() end,
	toggle  = function() VortexMeter.Toggle() end,
	clear   = function() VortexMeter.Clear() end,
	default = function() VortexMeter.Default() end,
	start   = function() VortexMeter.NewCombat() end,
	stop    = function() VortexMeter.EndCombat() end,
	new     = function() VortexMeter.UI.NewWindow() end,
	lock    = function() VortexMeter.UI.Lock(true) end,
	unlock  = function() VortexMeter.UI.Lock(false) end,
	config  = function() VortexMeter.ConfigInit() end,
},
{
	__index = function (t, key)
		return function ()
			Print(L["Available commands:"])
			for cmd, func in pairs(t) do
				Print("- " .. cmd)
			end
		end
	end
})

function VortexMeter:SlashHandler(cmd, arg)
	local list = {}
	for param in arg:gmatch("[^%s]+") do
		tinsert(list, param)
	end

	VortexMeter.SlashCommands[list[1]](unpack(list, 2, #list))
end

-- Register addon
Apollo.RegisterAddon(VortexMeter)
