#!/usr/bin/env bash
# Asks the platform at $ENDPOINT which Collector image to run and writes it to
# $GITHUB_OUTPUT as `image`. Every failure exits 1 with its own sentence: a
# check that verified nothing has not passed (#4148).
#
# A file of its own rather than inline in action.yml so that
# apps/analyzer/src/capture/resolve-collector.test.ts can run it.
set -euo pipefail

# The endpoint input's default, which we run. Set by the test to its own server.
CLOUD="${QUERY_DOCTOR_CLOUD:-https://cloud.querydoctor.com}"

endpoint="${ENDPOINT%/}"
url="$endpoint/ingest/collector"
body="$RUNNER_TEMP/query-doctor-collector.json"

if ! answer=$(curl --silent --show-error --max-time 30 \
  --output "$body" --write-out '%{http_code} %{content_type}' \
  --header "Authorization: Bearer $TOKEN" \
  "$url"); then
  echo "::error title=Query Doctor::Could not reach $endpoint to ask which Collector to run. Check the endpoint input; re-run if it was a network blip."
  exit 1
fi
read -r status content_type <<<"$answer"

case "$status" in
  200) ;;
  404)
    # Who sent the 404 decides the fix. On cloud the fault is ours. NestJS
    # answers a missing route with this JSON, so an app answered and lacks the
    # route. Anything else came from another server, such as a proxy.
    if [[ "$endpoint" == "$CLOUD" ]]; then
      echo "::error title=Query Doctor::$CLOUD returned HTTP 404 for /ingest/collector. The fault is on our end. No queries were checked; re-run the job later."
    elif jq -e '.statusCode == 404' "$body" >/dev/null 2>&1; then
      echo "::error title=Query Doctor::$url returned HTTP 404 because the app there has no such route. A Query Doctor platform older than query-doctor/ci@v1 has none; upgrade it. If $endpoint is not a Query Doctor platform, correct the endpoint input. No queries were checked."
    else
      # A workflow command ends at a newline and decodes %, so both are
      # escaped in the quoted body.
      excerpt=$(head -c 80 "$body" | tr '\r\n' '  ' | sed -e 's/[[:space:]]*$//' -e 's/%/%25/g')
      if [[ -n "$excerpt" ]]; then sent=": \"$excerpt\""; else sent=" with an empty body"; fi
      echo "::error title=Query Doctor::$url returned HTTP 404 (${content_type:-no content type})$sent. A Query Doctor platform answers an unknown route with JSON, so another server answered, such as a reverse proxy whose platform container is not running. Check that the container runs and that the proxy routes to it, then check the endpoint input. No queries were checked."
    fi
    exit 1 ;;
  401|403)
    echo "::error title=Query Doctor::$endpoint rejected the token. Check the QUERYDOCTOR_TOKEN secret."
    exit 1 ;;
  *)
    echo "::error title=Query Doctor::$endpoint answered HTTP $status when asked which Collector to run. Re-run the job; if it persists, the platform is unwell."
    exit 1 ;;
esac

image=$(jq -er '.image | select(type == "string" and length > 0)' "$body") || {
  echo "::error title=Query Doctor::$endpoint answered without naming a Collector image. The platform is newer or older than this action can read."
  exit 1
}
protocol=$(jq -r '.protocol' "$body")
echo "Platform at $endpoint speaks ingest protocol $protocol and names $image"
echo "image=$image" >> "$GITHUB_OUTPUT"
