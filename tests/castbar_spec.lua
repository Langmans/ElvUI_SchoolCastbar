-- How the plugin colours ElvUI's cast bars: one school, several, and when it leaves ElvUI's colour.

local FIREBALL, FROSTBOLT, FROSTFIRE = 133, 116, 401502

---The colour a settings entry holds, as the bar gets it: r, g, b, alpha.
local function rgba(color, alpha)
    return { color.r, color.g, color.b, alpha or 1 }
end

local function colors(client)
    return client.E.db.schoolCastbar.colors
end

describe("a spell of one school", function()
    it("colours the bar in that school's colour", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Fireball", FIREBALL)
        assert.same(rgba(colors(client).fire), bar.fill.color)
        assert.equal(0, #client:Segments(bar))
    end)

    it("colours the background through ElvUI too, darker", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostbolt", FROSTBOLT)
        local frost = colors(client).frost
        assert.same({ frost.r * 0.35, frost.g * 0.35, frost.b * 0.35, 1 }, bar.bg.color)
    end)

    it("keeps the alpha ElvUI gives a transparent bar", function()
        local client = NewClient({ client = "forever" })
        client.frames.player.Castbar.isTransparent = true
        local bar = client:Cast("player", "Fireball", FIREBALL)
        assert.same(rgba(colors(client).fire, 0.5), bar.fill.color)
    end)
end)

describe("a spell of several schools", function()
    it("fades from the first school to the next across the bar", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local segments = client:Segments(bar)
        assert.equal(1, #segments)
        -- Fire (4) comes before Frost (16): the schools go in the order of their bits.
        assert.same({ "HORIZONTAL", rgba(colors(client).fire), rgba(colors(client).frost) }, segments[1].gradient)
        assert.same({ bar, "TOPLEFT", 0, 0 }, segments[1].points.TOPLEFT)
        assert.same({ bar, "BOTTOMLEFT", 200, 0 }, segments[1].points.BOTTOMRIGHT)
        assert.same({ 0, 1, 0, 1 }, segments[1].texCoord)
    end)

    it("draws ElvUI's own bar texture in the gradient and hides the plain fill", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        assert.equal("Interface\\ElvUI\\Minimalist", client:Segments(bar)[1].texture)
        assert.equal(0, bar.fill.alpha)
    end)

    it("shows the gradient only where the bar has filled, through a mask on the fill", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local mask = client:Segments(bar)[1].masks[1]
        assert.equal("MaskTexture", mask.kind)
        assert.same({ bar, "TOPLEFT", 0, 0 }, mask.points.TOPLEFT)
        assert.same({ bar.fill, "BOTTOMRIGHT", 0, 0 }, mask.points.BOTTOMRIGHT)
    end)

    it("gives three schools two pieces, each half the bar", function()
        local client = NewClient({ client = "forever" })
        client.ns.Schools.overrides["Chaos Bolt"] = 4 + 32 + 64
        local bar = client:Cast("player", "Chaos Bolt", 1)
        local segments = client:Segments(bar)
        assert.equal(2, #segments)
        local c = colors(client)
        assert.same({ "HORIZONTAL", rgba(c.fire), rgba(c.shadow) }, segments[1].gradient)
        assert.same({ "HORIZONTAL", rgba(c.shadow), rgba(c.arcane) }, segments[2].gradient)
        assert.same({ bar, "TOPLEFT", 100, 0 }, segments[2].points.TOPLEFT)
        assert.same({ bar, "BOTTOMLEFT", 200, 0 }, segments[2].points.BOTTOMRIGHT)
        assert.same({ 0.5, 1, 0, 1 }, segments[2].texCoord)
    end)

    it("mirrors everything on a bar that fills from the right", function()
        local client = NewClient({ client = "forever" })
        client.frames.player.Castbar.reverse = true
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local segment = client:Segments(bar)[1]
        local c = colors(client)
        -- The cast starts on the right: there it is Fire, towards the left Frost.
        assert.same({ "HORIZONTAL", rgba(c.frost), rgba(c.fire) }, segment.gradient)
        assert.same({ bar, "TOPRIGHT", 0, 0 }, segment.points.TOPRIGHT)
        assert.same({ bar, "BOTTOMRIGHT", -200, 0 }, segment.points.BOTTOMLEFT)
        local mask = segment.masks[1]
        assert.same({ bar, "TOPRIGHT", 0, 0 }, mask.points.TOPRIGHT)
        assert.same({ bar.fill, "BOTTOMLEFT", 0, 0 }, mask.points.BOTTOMLEFT)
    end)

    it("uses the first school's colour alone with the gradient off", function()
        local client = NewClient({ client = "forever" })
        client.E.db.schoolCastbar.gradient = false
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        assert.equal(0, #client:Segments(bar))
        assert.same(rgba(colors(client).fire), bar.fill.color)
        assert.equal(1, bar.fill.alpha)
    end)

    it("uses the first school's colour alone when ElvUI inverts the bar's colours", function()
        local client = NewClient({ client = "forever" })
        client.frames.player.Castbar.invertColors = true
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        assert.equal(0, #client:Segments(bar))
    end)

    it("drops the gradient for the next cast of one school", function()
        local client = NewClient({ client = "forever" })
        client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local bar = client:Cast("player", "Fireball", FIREBALL)
        assert.equal(0, #client:Segments(bar))
        assert.equal(1, bar.fill.alpha)
    end)

    it("makes its textures once per bar", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local made = #bar.children
        client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        assert.equal(made, #bar.children)
    end)
end)

describe("a cast that fails", function()
    it("shows ElvUI's fail colour over the whole fill", function()
        local client = NewClient({ client = "forever" })
        client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local bar = client:Fail("player")
        assert.equal(0, #client:Segments(bar))
        assert.equal(1, bar.fill.alpha)
        assert.same({ ELVUI_FAIL[1], ELVUI_FAIL[2], ELVUI_FAIL[3], 1 }, bar.fill.color)
    end)

    it("does the same when interrupted", function()
        local client = NewClient({ client = "forever" })
        client:Cast("player", "Frostfire Bolt", FROSTFIRE)
        local bar = client:Interrupt("player")
        assert.equal(0, #client:Segments(bar))
        assert.equal(1, bar.fill.alpha)
    end)
end)

describe("ElvUI's own colour", function()
    it("stays for a spell of unknown school", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("player", "Mystery", 999999999)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)

    it("stays on a unit the plugin is off for", function()
        local client = NewClient({ client = "forever" })
        client.E.db.schoolCastbar.units.target = false
        local bar = client:Cast("target", "Fireball", FIREBALL)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)

    it("stays for a cast that cannot be interrupted, which ElvUI marks with its own colour", function()
        local client = NewClient({ client = "forever" })
        local bar = client.frames.target.Castbar
        bar.notInterruptible = true
        client:Cast("target", "Fireball", FIREBALL)
        bar:PostCastInterruptible("target")
        assert.same({ ELVUI_INTERRUPT[1], ELVUI_INTERRUPT[2], ELVUI_INTERRUPT[3], 1 }, bar.fill.color)
    end)

    it("stays when the client hides the spell's name and ID", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("target", SECRET, SECRET)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)
end)

describe("the bars", function()
    it("are the player's, the target's, the focus's and the pet's", function()
        local client = NewClient({ client = "forever" })
        for _, unit in ipairs({ "player", "target", "focus", "pet" }) do
            local bar = client:Cast(unit, "Fireball", FIREBALL)
            assert.same(rgba(colors(client).fire), bar.fill.color, unit)
        end
    end)

    it("colour a warlock pet's spell by its school", function()
        local client = NewClient()
        -- The Imp's Firebolt and the Succubus's Seduction, from the pets' skill lines.
        assert.same(rgba(colors(client).fire), client:Cast("pet", "Firebolt", 3110).fill.color)
        assert.same(rgba(colors(client).shadow), client:Cast("pet", "Seduction", 6358).fill.color)
    end)

    it("leave the party's alone until switched on", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("party1", "Fireball", FIREBALL)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
        client.E.db.schoolCastbar.units.party = true
        client:Cast("party1", "Fireball", FIREBALL)
        assert.same(rgba(colors(client).fire), bar.fill.color)
    end)

    it("include a frame ElvUI builds later, once ElvUI configures its cast bar", function()
        local client = NewClient({ client = "forever", noFocus = true })
        local frame = client:BuildFrame("focus")
        client.UF:Configure_Castbar(frame)
        client.UF:Configure_Castbar(frame)
        local bar = client:Cast("focus", "Fireball", FIREBALL)
        assert.same(rgba(colors(client).fire), bar.fill.color)
    end)

    it("include the bosses'", function()
        local client = NewClient({ client = "forever" })
        local frame = client:BuildFrame("boss1", "boss")
        client.UF:Configure_Castbar(frame)
        local bar = client:Cast("boss1", "Fireball", FIREBALL)
        assert.same(rgba(colors(client).fire), bar.fill.color)
    end)

    it("leave out other frames ElvUI configures", function()
        local client = NewClient({ client = "forever" })
        local frame = client:BuildFrame("arena1", "arena")
        client.UF:Configure_Castbar(frame)
        local bar = client:Cast("arena1", "Fireball", FIREBALL)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)
end)
