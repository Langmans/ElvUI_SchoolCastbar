-- The plugin's page in ElvUI's options: the bars it colours, the colours, and the schools per spell.

local FIREBALL, FROSTFIRE = 133, 401502

---Calls an AceConfig option's get, set, values or disabled the way AceConfigDialog does: with
---the path to the option as the info table, the option's key last.
local function call(option, fn, key, ...)
    local handler = option[fn]
    return handler({ key }, ...)
end

local function page(client)
    return assert(client:LoadOptions())
end

describe("the options page", function()
    it("sits among ElvUI's plugins", function()
        local client = NewClient()
        assert.same({ { "ElvUI_SchoolCastbar" } }, client:called("RegisterPlugin"))
        assert.equal("group", page(client).type)
    end)

    it("is skipped when ElvUI_Options is not loaded", function()
        local client = NewClient({ noOptions = true })
        assert.is_nil(client:LoadOptions())
    end)
end)

describe("the general tab", function()
    it("turns the plugin off for a unit and repaints its bar", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("target", "Fireball", FIREBALL)
        local general = page(client).args.general
        assert.is_true(call(general, "get", "target"))
        call(general, "set", "target", false)
        assert.is_false(client.E.db.schoolCastbar.units.target)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)

    it("has the pet's bar on and the party's off at first", function()
        local client = NewClient({ client = "forever" })
        local general = page(client).args.general
        assert.is_true(call(general, "get", "pet"))
        assert.is_true(call(general, "get", "boss"))
        assert.is_true(call(general, "get", "arena"))
        assert.is_false(call(general, "get", "party"))
        call(general, "set", "party", true)
        assert.is_true(client.E.db.schoolCastbar.units.party)
    end)

    it("turns the gradient and the description off", function()
        local client = NewClient({ client = "forever" })
        local general = page(client).args.general
        call(general, "set", "gradient", false)
        call(general, "set", "tooltip", false)
        assert.is_false(client.E.db.schoolCastbar.gradient)
        assert.is_false(call(general, "get", "tooltip"))
    end)
end)

describe("the colours tab", function()
    it("sets a school's colour and repaints", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Fireball", FIREBALL)
        local tab = page(client).args.colors
        call(tab, "set", "fire", 0.1, 0.2, 0.3)
        assert.same({ 0.1, 0.2, 0.3 }, { call(tab, "get", "fire") })
        assert.same({ 0.1, 0.2, 0.3, 1 }, bar.fill.color)
    end)

    it("puts every colour back", function()
        local client = NewClient({ client = "forever" })
        local tab = page(client).args.colors
        local fire = { call(tab, "get", "fire") }
        call(tab, "set", "fire", 0.1, 0.2, 0.3)
        tab.args.reset.func()
        assert.same(fire, { call(tab, "get", "fire") })
    end)
end)

describe("the spells tab", function()
    it("lists the spells cast this session and those with a choice of their own", function()
        local client = NewClient({ client = "forever" })
        client:Cast("player", "Fireball", FIREBALL)
        client.ns.Schools.overrides.Heal = 2
        local tab = page(client).args.spells
        assert.same({ Fireball = "Fireball", Heal = "Heal" }, tab.args.spell.values())
    end)

    it("picks a spell by name, or by ID", function()
        local client = NewClient({ client = "forever" })
        local tab = page(client).args.spells
        tab.args.add.set({ "add" }, "401502")
        assert.equal("Frostfire Bolt", tab.args.spell.get())
        tab.args.add.set({ "add" }, "Mind Control")
        assert.equal("Mind Control", tab.args.spell.get())
        -- The box empties again for the next one.
        assert.equal("", tab.args.add.get())
    end)

    it("ticks the schools the spell has now, and says where they come from", function()
        local client = NewClient({ client = "forever" })
        client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local tab = page(client).args.spells
        tab.args.spell.set({ "spell" }, "Frostfire Bolt")
        assert.is_true(call(tab, "get", "fire"))
        assert.is_true(call(tab, "get", "frost"))
        assert.is_false(call(tab, "get", "shadow"))
        assert.truthy(tab.args.source.name():find("spell data", 1, true))
    end)

    it("makes a tick the player's own choice, starting from what the spell had", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local tab = page(client).args.spells
        tab.args.spell.set({ "spell" }, "Frostfire Bolt")
        call(tab, "set", "frost", false)
        assert.equal(4, client.ns.Schools.overrides["Frostfire Bolt"])
        assert.equal(0, #client:Segments(bar))
        assert.truthy(tab.args.source.name():find("your own choice", 1, true))
    end)

    it("gives a spell of unknown school its first tick", function()
        local client = NewClient({ client = "forever" })
        local tab = page(client).args.spells
        tab.args.add.set({ "add" }, "Mind Control")
        assert.truthy(tab.args.source.name():find("unknown", 1, true))
        call(tab, "set", "shadow", true)
        assert.equal(32, client.ns.Schools.overrides["Mind Control"])
    end)

    it("forgets the choice when every tick is off", function()
        local client = NewClient({ client = "forever" })
        client.ns.Schools.overrides.Heal = 2
        local tab = page(client).args.spells
        tab.args.spell.set({ "spell" }, "Heal")
        call(tab, "set", "holy", false)
        assert.is_nil(client.ns.Schools.overrides.Heal)
    end)

    it("removes the choice with the button, back to the spell's own school", function()
        local client = NewClient({ client = "forever" })
        client.ns.Schools.overrides["Frostfire Bolt"] = 16
        local tab = page(client).args.spells
        tab.args.spell.set({ "spell" }, "Frostfire Bolt")
        assert.is_false(tab.args.remove.disabled())
        tab.args.remove.func()
        assert.is_nil(client.ns.Schools.overrides["Frostfire Bolt"])
        assert.is_true(tab.args.remove.disabled())
    end)

    it("hides the ticks until a spell is picked", function()
        local client = NewClient({ client = "forever" })
        local tab = page(client).args.spells
        assert.is_true(tab.args.fire.hidden())
        assert.equal("", tab.args.source.name())
        tab.args.add.set({ "add" }, "Fireball")
        assert.is_false(tab.args.fire.hidden())
    end)
end)
