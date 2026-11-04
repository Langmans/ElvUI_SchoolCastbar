-- Colours a cast bar by its spell's school. One school: the colour goes through ElvUI's own
-- UF:SetStatusBarColor, which also tints the background and keeps a transparent bar's alpha.
--
-- Several schools: a gradient across the whole bar, from the first school (where the cast starts)
-- to the last, in pieces of equal width, one piece between each two schools (a texture gradient has
-- only two colours). The pieces use ElvUI's bar texture and lie above the fill, which is hidden;
-- a mask anchored to the fill's edge shows them only where the bar has filled, so the colours stay
-- in place while the bar grows. A failed cast hides them again, so ElvUI's fail colour shows.

local _, ns = ... ---@type string, SchoolCastbarNamespace
local E = ElvUI[1]
local UF = E:GetModule("UnitFrames")
local S = ns.Schools

-- At most 7 schools: 6 pieces between them.
local MAX_PIECES = 6

-- The school names of the cast being painted, filled by S.Split and reused for every cast.
---@type string[]
local schools = {}

---The pieces and the mask of a bar, made on its first gradient.
---@param bar SchoolCastbarBar
---@return SchoolCastbarPieces
local function Pieces(bar)
    if bar.schoolPieces then return bar.schoolPieces end
    local mask = bar:CreateMaskTexture()
    mask:SetTexture(E.media.blankTex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ---@type SchoolCastbarPieces
    local pieces = { mask = mask, list = {} }
    for i = 1, MAX_PIECES do
        -- ARTWORK 1: above the fill (ARTWORK 0), below ElvUI's spark, ticks and text (OVERLAY).
        local piece = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        piece:AddMaskTexture(mask)
        piece:Hide()
        pieces.list[i] = { texture = piece, from = CreateColor(1, 1, 1, 1), to = CreateColor(1, 1, 1, 1) }
    end
    bar.schoolPieces = pieces
    return pieces
end

---Puts the bar back as ElvUI draws it: no pieces, the fill shown.
---@param bar SchoolCastbarBar
function ns.Clear(bar)
    local pieces = bar.schoolPieces
    if not pieces then return end
    for _, piece in ipairs(pieces.list) do
        piece.texture:Hide()
    end
    bar:GetStatusBarTexture():SetAlpha(1)
end

---Sets a colour object to a school's colour from the settings, at the given alpha.
---@param color ColorMixin
---@param school string
---@param alpha number
local function SetSchoolColor(color, school, alpha)
    local c = ns.db().colors[school]
    color:SetRGBA(c.r, c.g, c.b, alpha)
end

---The gradient across the bar for count schools.
---@param bar SchoolCastbarBar
---@param count number
local function Gradient(bar, count)
    local fill = bar:GetStatusBarTexture()
    local pieces = Pieces(bar)
    local width, reverse = bar:GetWidth(), bar:GetReverseFill()
    local texture = fill:GetTexture()
    local _, _, _, alpha = fill:GetVertexColor()

    local mask = pieces.mask
    mask:ClearAllPoints()
    if reverse then
        mask:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
        mask:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
    else
        mask:SetPoint("TOPLEFT", bar, "TOPLEFT")
        mask:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    end

    local n = count - 1
    for i, piece in ipairs(pieces.list) do
        local tex = piece.texture
        if i > n then
            tex:Hide()
        else
            -- The piece from school i to school i + 1, as a part of the bar from left to right.
            local left, right = (i - 1) / n, i / n
            SetSchoolColor(piece.from, schools[i], alpha)
            SetSchoolColor(piece.to, schools[i + 1], alpha)
            tex:SetTexture(texture)
            tex:ClearAllPoints()
            if reverse then
                -- Filling from the right: the cast starts there, so the colours run right to left.
                tex:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -left * width, 0)
                tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -right * width, 0)
                tex:SetTexCoord(1 - right, 1 - left, 0, 1)
                tex:SetGradient("HORIZONTAL", piece.to --[[@as colorRGBA]], piece.from --[[@as colorRGBA]])
            else
                tex:SetPoint("TOPLEFT", bar, "TOPLEFT", left * width, 0)
                tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", right * width, 0)
                tex:SetTexCoord(left, right, 0, 1)
                tex:SetGradient("HORIZONTAL", piece.from --[[@as colorRGBA]], piece.to --[[@as colorRGBA]])
            end
            tex:Show()
        end
    end
    fill:SetAlpha(0)
end

---ElvUI's own colour for the cast on a bar, as its PostCastStart sets it.
---@param bar SchoolCastbarBar
local function ElvUIColor(bar)
    local r, g, b = UF.GetInterruptColor(bar, bar.__owner.db, bar.__unit)
    UF:SetStatusBarColor(bar, r, g, b)
end

---Colours a bar for the cast on it, or leaves ElvUI's colour: for a unit the plugin is off for, a
---cast that cannot be interrupted (ElvUI marks it with its own colour), or a spell of unknown school.
---@param bar SchoolCastbarBar
---@param again boolean? painting a cast already on the bar (a settings change): ElvUI's colour is
---put back where the plugin's no longer applies
function ns.Paint(bar, again)
    local db = ns.db()
    local name, id = bar.spellName, bar.spellID
    -- Every cast seen goes in the Spells tab's list, also one of unknown school.
    if name and not issecretvalue(name) then ns.seen[name] = not issecretvalue(id) and id or false end
    local notInterruptible = bar.notInterruptible
    local mask = db.units[bar.__owner.unitframeType]
        and not (notInterruptible and not issecretvalue(notInterruptible))
        and S.Of(id, name)
    if not mask then
        if again then ElvUIColor(bar) end
        ns.Clear(bar)
        return
    end

    local count = S.Split(mask, schools)
    local first = db.colors[schools[1]]
    UF:SetStatusBarColor(bar, first.r, first.g, first.b)
    if count > 1 and db.gradient and not bar.invertColors then
        Gradient(bar, count)
    else
        ns.Clear(bar)
    end
end
