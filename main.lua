local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local Screen = require("device").screen
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local time = require("ui/time")
local _ = require("gettext")
local T = require("ffi/util").template

local REFRESH_MODE = "[ui]"
local MODE_SECONDS = "seconds"
local MODE_MILLISECONDS = "milliseconds"
local STYLE_DOT = "dot"
local STYLE_HIDDEN = "hidden"
local STYLE_CLOCK = "clock"
local CORNER_TOP_RIGHT = "top_right"
local CORNER_TOP_LEFT = "top_left"

local ClockWidget = Widget:extend{
    name = "einkfixer_clock",
    padding = nil,
    face = nil,
    fixed_size = nil,
    text_widget = nil,
    show_milliseconds = false,
}

function ClockWidget:init()
    self.padding = self.padding or Screen:scaleBySize(1)
    self.face = self.face
        or Font:getFace("smallinfont", 9)
        or Font:getFace("infont", 9)
        or Font:getFace("smallinfofont", 9)
        or Font:getFace("cfont", 9)
    self.text_widget = TextWidget:new{
        text = self.show_milliseconds and "88:88:88.888" or "88:88:88",
        face = self.face,
        fgcolor = Blitbuffer.COLOR_BLACK,
        padding = 0,
    }
    local text_size = self.text_widget:getSize()
    self.fixed_size = Geom:new{
        x = 0,
        y = 0,
        w = text_size.w + self.padding * 2,
        h = text_size.h + self.padding * 2,
    }
end

function ClockWidget:getSize()
    return self.fixed_size
end

function ClockWidget:setText(text)
    self.text_widget:setText(text)
end

function ClockWidget:paintTo(bb, x, y)
    local size = self:getSize()
    local text_size = self.text_widget:getSize()
    bb:paintRect(x, y, size.w, size.h, Blitbuffer.COLOR_WHITE)
    self.text_widget:paintTo(bb, x + size.w - self.padding - text_size.w, y + self.padding)
    self.dimen = Geom:new{x = x, y = y, w = size.w, h = size.h}
end

function ClockWidget:free()
    if self.text_widget then
        self.text_widget:free()
    end
end

local PointWidget = Widget:extend{
    name = "einkfixer_point",
    style = STYLE_DOT,
    size = nil,
    fixed_size = nil,
    on = false,
}

function PointWidget:init()
    self.size = self.size or (self.style == STYLE_HIDDEN and 1 or Screen:scaleBySize(4))
    self.fixed_size = Geom:new{x = 0, y = 0, w = self.size, h = self.size}
end

function PointWidget:getSize()
    return self.fixed_size
end

function PointWidget:step()
    self.on = not self.on
end

function PointWidget:paintTo(bb, x, y)
    local size = self:getSize()
    if self.style ~= STYLE_HIDDEN then
        bb:paintRect(x, y, size.w, size.h, self.on and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE)
    end
    self.dimen = Geom:new{x = x, y = y, w = size.w, h = size.h}
end

local EinkFixer = WidgetContainer:extend{
    name = "einkfixer",
    is_doc_only = false,
    enabled = nil,
    mode = nil,
    style = nil,
    corner = nil,
    millisecond_interval_ms = 100,
    task = nil,
    scheduled = false,
    refresh_widget = nil,
    last_region = nil,
}

function EinkFixer:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/einkfixer.lua")
    self.enabled = self.settings:nilOrTrue("enabled")
    self.mode = self.settings:readSetting("mode", MODE_SECONDS)
    self.style = self.settings:readSetting("style", STYLE_DOT)
    self.corner = self.settings:readSetting("corner", CORNER_TOP_RIGHT)
    self.millisecond_interval_ms = self.settings:readSetting("millisecond_interval_ms", 100)
    self.task = function()
        self:_tick()
    end
    self.ui.menu:registerToMainMenu(self)
    if self.enabled then
        self:_start()
    end
end

function EinkFixer:_formatTime()
    local now = time.realtime()
    local sec, usec = time.split_s_us(now)
    local clock = os.date("%H:%M:%S", sec)
    if self.mode == MODE_MILLISECONDS then
        return string.format("%s.%03d", clock, math.floor(usec / 1000))
    end
    return clock
end

function EinkFixer:_getRefreshWidget()
    if not self.refresh_widget then
        if self.style == STYLE_CLOCK then
            self.refresh_widget = ClockWidget:new{
                show_milliseconds = self.mode == MODE_MILLISECONDS,
            }
        else
            self.refresh_widget = PointWidget:new{
                style = self.style,
            }
        end
    end
    return self.refresh_widget
end

function EinkFixer:_resetRefreshWidget()
    if self.refresh_widget and self.refresh_widget.free then
        self.refresh_widget:free()
    end
    self.refresh_widget = nil
