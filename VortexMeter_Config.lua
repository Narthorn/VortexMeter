---------------------------------------------------------------------------------------
-- Vortex Meter
--- Maintained by Vim <Codex>
--- Original addon : Rift Meter by Vince (http://www.curse.com/addons/rift/rift-meter)

local RM = Apollo.GetAddon("VortexMeter")
local L = RM.l

function RM.ConfigInit()
	local window = RM.configWindow
	
	if not window then
		RM.configWindow = { visible = false }
		window = RM.configWindow
		
		window.base = Apollo.LoadForm(RM.xmlMainDoc, "ConfigForm", nil, RM)
		local anchors = {window.base:GetAnchorOffsets()}
		window.base:SetAnchorOffsets(
		(Apollo.GetDisplaySize().nWidth - 350) / 2,
		(Apollo.GetDisplaySize().nHeight - 280) / 2,
		(Apollo.GetDisplaySize().nWidth - 350) / 2 + anchors[3],
		(Apollo.GetDisplaySize().nHeight - 280) / 2 + anchors[4])
		
		window.opacity = window.base:FindChild("OpacityBackground")
		window.opacity:SetOpacity(0.8)
		
		window.tabs = {}
		window.tabs[1] = window.base:FindChild("TabList:Tab1:TabBackground")
		window.tabs[2] = window.base:FindChild("TabList:Tab2:TabBackground")
		window.tabs[3] = window.base:FindChild("TabList:Tab3:TabBackground")
		window.currenttab = 1
		
		window.tabwindows = {}
		window.tabwindows[1] = window.base:FindChild("TabWindow1")
		window.tabwindows[2] = window.base:FindChild("TabWindow2")
		window.tabwindows[3] = window.base:FindChild("TabWindow3")
		
		window.tabwindows[window.currenttab]:Show(true)
		window.tabs[window.currenttab]:SetOpacity(0.9)
		for i = 2, #window.tabs do
			window.tabs[i]:SetOpacity(0.2)
			window.tabwindows[i]:Show(false)
		end
		
		-- Tab 1
		window.lockbutton = window.base:FindChild("LockButton")
		window.tooltipsbutton = window.base:FindChild("TooltipsButton")
		window.selfbutton = window.base:FindChild("SelfButton")
		window.onlybossbutton = window.base:FindChild("OnlyBossButton")
		window.logothersbutton = window.base:FindChild("LogOthersButton")
		window.percentbutton = window.base:FindChild("ShowPercentButton")
		window.absbutton = window.base:FindChild("ShowAbsButton")
		window.rankbutton = window.base:FindChild("ShowRankButton")
		window.shortbutton = window.base:FindChild("ShowShortButton")
		
		-- Tab 2
		window.classcolors = {}
		--window.base:FindChild("TabWindow2:WarriorColorPicker:Color"):SetColor()
		--window.base:FindChild("TabWindow2:EngineerColorPicker:Color") = window.settings.classColors[GameLib.CodeEnumClass.Engineer]
		--window.base:FindChild("TabWindow2:EngineerColorPicker:Color") = window.settings.classColors[GameLib.CodeEnumClass.Engineer]
		--window.base:FindChild("TabWindow2:EngineerColorPicker:Color") = window.settings.classColors[GameLib.CodeEnumClass.Engineer]
		--window.base:FindChild("TabWindow2:EngineerColorPicker:Color") = window.settings.classColors[GameLib.CodeEnumClass.Engineer]
		--window.base:FindChild("TabWindow2:EngineerColorPicker:Color") = window.settings.classColors[GameLib.CodeEnumClass.Engineer]
		
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.Magic] = {0.5, 0.1, 0.8}
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.Tech] = {0.2, 0.6, 0.1}
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.Physical] = {0.6, 0.6, 0.6}
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.HealShields] = {0.1, 0.5, 0.7}
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.Heal] = {0, 0.8, 0}
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.Fall] = {0.6, 0.6, 0.6}
		--VortexMeter.settings.abilityTypeColors[GameLib.CodeEnumDamageType.Suffocate] = {0.6, 0.6, 0.6}
		
		-- Tab 3
		window.opacityslider = window.base:FindChild("TransparencySlider")
		window.opacityslider:SetValue(RM.settings.opacity * 10)
		window.opacitytext = window.base:FindChild("TransparencyValue")
		window.opacitytext:SetText(RM.settings.opacity)
		
		window.updateslider = window.base:FindChild("UpdateRateSlider")
		window.updateslider:SetValue((RM.settings.updaterate / 5) - 0.1)
		window.updatetext = window.base:FindChild("UpdateRateValue")
		window.updatetext:SetText(RM.settings.updaterate)
		
		window.mousetransparancyslider = window.base:FindChild("MouseTransparancySlider")
		window.mousetransparancyslider:SetValue((RM.settings.mousetransparancy / 10))
		window.mousetransparancytext = window.base:FindChild("MouseTransparancyValue")
		window.mousetransparancytext:SetText(RM.settings.mousetransparancy)
		
	end
	
	window.lockbutton:SetCheck(RM.settings.lock)
	window.tooltipsbutton:SetCheck(RM.settings.tooltips)
	window.selfbutton:SetCheck(RM.settings.alwaysShowPlayer)
	window.onlybossbutton:SetCheck(RM.settings.showOnlyBoss)
	window.logothersbutton:SetCheck(not Apollo.GetConsoleVariable("cmbtlog.disableOtherPlayers"))
	window.percentbutton:SetCheck(RM.settings.showPercent)
	window.absbutton:SetCheck(RM.settings.showAbsolute)
	window.rankbutton:SetCheck(RM.settings.showRankNumber)
	window.shortbutton:SetCheck(RM.settings.showShortNumber)
	
	window.base:Show(not window.visible)
	window.visible = not window.visible
