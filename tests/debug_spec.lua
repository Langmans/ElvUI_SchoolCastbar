-- The bridge to the debug addons (Debug.lua): OAP Debug and _DebugLog get a line for each school the
-- plugin reads from a spell's description, the spells its data lacks.

local ICON = "Interface\\Icons\\Spell_Fire_FlameBolt"
local NPC_BOLT = 999001
local FIREBALL = 133
local DESCRIPTION = "Deals 100 Frostfire damage."

---A client with both debug addons, a spell its data lacks, and its description.
local function withDebug(level)
    return NewClient({
        oapDebug = true,
        debugLog = true,
        debugLevel = level,
        descriptions = { [NPC_BOLT] = DESCRIPTION, [FIREBALL] = "Causes Fire damage." },
    })
end

describe("OAP Debug", function()
    it("gets the plugin registered at login, with its folder for Lua errors and its icon", function()
        local client = withDebug()
        local name = "ElvUI_SchoolCastbar"
        assert.same({ { name, { title = name, folder = name, icon = ICON } } }, client:debug("Register"))
    end)

    it("logs a school read from a description, with the spell and the schools", function()
        local client = withDebug()
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.same({
            {
                "ElvUI_SchoolCastbar",
                "tooltip: {1} ({2}) is not in the spell data; its description says {3}",
                "info",
                "Frost Flame",
                NPC_BOLT,
                "Frostfire",
            },
        }, client:debug("Log"))
        assert.same({ { "ElvUI_SchoolCastbar", "tooltip" } }, client:debug("Count"))
    end)

    it("logs a spell once, as its description is read once", function()
        local client = withDebug()
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.equal(1, #client:debug("Log"))
    end)

    it("logs nothing for a spell the data has", function()
        local client = NewClient({ oapDebug = true, client = "forever", descriptions = { [FIREBALL] = "Fire damage" } })
        client.ns.Schools.Of(FIREBALL, "Fireball")
        assert.same({}, client:debug("Log"))
    end)

    it("adds the description itself at the detailed level", function()
        local client = withDebug("detailed")
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        local lines = client:debug("Log")
        assert.equal(2, #lines)
        assert.same({ "tooltip: {1}'s description: {2}", "debug", "Frost Flame", DESCRIPTION }, { unpack(lines[2], 2) })
    end)

    it("sends nothing at the errors-only level", function()
        local client = withDebug("errors")
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.same({}, client:debug("Log"))
        assert.same({}, client:debug("DebugLog"))
    end)

    it("counts only from the metrics level", function()
        local client = withDebug("normal")
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.equal(1, #client:debug("Log"))
        assert.same({}, client:debug("Count"))
    end)
end)

describe("_DebugLog", function()
    it("gets the same line as text in the plugin's tab, under its category", function()
        local client = withDebug()
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.same({
            {
                "ElvUI_SchoolCastbar",
                "%s",
                "tooltip~Frost Flame (999001) is not in the spell data; its description says Frostfire",
            },
        }, client:debug("DebugLog"))
    end)

    it("marks a detailed line as detail", function()
        local client = withDebug("detailed")
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.equal("2~tooltip~Frost Flame's description: " .. DESCRIPTION, client:debug("DebugLog")[2][3])
    end)

    it("works without OAP Debug", function()
        local client = NewClient({ debugLog = true, descriptions = { [NPC_BOLT] = DESCRIPTION } })
        client.ns.Schools.Of(NPC_BOLT, "Frost Flame")
        assert.equal(1, #client:debug("DebugLog"))
    end)
end)

describe("without a debug addon", function()
    it("reads descriptions as before, sending nothing", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = DESCRIPTION } })
        assert.equal(20, client.ns.Schools.Of(NPC_BOLT, "Frost Flame"))
        assert.same({}, client.debugCalls)
    end)
end)

describe("the debug setting", function()
    it("is a choice on the General tab, metrics at first", function()
        local client = withDebug()
        local option = client:LoadOptions().args.general.args.debug.args.level
        assert.equal("metrics", option.get())
        option.set({ "level" }, "detailed")
        assert.equal("detailed", client.E.db.schoolCastbar.oapDebug)
        assert.equal(4, #(function()
            local n = {}
            for key in pairs(option.values) do
                n[#n + 1] = key
            end
            return n
        end)())
    end)

    it("says when neither debug addon is installed", function()
        local client = NewClient()
        local option = client:LoadOptions().args.general.args.debug.args.level
        assert.truthy(option.desc():find("Not installed", 1, true))
        local installed = withDebug():LoadOptions().args.general.args.debug.args.level
        assert.falsy(installed.desc():find("Not installed", 1, true))
    end)
end)
