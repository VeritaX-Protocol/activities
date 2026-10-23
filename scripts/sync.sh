#!/usr/bin/env bash
# Replica 1 a 1 los commits de los repos públicos de la organización como commits vacíos.
# Uso: scripts/sync.sh           (crea los commits que falten y verifica)
#      scripts/sync.sh verificar (solo compara conteos)
# Requiere: gh autenticado, git, y ejecutarse dentro del repo activities.
set -euo pipefail

ORG="${ORG:-VeritaX-Protocol}"
SELF="${SELF:-activities}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

repos() {
  gh api --paginate "orgs/$ORG/repos?type=public&per_page=100" --jq '.[].name' | grep -vx "$SELF" || true
}

# Una línea por commit: sha, fecha, nombre, email, asunto (separados por tabulador)
commits_de() {
  gh api --paginate "repos/$ORG/$1/commits?per_page=100" \
    --jq '.[] | [.sha, .commit.author.date, .commit.author.name, .commit.author.email, (.commit.message | split("\n")[0])] | @tsv' 2>/dev/null || true
}

# Source ya presentes en este repo (git log falla si aún no hay commits)
espejados() {
  git log --format=%B 2>/dev/null | grep -E '^Source: ' || true
}

sincronizar() {
  espejados > "$TMP/existentes"
  : > "$TMP/nuevos"
  for repo in $(repos); do
    commits_de "$repo" > "$TMP/$repo.tsv"
    while IFS=$'\t' read -r sha fecha nombre email asunto; do
      [ -z "$sha" ] && continue
      grep -qxF "Source: $ORG/$repo@$sha" "$TMP/existentes" && continue
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fecha" "$repo" "$sha" "$nombre" "$email" "$asunto" >> "$TMP/nuevos"
    done < "$TMP/$repo.tsv"
  done
  # Orden cronológico global (las fechas ISO 8601 UTC ordenan como texto)
  sort -t$'\t' -k1,1 "$TMP/nuevos" | while IFS=$'\t' read -r fecha repo sha nombre email asunto; do
    GIT_AUTHOR_NAME="$nombre" GIT_AUTHOR_EMAIL="$email" GIT_AUTHOR_DATE="$fecha" \
    GIT_COMMITTER_NAME="$nombre" GIT_COMMITTER_EMAIL="$email" GIT_COMMITTER_DATE="$fecha" \
      git commit --allow-empty -q -m "[$repo] $asunto" -m "Source: $ORG/$repo@$sha"
    echo "+ [$repo] $asunto"
  done
}

# Falla si algún repo tiene más commits que espejos
verificar() {
  espejados > "$TMP/existentes"
  local fallo=0
  for repo in $(repos); do
    local fuente espejos
    fuente="$(commits_de "$repo" | grep -c . || true)"
    espejos="$(grep -c "^Source: $ORG/$repo@" "$TMP/existentes" || true)"
    echo "$repo: fuente=$fuente espejos=$espejos"
    [ "$espejos" -lt "$fuente" ] && fallo=1
    [ "$espejos" -gt "$fuente" ] && echo "  aviso: hay más espejos que commits (historial reescrito en origen)"
  done
  return $fallo
}

[ "${1:-}" = "verificar" ] || sincronizar
verificar