end

function RM:OnConfigTabEnter(wndHandler, wndControl, x, y)
	if wndControl ~= RM.configWindow.tabs[RM.configWindow.currenttab] then
		wndControl:SetOpacity(0.6)
	end
end

function RM:OnConfigTabExit(wndHandler, wndControl, x, y)
	if wndControl ~= RM.configWindow.tabs[RM.configWindow.currenttab] then
		wndControl:SetOpacity(0.2)
	end
end

function RM:OnConfigButtonClose(wndHandler, wndControl, eMouseButton)
	RM.configWindow.base:Show(false)
	RM.configWindow.visible = false
end

function RM:OnConfigTabPress(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	for i = 1, #RM.configWindow.tabs do
		if RM.configWindow.tabs[i] == wndControl and i ~= RM.configWindow.currenttab then
			for i = 1, #RM.configWindow.tabs do
				RM.configWindow.tabs[i]:SetOpacity(0.2)
				RM.configWindow.tabwindows[i]:Show(false)
			end
			
			RM.configWindow.currenttab = i
			RM.configWindow.tabwindows[RM.configWindow.currenttab]:Show(true)
			RM.configWindow.tabs[RM.configWindow.currenttab]:SetOpacity(0.9)
			
			break
		end
	end
end

function RM:OnConfigHeaderButtonDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = RM.configWindow

	if eMouseButton == 0 then
		window.pressed = true
		local mouse = Apollo.GetMouse()
		window.mouseStartX = mouse.x
		window.mouseStartY = mouse.y
		
		local anchor = {window.base:GetAnchorOffsets()}
		window.attrStartX = anchor[1]
		window.attrStartY = anchor[2]
	end
end

function RM:OnConfigHeaderButtonUp(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = RM.configWindow
	
	if eMouseButton == 0 then
		window.pressed = false
	end
end

function RM:OnConfigHeaderMouseMove(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	local window = RM.configWindow
	
	if window.pressed then
		local mouse = Apollo.GetMouse()
		local x = mouse.x - window.mouseStartX + window.attrStartX
		local y = mouse.y - window.mouseStartY + window.attrStartY
		
		local anchor = {window.base:GetAnchorOffsets()}
		window.base:SetAnchorOffsets(x, y, x + anchor[3] - anchor[1], y + anchor[4] - anchor[2])
	end
end

function RM:OnConfigClassColorEnter(wndHandler, wndControl, x, y)
	if wndControl == wndHandler then
		wndControl:SetOpacity(0.7)
	end
end

function RM:OnConfigClassColorExit(wndHandler, wndControl, x, y)
	if wndControl == wndHandler then
		wndControl:SetOpacity(1)
	end
end

function RM:OnConfigClassColorPress(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY)
	for key, frame in pairs(RM.configWindow.classcolors) do
		if wndControl == frame then
			break
		end
	end
end

function RM:OnConfigLockButton(wndHandler, wndControl, eMouseButton)
	RM.settings.lock = not RM.settings.lock
	RM.UI.ShowResizer(not RM.settings.lock)
end

function RM:OnConfigTooltipsButton(wndHandler, wndControl, eMouseButton)
	RM.settings.tooltips = not RM.settings.tooltips
end

function RM:OnConfigSelfButton(wndHandler, wndControl, eMouseButton)
	RM.settings.alwaysShowPlayer = not RM.settings.alwaysShowPlayer
end

function RM:OnConfigOnlyBossButton(wndHandler, wndControl, eMouseButton)
	RM.settings.showOnlyBoss = not RM.settings.showOnlyBoss
end

function RM:OnConfigLogOthersButton(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("cmbtlog.disableOtherPlayers", not wndHandler:IsChecked())
end

function RM:OnConfigPercentButton(wndHandler, wndControl, eMouseButton)
	RM.settings.showPercent = not RM.settings.showPercent
end

function RM:OnConfigAbsButton(wndHandler, wndControl, eMouseButton)
	RM.settings.showAbsolute = not RM.settings.showAbsolute
end

function RM:OnConfigRankButton(wndHandler, wndControl, eMouseButton)
	RM.settings.showRankNumber = not RM.settings.showRankNumber
end

function RM:OnConfigShortButton(wndHandler, wndControl, eMouseButton)
	RM.settings.showShortNumber = not RM.settings.showShortNumber
end

function RM:OnOpacitySliderChanged(wndHandler, wndControl, fNewValue, fOldValue)
	RM.configWindow.opacitytext:SetText(fNewValue / 10)
	RM.settings.opacity = fNewValue / 10
	RM.Windows[1].frames.opacitybackground:SetOpacity(RM.settings.opacity)
end

function RM:OnUpdateRateSliderChanged(wndHandler, wndControl, fNewValue, fOldValue)
	RM.configWindow.updatetext:SetText(0.1 + (fNewValue / 5))
	RM.settings.updaterate = 0.1 + (fNewValue / 5)
	RM.timerPulse:Set(RM.settings.updaterate, true, "Update", self)
end

function RM:OnMouseTransparancySliderChanged(wndHandler, wndControl, fNewValue, fOldValue)
	RM.configWindow.mousetransparancytext:SetText(fNewValue / 10)
	RM.settings.mousetransparancy = (fNewValue / 10)
	window.frames.header:SetOpacity(RM.settings.mousetransparancy)
	window.frames.footer:SetOpacity(RM.settings.mousetransparancy)
end
