---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

-- TODO: Tidy

local RM = Apollo.GetAddon("VortexMeter")

local L = RM.L
local NumberFormat = RM.numberFormat
local FormatSeconds = RM.formatSeconds
local BuildFormat = RM.BuildFormat

local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local tsort = table.sort
local tremove = table.remove
local setmetatable = setmetatable
local max = math.max
local min = math.min
local floor = math.floor
local ceil = math.ceil
local round = function(val) return math.floor(val + .5) end

local Dummy = function() end

local Windows = {}
RM.Windows = Windows

local Modes = {}
local Sortmodes = {
	"damage",
	"heal",
	"damageTaken",
	"healTaken",
	"overheal",
	"overkill",
	"interrupts",
}

-- Tooltips

RM.Tooltip = { }
function RM.Tooltip:init()
	self.tooltip = Apollo.LoadForm(RM.xmlMainDoc, "Tooltip", nil, RM)
	self.tooltipText = self.tooltip:FindChild("TooltipText")
end

function RM.Tooltip:show(text, anchor, center)
	if not self.tooltip then
		self:init()
	end
	
	if not RM.settings.tooltips then return end
	
	self.tooltipText:SetAML(text)
	
	local mouse = Apollo:GetMouse()
	self.tooltip:SetAnchorOffsets(mouse.x, mouse.y, mouse.x + 500, mouse.y + 100)
	local nTextWidth, nTextHeight = self.tooltipText:SetHeightToContentHeight()
	self.tooltip:SetAnchorOffsets(mouse.x + 10, mouse.y - 20, mouse.x + nTextWidth + 22, mouse.y + nTextHeight - 8)
	
	self.tooltip:Show(true)
end

function RM.Tooltip:hide()
	if not self.tooltip then
		return
	end
	self.tooltip:Show(false)
end

-- Windows

local Window = {}
Window.__index = Window
function Window:new(settings)
	local self = {}
	
	self.settings = settings
	self.frames = {}
	self.lastData = {}
	self.history = {}
	self.maxValue = 0
	self.rowCount = 0
	self.scrollOffset = 0
	self.showNpcs = false
	self.selectedMode = Modes.combat
	self.selectedSortmode = nil
	self.selectedCombat = nil
	self.selectedPlayer = nil
	self.selectedPlayerDetail = nil
	self.selectedAbility = nil
	self.selectedAbilityDetail = nil
	
	setmetatable(self, Window)
	
	self:init()
	
	return self
end

function Window:init()
	local base = Apollo.LoadForm(RM.xmlMainDoc, "VortexMeterForm", nil, RM)

	self.frames = {
		base        = base,
		header      = base:FindChild("Header"),
		headerLabel = base:FindChild("HeaderText"),
		
		buttons = {
			close       = base:FindChild("ButtonClose"),
			copy        = base:FindChild("ButtonCopy"),
			clear       = base:FindChild("ButtonClear"),
			pin         = base:FindChild("ButtonPin"),
			config      = base:FindChild("ButtonConfig"),
			showEnemies = base:FindChild("ButtonEnemies"),
			showPlayers = base:FindChild("ButtonPlayers"),
			combatStart = base:FindChild("ButtonStart"),
			combatEnd   = base:FindChild("ButtonStop"),
		},
		
		rows = {},

		background        = base:FindChild("Background"),
		opacitybackground = base:FindChild("OpacityBackground"),
		
		footer = base:FindChild("Footer"),
		solo   = base:FindChild("btnSolo"),
		
		resizerLeft  = base:FindChild("ResizeLeft"),
		resizerRight = base:FindChild("ResizeRight"),
		
		timerLabel      = base:FindChild("TimerLabel"),
		globalStatLabel = base:FindChild("GlobalStatLabel"),
	}

	self.frames.base:SetData(self)
	self.frames.base:SetAnchorOffsets(self.settings.x, self.settings.y, self.settings.x + self.settings.width, 0)
	self.frames.base:SetSizingMinimum(140)
	self:setRows(self.settings.rows)

	local bSolo = Apollo.GetConsoleVariable("cmbtlog.disableOtherPlayers")
	self.frames.solo:SetTextColor(bSolo and "xkcdAcidGreen" or "xkcdBloodOrange")
	
	self:Lock(RM.settings.lock)

	self.frames.opacitybackground:SetOpacity(RM.settings.opacity)
	self.frames.header:SetOpacity(RM.settings.mousetransparancy)
	self.frames.footer:SetOpacity(RM.settings.mousetransparancy)

	self.selectedMode:init(self)
end

function Window:clearRows(count) -- from count to rowCount will be hidden
	self.scrollOffset = 0
	
	local rows = self.frames.rows
	if not rows or count == #rows then return end
	if not count then
		count = 1
	end
	
	for i = count, #rows do
		local row = rows[i]
		row.icon:Show(false)
		row.leftLabel:SetText("")
		row.rightLabel:SetText("")
		row.base:Show(false)
	end
