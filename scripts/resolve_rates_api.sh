#!/usr/bin/env bash
# Honor explicit test endpoints. Treat the old Sites URL as the legacy default
# so existing Pages and Actions settings do not override the backend cutover.
case "${RATES_API:-}" in
  ''|'https://bahtzay-rates.muddyhinny2048.chatgpt.site'|'https://bahtzay-rates.muddyhinny2048.chatgpt.site/') printf '%s\n' 'https://bahtzay-api-staging.sharedbyatt.workers.dev' ;;
  *) printf '%s\n' "${RATES_API%/}" ;;
esac
