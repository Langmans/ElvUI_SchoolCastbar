---@meta
-- Editor-only types: the parts of ElvUI the plugin touches, as ElvUI's own code defines them
-- (Game\Shared\Modules\UnitFrames), and the plugin's own tables. Not in the .toc, not in releases.

---ElvUI's global: { E, L, V, P, G }; the plugin uses the engine (E) and the profile defaults (P).
---@class ElvUIGlobal
---@field [1] ElvUIEngine
---@field [4] ElvUIProfileDefaults

---@type ElvUIGlobal
ElvUI = nil

---@class ElvUIEngine
---@field Modern boolean retail or WoW: Forever
---@field oUF {objects: SchoolCastbarFrame[]} ElvUI's oUF, with every frame it spawned
---@field media {blankTex: string}
---@field db {schoolCastbar: SchoolCastbarSettings}
---@field Options? {args: table<string, table>}
---@field GetModule fun(self: ElvUIEngine, name: "UnitFrames"): ElvUIUnitFrames
---@field NewModule fun(self: ElvUIEngine, name: string, ...: string): SchoolCastbarModule
---@field RegisterModule fun(self: ElvUIEngine, name: string)

---@class ElvUIProfileDefaults
---@field schoolCastbar SchoolCastbarSettings

---@class ElvUIUnitFrames
---@field SetStatusBarColor fun(self: ElvUIUnitFrames, bar: SchoolCastbarBar, r: number, g: number, b: number)
---@field GetInterruptColor fun(bar: SchoolCastbarBar, db: table, unit: string?): number, number, number
---@field Configure_Castbar fun(self: ElvUIUnitFrames, frame: SchoolCastbarFrame)

---A unit frame of ElvUI's, as far as the plugin reads it.
---@class SchoolCastbarFrame : Frame
---@field unitframeType string "player", "target", "focus", ...
---@field db table the frame's settings
---@field Castbar? SchoolCastbarBar

---An ElvUI cast bar: oUF's Castbar element with ElvUI's callbacks, and the plugin's own fields.
---@class SchoolCastbarBar : StatusBar
---@field __owner SchoolCastbarFrame
---@field __unit? string the unit of the cast, set by ElvUI's PostCastStart
---@field bg Texture
---@field spellName string|nil the cast's spell, set by oUF; may be hidden (issecretvalue)
---@field spellID number|nil
---@field notInterruptible boolean|nil
---@field invertColors boolean|nil ElvUI's "invert colours" for the bar
---@field PostCastStart fun(self: SchoolCastbarBar, unit: string)
---@field PostCastInterruptible fun(self: SchoolCastbarBar, unit: string)
---@field PostCastFail fun(self: SchoolCastbarBar, unit: string)
---@field PostCastInterrupted fun(self: SchoolCastbarBar, unit: string)
---@field schoolWrapped? boolean the plugin wrapped its callbacks
---@field schoolPieces? SchoolCastbarPieces the gradient's textures, once made

---One piece of a gradient: its texture and its two colours, kept for reuse.
---@class SchoolCastbarPiece
---@field texture Texture
---@field from ColorMixin
---@field to ColorMixin

---The pieces of a bar's gradient, and the mask that shows them where the bar has filled.
---@class SchoolCastbarPieces
---@field mask MaskTexture
---@field list SchoolCastbarPiece[]

---A colour as ElvUI's options store it.
---@class SchoolCastbarColor
---@field r number
---@field g number
---@field b number

---The plugin's settings, in ElvUI's profile (E.db.schoolCastbar).
---@class SchoolCastbarSettings
---@field units table<string, boolean> by unitframeType
---@field gradient boolean
---@field tooltip boolean
---@field colors table<string, SchoolCastbarColor> by school name

---The plugin's module: an ElvUI module with AceHook and AceEvent mixed in.
---@class SchoolCastbarModule
---@field GetName fun(self: SchoolCastbarModule): string
---@field SecureHook fun(self: SchoolCastbarModule, object: table, method: string, handler: string)
---@field RegisterEvent fun(self: SchoolCastbarModule, event: string, handler: string?)

---LibElvUIPlugin-1.0, the one call the plugin makes.
---@class LibElvUIPlugin
---@field RegisterPlugin fun(self: LibElvUIPlugin, name: string, callback: fun())

---The addon's namespace.
---@class SchoolCastbarNamespace
---@field data? table<number, number> the client's spell table: school mask by spell ID (Data\)
---@field Schools SchoolCastbarSchools
---@field units table<string, string>
---@field unitOrder string[]
---@field seen table<string, number|false>
---@field db fun(): SchoolCastbarSettings
---@field Paint fun(bar: SchoolCastbarBar, again: boolean?)
---@field Clear fun(bar: SchoolCastbarBar)
---@field RepaintAll fun()
---@field InsertOptions fun()

---The saved variables: the player's choices and what the combat log named, by spell name.
---@class SchoolCastbarSaved
---@field overrides? table<string, number>
---@field learned? table<string, number>

---@type SchoolCastbarSaved?
ElvUI_SchoolCastbarDB = nil
