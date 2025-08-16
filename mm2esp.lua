--[[
    Severe UI Framework
    - v5.7 (Definitive): Final stability update. Removed composite ColorPicker to resolve all input conflicts.
    - This version is streamlined for maximum reliability.
]]

-- Forward-declare classes
local Library, UI, Tab, Section, Button, Toggle, Slider, Label = {}, {}, {}, {}, {}, {}, {}, {}

-- A utility table for validating inputs
local Validate = {}
function Validate.Vector2(vec, default) if type(vec) == "table" and type(vec.x) == "number" and type(vec.y) == "number" then return vec end return default or {x = 0, y = 0} end

-- Centralized theme table
local Theme = {
    Accent = {100, 118, 255}, Accent_Hover = {130, 148, 255}, Background = {45, 45, 52}, TitleBar = {35, 35, 42},
    Section = {55, 55, 62}, SectionHeader = {65, 65, 72}, Element = {75, 75, 82}, Element_Hover = {95, 95, 102},
    Border = {25, 25, 30}, Text = {230, 230, 230}, Text_Dark = {150, 150, 150},
    Rounding = 4, Font_Size_Normal = 14, Font_Size_Small = 12
}

-- Track UI state
local ActiveUI, ActiveSlider, ActiveScroll, isDragging = nil, nil, nil, false
local dragOffset, scrollDragOffset = {x = 0, y = 0}, {y = 0}

-------------------------------------------------------------------
-- ## Class Definitions
-------------------------------------------------------------------
Library.__index = Library
function Library:Create(properties)
    properties = properties or {}
    local self = setmetatable({}, UI); self.Name = properties.Name or "UI Framework"; self.Position = Validate.Vector2(properties.Position, {x=200, y=200}); self.Size = Validate.Vector2(properties.Size, {x=550, y=450}); self.Tabs, self.ActiveTab = {}, nil
    self.Drawings = { Body=Drawing.new("Square"), TitleBar=Drawing.new("Square"), TitleText=Drawing.new("Text"), TooltipBody=Drawing.new("Square"), TooltipText=Drawing.new("Text") }
    ActiveUI = self; return self
end

UI.__index = UI
function UI:Tab(properties)
    local tab = setmetatable({}, Tab); tab.Name = properties.Name or "Tab"; tab.Parent = self; tab.LeftSections, tab.RightSections = {}, {}; tab.Drawings = { Button = Drawing.new("Square"), Text = Drawing.new("Text") }
    table.insert(self.Tabs, tab); if not self.ActiveTab then self.ActiveTab = tab end; return tab
end

Tab.__index = Tab
function Tab:Section(properties)
    local section = setmetatable({}, Section); section.Name = properties.Name or "Section"; section.Side = properties.Side or "Left"; section.Parent = self; section.Elements, section.NextElementY = {}, 40
    section.Scrollable, section.ScrollOffset, section.CanvasHeight = false, 0, 0
    section.Drawings = { Outline=Drawing.new("Square"), Header=Drawing.new("Square"), Body=Drawing.new("Square"), Title=Drawing.new("Text"), ScrollTrack=Drawing.new("Square"), ScrollThumb=Drawing.new("Square") }
    if section.Side == "Left" then table.insert(self.LeftSections, section) else table.insert(self.RightSections, section) end; return section
end

Section.__index = Section
local elementSpacing = 18
function Section:Label(properties)
    local el = setmetatable({}, Label); el.Type, el.Parent, el.Name, el.Tooltip, el.Size, el.Position = "Label", self, properties.Name or "Label", properties.Tooltip, {x=220, y=18}, {x=15, y=self.NextElementY}
    el.Drawings = { Text=Drawing.new("Text") }; self.NextElementY = el.Position.y + el.Size.y + elementSpacing; table.insert(self.Elements, el); return el
end
function Section:Button(properties)
    local el = setmetatable({}, Button); el.Type, el.Parent, el.Name, el.Tooltip, el.Callback, el.Size, el.Position = "Button", self, properties.Name or "Button", properties.Tooltip, properties.Callback or function() end, {x=220, y=28}, {x=15, y=self.NextElementY}
    el.Drawings = { Body=Drawing.new("Square"), Text=Drawing.new("Text") }; self.NextElementY = el.Position.y + el.Size.y + elementSpacing; table.insert(self.Elements, el); return el
