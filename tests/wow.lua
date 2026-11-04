-- A simulated client for the plugin. ElvUI: E with its profile, the UnitFrames module with the player,
-- target and focus frames and their cast bars, the cast bar callbacks ElvUI sets on each
-- (PostCastStart and the rest, colouring the bar through UF:SetStatusBarColor), and LibElvUIPlugin.
-- The game: textures, masks and colours as far as the plugin uses them, the spell calls, the combat
-- log on Classic Era (none on WoW: Forever). NewClient() resets the globals, loads the .toc's files
-- and logs in: ElvUI builds its frames, then initialises the plugin's module.

---@class TestClientOptions
---@field client "era"|"tbc"|"wrath"|"mists"|"retail"|"forever"? default "era"
---@field saved table? the plugin's SavedVariables from an earlier session
---@field noFocus boolean? no focus frame at login (ElvUI's focus frame turned off)
---@field descriptions table<number, string>? spell descriptions by spell ID
---@field noOptions boolean? ElvUI_Options not loaded
---@field locale string? the client's language, default "enUS"; "deDE" words damage "Schaden"
---@field oapDebug boolean? OAP Debug installed: its calls go to client.debugCalls
---@field debugLog boolean? _DebugLog installed (DLAPI): its lines go to client.debugCalls too
---@field debugLevel string? the plugin's OAP Debug setting in the profile

-- What ElvUI colours a cast with, unless the plugin does: its cast colour and its fail colour.
ELVUI_COLOR = { 0.31, 0.41, 0.53 }
ELVUI_FAIL = { 0.78, 0.25, 0.25 }
ELVUI_INTERRUPT = { 0.78, 0.25, 0.25 }

-- What the client returns for a value it hides (issecretvalue says so).
SECRET = setmetatable({}, {
    __tostring = function()
        return "<secret>"
    end,
})

-- The client's school names: one per school, and the few combinations it names.
local SCHOOL_NAMES = {
    [1] = "Physical",
    [2] = "Holy",
    [4] = "Fire",
    [8] = "Nature",
    [16] = "Frost",
    [32] = "Shadow",
    [64] = "Arcane",
    [5] = "Flamestrike",
    [20] = "Frostfire",
    [36] = "Shadowflame",
    [24] = "Froststorm",
    [127] = "Chromatic",
}

---A region: what the plugin calls on a texture, a mask or a frame.
---@param kind string
---@param parent table?
---@return table
local function Region(kind, parent)
    local r = { kind = kind, parent = parent, shown = true, points = {}, alpha = 1, masks = {} }
    function r:Show()
        self.shown = true
    end
    function r:Hide()
        self.shown = false
    end
    function r:IsShown()
        return self.shown
    end
    function r:SetAlpha(a)
        self.alpha = a
    end
    function r:GetAlpha()
        return self.alpha
    end
    function r:ClearAllPoints()
        self.points = {}
    end
    function r:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[point] = { relativeTo, relativePoint, x or 0, y or 0 }
    end
    function r:SetTexture(path)
        self.texture = path
    end
    function r:GetTexture()
        return self.texture
    end
    function r:SetTexCoord(left, right, top, bottom)
        self.texCoord = { left, right, top, bottom }
    end
    function r:SetVertexColor(red, green, blue, alpha)
        self.color = { red, green, blue, alpha or 1 }
        self.gradient = nil
    end
    function r:GetVertexColor()
        return unpack(self.color or { 1, 1, 1, 1 })
    end
    function r:SetGradient(orientation, minColor, maxColor)
        local r1, g1, b1, a1 = minColor:GetRGBA()
        local r2, g2, b2, a2 = maxColor:GetRGBA()
        self.gradient = { orientation, { r1, g1, b1, a1 }, { r2, g2, b2, a2 } }
    end
    function r:AddMaskTexture(mask)
        self.masks[#self.masks + 1] = mask
    end
    function r:CreateTexture(_, layer, _, sublevel)
        local t = Region("Texture", self)
        t.layer, t.sublevel = layer, sublevel
        self.children[#self.children + 1] = t
        return t
    end
    function r:CreateMaskTexture()
        local m = Region("MaskTexture", self)
        self.children[#self.children + 1] = m
        return m
    end
    r.children = {}
    return r
end

---A colour object, as CreateColor makes it.
---@return table
function CreateColor(red, green, blue, alpha)
    local c = {}
    function c:SetRGBA(r2, g2, b2, a2)
        self.r, self.g, self.b, self.a = r2, g2, b2, a2
    end
    function c:GetRGBA()
        return self.r, self.g, self.b, self.a
    end
    c:SetRGBA(red, green, blue, alpha)
    return c
end

---@param t table
---@return table
local function copy(t)
    local c = {}
    for k, v in pairs(t) do
        c[k] = type(v) == "table" and copy(v) or v
    end
    return c
end

---@param opts TestClientOptions?
function NewClient(opts)
    opts = opts or {}
    local kind = opts.client or "era"
    local client = { calls = {}, events = {}, modules = {}, ns = {}, frames = {} }
    client.descriptions = opts.descriptions or {}

    local function record(name, ...)
        client.calls[#client.calls + 1] = { name, ... }
    end
    function client:called(name)
        local found = {}
        for _, call in ipairs(self.calls) do
            if call[1] == name then found[#found + 1] = { unpack(call, 2) } end
        end
        return found
    end

    -- The client's flavour, as ElvUI reads it.
    WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 1, 2, 5
    WOW_PROJECT_WRATH_CLASSIC, WOW_PROJECT_MISTS_CLASSIC, WOW_PROJECT_CAMELOT = 11, 19, 20
    local projects = {
        era = WOW_PROJECT_CLASSIC,
        tbc = WOW_PROJECT_BURNING_CRUSADE_CLASSIC,
        wrath = WOW_PROJECT_WRATH_CLASSIC,
        mists = WOW_PROJECT_MISTS_CLASSIC,
        retail = WOW_PROJECT_MAINLINE,
        forever = WOW_PROJECT_CAMELOT,
    }
    WOW_PROJECT_ID = projects[kind]
    -- The client's school masks; Wrath Classic is left without them, as a client that lacks the enum.
    Enum = kind ~= "wrath"
            and {
                Damageclass = {
                    MaskPhysical = 1,
                    MaskHoly = 2,
                    MaskFire = 4,
                    MaskNature = 8,
                    MaskFrost = 16,
                    MaskShadow = 32,
                    MaskArcane = 64,
                },
            }
        or nil

    function issecretvalue(v)
        return v == SECRET
    end

    -- The client's language and its word for damage (GlobalStrings' DAMAGE).
    local locale = opts.locale or "enUS"
    function GetLocale()
        return locale
    end
    DAMAGE = ({ deDE = "Schaden", frFR = "Dégâts", ruRU = "Урон" })[locale] or "Damage"

    -- WoW's bit library, for the 7-bit school masks.
    bit = {
        band = function(a, b)
            local result, place = 0, 1
            while a > 0 and b > 0 do
                if a % 2 == 1 and b % 2 == 1 then result = result + place end
                a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
            end
            return result
        end,
        bor = function(a, b)
            local result, place = 0, 1
            while a > 0 or b > 0 do
                if a % 2 == 1 or b % 2 == 1 then result = result + place end
                a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
            end
            return result
        end,
    }

    C_Spell = {
        GetSchoolString = function(mask)
            -- A French and a Russian client name Fire in their language; the tests need no other
            -- of their names.
            if mask == 4 and locale == "frFR" then return "Feu" end
            if mask == 4 and locale == "ruRU" then return "огня" end
            return SCHOOL_NAMES[mask]
        end,
        GetSpellDescription = function(id)
            return client.descriptions[id] or ""
        end,
        GetSpellName = function(id)
            return client.spellNames and client.spellNames[id]
        end,
    }
    client.spellNames = { [133] = "Fireball", [116] = "Frostbolt", [401502] = "Frostfire Bolt" }

    -- The combat log: the classic clients read it through C_CombatLog; retail and WoW: Forever have
    -- none for addons.
    local modern = kind == "forever" or kind == "retail"
    C_CombatLog = nil
    if not modern then
        C_CombatLog = {
            GetCurrentEventInfo = function()
                return unpack(client.combatLog)
            end,
        }
    end

    -- LibStub with the libraries the plugin asks for: AceLocale (enough of it) and LibElvUIPlugin.
    local locales = {}
    local libs = {
        ["AceLocale-3.0"] = {
            NewLocale = function(_, app, _, isDefault)
                if not isDefault then return nil end
                locales[app] = setmetatable({}, {
                    __newindex = function(t, k, v)
                        rawset(t, k, v == true and k or v)
                    end,
                })
                return locales[app]
            end,
            GetLocale = function(_, app)
                return locales[app]
            end,
        },
        ["LibElvUIPlugin-1.0"] = {
            RegisterPlugin = function(_, name, callback)
                record("RegisterPlugin", name)
                client.optionsCallback = callback
            end,
        },
    }
    function LibStub(name)
        return assert(libs[name], "no library " .. name)
    end

    -- ElvUI: E with its modules and profile defaults (P), the UnitFrames module.
    local E, P = { Modern = modern, media = { blankTex = "blank" } }, {}
    E.Options = not opts.noOptions and { args = {} } or nil
    local UF = {}
    client.UF, client.E = UF, E

    function E:GetModule(name)
        if name == "UnitFrames" then return UF end
        return client.modules[name]
    end
    function E:NewModule(name)
        local module = { name = name }
        function module:GetName()
            return self.name
        end
        function module:RegisterEvent(event, handler)
            record("RegisterEvent", event)
            client.events[event] = { module = self, handler = handler or event }
        end
        ---As AceHook's SecureHook: the handler runs after the original, with its arguments.
        function module:SecureHook(object, method, handler)
            local original = object[method]
            object[method] = function(...)
                local results = { original(...) }
                self[handler](self, ...)
                return unpack(results)
            end
        end
        client.modules[name] = module
        return module
    end
    function E:RegisterModule(name)
        record("RegisterModule", name)
    end

    ---ElvUI's SetStatusBarColor, less what the tests do not need: the fill gets the colour, at
    ---half alpha on a transparent bar, and the background the same colour, darker.
    function UF:SetStatusBarColor(bar, r, g, b)
        local alpha = bar.isTransparent and 0.5 or 1
        bar:GetStatusBarTexture():SetVertexColor(r, g, b, alpha)
        bar.bg:SetVertexColor(r * 0.35, g * 0.35, b * 0.35, 1)
    end
    ---ElvUI's Configure_Castbar runs on every settings change of a frame; here it only records.
    function UF:Configure_Castbar(frame)
        record("Configure_Castbar", frame.unitframeType)
    end

    ---ElvUI's cast colour for a bar: its interrupt colour for a cast that cannot be interrupted.
    function UF.GetInterruptColor(bar, db, unit)
        assert(db == bar.__owner.db and unit == bar.__unit, "the frame's settings and the bar's unit")
        return unpack(bar.notInterruptible and ELVUI_INTERRUPT or ELVUI_COLOR)
    end

    -- ElvUI's cast bar callbacks, as Construct_Castbar sets them on each bar.
    local function PostCastStart(bar, unit)
        bar.__unit = unit
        UF:SetStatusBarColor(bar, UF.GetInterruptColor(bar, bar.__owner.db, unit))
    end
    local function PostCastFail(bar)
        UF:SetStatusBarColor(bar, unpack(ELVUI_FAIL))
    end
    local function PostCastInterrupted(bar)
        PostCastFail(bar)
    end
    local function PostCastInterruptible(bar)
        if bar.notInterruptible then UF:SetStatusBarColor(bar, unpack(ELVUI_INTERRUPT)) end
    end

    -- oUF's list of every frame it spawned.
    E.oUF = { objects = {} }

    ---A unit frame with its cast bar, as UF:Construct_Castbar builds it, in oUF's list.
    ---@param unit string the frame's unit, also its key in client.frames
    ---@param kind string? ElvUI's unitframeType, when not the unit ("party" for party1)
    ---@return table
    function client:BuildFrame(unit, kind)
        local frame = Region("Frame")
        frame.unitframeType, frame.unit, frame.db = kind or unit, unit, { castbar = {} }
        E.oUF.objects[#E.oUF.objects + 1] = frame
        local bar = Region("StatusBar", frame)
        bar.__owner, bar.width, bar.reverse = frame, 200, false
        bar.fill = Region("Texture", bar)
        bar.fill.texture = "Interface\\ElvUI\\Minimalist"
        bar.bg = Region("Texture", bar)
        function bar:GetStatusBarTexture()
            return self.fill
        end
        function bar:GetWidth()
            return self.width
        end
        function bar:GetReverseFill()
            return self.reverse
        end
        bar.PostCastStart, bar.PostCastFail = PostCastStart, PostCastFail
        bar.PostCastInterrupted, bar.PostCastInterruptible = PostCastInterrupted, PostCastInterruptible
        bar:Hide()
        frame.Castbar = bar
        self.frames[unit] = frame
        return frame
    end

    if TOC_SAVED then _G[TOC_SAVED] = opts.saved and copy(opts.saved) or nil end
    ElvUI = { E, {}, {}, P, {} }

    for _, file in ipairs(TOC_FILES) do
        assert(loadfile(file))("ElvUI_SchoolCastbar", client.ns)
    end

    -- The debug addons, loaded before the plugin (its OptionalDeps): every call recorded as
    -- { name, ... } in client.debugCalls.
    client.debugCalls = {}
    local function recorder(name)
        return function(...)
            client.debugCalls[#client.debugCalls + 1] = { name, ... }
        end
    end
    OAPDebug = opts.oapDebug and { Register = recorder("Register"), Log = recorder("Log"), Count = recorder("Count") }
        or nil
    DLAPI = opts.debugLog and { DebugLog = recorder("DebugLog") } or nil
    ---The debug calls of one kind, without their name.
    function client:debug(name)
        local found = {}
        for _, call in ipairs(self.debugCalls) do
            if call[1] == name then found[#found + 1] = { unpack(call, 2) } end
        end
        return found
    end

    -- Login: ElvUI reads the profile (defaults included), builds its unit frames, then
    -- initialises the plugin's module.
    E.db = copy(P)
    if opts.debugLevel then E.db.schoolCastbar.oapDebug = opts.debugLevel end
    client:BuildFrame("player")
    client:BuildFrame("target")
    if not opts.noFocus then client:BuildFrame("focus") end
    client:BuildFrame("pet")
    client:BuildFrame("party1", "party")
    -- A frame without a cast bar of its own.
    client:BuildFrame("targettarget").Castbar = nil
    for _, module in pairs(client.modules) do
        module:Initialize()
    end

    ---Fires an event at the module that registered it, as AceEvent does.
    function client:Fire(event, ...)
        local entry = self.events[event]
        if not entry then return end
        entry.module[entry.handler](entry.module, event, ...)
    end
    ---A cast starts on a unit's bar: oUF fills in the bar's fields, then calls ElvUI's PostCastStart.
    ---@param unit string
    ---@param name string|table the spell's name, or SECRET
    ---@param id number|table|nil
    function client:Cast(unit, name, id)
        local bar = self.frames[unit].Castbar
        bar.spellName, bar.spellID = name, id
        bar:Show()
        bar:PostCastStart(unit)
        return bar
    end
    ---The cast on a unit's bar fails (oUF's PostCastFail) or is interrupted.
    function client:Fail(unit)
        local bar = self.frames[unit].Castbar
        bar:PostCastFail(unit)
        return bar
    end
    function client:Interrupt(unit)
        local bar = self.frames[unit].Castbar
        bar:PostCastInterrupted(unit)
        return bar
    end
    ---A combat log line: the fields CombatLogGetCurrentEventInfo returns, up to the spell's school.
    ---@param subevent string
    ---@param name string
    ---@param school number
    function client:CombatLog(subevent, name, school)
        self.combatLog = { 0, subevent, false, "Player-1", "Me", 0, 0, "", "", 0, 0, 0, name, school }
        self:Fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    ---Loads ElvUI_Options: LibElvUIPlugin runs the plugin's callback.
    function client:LoadOptions()
        if self.optionsCallback then self.optionsCallback() end
        return E.Options and E.Options.args.ElvUI_SchoolCastbar
    end
    ---The textures the plugin made on a bar for the gradient, shown ones only.
    function client:Segments(bar)
        local shown = {}
        for _, child in ipairs(bar.children) do
            if child.kind == "Texture" and child.shown then shown[#shown + 1] = child end
        end
        return shown
    end

    return client
end
