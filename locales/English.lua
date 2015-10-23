-- Copyright (C) 2014 Bradley Smith <brad@brad-smith.co.uk>
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local VortexMeter = Apollo.GetAddon("VortexMeter")

if VortexMeter.l then return end

VortexMeter.l = setmetatable({
	["Sort Modes"] = "Sort Modes",
	["damage"] = "Damage Done",
	["damagePerSecond"] = "DPS",
	["damageAbsorbed"] = "Damage Absorbed",
	["damageBlocked"] = "Damage Blocked",
	["damageDeflected"] = "Damage Deflected",
	["damageIntercepted"] = "Damage Intercepted",
	["damageModified"] = "Damage Modified",
	["damageTaken"] = "Damage Taken",
	["damageTakenPerSecond"] = "DTPS",
	["friendlyFire"] = "Friendly Fire",
	["friendlyFirePerSecond"] = "FFPS",
	["overkill"] = "Overkill done",
	["overkillPerSecond"] = "OKPS",
	["heal"] = "Healing Done",
	["healPerSecond"] = "HPS",
	["healTaken"] = "Healing Taken",
	["healTakenPerSecond"] = "HTPS",
	["overheal"] = "Overhealing Done",
	["overhealPerSecond"] = "OHPS",
	["deaths"] = "Deaths",
	["total"] = "Total",
	["max"] = "Max Hit",
	["average"] = "Average Hit",
	["average crit"] = "Average Crit",
	["min"] = "Min Hit",
	["crit rate"] = "Crit Rate",
	["swings"] = "Swings",
	["hits"] = "Hits",
	["crits"] = "Crits",
	["filtered"] = "Filtered",
	["filter"] = "Filter by Targets",	
    ["deflects"] = "Deflects",
    ["interrupts"] = "Interrupts",
	["absorbed"] = "Absorbed",
	["intercepted"] = "Intercepted",
	["Total"] = "Total",
	["%s's Abilities"] = "%s's Abilities",
	["Combats"] = "Combats",
	["Targets"] = "Targets",	
	["Unknown"] = "Unknown",
	["%s: Interactions: %s"] = "%s: Interactions: %s",
	["%s v%s loaded. /vm for commands"] = "%s v%s loaded. /vm for commands",
	["Type /vm show to reactivate %s."] = "Type /vm show to reactivate %s.",
	["Available commands:"] = "Available commands:",
	["Clear data?"] = "Clear data?",
	["Top 3 Abilities:"] = "Top 3 Abilities:",
	["Top 3 Interactions:"] = "Top 3 Interactions:",
	["Middle-Click for interactions"] = "Middle-Click for interactions",

	-- Tooltip buttons
	["Close"] = "Close",
	["Copy"] = "Copy",
	["Clear data"] = "Clear data",
	["Jump to current fight"] = "Jump to current fight",
	["Configuration"] = "Configuration",
	["Force combat start"] = "Force combat start",
	["Force combat end"] = "Force combat end",
	["Show Enemies"] = "Show Enemies",

	-- Configuration
	["VortexMeter: Configuration"] = "VortexMeter: Configuration",
	["Set background transparent"] = "Set background transparent",
	["Lock frame in position"] = "Lock frame in position",
	["Always show yourself"] = "Always show yourself",
	["Show scrollbar"] = "Show scrollbar",
	["Show rank number"] = "Show rank number",
	["Show absolute"] = "Show absolute",
	["Show percent"] = "Show percent",
	["Merge abilities by name"] = "Merge abilities by name",
	["Add Window"] = "Add Window",

	["thousandSeparator"] = ",",
}, {__index = function(self, key) return tostring(key) end})

