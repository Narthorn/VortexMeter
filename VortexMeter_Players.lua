---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

local VortexMeter = VortexMeter
local pairs = pairs
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local max = math.max
local min = math.min

local L = VortexMeter.L
local Abilities = VortexMeter.Abilities
local Ability = VortexMeter.Meta.Ability

local Player = VortexMeter.Meta.Player
Player.__index = Player
function Player:new(unit, reduced)
	local self = {}
	self.detail = unit
	self.reduced = reduced
	self.damage = 0
	self.damageTaken = 0
	self.friendlyFire = 0
	self.overkill = 0
	self.heal = 0
	self.healTaken = 0
	self.overheal = 0
	self.interrupts = 0

	if reduced then
		self.abilities = {}
		self.linkedToOwner = false
		self.pets = false
		self.interactions = false
	else
		self.linkedToOwner = false
		self.pets = {}

		self.interactions = {
			damage = {},
			damageTaken = {},
			friendlyFire = {},
			overkill = {},
			heal = {},
			healTaken = {},
			overheal = {},
			interrupts = {}
		}
	end

	return setmetatable(self, Player)
end
function Player:addStat(interactedWith, statType, stat, amount, info)
	local ability = self:addAbility(interactedWith, statType, stat, amount, info)

	if not ability.filter then
		self[statType] = self[statType] + amount
	end

end
function Player:addAbility(interactedWith, statType, stat, amount, info)
	local abilityDetail = Abilities[info.ability:GetId() .. (info.periodic and "1" or "0")]
	if self.reduced then
		local ability = self.abilities[abilityDetail]
		if not ability then
			ability = Ability:new(info)
			self.abilities[abilityDetail] = ability
		end
		ability:add(stat, amount, info)
	end

	if not self.reduced and self.interactions then
		local key = interactedWith and interactedWith or L["Unknown"]
		local player = self.interactions[statType][key]
		if not player then
			player = self:new(interactedWith, true)
			if not player.detail then
				player.detail = { name = key }
			end
			self.interactions[statType][key] = player
		end

		player:addStat(interactedWith, statType, stat, amount, info)
	end

	return abilityDetail
end
function Player:getStat(sort)
	local stat = self[sort]
	for _, value in pairs(self.pets) do
		stat = stat + value[sort]
	end
	return stat
end
function Player:getInteractions(sort)
	local data = {
		interactions = {},
		count = 0,
		max = 1,
		total = 1
	}

	local interactions = {}
	for _, interaction in pairs(self.interactions[sort]) do
		tinsert(interactions, interaction)
	end

	tsort(interactions, function (a, b)
		return a[sort] > b[sort]
	end)

	for _, interaction in pairs(interactions) do
		local value = interaction[sort]
		local name = interaction.detail.name

		tinsert(data.interactions, {
			name = name,
			value = value,
			ref = interaction
		})

		data.total = data.total + value
		data.count = data.count + 1
	end

	if data.count > 0 then
		data.max = max(data.interactions[1].value, 1)
	end

	return data
end
function Player:getAbility(ability, sort)
	local returnAbility
	for _, interaction in pairs(self.interactions[sort]) do
		for _, ability2 in pairs(interaction.abilities) do
			if ability.name == ability2.name then
				if not returnAbility then
					returnAbility = ability2:clone()
				else
					returnAbility:merge(ability2)
				end
			end
		end
	end
	return returnAbility
end
function Player:getAbilities(sort)
	local abilities = {}
	for _, interaction in pairs(self.interactions[sort]) do
		for _, ability in pairs(interaction.abilities) do
			local found = false
			for _, insertedAbility in pairs(abilities) do
				if insertedAbility.name == ability.name then
					found = true
					insertedAbility:merge(ability)
				end
			end
			if not found then
				tinsert(abilities, ability:clone())
			end
		end
	end

	for _, pet in pairs(self.pets) do
		for _, interaction in pairs(pet.interactions[sort]) do
			for _, ability in pairs(interaction.abilities) do
				local found = false
				for _, insertedAbility in pairs(abilities) do
					if insertedAbility.name == ability.name then
						found = true
						insertedAbility:merge(ability)
					end
				end
				if not found then
					tinsert(abilities, ability:clone())
				end
			end
		end
	end

	tsort(abilities, function (a, b)
		return a.total > b.total
	end)

	return abilities