end
function Window:update()
	self.lastData, self.rowCount, self.maxValue = self.selectedMode:update(self)
	
	self.lastData = self.lastData or {}
	self.rowCount = self.rowCount or 0
	self.maxValue = max(self.maxValue or 1, 1)
	
	for i = 1, self.settings.rows do
		local row = self.frames.rows[i]
		local data = self.lastData[i]
		if data then
			-- Default values
			if not data.value then
				data.value = 0
			end
			if not data.color then
				data.color = {0, 0.5, 1}
			end
			if not data.leftLabel then
				data.leftLabel = ""
			end
			if not data.rightLabel then
				data.rightLabel = ""
			end
			if not data.leftClick then
				data.leftClick = Dummy
			end
			if not data.middleClick then
				data.middleClick = Dummy
			end
			if not data.rightClick then
				data.rightClick = Dummy
			end
			if data.icon and data.icon ~= "" then
				row.icon:SetSprite(data.icon)
				row.icon:Show(true)
			else
				row.icon:Show(false)
			end
			
			row.leftLabel:SetText(tostring(data.leftLabel))
			row.rightLabel:SetText(tostring(data.rightLabel))
			row.background:SetAnchorPoints(0, 0, data.value / self.maxValue, 1)
			row.background:SetBGColor(ApolloColor.new(data.color[1], data.color[2], data.color[3], 1))
			row.events.leftClick = data.leftClick
			row.events.middleClick = data.middleClick
			row.events.rightClick = data.rightClick
			row.tooltip = data.tooltip
			row.base:Show(true)
		else
			row.base:Show(false)
		end
	end
end
function Window.report(text)
	if not text then return end
	
	local chan = RM.settings.report_channel
	local target = RM.settings.report_target
	
	for i = 1, #text do
		if ( chan == 'whisper' or chan == 'tell' or chan == 'w' or chan == 't' ) then
			ChatSystemLib.Command("/" .. chan .. " " .. target .. " " .. text[i])
		else
			ChatSystemLib.Command("/" .. chan .. " " .. text[i])
		end
	end
