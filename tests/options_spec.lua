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

-- The spell each page returned by entry is for.
local pageSpell = setmetatable({}, { __mode = "k" })

---A spell's page in the Spells tab's list; nil when it is not listed.
local function entry(tab, name)
    local spell = tab.args["spell:" .. name]
    if spell then pageSpell[spell] = name end
    return spell
end

---Calls an option on a spell's page as AceConfigDialog does: the path ends in the page and the option.
local function on(spell, fn, key, ...)
    local option = spell.args[key]
    local handler = option[fn] or spell[fn]
    return handler({ "ElvUI_SchoolCastbar", "spells", "spell:" .. pageSpell[spell], key }, ...)
end

---The names of the listed spells, in order.
local function listed(tab)
    local names = {}
    for key in pairs(tab.args) do
        local name = key:match("^spell:(.+)$")
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

describe("the spells tab", function()
    it("is a list at the left, as ElvUI's tags and BattleCry's triggers", function()
        local client = NewClient({ client = "forever" })
        assert.equal("tree", page(client).args.spells.childGroups)
    end)

    it("lists the player's own choices, the spellbook, the combat log and this session's casts", function()
        local client = NewClient({ spellbook = { 133, 5143 } })
        client.ns.Schools.overrides.Hearthstone = 127
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        client:Cast("target", "Mend Pet", 136)
        assert.same(
            { "Arcane Missiles", "Dark Bolt", "Fireball", "Hearthstone", "Mend Pet" },
            listed(page(client).args.spells)
        )
    end)

    it("leaves out a spellbook spell without a cast bar", function()
        -- Arcane Intellect is instant; Arcane Missiles is a channel, which the data has.
        local client = NewClient({ client = "forever", spellbook = { 1459, 5143 } })
        assert.same({ "Arcane Missiles" }, listed(page(client).args.spells))
    end)

    it("reads the spellbook of the classic clients too", function()
        local client = NewClient({ client = "era", spellbook = { 133 } })
        assert.same({ "Fireball" }, listed(page(client).args.spells))
    end)

    it("shows each spell's icon before its name", function()
        local client = NewClient({ client = "forever", spellbook = { 133 } })
        local fireball = entry(page(client).args.spells, "Fireball")
        assert.equal("|T135812:16:16|t Fireball", fireball.name())
    end)

    it("shows a question mark for a spell the client has no icon for", function()
        local client = NewClient()
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        local bolt = entry(page(client).args.spells, "Dark Bolt")
        assert.equal("|T134400:16:16|t Dark Bolt", bolt.name())
    end)

    it("ticks the schools the spell has now, and says where they come from", function()
        local client = NewClient({ client = "forever", spellbook = { FROSTFIRE } })
        local spell = entry(page(client).args.spells, "Frostfire Bolt")
        assert.is_true(on(spell, "get", "fire"))
        assert.is_true(on(spell, "get", "frost"))
        assert.is_false(on(spell, "get", "shadow"))
        assert.truthy(spell.args.source.name():find("spell data", 1, true))
    end)

    it("makes a tick the player's own choice, starting from what the spell had", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local spell = entry(page(client).args.spells, "Frostfire Bolt")
        on(spell, "set", "frost", false)
        assert.equal(4, client.ns.Schools.overrides["Frostfire Bolt"])
        assert.equal(0, #client:Segments(bar))
        assert.truthy(spell.args.source.name():find("your own choice", 1, true))
    end)

    it("turns a spell off when every tick goes off, kept as the player's choice", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Fireball", FIREBALL)
        local spell = entry(page(client).args.spells, "Fireball")
        on(spell, "set", "fire", false)
        assert.equal(0, client.ns.Schools.overrides.Fireball)
        assert.is_false(on(spell, "get", "fire"))
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)

    it("turns a spell off with its own tick, and on again with a school", function()
        local client = NewClient({ client = "forever", spellbook = { FIREBALL } })
        local spell = entry(page(client).args.spells, "Fireball")
        assert.is_false(on(spell, "get", "off"))
        on(spell, "set", "off", true)
        assert.is_true(on(spell, "get", "off"))
        assert.equal(0, client.ns.Schools.overrides.Fireball)
        on(spell, "set", "frost", true)
        assert.equal(16, client.ns.Schools.overrides.Fireball)
        on(spell, "set", "off", false)
        assert.is_nil(client.ns.Schools.overrides.Fireball)
    end)

    it("names a spell that is off in red", function()
        local client = NewClient({ client = "forever", spellbook = { FIREBALL } })
        client.ns.Schools.overrides.Fireball = 0
        local spell = entry(page(client).args.spells, "Fireball")
        assert.equal("|T135812:16:16|t |cffff3333Fireball|r", spell.name())
        assert.truthy(spell.args.source.name():find("off", 1, true))
    end)

    it("is off in the colouring too: ElvUI's own colour", function()
        local client = NewClient({ client = "forever" })
        client.ns.Schools.overrides.Fireball = 0
        assert.same({ nil, "override" }, { client.ns.Schools.Of(FIREBALL, "Fireball") })
    end)

    it("goes back to the spell's own schools with the button", function()
        local client = NewClient({ client = "forever" })
        client.ns.Schools.overrides["Frostfire Bolt"] = 16
        local spell = entry(page(client).args.spells, "Frostfire Bolt")
        assert.is_false(spell.args.remove.disabled({}))
        spell.args.remove.func({ "ElvUI_SchoolCastbar", "spells", "spell:Frostfire Bolt", "remove" })
        assert.is_nil(client.ns.Schools.overrides["Frostfire Bolt"])
        assert.is_true(
            spell.args.remove.disabled({ "ElvUI_SchoolCastbar", "spells", "spell:Frostfire Bolt", "remove" })
        )
    end)

    it("adds a spell by name or ID and opens its page", function()
        local client = NewClient({ client = "forever" })
        local tab = page(client).args.spells
        tab.args.add.set({ "add" }, "401502")
        assert.truthy(entry(page(client).args.spells, "Frostfire Bolt"))
        tab.args.add.set({ "add" }, "Dominate Mind")
        assert.truthy(entry(page(client).args.spells, "Dominate Mind"))
        assert.same(
            { { "ElvUI", "ElvUI_SchoolCastbar", "spells", "spell:Dominate Mind" } },
            { client:called("SelectGroup")[2] }
        )
        -- The box empties again for the next one.
        assert.equal("", tab.args.add.get())
    end)

    it("hides the spells whose name does not hold the filter", function()
        local client = NewClient({ client = "forever", spellbook = { 133, 116 } })
        local tab = page(client).args.spells
        tab.args.filter.set({ "filter" }, "frost")
        assert.equal("frost", tab.args.filter.get())
        assert.is_true(entry(tab, "Fireball").hidden())
        assert.is_false(entry(tab, "Frostbolt").hidden())
    end)

    it("takes in a spell cast while the options window is open, and redraws it", function()
        local client = NewClient({ client = "forever" })
        page(client)
        client:OpenOptions()
        client:Cast("player", "Fireball", FIREBALL)
        assert.truthy(entry(page(client).args.spells, "Fireball"))
        assert.truthy(#client:called("NotifyChange") > 0)
    end)

    it("takes in the spellbook again when it changes", function()
        local client = NewClient({ client = "forever" })
        page(client)
        client:OpenOptions()
        client.spellbook[1] = 133
        client:Fire("SPELLS_CHANGED")
        assert.truthy(entry(page(client).args.spells, "Fireball"))
    end)

    it("waits with a closed window until it opens again, building the list no more than once", function()
        local client = NewClient({ client = "forever" })
        page(client)
        client:Cast("player", "Fireball", FIREBALL)
        client:Cast("player", "Frostbolt", 116)
        assert.falsy(entry(page(client).args.spells, "Fireball"))
        assert.same({}, client:called("NotifyChange"))
        client:OpenOptions()
        assert.truthy(entry(page(client).args.spells, "Frostbolt"))
        assert.equal(1, #client:called("NotifyChange"))
        client:OpenOptions()
        assert.equal(1, #client:called("NotifyChange"))
    end)

    it("builds the list from what is known when the options load", function()
        local client = NewClient({ client = "forever" })
        client:Cast("player", "Fireball", FIREBALL)
        assert.truthy(entry(page(client).args.spells, "Fireball"))
    end)
end)