end

function EinkFixer:_restoreLastRegion()
    if self.last_region then
        UIManager:setDirty("all", REFRESH_MODE, self.last_region)
        self.last_region = nil
    end
end

function EinkFixer:_getRegion()
    local widget = self:_getRefreshWidget()
    local size = widget:getSize()
    local margin = Screen:scaleBySize(1)
    return Geom:new{
        x = self.corner == CORNER_TOP_LEFT and margin or Screen:getWidth() - size.w - margin,
        y = margin,
        w = size.w,
        h = size.h,
    }
end

function EinkFixer:_canPaintNow()
    local stack = UIManager._window_stack
    local top = stack and stack[#stack]
    if not top then
        return false
    end
    local ui = self.ui
    return top.widget == ui
        or (ui and top.widget == ui.file_chooser)
end

function EinkFixer:_paintFixer()
    if not self:_canPaintNow() then
        return
    end
    local widget = self:_getRefreshWidget()
    local region = self:_getRegion()
    if widget.setText then
        widget:setText(self:_formatTime())
    elseif widget.step then
        widget:step()
    end
    Screen:beforePaint()
    UIManager:widgetRepaint(widget, region.x, region.y)
    self:_refreshRegion(region)
    Screen:afterPaint()
    self.last_region = region
end

function EinkFixer:_nextDelay()
    if self.mode == MODE_MILLISECONDS then
        local interval = math.max(10, tonumber(self.millisecond_interval_ms) or 100)
        local now_ms = time.to_ms(time.realtime())
        local delay_ms = interval - (now_ms % interval)
        return math.max(delay_ms / 1000, 0.001)
    end

    local _sec, usec = time.split_s_us(time.realtime())
    return math.max((1000000 - usec) / 1000000, 0.001)
end

function EinkFixer:_schedule(delay)
    if not self.enabled then
        return
    end
    UIManager:scheduleIn(delay or self:_nextDelay(), self.task)
    self.scheduled = true
end

function EinkFixer:_unschedule()
    if self.scheduled then
        UIManager:unschedule(self.task)
        self.scheduled = false
    end
end

function EinkFixer:_start()
    self:_unschedule()
    self:_paintFixer()
    self:_schedule()
end

function EinkFixer:_refreshRegion(region)
    if Screen.refreshNoMergeUI then
        Screen:refreshNoMergeUI(region.x, region.y, region.w, region.h)
    elseif Screen.refreshUI then
        Screen:refreshUI(region.x, region.y, region.w, region.h)
    else
        UIManager:setDirty(nil, REFRESH_MODE, region)
    end
end

function EinkFixer:_stop(restore_region)
    self:_unschedule()
    if restore_region then
        self:_restoreLastRegion()
    end
end

function EinkFixer:_tick()
    self.scheduled = false
    if not self.enabled then
        return
    end
    self:_paintFixer()
    self:_schedule()
end

function EinkFixer:setEnabled(enabled)
    self.enabled = enabled and true or false
    self.settings:saveSetting("enabled", self.enabled)
    if self.enabled then
        self:_start()
    else
        self:_stop(true)
    end
end

function EinkFixer:setMode(mode)
    if mode ~= MODE_SECONDS and mode ~= MODE_MILLISECONDS then
        mode = MODE_SECONDS
    end
    self.mode = mode
    self.settings:saveSetting("mode", mode)
    if self.style == STYLE_CLOCK then
        self:_resetRefreshWidget()
    end
    if self.enabled then
        self:_start()
    end
end

function EinkFixer:setStyle(style)
    if style ~= STYLE_DOT and style ~= STYLE_HIDDEN and style ~= STYLE_CLOCK then
        style = STYLE_DOT
    end
    self:_restoreLastRegion()
    self.style = style
    self.settings:saveSetting("style", style)
    self:_resetRefreshWidget()
    if self.enabled then
        self:_start()
    end
end

function EinkFixer:setCorner(corner)
    if corner ~= CORNER_TOP_LEFT and corner ~= CORNER_TOP_RIGHT then
        corner = CORNER_TOP_RIGHT
    end
    self:_restoreLastRegion()
    self.corner = corner
    self.settings:saveSetting("corner", corner)
    if self.enabled then
        self:_start()
    end
end

function EinkFixer:setMillisecondInterval(interval_ms)
    self.millisecond_interval_ms = interval_ms
    self.settings:saveSetting("millisecond_interval_ms", interval_ms)
    if self.enabled and self.mode == MODE_MILLISECONDS then
        self:_start()
    end
end

function EinkFixer:onSuspend()
    self:_unschedule()
end

function EinkFixer:onResume()
    if self.enabled then
        self:_start()
    end
end

function EinkFixer:onScreenResize()
    if self.enabled then
        self.last_region = nil
        self:_start()
    end
end

function EinkFixer:onSetRotationMode()
    if self.enabled then
        self.last_region = nil
        self:_start()
    end
end

function EinkFixer:onCloseWidget()
    self:_stop(false)
    self:_resetRefreshWidget()
end

function EinkFixer:onFlushSettings()
    self.settings:flush()
end

function EinkFixer:addToMainMenu(menu_items)
    local mode_text = {
        [MODE_SECONDS] = _("seconds"),
        [MODE_MILLISECONDS] = _("milliseconds"),
    }
    local style_text = {
        [STYLE_DOT] = _("blinking dot"),
        [STYLE_HIDDEN] = _("hidden"),
        [STYLE_CLOCK] = _("small clock"),
    }

    menu_items.einkfixer = {
        sorting_hint = "more_tools",
        text_func = function()
            return self.enabled
                and T(_("E-ink Fixer: %1"), style_text[self.style] or style_text[STYLE_DOT])
                or _("E-ink Fixer")
        end,
        checked_func = function()
            return self.enabled
        end,
        sub_item_table = {
            {
                text_func = function()
                    return self.enabled and _("Disable") or _("Enable")
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    self:setEnabled(not self.enabled)
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                    UIManager:show(InfoMessage:new{
                        text = self.enabled and _("E-ink Fixer enabled") or _("E-ink Fixer disabled"),
                        timeout = 2,
                    })
                end,
            },
            {
                text = _("Style"),
                sub_item_table = {
                    {
                        text = _("Blinking dot"),
                        radio = true,
                        checked_func = function()
                            return self.style == STYLE_DOT
                        end,
                        callback = function()
                            self:setStyle(STYLE_DOT)
                        end,
                    },
                    {
                        text = _("Hidden refresh area"),
                        radio = true,
                        checked_func = function()
                            return self.style == STYLE_HIDDEN
                        end,
                        callback = function()
                            self:setStyle(STYLE_HIDDEN)
                        end,
                    },
                    {
                        text = _("Small clock"),
                        radio = true,
                        checked_func = function()
                            return self.style == STYLE_CLOCK
                        end,
                        callback = function()
                            self:setStyle(STYLE_CLOCK)
                        end,
                    },
                },
            },
            {
                text = _("Corner"),
                sub_item_table = {
                    {
                        text = _("Top right"),
                        radio = true,
                        checked_func = function()
                            return self.corner == CORNER_TOP_RIGHT
                        end,
                        callback = function()
                            self:setCorner(CORNER_TOP_RIGHT)
                        end,
                    },
                    {
                        text = _("Top left"),
                        radio = true,
                        checked_func = function()
                            return self.corner == CORNER_TOP_LEFT
                        end,
                        callback = function()
                            self:setCorner(CORNER_TOP_LEFT)
                        end,
                    },
                },
            },
            {
                text = _("Show seconds"),
                radio = true,
                checked_func = function()
                    return self.mode == MODE_SECONDS
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    self:setMode(MODE_SECONDS)
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
            },
            {
                text = _("Show milliseconds"),
                radio = true,
                checked_func = function()
                    return self.mode == MODE_MILLISECONDS
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    self:setMode(MODE_MILLISECONDS)
                    if touchmenu_instance then
                        touchmenu_instance:updateItems()
                    end
                end,
            },
            {
                text_func = function()
                    return T(_("Millisecond refresh: %1 ms"), self.millisecond_interval_ms)
                end,
                enabled_func = function()
                    return self.mode == MODE_MILLISECONDS
                end,
                sub_item_table = {
                    {
                        text = _("50 ms"),
                        radio = true,
                        checked_func = function()
                            return self.millisecond_interval_ms == 50
                        end,
                        callback = function()
                            self:setMillisecondInterval(50)
                        end,
                    },
                    {
                        text = _("100 ms"),
                        radio = true,
                        checked_func = function()
                            return self.millisecond_interval_ms == 100
                        end,
                        callback = function()
                            self:setMillisecondInterval(100)
                        end,
                    },
                    {
                        text = _("250 ms"),
                        radio = true,
                        checked_func = function()
                            return self.millisecond_interval_ms == 250
                        end,
                        callback = function()
                            self:setMillisecondInterval(250)
                        end,
                    },
                    {
                        text = _("500 ms"),
                        radio = true,
                        checked_func = function()
                            return self.millisecond_interval_ms == 500
                        end,
                        callback = function()
                            self:setMillisecondInterval(500)
                        end,
                    },
                },
            },
        },
    }
end

return EinkFixer