end
function Section:Toggle(properties)
    local el = setmetatable({}, Toggle); el.Type, el.Parent, el.Name, el.Tooltip, el.State, el.Callback, el.Size, el.Position = "Toggle", self, properties.Name or "Toggle", properties.Tooltip, properties.Default==true, properties.Callback or function(s) end, {x=18, y=18}, {x=15, y=self.NextElementY}
    el.Drawings = { Box=Drawing.new("Square"), Check=Drawing.new("Square"), Text=Drawing.new("Text") }; self.NextElementY = el.Position.y + el.Size.y + elementSpacing; table.insert(self.Elements, el); return el
end
function Section:Slider(properties)
    local el = setmetatable({}, Slider); el.Type, el.Parent, el.Name, el.Tooltip, el.Min, el.Max, el.Default, el.Increment, el.Units, el.Callback, el.Value, el.Size, el.Position = "Slider", self, properties.Name or "Slider", properties.Tooltip, properties.Min or 0, properties.Max or 100, properties.Default or 50, properties.Increment or 1, properties.Units or "", properties.Callback or function(v) end, properties.Default or 50, {x=220, y=12}, {x=15, y=self.NextElementY+18}
    el.Drawings = { Bar=Drawing.new("Square"), Thumb=Drawing.new("Square"), Text=Drawing.new("Text"), Value=Drawing.new("Text") }; self.NextElementY = el.Position.y + el.Size.y + elementSpacing; table.insert(self.Elements, el); return el
end

local function isMouseInBounds(mousePos, elementPos, elementSize) return mousePos.x >= elementPos.x and mousePos.x <= elementPos.x + elementSize.x and mousePos.y >= elementPos.y and mousePos.y <= elementPos.y + elementSize.y end

