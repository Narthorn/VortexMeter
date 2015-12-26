---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

local VortexMeter = VortexMeter

local L = VortexMeter.L
local Abilities = VortexMeter.Abilities
local numberFormat = VortexMeter.numberFormat

local Ability = VortexMeter.Meta.Ability
Ability.__index = Ability
function Ability:new(info)
	local self = {}
	if info.ability:GetId() ~= nil then
		self.detail = Abilities[info.ability:GetId() .. (info.periodic and "1" or "0")]
		self.name = self.detail.name
	end
	self.type = info.damagetype
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

	if info.owner then
	  self.name = self.name .. " (Pet: " .. info.caster:GetName() .. ")"
	elseif info.periodic then
	  self.name = self.name .. " (Dot)"
	end

	return setmetatable(self, Ability)
end

function Ability:clone()
	local clone = {
		detail = self.detail,
		name = self.name,
		total = self.total,
		type = self.type,
		totalHit = self.totalHit,
		totalCrit = self.totalCrit,
		totalMultiHit = self.totalMultiHit,
		max = self.max,
		min = self.min,
		hits = self.hits,
		crits = self.crits,
		multihits = self.multihits,
		swings = self.swings,
		filtered = self.filtered,
		interrupts = self.interrupts,
		deflects = self.deflects,
	}

	return setmetatable(clone, Ability)
end

function Ability:merge(otherAbility)
	self.total = self.total + otherAbility.total
	self.totalHit = self.totalHit + otherAbility.totalHit
	self.totalCrit = self.totalCrit + otherAbility.totalCrit
	self.totalMultiHit = self.totalMultiHit + otherAbility.totalMultiHit
	self.max = math.max(self.max, otherAbility.max)
	if self.min == 0 then
		self.min = otherAbility.min
	else
		if otherAbility.min > 0 then
			self.min = math.min(self.min, otherAbility.min)
		end
	end
	self.hits = self.hits + otherAbility.hits
	self.crits = self.crits + otherAbility.crits
	self.multihits = self.multihits + otherAbility.multihits
	self.swings = self.swings + otherAbility.swings
	self.filtered = self.filtered + otherAbility.filtered
	self.interrupts = self.interrupts + otherAbility.interrupts
	self.deflects = self.deflects + otherAbility.deflects
end

function Ability:add(statType, amount, info)

	self.total = self.total + amount
	if not info.multihit then self.swings = self.swings + 1 end

	if statType == "deflects" or statType == "interrupts" then
		if not info.multihit then
			self[statType] = self[statType] + 1
		end
	else
		if info.multihit then
			self.multihits = self.multihits + 1
			self.totalMultiHit = self.totalMultiHit + amount
		else
			if info.crit then
				self.crits = self.crits + 1
				self.totalCrit = self.totalCrit + amount
			else
				self.hits = self.hits + 1
				self.totalHit = self.totalHit + amount
			end
			if amount > self.max then self.max = amount end
			if (amount < self.min or self.min == 0) then self.min = amount end
		end
	end
end

function Ability:getPreparedAbilityStatData(combat)
	local stats = {
		{ name = L["total"], value = numberFormat(self.total) },
		{ name = L["Min/Avg/Max"], value = numberFormat(self.min) .. " / " .. numberFormat(math.round(self.total / self.swings)) .. " / " .. numberFormat(self.max) },
		{ name = L["Average Hit/Crit/Multi-Hit"], value = numberFormat(math.round(self.totalHit / math.max(self.hits, 1))) .. " / " .. numberFormat(math.round(self.totalCrit / math.max(self.crits, 1))) .. " / " .. numberFormat(math.round(self.totalMultiHit / math.max(self.multihits, 1))) },
		{ name = L["Crit Total (%)"], value = numberFormat(self.totalCrit) .. " (" .. ("%.2f%%"):format(self.totalCrit / math.max(self.total,1) * 100) .. ")" },
		{ name = L["Crit Rate"], value = ("%.2f%%"):format(self.crits / self.swings * 100) },
		{ name = L["Multi-Hit Total (%)"], value = numberFormat(self.totalMultiHit) .. " (" .. ("%.2f%%"):format(self.totalMultiHit / math.max(self.total,1) * 100) .. ")"},
		{ name = L["Multi-Hit Rate"], value = ("%.2f%%"):format(self.multihits / self.swings * 100) },
		{ name = L["Swings (Per second)"], value = numberFormat(self.swings) .. " (" .. ("%.2f"):format(self.swings / math.max(combat.duration, 1)) .. ")" },
		{ name = L["Hits / Crits / Multi-Hits"], value = numberFormat(self.hits) .. " / " .. numberFormat(self.crits) .. " / " .. numberFormat(self.multihits)},
		{ name = L["Deflects (%)"], value = numberFormat(self.deflects) .. " (" .. ("%.2f%%"):format(self.deflects / self.swings * 100) .. ")" },
		{ name = L["Interrupts"], value = numberFormat(self.interrupts) },
	}

	return stats
end
