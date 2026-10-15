#!/usr/bin/env bash
set -euo pipefail

NOTIFY_URL="${NOTIFY_URL:-https://notify.gauchoracing.com/api}"
SENTINEL_URL="${SENTINEL_URL:-https://sso.gauchoracing.com/api}"

discord_id=$(
  curl -fsS --max-time 10 "${SENTINEL_URL%/}/core/entity/external/GITHUB/${REVIEWER_ID}" \
    -H "Authorization: Bearer ${NOTIFY_TOKEN}" \
    | jq -r '[.external_auths[]? | select(.provider == "DISCORD") | .external_id][0] // empty'
) || {
  echo "::warning::Could not look up a Discord account for GitHub user ${REVIEWER_LOGIN}."
  discord_id=""
}

if [ -n "$discord_id" ]; then
  who="<@${discord_id}>"
else
  who="**${REVIEWER_LOGIN}**"
fi

if [[ "$PR_TITLE" =~ ^Deploy:\ ([^ ]+)\ to\ ([^ ]+) ]]; then
  service="${BASH_REMATCH[1]}"
  target="**${service^} ${BASH_REMATCH[2]}**"
else
  target="**${PR_TITLE}**"
fi

content="${who} wants to deploy ${target}! [infrastructure#${PR_NUMBER}](<${PR_URL}>)"

jq -n --arg channels "$DISCORD_CHANNEL_IDS" --arg content "$content" '{
  channel: "DISCORD",
  category: "deploy",
  recipients: { entity_ids: [], group_ids: [], discord_channel_ids: ($channels | split(" ") | map(select(. != ""))) },
  discord: {
    content: $content,
    webhook: { username: "GitHub", avatar_url: "https://notify.gauchoracing.com/logo/github.png" }
  }
}' | curl -fsS --max-time 15 -X POST "${NOTIFY_URL%/}/messages" \
  -H "Authorization: Bearer ${NOTIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @-
echo
