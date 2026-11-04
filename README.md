# ElvUI School Castbar

An ElvUI plugin that colours ElvUI's own cast bars by the spell's school: Fire
orange, Frost icy blue, Shadow purple, and so on. A spell of several schools, like
Frostfire Bolt or Shadowflame, fades from one school's colour to the next across
the bar.

- **The cast bars of the player, the target, the focus, the pet** (a warlock's
  Imp casting Firebolt in Fire's colour) **and the bosses**, each to be switched
  off; **the party's** too, off at first.
- **A colour per school**, on the plugin's own page.
- **ElvUI's colours stay** for a failed or interrupted cast, for a cast that
  cannot be interrupted, and for a spell whose school nothing knows.
- **Your own choice per spell**: tick a spell's schools on the Spells tab when the
  plugin gets one wrong or does not know it.

Everything else about the bars (size, texture, ticks, latency, text, mover) stays
ElvUI's own. Open `/ec` and pick School Castbar among the plugins in the side bar.

It loads on every client ElvUI runs on: Classic Era (with Hardcore and Season of
Discovery), Burning Crusade Classic Anniversary, Wrath Classic, Mists of Pandaria
Classic, retail and WoW: Forever.

## Where the school comes from

No call in the game returns a spell's school. The plugin tries, in this order:

1. **Your own choice** on the Spells tab, by spell name.
2. **The client's spell table** (`Data\`), by spell ID: every spell a class can cast
   with a cast bar, from the game's own data. Season of Discovery's runes are in
   Classic Era's table.
3. **The combat log**, by spell name, on the classic clients: each cast names its
   school there, and the plugin keeps what it saw between sessions. This covers
   NPCs' spells and anything the table lacks. Retail and WoW: Forever give addons no
   combat log.
4. **The spell's description**: the first school it deals damage in ("Fire damage",
   "Frostfire damage"): the school and damage as whole words with any space between,
   in the client's own words for both, in any capitals (Lua lowers only the letters
   A to Z, so Cyrillic and the like still match their exact case). A school named
   for anything else ("Fire resistance", "Bonfire") does not count. In a language
   that joins the two into one word ("Frostschaden") or puts the school after damage
   ("dégâts de feu"), the first school's name at the start of a word counts. A
   switch on the General tab turns this off.

A cast whose school arrives later (the combat log line, or a description the client
loads late) is coloured as soon as it arrives.

## How it works

- `Castbar.lua` is the plugin's ElvUI module. ElvUI sets its cast callbacks
  (`PostCastStart`, `PostCastInterruptible`, `PostCastFail`, `PostCastInterrupted`)
  on each bar when it builds the frame; the plugin wraps them on the bar, so
  ElvUI's runs first: at login on every frame in `E.oUF.objects` (the party buttons
  have no fixed names), and through a hook on `UF.Configure_Castbar` on a frame
  built later. Which bars it paints goes by the frame's `unitframeType` (`player`,
  `target`, `focus`, `pet`, `boss`, `party`).
  It listens to `COMBAT_LOG_EVENT_UNFILTERED` (not on `E.Modern`) and
  `SPELL_TEXT_UPDATE`.
- `Paint.lua` colours a bar. One school goes through ElvUI's own
  `UF:SetStatusBarColor`, which also tints the background and keeps a transparent
  bar's alpha. Several schools: pieces of ElvUI's bar texture across the whole bar,
  each a two-colour gradient (`SetGradient`) between two schools, above the hidden
  fill; a mask anchored to the fill's edge shows them only where the bar has
  filled, so the colours stay put as the bar grows. A bar that fills from the right
  gets everything mirrored. With ElvUI's "invert colours" the first school's
  colour is used alone.
- `Schools.lua` finds a spell's school mask (`Enum.Damageclass`, with the values
  built in for a client without the enum) and splits it into schools.
- `Debug.lua` is the only file that talks to the debug addons: with
  [OAP Debug](https://www.curseforge.com/wow/addons/oap-debug) (`/oapd`) installed
  the plugin registers with it (its Lua errors filed under its name) and sends log
  lines and counts; with _DebugLog (`DLAPI`) the same lines go to its own tab. What
  it sends: each spell whose school comes from its description, so a spell missing
  from the spell data (`tooltip:`), with the description itself at the detailed
  level. How much goes is `schoolCastbar.oapDebug`: `errors`, `normal`, `metrics`
  (the default) or `detailed`, on the General tab.
- `Options.lua` adds the page to ElvUI's options (`E.Options.args.ElvUI_SchoolCastbar`).
  The settings live in ElvUI's profile (`E.db.schoolCastbar`); your choices per
  spell and what the combat log named are account-wide (`ElvUI_SchoolCastbarDB`).

## Development

Tests and checks run with Lua 5.1 from the repository root:

```
lua tests/check.lua           StyLua, WoW Lua LS, then the tests with coverage
lua tests/check.lua test      the tests only
lua tests/check.lua format    formats all Lua with StyLua
```

`tests/setup-lua.ps1` installs Lua, LuaRocks, the test rocks and StyLua into `.lua\`
on Windows. `tests/wow.lua` simulates the client and the part of ElvUI the plugin
touches. Every line must be covered and every symbol typed; the types for ElvUI are
in `annotations/`.

The spell tables are generated. After a patch:

```
bash tools/fetch-spelldata.sh    the newest spell data per client from wago.tools
lua tools/spell-data.lua         Data\*.lua from it
```

Each table lists its spells per class (the class from the spell's family in
`SpellClassOptions`, else from its skill line, else for a Season of Discovery rune
from its Engrave ability), then per school, by name; then Pets, every spell on a
pet's skill line; what fits no class comes last, under Other. A spell is one line,
`Set(FIRE, 133, 143, ...)`, with its name above it: its school as a named local
(from `Enum.Damageclass`: `FIRE`, `FROSTFIRE`; a combination without a name of its
own joins its schools, `FIRE_FROST_ARCANE`), then the IDs of all its ranks, also
those named with a Roman numeral ("Instant Poison II").

A class spell is one on a skill line of category Class (less Mounts, Companions,
Engraving and the like; the pets' lines count), or taught by a specialization or a
talent (`Talent` on the classic clients, `TraitDefinition` on retail), less
professions' recipes; with a cast time (its `SpellCastTimes` base above 0 ms: the
instant ranged shots have a special -1000000 there) or a channel. A class spell
none of these names goes in `tools/spell-fixes.lua`.

The data goes to `../.spelldata/`, next to the repository, which the other addons in
that folder share.

Releases: push a version tag; the Release workflow runs the checks, packages the
addon and uploads it.

## License

MIT
