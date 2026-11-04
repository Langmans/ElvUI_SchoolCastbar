-- Class spells that no table tools/spell-data.lua reads puts down as one, by product (the
-- folder names in ../.spelldata) and spell ID. `true` takes the spell in with its school from the
-- client's SpellMisc; a number gives it that school mask instead (Enum.Damageclass). The script
-- says so when a fix finds no spell with a cast bar.
--
--   wow_classic = {
--       [605] = true, -- Dominate Mind
--   },
return {}
