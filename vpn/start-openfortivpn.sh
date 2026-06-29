#!/usr/bin/env bash
set -euo pipefail

config_file="/etc/openfortivpn/config"

read_config() {
  local key="$1"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$config_file" | tail -n 1 | tr -d '\r'
}

vpn_host="$(read_config host)"
vpn_port="$(read_config port)"
vpn_username="$(read_config username)"
vpn_password="$(read_config password)"
vpn_trusted_cert="$(read_config trusted-cert)"

if [[ -z "$vpn_host" || -z "$vpn_port" || -z "$vpn_username" || -z "$vpn_password" ]]; then
  echo "Missing host, port, username or password in $config_file." >&2
  echo "Expected lines like: host = 1.2.3.4, port = 443, username = user, password = secret." >&2
  echo "Current non-empty config keys:" >&2
  sed -n 's/^[[:space:]]*\([^#;][^=[:space:]]*\)[[:space:]]*=.*/- \1/p' "$config_file" >&2 || true
  exit 1
fi

vpn_args=("${vpn_host}:${vpn_port}" -u "$vpn_username" -p "$vpn_password")

if [[ -n "$vpn_trusted_cert" ]]; then
  vpn_args+=(--trusted-cert "$vpn_trusted_cert")
fi

openfortivpn "${vpn_args[@]}" &
vpn_pid="$!"

for _ in $(seq 1 60); do
  if ! kill -0 "$vpn_pid" >/dev/null 2>&1; then
    wait "$vpn_pid"
  fi

  if ip link show ppp0 >/dev/null 2>&1; then
    sysctl -w net.ipv4.ip_forward=1 >/dev/null || true
    iptables -t nat -C POSTROUTING -o ppp0 -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE
    break
  fi
  sleep 1
done

if ! ip link show ppp0 >/dev/null 2>&1; then
  echo "VPN did not create ppp0 within 60 seconds; waiting for openfortivpn output." >&2
fi

wait "$vpn_pid"
