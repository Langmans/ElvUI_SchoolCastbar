-- English strings, also the fallback for every other client language. Each says where it appears.
local L = LibStub("AceLocale-3.0"):NewLocale("ElvUI_SchoolCastbar", "enUS", true)

-- stylua: ignore start

-- ElvUI's options: the plugin's page in the side bar and its text.
L.OPTIONS = "School Castbar"
L.OPTIONS_DESC = "Colours ElvUI's cast bars by the spell's school. A spell of several schools fades from one colour to the next. ElvUI's own colours stay for a failed cast and for one that cannot be interrupted."

-- The General tab: the bars (by ElvUI's unit frame), the gradient, the description.
L.GENERAL = "General"
L.UNITS = "Cast bars"
L.player = "Player"
L.target = "Target"
L.focus = "Focus"
L.pet = "Pet"
L.boss = "Boss"
L.party = "Party"
L.GRADIENT = "Gradient"
L.GRADIENT_DESC = "Fade from one school's colour to the next for a spell of several schools. Off: the first school's colour."
L.TOOLTIP = "Read the description"
L.TOOLTIP_DESC = "Take the school from the school names in the spell's description when nothing else gives it."

-- The Colours tab: a colour per school, and putting them back.
L.COLORS = "Colours"
L.RESET = "Default colours"
L.physical = "Physical"
L.holy = "Holy"
L.fire = "Fire"
L.nature = "Nature"
L.frost = "Frost"
L.shadow = "Shadow"
L.arcane = "Arcane"

-- The Spells tab: picking a spell, its schools, where they come from (%s), removing the choice.
L.SPELLS = "Spells"
L.SPELLS_DESC = "Choose the schools of a spell yourself, for one the plugin colours wrongly or not at all."
L.ADD = "Spell name or ID"
L.SPELL = "Spell"
L.SPELL_DESC = "The spells cast this session, and those with schools of your own choice."
L.SOURCE = "Its schools now: %s."
L.SOURCE_override = "your own choice"
L.SOURCE_data = "the game's spell data"
L.SOURCE_combatlog = "the combat log"
L.SOURCE_tooltip = "the spell's description"
L.SOURCE_none = "unknown"
L.REMOVE = "Use the spell's own schools"

-- stylua: ignore end
