---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

-- TODO: Tidy

local RM = Apollo.GetAddon("VortexMeter")
local Info = Apollo.GetAddonInfo("VortexMeter")
RM.UI = { }

local L = RM.l
local NumberFormat = RM.numberFormat
local FormatSeconds = RM.formatSeconds

local UI = UI

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
local AsyncRowHoverEventHelper = 0 -- e.g. mousein, mousein, mouseout :(
local Windows = {}
RM.Windows = Windows
local Modes = {}
--local Sortmodes = {}
local Sortmodes = {
	"damage",
	"heal",
	"damageTaken",
	"healTaken",
	"overheal",
	"overkill",
	"interrupts",
}


local Mode = {}
Mode.__index = Mode
function Mode:new(name)
	local self = {}
	self.name = name
	self.scrollOffset = 0
	self.index = 0
	return setmetatable(self, Mode)
end
function Mode:rightClick() end
function Mode:mouse4Click() end
function Mode:mouse5Click() end
function Mode:init() end
function Mode:update() end
function Mode:onSortmodeChange(window, newSortmode) return true end
function Mode:getReportText() end

local Sortmode = {}
Sortmode.__index = Sortmode
function Sortmode:new()
	local self = {}
	
	return setmetatable(self, Sortmode)
end
function Sortmode:isCompatibleWith(mode) return false end
function Sortmode:getData(mode) return {} end


local Dialog = {}
function Dialog:init()
	self.dialog = UI.CreateFrame("Frame", "RM_dialog", Context)
	self.dialog:SetVisible(false)
	self.dialog:SetWidth(350)
	self.dialog:SetHeight(100)
	self.dialog:SetBackgroundColor(0, 0, 0, .9)
	self.dialog:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	
	self.dialogText = UI.CreateFrame("Text", "RM_dialogText", self.dialog)
	self.dialogText:SetFontSize(14)
	self.dialogText:SetPoint("TOPCENTER", self.dialog, "TOPCENTER", 0, 15)
	
	self.dialogButtonYes = UI.CreateFrame("RiftButton", "RM_dialogButtonYes", self.dialog)
	self.dialogButtonYes:SetText("Yes")
	self.dialogButtonYes:SetPoint("BOTTOMLEFT", self.dialog, "BOTTOMLEFT", 20, -5)
	
	self.dialogButtonNo = UI.CreateFrame("RiftButton", "RM_dialogButtonNo", self.dialog)
	self.dialogButtonNo:SetText("No")
	self.dialogButtonNo:SetPoint("BOTTOMRIGHT", self.dialog, "BOTTOMRIGHT", -20, -5)
end
function Dialog:show(text, yesLabel, noLabel, yesCallback, noCallback)
	if not self.dialog then
		self:init()
	end
	local dialog = self.dialog
	
	dialog:SetVisible(true)
	self.dialogText:SetText(text)
	self.dialogButtonYes:SetText(yesLabel)
	self.dialogButtonNo:SetText(noLabel)
	
	function self.dialogButtonYes.Event:LeftPress()
		dialog:SetVisible(false)
		yesCallback()
	end
	function self.dialogButtonNo.Event:LeftPress()
		dialog:SetVisible(false)
		noCallback()
	end
end

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




local function RemoveOtherWindows()
	while #Windows > 1 do
		Windows[#Windows].frames.base:Destroy()
		tremove(Windows, #Windows)
		tremove(RM.settings.windows, #Windows)
	end
end

local function Close(window)
	if #Windows == 1 then
		Print((L["Type /vm show to reactivate %s."]):format(Info.strName))
		RM.Off()
		return
	end
	
	for i = 1, #Windows do
		if window == Windows[i] then
			Windows[i].frames.base:Show(false)
			tremove(Windows, i)
			tremove(RM.settings.windows, i)
			return
		end
	end
end

local function GetClassColor(unit)
	local calling
	if unit.owner then
		calling = unit.owner.calling -- pet has no calling -> get pet owner's calling
	else
		calling = unit.calling
	end
	
	if calling then
		return RM.settings.classColors[calling]
	else
		return {1, 1, 1}
	end
end

local function BuildFormat(absolute, perSecond, percent)
	local args = {}
	local format = ""
	if RM.settings.showAbsolute then
		tinsert(args, absolute)
		format = format .. "%s" .. (RM.settings.showPercent and " (" or ", ") .. "%s"
	else
		format = format .. "%s"
	end
	
	tinsert(args, RM.numberFormat(perSecond))
	
	if RM.settings.showPercent then
		tinsert(args, percent)
		format = format .. (RM.settings.showAbsolute and ", " or " ") .. (not RM.settings.showAbsolute and "(" or "") .. "%.1f%%)"
	end
	
	return format:format(unpack(args))
end






local Window = {}
Window.__index = Window
function Window:new(settings)
	local self = {}
	
	self.settings = settings
	self.resizing = false
	self.frames = {}
	self.lastData = {}
	self.history = {}
	self.maxValue = 0
	self.rowCount = 0
	self.scrollOffset = 0
	self.showNpcs = false
	self.isScrollbarPresent = false
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
	window = self
	
	window.frames.base = Apollo.LoadForm(RM.xmlMainDoc, "VortexMeterForm", nil, RM)
	window.frames.header = window.frames.base:FindChild("Header")
	window.frames.headerLabel = window.frames.base:FindChild("HeaderText")
	
	window.frames.buttons = { }
	
	window.frames.buttons.close = window.frames.base:FindChild("ButtonClose")
	window.frames.buttons.copy = window.frames.base:FindChild("ButtonCopy")
	window.frames.buttons.clear = window.frames.base:FindChild("ButtonClear")
	window.frames.buttons.pin = window.frames.base:FindChild("ButtonPin")
	window.frames.buttons.config = window.frames.base:FindChild("ButtonConfig")
	window.frames.buttons.showEnemies = window.frames.base:FindChild("ButtonEnemies")
	window.frames.buttons.showPlayers = window.frames.base:FindChild("ButtonPlayers")
	window.frames.buttons.combatStart = window.frames.base:FindChild("ButtonStart")
	window.frames.buttons.combatEnd = window.frames.base:FindChild("ButtonStop")
	
	window.frames.background = window.frames.base:FindChild("Background")
	window.frames.opacitybackground = window.frames.base:FindChild("OpacityBackground")
	window.frames.opacitybackground:SetOpacity(RM.settings.opacity)
	
	window.frames.resizeLeaf = window.frames.base:FindChild("ResizeLeaf")
	window.frames.footer = window.frames.base:FindChild("Footer")
	window.frames.solo = window.frames.footer:FindChild("btnSolo")
	window.frames.filter = window.frames.footer:FindChild("btnFilter")
	window.frames.copyField = window.frames.base:FindChild("CopyField")
	window.frames.copyBackground = window.frames.base:FindChild("CopyBackground")
	
	window.frames.resizerLeft = window.frames.base:FindChild("ResizeLeft")
	window.frames.resizerRight = window.frames.base:FindChild("ResizeRight")
	
	window.frames.reportform = Apollo.LoadForm(RM.xmlMainDoc, "ReportForm", nil, RM)
	window.frames.reportform:Show(false)
	
	window.frames.timerLabel = window.frames.base:FindChild("TimerLabel")
	window.frames.globalStatLabel = window.frames.base:FindChild("GlobalStatLabel")
	
	window.selectedMode:init(window)
	window:resize()
	window:showResizer(not RM.settings.lock)
	
	window.frames.header:SetOpacity(RM.settings.mousetransparancy)
	window.frames.footer:SetOpacity(RM.settings.mousetransparancy)
	
	if RM.settings.showScrollbar then
		window:showScrollbar(true)
	end
end

function RM:OnHeaderButtonDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = self.Windows[1]
	
	if eMouseButton == 0 and not RM.settings.lock then
		window.pressed = true
		local mouse = Apollo.GetMouse()
		window.mouseStartX = mouse.x
		window.mouseStartY = mouse.y
		
		local anchor = {window.frames.base:GetAnchorOffsets()}
		window.attrStartX = anchor[1]
		window.attrStartY = anchor[2]
	end
end

function RM:OnHeaderButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = self.Windows[1]
	
	if eMouseButton == 1 then
		window:setMode("modes")
	elseif eMouseButton == 0 then
		window.pressed = false
	end
end

function RM:OnHeaderMouseMove(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = self.Windows[1]
	
	if window.pressed then
		local mouse = Apollo.GetMouse()
		window.settings.x = mouse.x - window.mouseStartX + window.attrStartX
		window.settings.y = mouse.y - window.mouseStartY + window.attrStartY
		
		local anchor = {window.frames.base:GetAnchorOffsets()}
		window.frames.base:SetAnchorOffsets(window.settings.x, window.settings.y,
			window.settings.x + anchor[3] - anchor[1] ,window.settings.y + anchor[4] - anchor[2])
	end
end

function RM:OnFrameMouseEnter(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		window.frames.header:SetOpacity(1)
		window.frames.footer:SetOpacity(1)
	end
end

function RM:OnFrameMouseExit(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		window.frames.header:SetOpacity(RM.settings.mousetransparancy)
		window.frames.footer:SetOpacity(RM.settings.mousetransparancy)
	end
end

function RM:OnButtonFilter( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	local window = self.Windows[1]
	
	if RM.FilterOn then
		local color = "xkcdBloodOrange"
		wndControl:SetTextColor(color)
		RM.FilterOn = false
	else
		local color = "xkcdAcidGreen"
		wndControl:SetTextColor(color)
		RM.FilterOn = true
		
		if window.selectedCombat then
			window:setMode("targets")
		else
			window:setMode("combats")
		end
		-- Open up window with mobs we have fought
		-- Pick a mob, and go back to normal dmg window, but only with dmg to that mob
	end
end

function RM:OnButtonSolo( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if Apollo.GetConsoleVariable("cmbtlog.disableOtherPlayers") then
		local color = "xkcdBloodOrange"
		Apollo.SetConsoleVariable("cmbtlog.disableOtherPlayers", false)
		wndControl:SetTextColor(color)
	else
		local color = "xkcdAcidGreen"
		Apollo.SetConsoleVariable("cmbtlog.disableOtherPlayers", true)
		wndControl:SetTextColor(color)
	end
end

function RM:OnButtonClose(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	
	Close(window)
	
	RM.Tooltip:hide()
end

function RM:OnButtonCopy(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	
	window:report()
end

function RM:OnButtonConfig(wndHandler, wndControl, eMouseButton)
	RM.ConfigInit()
end

function RM:OnButtonClear(wndHandler, wndControl, eMouseButton)
	RM.Reset()
end

function RM:OnButtonStart(wndHandler, wndControl, eMouseButton)
	RM.NewCombat(true)
end

function RM:OnButtonStop(wndHandler, wndControl, eMouseButton)
	RM.EndCombat(true)
end

function RM:OnButtonPin(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	
	window:setMode("combat", RM.combats[#RM.combats])
end

function RM:OnButtonEnemies(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	
	window.frames.buttons.showPlayers:Show(true)
	window.frames.buttons.showEnemies:Show(false)
	window.showEnemies = true
	window:update()
end

function RM:OnButtonPlayers(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	
	window.frames.buttons.showPlayers:Show(false)
	window.frames.buttons.showEnemies:Show(true)
	window.showEnemies = false
	window:update()
end

function RM:OnRowButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = self.Windows[1]
	
	for i = 1, window.settings.rows do
		local row = window.frames.rows[i]
		if row.base == wndControl then
			if eMouseButton == 0 then
				row.events.leftClick()
			elseif eMouseButton == 1 then
				row.events.rightClick()
			elseif eMouseButton == 2 then
				row.events.middleClick()
			end
		end
	end
end

function RM:OnBackgroundButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = self.Windows[1]
	
	if eMouseButton == 1 then
		window.selectedMode:rightClick(window)
	elseif eMouseButton == 4 then
		window.selectedMode:mouse4Click(window)
	elseif eMouseButton == 5 then
		window.selectedMode:mouse5Click(window)
	end
end

function RM:OnBackgroundScroll(wndHandler, wndControl, nLastRelativeMouseX, nLastRelativeMouseY, fScrollAmount, bConsumeMouseWheel)
	local window = self.Windows[1]
	
	if fScrollAmount > 0 then
		local val = max(window.scrollOffset - 1, 0)
		if val ~= window.scrollOffset then
			window.scrollOffset = val
			window:update()
			
			if window.isScrollbarPresent then
				window.frames.scrollbar:SetPosition(window.scrollOffset)
			end
		end
	else
		local val = min(window.scrollOffset + 1, window.rowCount - window.settings.rows)
		if val ~= window.scrollOffset and val > 0 then
			window.scrollOffset = val
			window:update()
			
			if window.isScrollbarPresent then
				self.frames.scrollbar:SetPosition(window.scrollOffset)
			end
		end
	end
	
	return true
end

function RM:OnButtonReport(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	local chan = window.frames.reportform:FindChild('ReportChannelEditBox')
	local target = window.frames.reportform:FindChild('ReportTargetEditBox')
	local lines = window.frames.reportform:FindChild('ReportLinesEditBox')
	if RM.settings.report_channel == nil then
		RM.settings.report_channel = "s"
	end
	if RM.settings.report_target == nil then
		RM.settings.report_target = "none"
	end
	if RM.settings.report_lines == nil then
		RM.settings.report_lines = "5"
	end
	chan:SetText(RM.settings.report_channel)
	target:SetText(RM.settings.report_target)
	lines:SetText(RM.settings.report_lines)
	window.frames.reportform:Show(true)
end

function RM:OnReportConfirmButton(wndHandler, wndControl, fNewValue, fOldValue)
	local window = self.Windows[1]
	local selectedMode = window.selectedMode
	if not selectedMode then
		selectedMode = Modes.interactionAbilities
	end
	
	local chan = window.frames.reportform:FindChild('ReportChannelEditBox'):GetText()
	local target = window.frames.reportform:FindChild('ReportTargetEditBox'):GetText()
	local lines = window.frames.reportform:FindChild('ReportLinesEditBox'):GetText()
	
	RM.settings.report_channel = chan
	RM.settings.report_target = target
	RM.settings.report_lines = tonumber(lines)
	
	local text = selectedMode:getReportText(window)
	window.frames.reportform:Show(false)
	window.report(text)
end

function RM:OnReportClose(wndHandler, wndControl, eMouseButton)
	local window = self.Windows[1]
	window.frames.reportform:Show(false)
end

-- TODO: I really want to get this working with mousemove...
function RM:OnWindowSizeChanged(wndHandler, wndControl)
	local window = self.Windows[1]
	
	if window and wndControl == wndHandler and not window.resizing then
		local mouse = Apollo.GetMouse()
		
		-- This is a hack since SizeChanged gets called on window move
		if mouse.y < window.settings.y + (window.settings.rowHeight + 1) * #window.frames.rows then return end
		
		-- This is also a hack, we attach this event to a leaf window, otherwise we get far too many events
		window.frames.resizeLeaf:RemoveEventHandler("WindowSizeChanged")
		
		local anchor = {window.frames.base:GetAnchorOffsets()}
		local rows = round((mouse.y - anchor[2] - 45) / (window.settings.rowHeight+1))
		if rows <= 0 then rows = 1 end
		window:setRows(rows)
		window.frames.base:SetAnchorOffsets(anchor[1], anchor[2], anchor[3], 45 + anchor[2] + (rows * (window.settings.rowHeight + 1)))
		window.settings.width = anchor[3] - anchor[1]
		
		for i = 1, rows do
			local anchor = {window.frames.rows[i].base:GetAnchorOffsets()}
			window.frames.rows[i].base:SetAnchorOffsets(anchor[1], anchor[2], anchor[1] + window.settings.width - 2, anchor[4])
		end
		
		window:update()
		
		window.frames.resizeLeaf:AddEventHandler("WindowSizeChanged", "OnWindowSizeChanged", RM)
	end
end

-- This is yet another hack to work around bugs caused by our SizeChanged on move hack...
function RM:OnResizerButtonDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	local window = self.Windows[1]
	
	local mouse = Apollo.GetMouse()
	local anchor = {window.frames.base:GetAnchorOffsets()}
	local rows = round((mouse.y - anchor[2] - 45) / (window.settings.rowHeight+1))
	if rows <= 0 then rows = 1 end
	if math.abs(rows - #window.frames.rows) > 1 then
		window:setRows(rows)
		window.frames.base:SetAnchorOffsets(anchor[1], anchor[2], anchor[3], 45 + anchor[2] + (rows * (window.settings.rowHeight + 1)))
	end
end

function RM:OnHeaderMouseEnter(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		window.frames.headerLabel:SetTextColor(ApolloColor.new(0.8, 0.8, 0.8, 1))
	end
end

function RM:OnHeaderMouseExit(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		window.frames.headerLabel:SetTextColor(ApolloColor.new(1, 1, 1, 1))
	end
end

function RM:OnButtonMouseEnter(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
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
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		RM.Tooltip:hide()
	end
end

function RM:OnRowMouseEnter(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		for i = 1, window.settings.rows do
			local row = window.frames.rows[i]
			if row.base == wndControl then
				row.background:SetOpacity(0.9)
				if row.tooltip then
					RM.Tooltip:show(row.tooltip())
				end
			end
		end
	end
end

function RM:OnRowMouseExit(wndHandler, wndControl, x, y)
	local window = self.Windows[1]
	
	if wndHandler == wndControl then
		for i = 1, window.settings.rows do
			local row = window.frames.rows[i]
			if row.base == wndControl then
				row.background:SetOpacity(0.7)
			 end
		end
		
		RM.Tooltip:hide()
	end
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
function Window:update(useOldData)
	if not useOldData then
		self.lastData, self.rowCount, self.maxValue = self.selectedMode:update(self)
	end
	
	self.lastData = self.lastData or {}
	self.rowCount = self.rowCount or 0
	self.maxValue = max(self.maxValue or 1, 1)
	
	if self.isScrollbarPresent then
		local scrollbar = self.frames.scrollbar
		local val = max(self.rowCount - self.settings.rows, 0)
		if val == 0 then
			scrollbar:SetEnabled(false)
		else
			scrollbar:SetEnabled(true)
			scrollbar:SetRange(0, val)
			scrollbar:SetPosition(self.scrollOffset) -- e.g. combats mode overrides scrollOffset
		end
	end
	
	local anchors = {self.frames.rows[1].base:GetAnchorOffsets()}
	local maxRowWidth = anchors[3] - anchors[1]
	for i = 1, self.settings.rows do
		local row = self.frames.rows[i]
		local data = self.lastData[i]
		local rightClick
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
				rightClick = function() end --RM:OnBackgroundButtonUp(self, self, 1, 0, 0) end
			else
				rightClick = function() data.rightClick(self) end
			end
			if data.icon and data.icon ~= "" then
				row.icon:SetSprite(data.icon)
				row.icon:Show(true)
			else
				row.icon:Show(false)
			end
			
			row.leftLabel:SetText(tostring(data.leftLabel))
			row.rightLabel:SetText(tostring(data.rightLabel))
			local anchor = {row.background:GetAnchorOffsets()}
			row.background:SetAnchorOffsets(anchor[1], anchor[2], anchor[1] + max(min(maxRowWidth * data.value / self.maxValue, maxRowWidth), 0), anchor[4])
			row.background:SetBGColor(ApolloColor.new(data.color[1], data.color[2], data.color[3], 1))
			row.events.leftClick = data.leftClick
			row.events.middleClick = data.middleClick
			row.events.rightClick = rightClick
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
	local rowCount = 0
	local rowpos = 1
	
	if self.frames.rows then
		rowCount = #self.frames.rows
		rowpos = 1 + rowCount * (self.settings.rowHeight + 1)
	end
	
	if rowCount == count then
		return
	end
	
	count = max(count, 1)
	self.settings.rows = count
	
	if self.frames.rows then
		local diff = count - rowCount
		if diff < 0 then -- remove row(s)
			self:clearRows(count)
			for i = count + 1, rowCount do
				self.frames.obscured_rows[rowCount - i + count + 1] = tremove(self.frames.rows)
			end
			RM.data5 = self.frames.obscured_rows
		elseif diff > 0 then -- add row(s)
			self.scrollOffset = max(min(self.scrollOffset, self.rowCount - self.settings.rows), 0)
		elseif diff == 0 then
			forCount = 0
		end
	else
		self.frames.rows = {}
		self.frames.obscured_rows = {}
	end
	
	for i = rowCount + 1, forCount do
		self.frames.rows[i] = self.frames.obscured_rows[i]
		
		if not self.frames.rows[i] then
			self.frames.rows[i] = { }
			self.frames.rows[i].events = { }
			self.frames.rows[i].base = Apollo.LoadForm(RM.xmlMainDoc, "Row", self.frames.background, RM)
			self.frames.rows[i].background = self.frames.rows[i].base:FindChild("Background")
			self.frames.rows[i].icon = self.frames.rows[i].base:FindChild("Icon")
			self.frames.rows[i].rightLabel = self.frames.rows[i].base:FindChild("RightLabel")
			self.frames.rows[i].leftLabel = self.frames.rows[i].base:FindChild("LeftLabel")
			self.frames.rows[i].background:SetOpacity(0.7)
		end
			
		local anchor = {self.frames.base:GetAnchorOffsets()}
		self.frames.rows[i].base:SetAnchorOffsets(1, rowpos, anchor[3] - anchor[1] - 1, rowpos + self.settings.rowHeight)
		rowpos = rowpos + self.settings.rowHeight + 1
		self.frames.rows[i].base:Show(false)
	end
	
	self.resizing = true
	local anchor = {self.frames.base:GetAnchorOffsets()}
	self.frames.base:SetAnchorOffsets(anchor[1], anchor[2], anchor[3], 45 + anchor[2] + (count * (self.settings.rowHeight + 1)))
	self.resizing = false
	
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
	
	if self.isScrollbarPresent and self.frames.scrollbar:GetEnabled() then
		self.frames.scrollbar:SetPosition(self.scrollOffset)
	end
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
function Window:setWidth(width)
	self.frames.base:SetWidth(width)
	self:update(true)
end
function Window:resize()
	self.resizing = true
	self.frames.base:SetAnchorOffsets(self.settings.x, self.settings.y, self.settings.x + self.settings.width, self.settings.y + 45 + (self.settings.rows * (self.settings.rowHeight + 1)))
	self.resizing = false
	
	self:setRows(self.settings.rows)
end
function Window:showResizer(state)
	self.frames.resizerLeft:Show(state)
	self.frames.resizerRight:Show(state)
	self.frames.base:SetStyle("Sizable", state)
end

-- Remove or port this
function Window:showScrollbar(state)
	local window = self
	if not self.frames.scrollbar and state then
		self.frames.scrollbar = UI.CreateFrame("RiftScrollbar", "RM_scrollbar", self.frames.base)
		self.frames.scrollbar:SetPoint("TOPRIGHT", self.frames.header, "BOTTOMRIGHT")
		self.frames.scrollbar:SetPoint("BOTTOM", self.frames.footer, "TOP")
		self.frames.scrollbar:SetOrientation("vertical")
		self.frames.scrollbar:SetLayer(2)
		self.frames.scrollbar:SetThickness(4)
		
		self.frames.scrollbar.Event.ScrollbarChange = function (self)
			local val = round(window.frames.scrollbar:GetPosition())
			if val ~= window.scrollOffset then
				window.scrollOffset = val
				window:update()
			end
		end
	end
	
	if state then
		self.frames.scrollbar:SetVisible(true)
		if self.rowCount - self.settings.rows > 0 then
			self.frames.scrollbar:SetRange(0, self.rowCount - self.settings.rows)
			self.frames.scrollbar:SetPosition(self.scrollOffset)
		end
	else
		self.frames.scrollbar:SetVisible(false)
	end
	
	for i, row in ipairs(self.frames.rows) do
		if RM.settings.showScrollbar then
			row.base:SetPoint("RIGHT", self.frames.scrollbar, "LEFT")
		else
			row.base:SetPoint("RIGHT", self.frames.background, "RIGHT", -1, nil)
		end
	end
	
	self.isScrollbarPresent = state
	
	self:update(true)
end


Modes.modes = Mode:new("modes")
function Modes.modes:init(window)
	window:setTitle("VortexMeter: " .. L["Sort Modes"])
end
function Modes.modes:update(window)
	local rows = {}
	local limit = min(#Sortmodes, window.settings.rows)
	for i = 1, limit do
		local data = {}
		local lastMode = window:getLastMode()
		local sortMode = Sortmodes[i + window.scrollOffset]
		
		data.leftLabel = L[sortMode]
		data.rightlabel = ""
		data.value = window.settings.width - 2
		data.leftClick = function()
			local oldSortmode = window.settings.sort
			window.settings.sort = Sortmodes[i + window.scrollOffset]
			
			if lastMode:onSortmodeChange(window, oldSortmode) then
				window:setMode(lastMode)
			end
		end
		
		rows[i] = data
	end
	return rows, #Sortmodes, window.settings.width - 2
end


Modes.combat = Mode:new("combat")
function Modes.combat:init(window, combat)
	if combat then
		window.selectedCombat = combat
	end
	
	if not window.selectedCombat then
		if #RM.combats > 0 then
			window.selectedCombat = RM.combats[#RM.combats]
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
	local limit = min(data.count, window.settings.rows)
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
		
		row.color = GetClassColor(player.ref.detail)
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
	if #RM.combats > 0 then
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
	for i, combat in ipairs(RM.combats) do
		if combat == window.selectedCombat and i > 1 then
			window:setMode("combat", RM.combats[i - 1])
			return
		end
	end
end
function Modes.combat:mouse5Click(window)
	for i, combat in ipairs(RM.combats) do
		if combat == window.selectedCombat and i < #RM.combats then
			window:setMode("combat", RM.combats[i + 1])
			return
		end
	end
end


-- FILTER STARTS HERE --

Modes.filter = Mode:new("filter")
function Modes.filter:init(window, combat)
	if combat then
		window.selectedCombat = combat
	end
	
	if not window.selectedCombat then
		if #RM.combats > 0 then
			window.selectedCombat = RM.combats[#RM.combats]
		end
	end
	
	if window.selectedCombat then
		window:timerUpdate(window.selectedCombat.duration)
	end
	window:setTitle(L[window.settings.sort])
end
function Modes.filter:update(window)
	if not window.selectedCombat then return end -- Update() is called on init
	
	local data = window.selectedCombat:getPreparedPlayerData(window.settings.sort, window.showEnemies)
	
	local rows = {}
	local selfFound = false
	local limit = min(data.count, window.settings.rows)
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
		
		row.color = GetClassColor(player.ref.detail)
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
function Modes.filter:rightClick(window)
	if #RM.combats > 0 then
		window:setMode("targets")
	end
end
function Modes.filter:getReportText(window)
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

function Modes.filter:mouse4Click(window)
	for i, combat in ipairs(RM.combats) do
		if combat == window.selectedCombat and i > 1 then
			window:setMode("targets", RM.combats[i - 1])
			return
		end
	end
end
function Modes.filter:mouse5Click(window)
	for i, combat in ipairs(RM.combats) do
		if combat == window.selectedCombat and i < #RM.combats then
			window:setMode("targets", RM.combats[i + 1])
			return
		end
	end
end



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
	local limit = min(data.count, window.settings.rows)
	for i = 1, limit do
		local row = {}
		local interaction = data.interactions[i + window.scrollOffset]
		
		row.leftLabel = (RM.settings.showRankNumber and i + window.scrollOffset .. ". " or "") .. interaction.name
		row.rightLabel = BuildFormat(NumberFormat(interaction.value), interaction.value / duration, interaction.value / data.total * 100)
		row.color = GetClassColor(interaction.ref.detail)
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
	local limit = min(data.count, window.settings.rows)
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
		
		row.color = RM.settings.abilityTypeColors[ability.ref.type]
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
	local limit = min(#data, window.settings.rows)
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



Modes.combats = Mode:new("combats")
function Modes.combats:init(window)
--	local val = max(RowCount - RM.settings.rows, 0) -- RowCount is an old value. last combat count
--	RowCount = #RM.combats -- now update
--	if self.scrollOffset == val or self.scrollOffset == 0 then -- dont scroll back to the last combats if the user is already in combats selection mode and a new combat started
--		self.scrollOffset = max(RowCount - RM.settings.rows, 0) -- set offset to the current combat
--	end
	
	window.rowCount = #RM.combats
	window.scrollOffset = max(window.rowCount - window.settings.rows, 0)
	window:setTitle(L["Combats"] .. ": " .. L[window.settings.sort])
end
function Modes.combats:update(window)
	if not window.selectedCombat then return end
	
	local rows = {}
	local limit = min(#RM.combats, window.settings.rows)
	local ncombats = 0
	for i = 1, limit do
		local row = {}
		local combat = RM.combats[i + window.scrollOffset]
		
		if not RM.settings.showOnlyBoss or (combat.hasBoss or combat == RM.CurrentCombat or combat == RM.overallCombat) then
			local stat = combat:getPreparedPlayerData(window.settings.sort, window.showEnemies).total / max(combat.duration, 1)
			local hostile = combat:getHostile()
			
			row.leftLabel = FormatSeconds(combat.duration) .. " " .. hostile
			row.rightLabel = NumberFormat(floor(stat))
			row.value = stat
		-- SEARCH FILTERONFUNCTION
			row.leftClick = function()
			window:setMode("combat", RM.combats[i + window.scrollOffset]) end
			
			ncombats = ncombats + 1
			rows[ncombats] = row
		end
	end
	
	window:setGlobalLabel(window.selectedCombat:getPreparedPlayerData(window.settings.sort, window.showEnemies).total / max(window.selectedCombat.duration, 1))
	
	return rows, #RM.combats, RM.GetMaxValueCombat(window.settings.sort, window.showEnemies)
end


-- ## FILTER TARGETS ##

Modes.targets = Mode:new("targets")
function Modes.targets:init(window)
--	local val = max(RowCount - RM.settings.rows, 0) -- RowCount is an old value. last combat count
--	RowCount = #RM.combats -- now update
--	if self.scrollOffset == val or self.scrollOffset == 0 then -- dont scroll back to the last combats if the user is already in combats selection mode and a new combat started
--		self.scrollOffset = max(RowCount - RM.settings.rows, 0) -- set offset to the current combat
--	end
	
	window.rowCount = #RM.combats
	window.scrollOffset = max(window.rowCount - window.settings.rows, 0)
	window:setTitle(L["Targets"] .. ": FilterMode")
end
function Modes.targets:update(window)
	if not window.selectedCombat then return end -- Update() is called on init
	
	--local data = window.selectedCombat:getPreparedPlayerData(window.settings.sort, window.showEnemies)
	local data = window.selectedCombat:getHostile()
	Print("Player is nil???: " .. data[i + window.scrollOffset])
	
	local rows = {}
	local limit = min(data.count)
	local duration = max(window.selectedCombat.duration, 1)
	local hostiles = {}
	
	--for i = 1, limit do
		--local player = data.players[i + window.scrollOffset]
				
		--local tmpData = player:getInteractions(window.settings.sort)
		
		--for i = 1, min(tmpData.count) do
			--local interaction = tmpData.interactions[i + window.scrollOffset]
			--tinsert(hostiles, interaction)
		--end
	--end
	if test == "22" then
		limit = min(data.count, window.settings.rows)
		for i = i, limit do
			local row = {}
			local hostile = hostiles[i + window.scrollOffset]
	
			row.leftLabel = (RM.settings.showRankNumber and i + window.scrollOffset .. ". " or "") .. hostile.name
			--row.rightLabel = BuildFormat(NumberFormat(player.value), player.value / duration, player.value / data.total * 100)
			row.color = GetClassColor(hostile.ref.detail)
			row.value = hostile.value
			row.leftClick = function()
				--window:setMode("interactionAbilities", player.ref, window.selectedPlayer)
			end
	
			tinsert(rows, row)
		end
	end
	
	window:setGlobalLabel(data.total / duration)
	
	return rows, data.count, data.max
end


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
	local limit = min(data.count, window.settings.rows)
	for i = 1, limit do
		
		-- total bar
		if i == 1 and self.scrollOffset == 0 then
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
		
		row.color = RM.settings.abilityTypeColors[ability.ref.type]
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
	local limit = min(#data, window.settings.rows)
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







function RM.UI.NewSortmode()
	local sortmode = Sortmode:new()
	tinsert(Sortmodes, sortmode)
	return sortmode
end

function RM.UI.Update()
	for i, window in ipairs(Windows) do
		window:update()
	end
end

function RM.UI.TimerUpdate(duration)
	local combat = RM.combats[#RM.combats]
	for i, window in ipairs(Windows) do
		if window.selectedCombat == combat then
			window:timerUpdate(duration)
		end
	end
end

function RM.UI.NewCombat()
	for i, window in ipairs(Windows) do
		-- update to current combat if last combat was selected
		if window.selectedCombat == RM.combats[#RM.combats - 1] or window.selectedCombat == nil then
			window.selectedCombat = RM.combats[#RM.combats]
			
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
		
		if window.selectedCombat == RM.combats[#RM.combats] then
			window:timerUpdate(window.selectedCombat.duration)
		end
	end
end


function RM.UI.Default()
	RM.Off()
	RM.UI.Destroy()
	RM.UI.NewWindow()
	RM.On()
end

function RM.UI.Reset()
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
	for i, window in ipairs(Windows) do
		Windows[i].frames.base:Destroy()
		tremove(Windows, i)
		tremove(RM.settings.windows, i)
	end
end

function RM.UI.NewWindow()
	local settings = RM.GetDefaultWindowSettings()
	tinsert(RM.settings.windows, settings)
	tinsert(Windows, Window:new(settings))
end

function RM.UI.Visible(visible)
	for i, window in ipairs(Windows) do
		window.frames.base:Show(visible)
	end
end

function RM.UI.ShowResizer(state)
	for i, window in ipairs(Windows) do
		window:showResizer(state)
	end
end
function RM.UI.ShowScrollbar(state)
	for i, window in ipairs(Windows) do
		window:showScrollbar(state)
	end
end
