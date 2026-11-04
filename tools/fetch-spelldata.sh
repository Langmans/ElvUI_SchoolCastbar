#!/usr/bin/env bash
# Downloads the spell tables tools/spell-data.lua reads, for every client the plugin loads on, from
# wago.tools as CSV, into ../.spelldata/<product>/<version>/<Table>.csv: the folder the other
# addons beside this one share (its own fetch.sh gets more tables). The newest build of each
# product; a table already there is skipped. Run from the repository root, then
# `lua tools/spell-data.lua`. Usage: bash tools/fetch-spelldata.sh [product ...]
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .spelldata
cd .spelldata

# wago.tools answers a custom User-Agent with 403.
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130 Safari/537.36"
PRODUCTS=("${@:-wow_classic_era wow_anniversary wow_classic_titan wow_classic wow wowf}")
# SpecializationSpells and the talent tables exist only on some clients (Talent up to Mists,
# TraitDefinition on retail); elsewhere their download fails, which is fine.
TABLES=(SpellName SpellMisc SpellClassOptions SkillLine SkillLineAbility SpecializationSpells Talent TraitDefinition)

latest=$(curl -s -A "$UA" "https://wago.tools/api/builds/latest")
for product in ${PRODUCTS[@]}; do
    version=$(printf '%s' "$latest" | grep -oE "\"$product\":\{\"product\":\"$product\",\"version\":\"[0-9.]+\"" |
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
    if [ -z "$version" ]; then
        echo "$product: no build on wago.tools" >&2
        continue
    fi
    dir="$product/$version"
    mkdir -p "$dir"
    for table in "${TABLES[@]}"; do
        file="$dir/$table.csv"
        if [ -s "$file" ]; then continue; fi
        curl -s -f -A "$UA" -o "$file" "https://wago.tools/db2/$table/csv?build=$version" ||
            { echo "$product $version $table: not on wago.tools" >&2; rm -f "$file"; }
        sleep 2 # be kind to wago.tools
    done
    echo "$product $version: $(ls "$dir" | wc -l) tables"
done
