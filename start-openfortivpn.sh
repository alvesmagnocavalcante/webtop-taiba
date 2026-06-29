#!/usr/bin/env bash
set -euo pipefail

openfortivpn -c /etc/openfortivpn/config &
vpn_pid="$!"

for _ in $(seq 1 60); do
  if ip link show ppp0 >/dev/null 2>&1; then
    sysctl -w net.ipv4.ip_forward=1 >/dev/null || true
    iptables -t nat -C POSTROUTING -o ppp0 -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE
    break
  fi
  sleep 1
done

wait "$vpn_pid"