end
function Player:getPreparedAbilityData(sort)
	local data = {
		abilities = {},
		count = 0,
		max = 1,
		total = 0
	}

	local abilities = self:getAbilities(sort)

	for _, ability in pairs(abilities) do
		local value = ability.total

		tinsert(data.abilities, {
			value = value,
			ref = ability
		})

		data.total = data.total + value
		data.count = data.count + 1
	end

	data.total = max(data.total, 1)
	if data.count > 0 then
		data.max = max(data.abilities[1].value, 1)
	end

	return data
end
function Player:getInteractionAbilityData()
	local data = {
		abilities = {},
		count = 0,
		max = 1,
		total = 0
	}

	local abilities = {}
	for _, ability in pairs(self.abilities) do
		tinsert(abilities, ability)
	end

	tsort(abilities, function (a, b)
		return a.total > b.total
	end)

	for _, ability in pairs(abilities) do
		local value = ability.total

		tinsert(data.abilities, {
			value = value,
			ref = ability
		})

		data.total = data.total + value
		data.count = data.count + 1
	end

	data.total = max(data.total, 1)
	if data.count > 0 then
		data.max = max(data.abilities[1].value, 1)
	end

	return data
end
function Player:createFakeAbility()
	local fakeAbility = Ability:new({ability = {GetId = function() return nil end}})
	local backup = fakeAbility.getPreparedAbilityStatData
	local player = self
	fakeAbility.detail = {
		name =  L["Total"],
		icon = "",
		type = "none",
		filter = false,
	}
	fakeAbility.name = L["Total"]

	function fakeAbility:getPreparedAbilityStatData(combat, sort)
		-- force update on retrieve

		self.total = 0
		self.totalHit = 0
		self.totalCrit = 0
		self.totalMultiHit = 0
		self.max = 0
		self.min = 0
		self.hits = 0
		self.crits = 0
		self.multihits = 0
		self.swings = 0
		self.filtered = 0
		self.interrupts = 0

		self.deflects = 0

		if player.interactions then -- real player
			for _, interaction in pairs(player.interactions[sort]) do
				for _, ability in pairs(interaction.abilities) do
					self:merge(ability)
				end
			end
		else -- interacted player
			for _, ability in pairs(player.abilities) do
				self:merge(ability)
			end
		end

		return backup(self, combat)
	end

	return fakeAbility
end
function Player:getTooltip(sort)
	local result = {"<P TextColor=\"FFFFD100\">" .. L["Top 3 Abilities:"] .. "</P>"}

	local players = {}
	for _, player in pairs(self.interactions[sort]) do
		tinsert(players, player)
	end

	tsort(players, function(a, b)
		return a[sort] > b[sort]
	end)

	local abilities = self:getAbilities(sort)

	for i = 1, 3 do
		if abilities[i] then
			tinsert(result, ("   (%d%%) %s"):format(abilities[i].total / self:getStat(sort) * 100, abilities[i].name:sub(0, 16)))
		end
	end

	tinsert(result, "<P TextColor=\"FFFFD100\">" .. L["Top 3 Interactions:"] .. "</P>")

	for i = 1, 3 do
		if players[i] then
			tinsert(result, ("   (%d%%) %s"):format(players[i][sort] / self:getStat(sort) * 100, players[i].detail.name:sub(0, 16)))
		end
	end

	tinsert(result, "<P TextColor=\"FF33FF33\">&lt;" .. L["Middle-Click for interactions"] .. "&gt;</P>")

	return table.concat(result, "\n")
end
