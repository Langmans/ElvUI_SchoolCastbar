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
4. **The spell's description**: the client's own school names in it ("Fire damage",
   "Frostfire damage"), in the client's language. A switch on the General tab
   turns this off.

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
lua tools/spell-data.lua --names the same, each line ending in the spell's name, to read through
```

A class spell is one on a skill line of category Class (less Mounts, Companions,
Engraving and the like; the pets' lines count), or taught by a specialization or a talent (`Talent` on the classic
clients, `TraitDefinition` on retail), less professions' recipes; with a cast time
or a channel.

The data goes to `../.spelldata/`, next to the repository, which the other addons in
that folder share.

Releases: push a version tag; the Release workflow runs the checks, packages the
addon and uploads it.

## License

MIT
