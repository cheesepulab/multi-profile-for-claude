#!/bin/bash
# Lists the code-signing certificates on this Mac and the team each one belongs to.
#
# The code in brackets in a certificate's name, as in "Apple Development: Jane Doe (AB12CD34EF)",
# is your user ID on that certificate, not the team. The team is recorded inside the certificate:
# a free Personal Team shows your own name as the team, a company team shows the company.
set -euo pipefail

security find-identity -v -p codesigning \
  | sed -nE 's/^ *[0-9]+\) ([0-9A-F]{40}) "(.*)"$/\1|\2/p' \
  | while IFS='|' read -r hash name; do
      pem="$(security find-certificate -a -Z -p -c "$name" | awk -v h="$hash" '
        /^SHA-1 hash:/ { take = ($3 == h) }
        take && /-----BEGIN CERTIFICATE-----/ { printing = 1 }
        printing { print }
        printing && /-----END CERTIFICATE-----/ { exit }')"
      subject="$(printf '%s\n' "$pem" | openssl x509 -noout -subject -nameopt multiline)"
      team_id="$(printf '%s\n' "$subject" | sed -nE 's/^ *organizationalUnitName *= *//p')"
      team_name="$(printf '%s\n' "$subject" | sed -nE 's/^ *organizationName *= *//p')"
      expires="$(printf '%s\n' "$pem" | openssl x509 -noout -enddate | cut -d= -f2)"
      printf '%s\n  team:    %s (%s)\n  hash:    %s\n  expires: %s\n\n' "$name" "$team_name" "$team_id" "$hash" "$expires"
    done
