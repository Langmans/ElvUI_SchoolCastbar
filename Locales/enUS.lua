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
L.arena = "Arena"
L.party = "Party"
L.GRADIENT = "Gradient"
L.GRADIENT_DESC = "Fade from one school's colour to the next for a spell of several schools. Off: the first school's colour."
L.TOOLTIP = "Read the description"
L.TOOLTIP_DESC = "Take the school from the school names in the spell's description when nothing else gives it."

-- The General tab's box for the debug addons (OAP Debug, _DebugLog), the setting every OAP addon
-- has: how much the plugin sends to them.
L.DEBUG = "OAP Debug"
L.DEBUG_LEVEL = "Send to OAP Debug"
L.DEBUG_DESC = "How much goes to OAP Debug's and _DebugLog's window: each spell whose school comes from its description, so missing from the spell data (metrics: counts)."
L.DEBUG_MISSING = "Not installed: nothing is sent."
L.DEBUG_errors = "Errors only"
L.DEBUG_normal = "Normal"
L.DEBUG_metrics = "Normal and metrics"
L.DEBUG_detailed = "Detailed"

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

-- The Spells tab: its text, the filter and the box to add a spell; on a spell's page where its
-- schools come from (%s), the Off tick and the button that removes the player's choice.
L.SPELLS = "Spells"
L.SPELLS_DESC = "Choose the schools of a spell yourself, for one the plugin colours wrongly or not at all, or turn a spell off. The list holds your own choices, your spellbook's spells with a cast bar, what the combat log named and what was cast this session; a spell that is off is red."
L.FILTER = "Filter"
L.ADD = "Add a spell (name or ID)"
L.OFF = "Off"
L.OFF_DESC = "Leave this spell in ElvUI's own colour. Every school ticked off does the same."
L.SOURCE = "Its schools now: %s."
L.SOURCE_off = "off, your own choice"
L.SOURCE_override = "your own choice"
L.SOURCE_data = "the game's spell data"
L.SOURCE_combatlog = "the combat log"
L.SOURCE_tooltip = "the spell's description"
L.SOURCE_none = "unknown"
L.REMOVE = "Use the spell's own schools"

-- stylua: ignore end
