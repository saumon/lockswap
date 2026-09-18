#!/usr/bin/env bash

set -Eeuo pipefail

# --- Server hostname -> environment mapping ---
DEV_HOSTNAME="lockswap-dev"
DEV_BRANCH="dev"
DEV_RAILS_ENVIRONMENT="development"

PROD_HOSTNAME="lockswap"
PROD_BRANCH="master"
PROD_RAILS_ENVIRONMENT="production"
# ---

CURRENT_HOSTNAME="$(hostname -s)"

case "${CURRENT_HOSTNAME}" in
	"${DEV_HOSTNAME}")
		BRANCH="${DEV_BRANCH}"
		RAILS_ENVIRONMENT="${DEV_RAILS_ENVIRONMENT}"
		;;
	"${PROD_HOSTNAME}")
		BRANCH="${PROD_BRANCH}"
		RAILS_ENVIRONMENT="${PROD_RAILS_ENVIRONMENT}"
		;;
	*)
		echo "Unknown server hostname '${CURRENT_HOSTNAME}'. Expected '${DEV_HOSTNAME}' or '${PROD_HOSTNAME}'." >&2
		exit 1
		;;
esac

SERVICE_NAME="puma-lockswap"
# WORKER_SERVICE_NAME="solid-queue-lockswap"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCK_FILE="/tmp/update_lockswap_${BRANCH}.lock"

exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
	echo "A deployment is already in progress (lock: ${LOCK_FILE})."
	exit 1
fi

cd "${ROOT_DIR}"

service_stopped=false

cleanup() {
	local exit_code=$?
	if [[ ${exit_code} -ne 0 ]]; then
		echo "Error detected (code ${exit_code})."
		if [[ "${service_stopped}" == "true" ]]; then
			echo "Attempting to restart ${SERVICE_NAME}..."
			systemctl --user start "${SERVICE_NAME}" || true
			#echo "Attempting to restart ${WORKER_SERVICE_NAME}..."
			#systemctl --user start "${WORKER_SERVICE_NAME}" || true
		fi
	fi
}
trap cleanup EXIT

echo "[1/6] Stopping service ${SERVICE_NAME}..."
systemctl --user stop "${SERVICE_NAME}"
#echo "[1/6] Stopping service ${WORKER_SERVICE_NAME}..."
#systemctl --user stop "${WORKER_SERVICE_NAME}"
service_stopped=true

echo "[2/6] Updating ${BRANCH} branch (fast-forward only)..."
git fetch --all --prune
git checkout "${BRANCH}"
git pull --ff-only

echo "[3/6] Installing Ruby dependencies (if needed)..."
bundle install

echo "[4/6] Precompiling JavaScript/CSS assets in ${RAILS_ENVIRONMENT}..."
RAILS_ENV="${RAILS_ENVIRONMENT}" bundle exec rails assets:precompile

echo "[5/6] Running migrations in ${RAILS_ENVIRONMENT}..."
RAILS_ENV="${RAILS_ENVIRONMENT}" bin/rails db:migrate

echo "[6/6] Starting service ${SERVICE_NAME}..."
systemctl --user start "${SERVICE_NAME}"
#echo "[7/7] Starting service ${WORKER_SERVICE_NAME}..."
#systemctl --user start "${WORKER_SERVICE_NAME}"
service_stopped=false

echo "Checking service status..."
systemctl --user is-active --quiet "${SERVICE_NAME}"
#systemctl --user is-active --quiet "${WORKER_SERVICE_NAME}"

echo "Update completed ✅"
