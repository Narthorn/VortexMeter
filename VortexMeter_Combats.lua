---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

local VortexMeter = VortexMeter

local pairs = pairs
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort

local L = VortexMeter.L
local Player = VortexMeter.Meta.Player

local Combat = VortexMeter.Meta.Combat
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
	
	for _, player in pairs(players) do
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
