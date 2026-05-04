#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-asterisk-snapshot}"
mkdir -p "$OUT"

copy_clean() {
  local src="$1"
  local dst="$2"
  if [[ -f "$src" ]]; then
    sed -E \
      -e 's/(secret[[:space:]]*=[[:space:]]*).*/\1__REDACTED__/Ig' \
      -e 's/(password[[:space:]]*=[[:space:]]*).*/\1__REDACTED__/Ig' \
      -e 's/(permit[[:space:]]*=[[:space:]]*).*/\1__REVIEW_IP__/Ig' \
      "$src" > "$dst"
  fi
}

copy_clean /etc/asterisk/pjsip_tauros_base.conf "$OUT/pjsip_tauros_base.conf"
copy_clean /etc/asterisk/manager_tauros.conf "$OUT/manager_tauros.conf"
copy_clean /etc/asterisk/extensions_tauros_base.conf "$OUT/extensions_tauros_base.conf"
copy_clean /etc/asterisk/pjsip_codex_agents.conf "$OUT/pjsip_codex_agents.conf"
copy_clean /etc/asterisk/queues_codex_discadora.conf "$OUT/queues_codex_discadora.conf"
copy_clean /etc/asterisk/extensions_codex_agents.conf "$OUT/extensions_codex_agents.conf"
copy_clean /etc/asterisk/extensions_codex_ivrs.conf "$OUT/extensions_codex_ivrs.conf"

asterisk -rx 'core show version' > "$OUT/core-version.txt" || true
asterisk -rx 'http show status' > "$OUT/http-status.txt" || true
asterisk -rx 'manager show settings' > "$OUT/manager-settings.txt" || true
asterisk -rx 'pjsip show transports' > "$OUT/pjsip-transports.txt" || true
asterisk -rx 'queue show' > "$OUT/queue-show.txt" || true

echo "Snapshot sanitizado salvo em: $OUT"