end
function Window:setRows(count)
	local forCount = count
	local rowCount = #self.frames.rows
	local rowpos = 1 + rowCount * (self.settings.rowHeight + 1)
	
	count = max(count, 1)

	if rowCount ~= count then
	
		self.settings.rows = count
		
		for i = count + 1, rowCount do
			tremove(self.frames.rows).base:Destroy()
		end

		self.scrollOffset = max(min(self.scrollOffset, rowCount - #self.frames.rows), 0)
		
		for i = rowCount + 1, count do
			local base = Apollo.LoadForm(RM.xmlMainDoc, "Row", self.frames.background, RM)
			local row = {
				events = {},
				base       = base,
				background = base:FindChild("Background"),
				icon       = base:FindChild("Icon"),
				leftLabel  = base:FindChild("LeftLabel"),
				rightLabel = base:FindChild("RightLabel"),
			}

			row.base:SetData(row)
			row.background:SetOpacity(0.7)
			self.frames.rows[i] = row
			
			local left, top, right, bottom = row.base:GetAnchorOffsets()
			row.base:SetAnchorOffsets(left, rowpos, right, rowpos + self.settings.rowHeight)
			row.base:Show(false)

			rowpos = rowpos + self.settings.rowHeight + 1
		end
	end

	local left, top, right, bottom = self.frames.base:GetAnchorOffsets()
	self.frames.base:SetAnchorOffsets(left,top,right, top + 45 + count * (self.settings.rowHeight + 1))

	self:update()
end
function Window:timerUpdate(duration)
	self.frames.timerLabel:SetText(FormatSeconds(duration))
end
function Window:setMode(mode, ...)
	RM.Tooltip:hide()
	
	local newMode = {}
	if type(mode) == "string" then
		newMode = Modes[mode]
	else
		newMode = mode
	end
	
	if newMode ~= self.selectedMode then -- prevent endless loop
		tinsert(self.history, self.selectedMode)
		self.selectedMode = newMode
	end
	
	self:clearRows()
	self.selectedMode:init(self, ...)
	self:update()
end
function Window:getLastMode()
	-- sortmode selection is skipped (Modes.modes)
	-- two same modes can't be behind one another
	
	local index = #self.history
	if self.history[index] == Modes.modes then
		index = index - 1
	end
	if self.history[index] == self.selectedMode then
		index = index - 1
	end
	
	return self.history[max(index, 1)]
end
function Window:getCurrentMode()
	return self.selectedMode
end
function Window:setTitle(title)
	self.frames.headerLabel:SetText(tostring(title))
end
function Window:setGlobalLabel(text)
	self.frames.globalStatLabel:SetText(NumberFormat(text))
end
function Window:Lock(state)
	self.frames.resizerLeft:Show(not state)
	self.frames.resizerRight:Show(not state)
	self.frames.base:SetStyle("Sizable", not state)
	self.frames.base:SetStyle("Moveable", not state)
end

-- Window Event Handlers

function RM:OnHeaderTextButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	if eMouseButton == 1 then
		local window = wndHandler:GetParent():GetParent():GetData()
		window:setMode("modes")
	end
end

function RM:OnHeaderTextMouseEnter(wndHandler, wndControl, x, y)
	wndHandler:SetTextColor(ApolloColor.new(1, 1, 1, 1))
end

function RM:OnHeaderTextMouseExit(wndHandler, wndControl, x, y)
	wndHandler:SetTextColor(ApolloColor.new(0.8, 0.8, 0.8, 1))
end

function RM:OnFrameMouseEnter(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then return end
	local window = wndHandler:GetData()
	window.frames.header:SetOpacity(1)
	window.frames.footer:SetOpacity(1)
end

function RM:OnFrameMouseExit(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then return end
	local window = wndHandler:GetData()
	window.frames.header:SetOpacity(RM.settings.mousetransparancy)
	window.frames.footer:SetOpacity(RM.settings.mousetransparancy)
end

function RM:OnFrameWindowMove(wndHandler, wndControl, left, top, right, bottom)
	local window = wndHandler:GetData()

	window.settings.x = left
	window.settings.y = top
	window.settings.width = right - left

	-- return when height is unchanged (i.e. only width changes or this event is fired by a window move)
	if (bottom-top) == (45 + #window.frames.rows * (window.settings.rowHeight + 1)) then return end

	-- have to use actual cursor position instead of height to account for repeated movements smaller than rowHeight
	window:setRows(round((Apollo.GetMouse().y - window.settings.y - 45) / (window.settings.rowHeight+1)))
end

function RM:OnButtonSolo(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	RM.UI.Solo(not Apollo.GetConsoleVariable("cmbtlog.disableOtherPlayers"))
end

function RM:OnButtonClose(wndHandler, wndControl, eMouseButton)
	local window = wndHandler:GetParent():GetParent():GetData()
	
	RM.UI.Close(window)
	
	RM.Tooltip:hide()
end

function RM:OnButtonConfig(wndHandler, wndControl, eMouseButton)
	RM.ConfigInit()
end

function RM:OnButtonClear(wndHandler, wndControl, eMouseButton)
	RM.Clear()
end

function RM:OnButtonStart(wndHandler, wndControl, eMouseButton)
	RM.NewCombat(true)
end

function RM:OnButtonStop(wndHandler, wndControl, eMouseButton)
	RM.EndCombat()
end

function RM:OnButtonPin(wndHandler, wndControl, eMouseButton)
	local window = wndHandler:GetParent():GetParent():GetData()
	
	window:setMode("combat", RM.Combats[#RM.Combats])
end

function RM:OnButtonEnemies(wndHandler, wndControl, eMouseButton)
	local window = wndHandler:GetParent():GetParent():GetData()
	
	window.frames.buttons.showPlayers:Show(true)
	window.frames.buttons.showEnemies:Show(false)
	window.showEnemies = true
	window:update()
end

function RM:OnButtonPlayers(wndHandler, wndControl, eMouseButton)
	local window = wndHandler:GetParent():GetParent():GetData()
	
	window.frames.buttons.showPlayers:Show(false)
	window.frames.buttons.showEnemies:Show(true)
	window.showEnemies = false
	window:update()
end

function RM:OnBackgroundButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = wndHandler:GetParent():GetData()
	
	if eMouseButton == 1 then
		window.selectedMode:rightClick(window)
	elseif eMouseButton == 4 then
		window.selectedMode:mouse4Click(window)
	elseif eMouseButton == 5 then
		window.selectedMode:mouse5Click(window)
	end
end

function RM:OnBackgroundScroll(wndHandler, wndControl, nLastRelativeMouseX, nLastRelativeMouseY, fScrollAmount, bConsumeMouseWheel)
	local window = wndHandler:GetParent():GetData()
	
	local val = window.scrollOffset + ((fScrollAmount < 0) and 1 or -1)
	val = max(0, min(val, window.rowCount - #window.frames.rows))
	if val ~= window.scrollOffset then
		window.scrollOffset = val
		window:update()
	end
	
	return true
end

function RM:OnButtonReport(wndHandler, wndControl, eMouseButton)
	local window = wndHandler:GetParent():GetParent():GetData()
	local wndReport = Apollo.LoadForm(RM.xmlMainDoc, "ReportForm", nil, RM)
	wndReport:SetData(window)
	wndReport:FindChild('ReportChannelEditBox'):SetText(RM.settings.report_channel or 's')
	wndReport:FindChild('ReportTargetEditBox'):SetText(RM.settings.report_target or 'none')
	wndReport:FindChild('ReportLinesEditBox'):SetText(RM.settings.report_lines or '5')
	wndReport:Show(true)
end

function RM:OnReportConfirmButton(wndHandler, wndControl)
	local wndReport = wndHandler:GetParent():GetParent()
	local window = wndReport:GetData()
	
	RM.settings.report_channel = wndReport:FindChild('ReportChannelEditBox'):GetText()
	RM.settings.report_target = wndReport:FindChild('ReportTargetEditBox'):GetText()
	RM.settings.report_lines = tonumber(wndReport:FindChild('ReportLinesEditBox'):GetText())
	
	wndReport:Destroy()

	local selectedMode = window.selectedMode or Modes.interactionAbilities
	window.report(selectedMode:getReportText(window))
end

function RM:OnReportClose(wndHandler, wndControl, eMouseButton)
	wndHandler:GetParent():Destroy()
end
function RM:OnReportCancel(wndHandler, wndControl, eMouseButton)
	wndHandler:GetParent():GetParent():Destroy()
end

function RM:OnButtonMouseEnter(wndHandler, wndControl, x, y)
	local window = wndHandler:GetParent():GetParent():GetData()
	
	if wndControl == window.frames.buttons.close then
		RM.Tooltip:show(L["Close"])
	elseif wndControl == window.frames.buttons.copy then
		RM.Tooltip:show(L["Report"])
	elseif wndControl == window.frames.buttons.clear then
		RM.Tooltip:show(L["Clear data"])
	elseif wndControl == window.frames.buttons.pin then
		RM.Tooltip:show(L["Jump to current fight"])
	elseif wndControl == window.frames.buttons.config then
		RM.Tooltip:show(L["Configuration"])
	elseif wndControl == window.frames.buttons.showEnemies then
		RM.Tooltip:show(L["Show Enemies"])
	elseif wndControl == window.frames.buttons.showPlayers then
		RM.Tooltip:show(L["Show Players"])
	elseif wndControl == window.frames.buttons.combatStart then
		RM.Tooltip:show(L["Force combat start"])
	elseif wndControl == window.frames.buttons.combatEnd then
		RM.Tooltip:show(L["Force combat end"])
	end
end

function RM:OnButtonMouseExit(wndHandler, wndControl, x, y)
	if wndHandler == wndControl then
		RM.Tooltip:hide()
	end
end

function RM:OnRowButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	if wndHandler ~= wndControl then return end
	local row = wndHandler:GetData()
	
	if eMouseButton == 0 then
		row.events.leftClick()
	elseif eMouseButton == 1 then
		row.events.rightClick()
	elseif eMouseButton == 2 then
		row.events.middleClick()
	end
end

function RM:OnRowMouseEnter(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then return end
	local row = wndHandler:GetData()
	
	row.background:SetOpacity(0.9)
	if row.tooltip then
		RM.Tooltip:show(row.tooltip())
	end
end

function RM:OnRowMouseExit(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then return end
	local row = wndHandler:GetData()
	row.background:SetOpacity(0.7)
	RM.Tooltip:hide()
end

-- Modes

local Mode = {}
Mode.__index = Mode
function Mode:new(name)
	local self = {}
	self.name = name
	return setmetatable(self, Mode)
end
function Mode:rightClick() end
function Mode:mouse4Click() end
function Mode:mouse5Click() end
function Mode:init() end
function Mode:update() end
function Mode:onSortmodeChange(window, newSortmode) return true end
function Mode:getReportText() end

-- Mode: Sort Modes

Modes.modes = Mode:new("modes")
function Modes.modes:init(window)
	window:setTitle("VortexMeter: " .. L["Sort Modes"])
end
function Modes.modes:update(window)
	local rows = {}
	local limit = min(#Sortmodes, #window.frames.rows)
	for i = 1, limit do
		local data = {}
		local lastMode = window:getLastMode()
		local sortMode = Sortmodes[i + window.scrollOffset]
		
		data.leftLabel = L[sortMode]
		data.rightlabel = ""
		data.value = 1
		data.leftClick = function()
			local oldSortmode = window.settings.sort
			window.settings.sort = Sortmodes[i + window.scrollOffset]
			
			if lastMode:onSortmodeChange(window, oldSortmode) then
				window:setMode(lastMode)
			end
		end
		
		rows[i] = data
	end
	return rows, #Sortmodes, 1
end

-- Mode: Combat

Modes.combat = Mode:new("combat")
function Modes.combat:init(window, combat)
	if combat then
		window.selectedCombat = combat
	end
	
	if not window.selectedCombat then
		if #RM.Combats > 0 then
			window.selectedCombat = RM.Combats[#RM.Combats]
		end
	end
	
	if window.selectedCombat then
		window:timerUpdate(window.selectedCombat.duration)
	end
	window:setTitle(L[window.settings.sort])
end
function Modes.combat:update(window)
	if not window.selectedCombat then return end -- Update() is called on init
	
	local data = window.selectedCombat:getPreparedPlayerData(window.settings.sort, window.showEnemies)
	
	local rows = {}
	local selfFound = false
	local limit = min(data.count, #window.frames.rows)
	local duration = max(window.selectedCombat.duration, 1)
	for i = 1, limit do
		local row = {}
		local player = data.players[i + window.scrollOffset]
		
		if RM.settings.alwaysShowPlayer then
			if player.ref.detail.self then
				selfFound = true
			end
			
			if i == limit and not selfFound then
				for j = i + window.scrollOffset, data.count do
					if data.players[j].ref.detail.self then
						player = data.players[j]
						i = j - window.scrollOffset
						break
					end
				end
			end
		end
		
		row.leftLabel = (RM.settings.showRankNumber and i + window.scrollOffset .. ". " or "") .. player.name
		row.rightLabel = BuildFormat(NumberFormat(player.value), player.value / duration, player.value / max(data.total, 1) * 100)
		
		row.color = RM.classColors[player.ref.detail.class] or {1, 1, 1}
		row.value = player.value
		row.tooltip = function()
			return player.ref:getTooltip(window.settings.sort)
		end
		row.leftClick = function()
			window:setMode("abilities", player.ref)
		end
		if player.ref.interactions then
			row.middleClick = function()
				window:setMode("interactions", player.ref)
			end
		end
		
		tinsert(rows, row)
	end
	
	window:setGlobalLabel(data.total / duration)
	
	return rows, data.count, data.max
end
function Modes.combat:rightClick(window)
	if #RM.Combats > 0 then
		window:setMode("combats")
	end
end
function Modes.combat:getReportText(window)
	if not window.selectedCombat then return end
	
	local data = window.selectedCombat:getPreparedPlayerData(window.settings.sort, window.showEnemies)
	local duration = max(window.selectedCombat.duration, 1)
	local text = {}
	tinsert(text, ("Target: %s ~ (%s)"):format(window.selectedCombat:getHostile():sub(0, 64), FormatSeconds(window.selectedCombat.duration)))
	tinsert(text, ("--------------------"))
	tinsert(text, ("Total %s: %s ~ (%s)"):format( window.settings.sort, NumberFormat(data.total), NumberFormat(data.total / duration) ))
	for i = 1, min( data.count, RM.settings.report_lines ) do
		local player = data.players[i]
		if not player.ref.detail.isPet then
			tinsert(text, ("%d) %s - %s (%s, %d%%) "):format( i, player.ref.detail.name:sub(0, 32), NumberFormat(player.value), NumberFormat(player.value / duration), round(player.value / data.total * 100, 2)))
		end
	end
	
	return text
end

function Modes.combat:mouse4Click(window)
	for i, combat in ipairs(RM.Combats) do
		if combat == window.selectedCombat and i > 1 then
			window:setMode("combat", RM.Combats[i - 1])
			return
		end
	end
end
function Modes.combat:mouse5Click(window)
	for i, combat in ipairs(RM.Combats) do
		if combat == window.selectedCombat and i < #RM.Combats then
			window:setMode("combat", RM.Combats[i + 1])
			return
		end
	end
end

-- Mode: Interactions

Modes.interactions = Mode:new("interactions")
function Modes.interactions:init(window, player)
	if player then
		window.selectedPlayer = player
	end
	if window.selectedPlayer then
		window:setTitle(L["%s: Interactions: %s"]:format(window.selectedPlayer.detail.name, L[window.settings.sort]))
	end
end
function Modes.interactions:update(window)
	if not window.selectedPlayer then
		if window.selectedPlayerDetail then
			self:findOwner(window)
		end
		if not window.selectedPlayer then
			return
		end
	end
	
	local data = window.selectedPlayer:getInteractions(window.settings.sort)
	local duration = max(window.selectedCombat.duration, 1)
	local rows = {}
	local limit = min(data.count, #window.frames.rows)
	for i = 1, limit do
		local row = {}
		local interaction = data.interactions[i + window.scrollOffset]
		
		row.leftLabel = (RM.settings.showRankNumber and i + window.scrollOffset .. ". " or "") .. interaction.name
		row.rightLabel = BuildFormat(NumberFormat(interaction.value), interaction.value / duration, interaction.value / data.total * 100)
		row.color = RM.classColors[interaction.ref.detail.class] or {1, 1, 1}
		row.value = interaction.value
		row.leftClick = function()
			window:setMode("interactionAbilities", interaction.ref, window.selectedPlayer)
		end
		
		tinsert(rows, row)
	end
	
	window:setGlobalLabel(data.total / duration)
	
	return rows, data.count, data.max
end

function Modes.interactions:rightClick(window)
	window:setMode("combat")
end
function Modes.interactions:findOwner(window)
	local player = window.selectedCombat.players[window.selectedPlayerDetail]
	if player then
		window.selectedPlayer = player
		window:setTitle(L["%s's Interactions: %s"]:format(player.detail.name, L[window.settings.sort]))
	end
end

-- Mode: Interactions ability list

Modes.interactionAbilities = Mode:new("interactionAbilities")
function Modes.interactionAbilities:init(window, player, parent)
	if player then
		window.selectedPlayer = player
	end
	if window.selectedPlayer then
		if parent then
			window.selectedPlayerParent = parent
		end
		window:setTitle(("%s: %s: %s"):format(window.selectedPlayerParent.detail.name:sub(0, 6), window.selectedPlayer.detail.name:sub(0, 6), L[window.settings.sort]))
	end
end
function Modes.interactionAbilities:update(window)
	if not window.selectedPlayer then
		if window.selectedPlayerDetail then
			self:findOwner(window)
		end
		if not window.selectedPlayer then
			return
		end
	end
	
	local data = window.selectedPlayer:getInteractionAbilityData()
	local duration = max(window.selectedCombat.duration, 1)
	local rows = {}
	local limit = min(data.count, #window.frames.rows)
	for i = 1, limit do
		
		-- total bar
		if i == 1 and window.scrollOffset == 0 then
			tinsert(rows, {
				leftLabel = "      " .. L["Total"],
				rightLabel = NumberFormat(data.total),
				value = data.max,
				leftClick = function()
					window:setMode("interactionAbility", window.selectedPlayer:createFakeAbility())
				end
			})
		end
		
		local row = {}
		local index = window.scrollOffset > 0 and i + window.scrollOffset - 1 or i + window.scrollOffset
		local ability = data.abilities[index]
		
		row.icon = ability.ref.detail.icon
		row.leftLabel = "      " .. ability.ref.name
		row.rightLabel = BuildFormat(NumberFormat(ability.value), ability.value / duration, ability.value / max(data.total, 1) * 100)
		
		row.color = RM.abilityTypeColors[ability.ref.type]
		row.value = ability.value
		row.leftClick = function()
			window:setMode("interactionAbility", ability.ref)
		end
		
		tinsert(rows, row)
	end
	
	window:setGlobalLabel(data.total / duration)
	
	return rows, data.count + 1, data.max
end

function Modes.interactionAbilities:rightClick(window)
	window:setMode("interactions", window.selectedPlayerParent)
end
function Modes.interactionAbilities:findOwner(window)
	local player = window.selectedCombat.players[window.selectedPlayerDetail]
	if player then
		window.selectedPlayer = player
		window:setTitle(("%s: %s"):format(player.detail.name, L[window.settings.sort]))
	end
end
function Modes.interactionAbilities:onSortmodeChange(window, oldSortmode)
	if window.settings.sort ~= oldSortmode then
		window:setMode("interactions", window.selectedPlayerParent)
		return false
	end
	return true
end

-- Mode: Interaction ability details

Modes.interactionAbility = Mode:new("interactionAbility")
function Modes.interactionAbility:init(window, ability)
	if ability then
		window.selectedAbility = ability
	end
	if window.selectedAbility then
		window:setTitle(("%s: %s"):format(window.selectedPlayerParent.detail.name, window.selectedAbility.name))
	end
end
function Modes.interactionAbility:update(window)
	if not window.selectedAbility or not window.selectedPlayer then
		self:findOwner(window)
		if not window.selectedAbility then
			return
		end
	end
	
	local data = window.selectedAbility:getPreparedAbilityStatData(window.selectedCombat, window.settings.sort)
	
	local rows = {}
	local limit = min(#data, #window.frames.rows)
	for i = 1, limit do
		local row = {}
		local stat = data[i + window.scrollOffset]
		
		row.leftLabel = stat.name
		row.rightLabel = stat.value
		row.color = {0.7, 0.7, 0.7}
		
		rows[i] = row
	end
	
	window:setGlobalLabel(window.selectedPlayerParent[window.settings.sort] / max(window.selectedCombat.duration, 1))
	
	return rows, #data, 1
end
function Modes.interactionAbility:rightClick(window)
	window:setMode("interactionAbilities")
end
function Modes.interactionAbility:findOwner(window)
	if not window.selectedPlayer then
		Modes.abilities:findOwner(window)
	end
	if window.selectedPlayer then
		window:setMode("abilities", window.selectedPlayer)
	end
end
function Modes.interactionAbility:onSortmodeChange(window, oldSortmode)
	if window.settings.sort ~= oldSortmode then
		window:setMode("interactions", window.selectedPlayerParent)
		return false
	end
	return true
end

-- Mode: Combat list

Modes.combats = Mode:new("combats")
function Modes.combats:init(window)
	window.rowCount = #RM.Combats
	window.scrollOffset = max(window.rowCount - #window.frames.rows, 0)
	window:setTitle(L["Combats"] .. ": " .. L[window.settings.sort])
end
function Modes.combats:update(window)
	if not window.selectedCombat then return end
	
	local rows = {}
	local limit = min(#RM.Combats, #window.frames.rows)
	local ncombats = 0
	local maxvalue = 0
	for i = 1, limit do
		local row = {}
		local combat = RM.Combats[i + window.scrollOffset]
		
		if not RM.settings.showOnlyBoss or (combat.hasBoss or combat == RM.CurrentCombat or combat == RM.overallCombat) then
			local stat = combat:getPreparedPlayerData(window.settings.sort, window.showEnemies).total / max(combat.duration, 1)
			local hostile = combat:getHostile()
			
			if stat > maxvalue then maxvalue = stat end

			row.leftLabel = FormatSeconds(combat.duration) .. " " .. hostile
			row.rightLabel = NumberFormat(floor(stat))
			row.value = stat

			row.leftClick = function()
			window:setMode("combat", RM.Combats[i + window.scrollOffset]) end
			
			ncombats = ncombats + 1
			rows[ncombats] = row
		end
	end
	
	window:setGlobalLabel(window.selectedCombat:getPreparedPlayerData(window.settings.sort, window.showEnemies).total / max(window.selectedCombat.duration, 1))
	
	return rows, #RM.Combats, maxvalue
end

-- Mode: Ability list

Modes.abilities = Mode:new("abilities")
function Modes.abilities:init(window, player)
	if player then
		window.selectedPlayer = player
	end
	if window.selectedPlayer then
		window:setTitle(("%s: %s"):format(window.selectedPlayer.detail.name, L[window.settings.sort]))
	end
end
function Modes.abilities:update(window)
	if not window.selectedPlayer then
		if window.selectedPlayerDetail then
			self:findOwner(window)
		end
		if not window.selectedPlayer then
			return
		end
	end
	
	local data = window.selectedPlayer:getPreparedAbilityData(window.settings.sort)
	local duration = max(window.selectedCombat.duration, 1)
	local rows = {}
	local limit = min(data.count, #window.frames.rows)
	for i = 1, limit do
		
		-- total bar
		if i == 1 and window.scrollOffset == 0 then
			tinsert(rows, {
				leftLabel = "      " .. L["Total"],
				rightLabel = NumberFormat(data.total),
				value = data.max,
				leftClick = function()
					window:setMode("ability", window.selectedPlayer:createFakeAbility())
				end
			})
		end
		
		local row = {}
		local index = window.scrollOffset > 0 and i + window.scrollOffset - 1 or i + window.scrollOffset
		local ability = data.abilities[index]
		
		row.icon = ability.ref.detail.icon
		row.leftLabel = "      " .. ability.ref.name
		row.rightLabel = BuildFormat(NumberFormat(ability.value), ability.value / duration, ability.value / max(data.total, 1) * 100)
		
		row.color = RM.abilityTypeColors[ability.ref.type]
		row.value = ability.value
		row.leftClick = function()
			window:setMode("ability", ability.ref)
		end
		
		tinsert(rows, row)
	end
	
	window:setGlobalLabel(data.total / duration)
	
	return rows, data.count + 1, data.max
end
function Modes.abilities:rightClick(window)
	window:setMode("combat")
end
function Modes.abilities:findOwner(window)
	local player = window.selectedCombat.players[window.selectedPlayerDetail]
	if player then
		window.selectedPlayer = player
		window:setTitle(("%s: %s"):format(player.detail.name, L[window.settings.sort]))
	end
end
function Modes.abilities:getReportText(window)
	local player = window.selectedPlayer
	local data = window.selectedPlayer:getPreparedAbilityData(window.settings.sort)
	local duration = max(window.selectedCombat.duration, 1)
	
	local text = {}
	tinsert(text, ("Player: %s ~ Target: %s ~ (%s)"):format(player.detail.name, window.selectedCombat:getHostile():sub(0, 64), FormatSeconds(window.selectedCombat.duration)))
	tinsert(text, ("--------------------"))
	tinsert(text, ("Total %s: %s ~ (%s)"):format( window.settings.sort, NumberFormat(data.total), NumberFormat(data.total / duration) ))
	for i = 1, min( data.count, RM.settings.report_lines ) do
		local ability = data.abilities[i]
		tinsert(text, ("%d) %s - %s (%s, %d%%) "):format( i, ability.ref.name:sub(0, 32), NumberFormat(ability.value), NumberFormat(ability.value / duration), ability.value / max(window.selectedPlayer[window.settings.sort], 1) * 100))
	end
	
	return text
end

-- Mode: Ability details

Modes.ability = Mode:new("ability")
function Modes.ability:init(window, ability)
	if ability then
		window.selectedAbility = ability
		window:setTitle(("%s: %s"):format(window.selectedPlayer.detail.name, window.selectedAbility.name))
	end
end
function Modes.ability:update(window)
	if not window.selectedAbility or not window.selectedPlayer then
		self:findOwner(window)
		if not window.selectedAbility then
			return
		end
	end
	
	local ability = window.selectedPlayer:getAbility(window.selectedAbility, window.settings.sort)
	local total
	local data
	if ability then
		data = ability:getPreparedAbilityStatData(window.selectedCombat)
		total = ability.total
	else
		data = window.selectedAbility:getPreparedAbilityStatData(window.selectedCombat, window.settings.sort)
		total = window.selectedPlayer[window.settings.sort]
	end
	
	local rows = {}
	local limit = min(#data, #window.frames.rows)
	for i = 1, limit do
		local row = {}
		local stat = data[i + window.scrollOffset]
		
		row.leftLabel = stat.name
		row.rightLabel = stat.value
		row.color = {0.7, 0.7, 0.7}
		
		rows[i] = row
	end
	
	window:setGlobalLabel(total / max(window.selectedCombat.duration, 1))
	
	return rows, #data, 1
end
function Modes.ability:rightClick(window)
	window:setMode("abilities", window.selectedPlayer)
end
function Modes.ability:findOwner(window)
	if not window.selectedPlayer then
		Modes.abilities:findOwner(window)
	end
	if window.selectedPlayer then
		window:setMode("abilities")
	end
end

-- UI API

RM.UI = { }

function RM.UI.Update()
	for i, window in ipairs(Windows) do
		window:update()
	end
end

function RM.UI.TimerUpdate(duration)
	local combat = RM.Combats[#RM.Combats]
	for i, window in ipairs(Windows) do
		if window.selectedCombat == combat then
			window:timerUpdate(duration)
		end
	end
end

function RM.UI.NewCombat()
	for i, window in ipairs(Windows) do
		-- update to current combat if last combat was selected
		if window.selectedCombat == RM.Combats[#RM.Combats - 1] or window.selectedCombat == nil then
			window.selectedCombat = RM.Combats[#RM.Combats]
			
			if window.selectedPlayer then
				window.selectedPlayerDetail = window.selectedPlayer.detail
				window.selectedPlayer = nil
			end
			if window.selectedAbility then
				window.selectedAbilityDetail = window.selectedAbility.detail
				window.selectedAbility = nil
			end
			
			window:clearRows()
			window.selectedMode:init(window)
		end
		
		window.frames.buttons.combatStart:Show(false)
		window.frames.buttons.combatEnd:Show(true)
	end
end

function RM.UI.EndCombat()
	for i, window in ipairs(Windows) do
		window.frames.buttons.combatStart:Show(true)
		window.frames.buttons.combatEnd:Show(false)
		
		if window.selectedCombat == RM.Combats[#RM.Combats] then
			window:timerUpdate(window.selectedCombat.duration)
		end
	end
end

function RM.UI.Solo(bDisabled)
	Apollo.SetConsoleVariable("cmbtlog.disableOtherPlayers", bDisabled)
	local color = bDisabled and "xkcdAcidGreen" or "xkcdBloodOrange"
	for i, window in ipairs(Windows) do
		window.frames.solo:SetTextColor(color)
	end
end

function RM.UI.Clear()
	for i, window in ipairs(Windows) do
		window.selectedCombat = nil
		window:setMode("combat")
		window.frames.timerLabel:SetText("00:00")
		window.frames.globalStatLabel:SetText("0")
		window:clearRows()
	end
end

function RM.UI.Init()
	for i, settings in ipairs(RM.settings.windows) do
		tinsert(Windows, Window:new(settings))
	end
end

function RM.UI.Destroy()
	for i=#Windows,1,-1 do
		tremove(Windows, i).frames.base:Destroy()
		tremove(RM.settings.windows, i)
	end
end

function RM.UI.NewWindow()
	local settings = RM.GetDefaultWindowSettings()
	tinsert(RM.settings.windows, settings)
	tinsert(Windows, Window:new(settings))
	RM.UI.Visible(true)
end

function RM.UI.Close(window)
	if #Windows == 1 then
		Print((L["Type /vm show to reactivate %s."]):format(RM.name))
		RM.Off()
		return
	end
	
	for i = 1, #Windows do
		if window == Windows[i] then
			tremove(Windows, i).frames.base:Destroy()
			tremove(RM.settings.windows, i)
			return
		end
	end
end

function RM.UI.Visible(visible)
	for i, window in ipairs(Windows) do
		window.frames.base:Show(visible)
	end
end

function RM.UI.Lock(state)
	RM.settings.lock = state
	for i, window in ipairs(Windows) do
		window:Lock(state)
	end
end
