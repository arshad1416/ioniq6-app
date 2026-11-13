#!/usr/bin/env bash
# Installs the Ioniq 6 Home Assistant pieces on the Pi:
#   automations/27_ioniq6_*.yaml       -> /opt/homeassistant/automations/
#   custom_components/ioniq6_extras/   -> /opt/homeassistant/custom_components/
# Anything it replaces is backed up first. Run from a checkout of this repo:
#   git -C ~/ioniq6-app pull && sudo ~/ioniq6-app/ha/install.sh
set -euo pipefail

HA=${HA_CONFIG:-/opt/homeassistant}
CONTAINER=${HA_CONTAINER:-homeassistant}
HERE=$(cd "$(dirname "$0")" && pwd)
BACKUP="$HA/backups-ioniq6/$(date +%Y%m%d-%H%M%S)"

[ -f "$HA/configuration.yaml" ] || { echo "No Home Assistant config at $HA (set HA_CONFIG)." >&2; exit 1; }

changed_component=no
backup() { # backup <path relative to $HA>
  if [ -e "$HA/$1" ]; then
    mkdir -p "$BACKUP/$(dirname "$1")"
    cp -a "$HA/$1" "$BACKUP/$1"
  fi
}

for f in "$HERE"/automations/*.yaml; do
  rel="automations/$(basename "$f")"
  if ! cmp -s "$f" "$HA/$rel"; then
    backup "$rel"
    install -m 644 "$f" "$HA/$rel"
    echo "Updated $rel"
  fi
done

for d in "$HERE"/custom_components/*/; do
  name=$(basename "$d")
  rel="custom_components/$name"
  if ! diff -rq --exclude=__pycache__ "$d" "$HA/$rel" >/dev/null 2>&1; then
    backup "$rel"
    rm -rf "${HA:?}/$rel"
    mkdir -p "$HA/custom_components"
    cp -a "$d" "$HA/$rel"
    find "$HA/$rel" -name __pycache__ -prune -exec rm -rf {} +
    echo "Updated $rel"
    changed_component=yes
  fi
done

[ -d "$BACKUP" ] && echo "Backups of replaced files: $BACKUP"

if [ "$changed_component" = yes ]; then
  read -r -p "The add-on changed, so Home Assistant needs a restart. Restart $CONTAINER now? [y/N] " ok
  if [[ "$ok" =~ ^[Yy] ]]; then
    docker restart "$CONTAINER" >/dev/null && echo "Restarted $CONTAINER."
  else
    echo "Restart Home Assistant later to load it."
  fi
else
  echo "Reload automations in Home Assistant (Developer tools > YAML > Automations) to pick up changes."
fi