-------------------------------------------------------------------
-- ## Core Render & Update Loop
-------------------------------------------------------------------
spawn(function()
    local hoveredTooltip = nil
    while wait() do
        if not ActiveUI then continue end
        hoveredTooltip = nil; ActiveUI.Drawings.TooltipBody.Visible, ActiveUI.Drawings.TooltipText.Visible = false, false
        for _, tab in ipairs(ActiveUI.Tabs) do
            tab.Drawings.Button.Visible, tab.Drawings.Text.Visible = false, false
            for _, section in ipairs(tab.LeftSections) do for _, d in pairs(section.Drawings) do d.Visible = false end for _, e in ipairs(section.Elements) do for _, d in pairs(e.Drawings) do d.Visible = false end end end
            for _, section in ipairs(tab.RightSections) do for _, d in pairs(section.Drawings) do d.Visible = false end for _, e in ipairs(section.Elements) do for _, d in pairs(e.Drawings) do d.Visible = false end end end
        end

        local mousePos, leftClicked, leftPressed = getmouseposition(), isleftclicked(), isleftpressed()
        local titleBarPos, titleBarSize = ActiveUI.Position, {x = ActiveUI.Size.x, y = 30}
        if isMouseInBounds(mousePos, titleBarPos, titleBarSize) and leftClicked and not ActiveScroll and not ActiveSlider then isDragging = true; dragOffset = {x = mousePos.x - ActiveUI.Position.x, y = mousePos.y - ActiveUI.Position.y} end
        if not leftPressed then isDragging, ActiveScroll, ActiveSlider = false, nil, nil end
        if isDragging then ActiveUI.Position = {x = mousePos.x - dragOffset.x, y = mousePos.y - dragOffset.y} end
        
        local uiPos, uiSize = ActiveUI.Position, ActiveUI.Size; local uiDrawings = ActiveUI.Drawings
        uiDrawings.TitleBar.ZIndex, uiDrawings.TitleBar.Visible, uiDrawings.TitleBar.Position, uiDrawings.TitleBar.Size, uiDrawings.TitleBar.Color, uiDrawings.TitleBar.Filled, uiDrawings.TitleBar.Rounding = 0,true,uiPos,titleBarSize,Theme.TitleBar,true,Theme.Rounding
        uiDrawings.Body.ZIndex, uiDrawings.Body.Visible, uiDrawings.Body.Position, uiDrawings.Body.Size, uiDrawings.Body.Color, uiDrawings.Body.Filled, uiDrawings.Body.Rounding = 0,true,{x=uiPos.x, y=uiPos.y+30},{x=uiSize.x, y=uiSize.y-30},Theme.Background,true,Theme.Rounding
        uiDrawings.TitleText.ZIndex, uiDrawings.TitleText.Visible, uiDrawings.TitleText.Text, uiDrawings.TitleText.Size, uiDrawings.TitleText.Position, uiDrawings.TitleText.Color = 1,true,ActiveUI.Name,Theme.Font_Size_Normal,{x=uiPos.x+10, y=uiPos.y+7},Theme.Text

        local tabOffset = 10
        for _, tab in ipairs(ActiveUI.Tabs) do
            local tabPos, tabSize = {x = uiPos.x + tabOffset, y = uiPos.y + 38}, {x = 85, y = 28}
            if isMouseInBounds(mousePos, tabPos, tabSize) and leftClicked and ActiveUI.ActiveTab ~= tab then
                ActiveUI.ActiveTab = tab; ActiveSlider, ActiveScroll, isDragging = nil, nil, false
            end
            tab.Drawings.Button.Visible=true; tab.Drawings.Button.ZIndex, tab.Drawings.Button.Position, tab.Drawings.Button.Size, tab.Drawings.Button.Filled, tab.Drawings.Button.Rounding = 1, tabPos, tabSize, true, Theme.Rounding
            tab.Drawings.Button.Color = (ActiveUI.ActiveTab == tab and Theme.Section or (isMouseInBounds(mousePos, tabPos, tabSize) and Theme.Element_Hover or Theme.Element))
            tab.Drawings.Text.Visible=true; tab.Drawings.Text.ZIndex, tab.Drawings.Text.Text, tab.Drawings.Text.Center, tab.Drawings.Text.Size, tab.Drawings.Text.Color = 2, tab.Name, true, Theme.Font_Size_Normal, Theme.Text
            tab.Drawings.Text.Position = {x=tabPos.x+tabSize.x/2, y=tabPos.y+(tabSize.y/2)-(tab.Drawings.Text.TextBounds.y/2)}; tabOffset = tabOffset + tabSize.x + 10
        end
        
        if ActiveUI.ActiveTab then
            local contentPos = {x = uiPos.x + 15, y = uiPos.y + 80}; local sections = {ActiveUI.ActiveTab.LeftSections, ActiveUI.ActiveTab.RightSections}
            for i, sectionList in ipairs(sections) do
                local sectionX, sectionY = (i == 1) and contentPos.x or contentPos.x + 265, contentPos.y
                for _, section in ipairs(sectionList) do
                    local headerHeight, viewHeight = 30, (uiPos.y + uiSize.y) - sectionY - 15
                    section.CanvasHeight, section.ViewHeight = section.NextElementY, viewHeight; section.Scrollable = section.CanvasHeight > section.ViewHeight
                    
                    local anElementWasClicked = false
                    if leftClicked then
                        for _, element in ipairs(section.Elements) do
                            local elemPos = {x = sectionX + element.Position.x, y = sectionY + element.Position.y - section.ScrollOffset}
                            if isMouseInBounds(mousePos, elemPos, element.Size) then anElementWasClicked = true; break end
                        end
                    end
                    
                    local scrollAreaPos = {x=sectionX, y=sectionY+headerHeight}; local scrollAreaSize = {x=250, y=viewHeight-headerHeight}
                    if not anElementWasClicked and isMouseInBounds(mousePos, scrollAreaPos, scrollAreaSize) and leftClicked and not isDragging and not ActiveSlider then
                        ActiveScroll = section; scrollDragOffset.y = mousePos.y + section.ScrollOffset
                    end
                    if ActiveScroll == section then section.ScrollOffset = scrollDragOffset.y - mousePos.y end
                    section.ScrollOffset = section.Scrollable and math.clamp(section.ScrollOffset, 0, section.CanvasHeight - section.ViewHeight) or 0
                    
                    local sDraw = section.Drawings
                    sDraw.Outline.Visible=true; sDraw.Outline.ZIndex,sDraw.Outline.Position,sDraw.Outline.Size,sDraw.Outline.Color,sDraw.Outline.Filled,sDraw.Outline.Rounding=2,{x=sectionX-1,y=sectionY-1},{x=252,y=viewHeight+2},Theme.Border,true,Theme.Rounding
                    sDraw.Body.Visible=true; sDraw.Body.ZIndex,sDraw.Body.Position,sDraw.Body.Size,sDraw.Body.Color,sDraw.Body.Filled,sDraw.Body.Rounding=3,{x=sectionX,y=sectionY},{x=250,y=viewHeight},Theme.Section,true,Theme.Rounding
                    sDraw.Header.Visible=true; sDraw.Header.ZIndex,sDraw.Header.Position,sDraw.Header.Size,sDraw.Header.Color,sDraw.Header.Filled,sDraw.Header.Rounding=4,{x=sectionX,y=sectionY},{x=250,y=headerHeight},Theme.SectionHeader,true,Theme.Rounding
                    sDraw.Title.Visible=true; sDraw.Title.ZIndex,sDraw.Title.Text,sDraw.Title.Size,sDraw.Title.Position,sDraw.Title.Color=5,section.Name,Theme.Font_Size_Normal,{x=sectionX+10,y=sectionY+7},Theme.Text
                    
                    if section.Scrollable then
                        local trackHeight, trackPos = viewHeight - headerHeight - 10, {x=sectionX+240, y=sectionY+headerHeight+5}; local thumbHeight = math.max(20, trackHeight * (section.ViewHeight / section.CanvasHeight))
                        if section.CanvasHeight > section.ViewHeight then
                            local thumbPosPercentage = section.ScrollOffset / (section.CanvasHeight - section.ViewHeight)
                            local thumbY = trackPos.y + (trackHeight - thumbHeight) * thumbPosPercentage
                            sDraw.ScrollTrack.Visible=true; sDraw.ScrollTrack.ZIndex,sDraw.ScrollTrack.Position,sDraw.ScrollTrack.Size,sDraw.ScrollTrack.Color,sDraw.ScrollTrack.Filled,sDraw.ScrollTrack.Rounding=5,trackPos,{x=5,y=trackHeight},Theme.Element,true,Theme.Rounding
                            sDraw.ScrollThumb.Visible=true; sDraw.ScrollThumb.ZIndex,sDraw.ScrollThumb.Position,sDraw.ScrollThumb.Size,sDraw.ScrollThumb.Color,sDraw.ScrollThumb.Filled,sDraw.ScrollThumb.Rounding=6,{x=trackPos.x,y=thumbY},{x=5,y=thumbHeight},Theme.Accent,true,Theme.Rounding
                        end
                    end
                    for _, element in ipairs(section.Elements) do
                        local elemPos = {x = sectionX + element.Position.x, y = sectionY + element.Position.y - section.ScrollOffset}; local eDraw = element.Drawings
                        local cullBuffer = (element.Type == "Slider" and 30) or (element.Type == "Label" and 0) or element.Size.y
                        if (elemPos.y >= sectionY + headerHeight - cullBuffer) and (elemPos.y < sectionY + viewHeight) then
                            local isHovered = isMouseInBounds(mousePos, elemPos, element.Size)
                            if isHovered and element.Tooltip then hoveredTooltip = element.Tooltip end
                            if element.Type == "Label" then
                                eDraw.Text.Visible=true; eDraw.Text.ZIndex,eDraw.Text.Text,eDraw.Text.Size,eDraw.Text.Position,eDraw.Text.Color=5,element.Name,Theme.Font_Size_Normal,elemPos,Theme.Text
                            elseif element.Type == "Button" then
                                if isHovered and leftClicked and not ActiveScroll then spawn(element.Callback) end
                                eDraw.Body.Visible=true; eDraw.Body.ZIndex,eDraw.Body.Position,eDraw.Body.Size,eDraw.Body.Filled,eDraw.Body.Rounding,eDraw.Body.Color=5,elemPos,element.Size,true,Theme.Rounding,isHovered and Theme.Accent_Hover or Theme.Accent
                                eDraw.Text.Visible=true; eDraw.Text.ZIndex,eDraw.Text.Text,eDraw.Text.Center,eDraw.Text.Size,eDraw.Text.Color,eDraw.Text.Position=6,element.Name,true,Theme.Font_Size_Normal,Theme.Text,{x=elemPos.x+element.Size.x/2,y=elemPos.y+(element.Size.y/2)-(eDraw.Text.TextBounds.y/2)}
                            elseif element.Type == "Toggle" then
                                if isHovered and leftClicked and not ActiveScroll then element.State = not element.State; spawn(function() element.Callback(element.State) end) end
                                eDraw.Box.Visible=true; eDraw.Box.ZIndex,eDraw.Box.Position,eDraw.Box.Size,eDraw.Box.Filled,eDraw.Box.Rounding,eDraw.Box.Color=5,elemPos,element.Size,true,Theme.Rounding,isHovered and Theme.Element_Hover or Theme.Element
                                eDraw.Check.Visible=element.State; eDraw.Check.ZIndex,eDraw.Check.Position,eDraw.Check.Size,eDraw.Check.Filled,eDraw.Check.Rounding,eDraw.Check.Color=6,{x=elemPos.x+4,y=elemPos.y+4},{x=10,y=10},true,Theme.Rounding-1,Theme.Accent
                                eDraw.Text.Visible=true; eDraw.Text.ZIndex,eDraw.Text.Text,eDraw.Text.Size,eDraw.Text.Position,eDraw.Text.Color=6,element.Name,Theme.Font_Size_Normal,{x=elemPos.x+element.Size.x+10,y=elemPos.y},Theme.Text
                            elseif element.Type == "Slider" then
                                if (isHovered or ActiveSlider == element) and leftClicked and not ActiveScroll then ActiveSlider = element end
                                if ActiveSlider == element then
                                    local percent = (mousePos.x - elemPos.x) / element.Size.x; local val = element.Min + (element.Max - element.Min) * percent
                                    val = math.floor(val / element.Increment + 0.5) * element.Increment; element.Value = math.clamp(val, element.Min, element.Max); spawn(function() element.Callback(element.Value) end)
                                end
                                local thumbPercent = (element.Value-element.Min)/(element.Max-element.Min); local thumbPos = {x=elemPos.x+(element.Size.x-12)*thumbPercent,y=elemPos.y}
                                eDraw.Text.Visible=true; eDraw.Text.ZIndex,eDraw.Text.Text,eDraw.Text.Size,eDraw.Text.Position,eDraw.Text.Color=5,element.Name,Theme.Font_Size_Normal,{x=elemPos.x,y=elemPos.y-18},Theme.Text
                                eDraw.Value.Visible=true; eDraw.Value.ZIndex,eDraw.Value.Text,eDraw.Value.Size,eDraw.Value.Position,eDraw.Value.Color=5,tostring(element.Value)..element.Units,Theme.Font_Size_Small,{x=elemPos.x+element.Size.x-eDraw.Value.TextBounds.x,y=elemPos.y-16},Theme.Text_Dark
                                eDraw.Bar.Visible=true; eDraw.Bar.ZIndex,eDraw.Bar.Position,eDraw.Bar.Size,eDraw.Bar.Filled,eDraw.Bar.Rounding,eDraw.Bar.Color=6,elemPos,element.Size,true,Theme.Rounding,Theme.Element
                                eDraw.Thumb.Visible=true; eDraw.Thumb.ZIndex,eDraw.Thumb.Position,eDraw.Thumb.Size,eDraw.Thumb.Filled,eDraw.Thumb.Rounding,eDraw.Thumb.Color=7,thumbPos,{x=12,y=12},true,Theme.Rounding,(isHovered or ActiveSlider == element) and Theme.Accent_Hover or Theme.Accent
                            end
                        end
                    end
                    sectionY = sectionY + viewHeight + 15
                end
            end
        end
        if hoveredTooltip then
            local ttDraw = ActiveUI.Drawings
            ttDraw.TooltipBody.Visible=true; ttDraw.TooltipBody.ZIndex,ttDraw.TooltipBody.Size = 10,{x=#hoveredTooltip*7+10,y=20}
            ttDraw.TooltipBody.Position,ttDraw.TooltipBody.Filled,ttDraw.TooltipBody.Rounding,ttDraw.TooltipBody.Color = {x=mousePos.x+15,y=mousePos.y},true,Theme.Rounding,Theme.TitleBar
            ttDraw.TooltipText.Visible=true; ttDraw.TooltipText.ZIndex,ttDraw.TooltipText.Text,ttDraw.TooltipText.Size,ttDraw.TooltipText.Position,ttDraw.TooltipText.Color = 11,hoveredTooltip,Theme.Font_Size_Small,{x=mousePos.x+20,y=mousePos.y+2},Theme.Text
        end
    end
end)

return Library
