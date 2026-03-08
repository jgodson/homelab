#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAFANA_NAMESPACE="${GRAFANA_NAMESPACE:-monitoring}"
GRAFANA_SERVICE="${GRAFANA_SERVICE:-grafana}"
GRAFANA_PORT_FORWARD_PORT="${GRAFANA_PORT_FORWARD_PORT:-33000}"
GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:${GRAFANA_PORT_FORWARD_PORT}}"
GRAFANA_URL="${GRAFANA_URL%/}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

if [[ -z "${ALERT_EMAIL}" ]]; then
  echo "ALERT_EMAIL is required" >&2
  exit 1
fi

if [[ -z "${GRAFANA_USER:-}" ]]; then
  GRAFANA_USER="$(kubectl -n "${GRAFANA_NAMESPACE}" get secret grafana-admin-credentials -o jsonpath='{.data.admin-user}' | base64 -d)"
fi

if [[ -z "${GRAFANA_PASSWORD:-}" ]]; then
  GRAFANA_PASSWORD="$(kubectl -n "${GRAFANA_NAMESPACE}" get secret grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d)"
fi

PF_PID=""
if ! curl -fsS "${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
  kubectl -n "${GRAFANA_NAMESPACE}" port-forward "svc/${GRAFANA_SERVICE}" "${GRAFANA_PORT_FORWARD_PORT}:80" >/tmp/grafana-alerting-port-forward.log 2>&1 &
  PF_PID=$!
  sleep 2
fi

cleanup() {
  if [[ -n "${PF_PID}" ]]; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grafana-alerting.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"; cleanup' EXIT

CONTACT_POINT_RENDERED="${TMP_DIR}/contact-point.json"
POLICIES_RENDERED="${TMP_DIR}/policies.json"

sed "s/__ALERT_EMAIL__/${ALERT_EMAIL//\//\\/}/g" "${SCRIPT_DIR}/contact-point.template.json" > "${CONTACT_POINT_RENDERED}"
sed "s/__ALERT_EMAIL__/${ALERT_EMAIL//\//\\/}/g" "${SCRIPT_DIR}/policies.template.json" > "${POLICIES_RENDERED}"

CONTACT_UID="$(jq -r '.uid' "${CONTACT_POINT_RENDERED}")"
CONTACT_NAME="$(jq -r '.name' "${CONTACT_POINT_RENDERED}")"

if curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/v1/provisioning/contact-points" | jq -e --arg uid "${CONTACT_UID}" '.[] | select(.uid == $uid)' >/dev/null; then
  curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -H 'X-Disable-Provenance: true' \
    -X PUT \
    "${GRAFANA_URL}/api/v1/provisioning/contact-points/${CONTACT_UID}" \
    --data @"${CONTACT_POINT_RENDERED}" >/dev/null
else
  curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -H 'X-Disable-Provenance: true' \
    -X POST \
    "${GRAFANA_URL}/api/v1/provisioning/contact-points" \
    --data @"${CONTACT_POINT_RENDERED}" >/dev/null
fi

existing_policy_receiver="$(
  curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/v1/provisioning/policies" | jq -r '.receiver // empty'
)"

if [[ -n "${existing_policy_receiver}" && "${existing_policy_receiver}" != "${CONTACT_NAME}" ]]; then
  old_contact_uid="$(
    curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/v1/provisioning/contact-points" \
      | jq -r --arg name "${existing_policy_receiver}" '.[] | select(.name == $name) | .uid' | head -n 1
  )"
  if [[ -n "${old_contact_uid}" && "${old_contact_uid}" != "${CONTACT_UID}" ]]; then
    curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
      -H 'X-Disable-Provenance: true' \
      -X DELETE \
      "${GRAFANA_URL}/api/v1/provisioning/contact-points/${old_contact_uid}" >/dev/null || true
  fi
fi

curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -H 'X-Disable-Provenance: true' \
  -X PUT \
  "${GRAFANA_URL}/api/v1/provisioning/policies" \
  --data @"${POLICIES_RENDERED}" >/dev/null

for file in "${SCRIPT_DIR}"/rule-groups/*.json; do
  folder_uid="$(jq -r '.folderUid' "${file}")"
  group_title="$(jq -r '.title' "${file}")"
  group_title_encoded="$(jq -rn --arg v "${group_title}" '$v|@uri')"

  curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -H 'X-Disable-Provenance: true' \
    -X PUT \
    "${GRAFANA_URL}/api/v1/provisioning/folder/${folder_uid}/rule-groups/${group_title_encoded}" \
    --data @"${file}" >/dev/null
done

echo "Grafana homelab alerting applied."
