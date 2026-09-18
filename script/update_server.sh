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

# RVM : ce script est lancé depuis le hook post-receive via SSH, dans un
# shell non interactif / non login. On passe par le binaire RVM autonome
# (comme le fait déjà le unit systemd de Puma) plutôt que par
# `source .../rvm.sh` + `rvm use`, qui déclenche un bug connu de RVM
# ("gemset_name: unbound variable") en contexte non interactif.
RVM_BIN="/usr/local/rvm/bin/rvm"
RVM_RUBY="ruby-3.4.6"

# Inherited git env vars would override the repo detected below.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_CEILING_DIRECTORIES

# Follow symlinks so the script works when called through a link outside the repo.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
	SCRIPT_LINK_DIR="$(cd -P "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
	SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
	[[ "${SCRIPT_SOURCE}" != /* ]] && SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done

SCRIPT_DIR="$(cd -P "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
ROOT_DIR="$(cd -P "${SCRIPT_DIR}/.." && pwd)"
LOCK_FILE="/tmp/update_lockswap_${BRANCH}.lock"

# ROOT_DIR (le répertoire de déploiement) n'a plus son propre .git : c'est
# un simple work-tree, checkouté par le hook post-receive depuis le bare
# repo ci-dessous. Garder un second .git indépendant ici (ex. un vieux
# clone GitHub) ferait tirer ce script depuis la mauvaise source.
BARE_DIR="${HOME}/$(basename "${ROOT_DIR}").git"

if ! git --git-dir="${BARE_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
	echo "'${BARE_DIR}' is not a git repository." >&2
	exit 1
fi

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

echo "[2/6] Working tree already checked out by post-receive (branch ${BRANCH})"
DEPLOYED_SHA="$(git --git-dir="${BARE_DIR}" rev-parse --short "refs/heads/${BRANCH}")"
echo "Deployed commit: ${DEPLOYED_SHA}"

echo "[3/6] Installing Ruby dependencies (if needed)..."
"${RVM_BIN}" "${RVM_RUBY}" do bundle install

echo "[4/6] Precompiling JavaScript/CSS assets in ${RAILS_ENVIRONMENT}..."
RAILS_ENV="${RAILS_ENVIRONMENT}" "${RVM_BIN}" "${RVM_RUBY}" do bundle exec rails assets:precompile

echo "[5/6] Running migrations in ${RAILS_ENVIRONMENT}..."
RAILS_ENV="${RAILS_ENVIRONMENT}" "${RVM_BIN}" "${RVM_RUBY}" do bin/rails db:migrate

echo "[6/6] Starting service ${SERVICE_NAME}..."
systemctl --user start "${SERVICE_NAME}"
#echo "[7/7] Starting service ${WORKER_SERVICE_NAME}..."
#systemctl --user start "${WORKER_SERVICE_NAME}"
service_stopped=false

echo "Checking service status..."
systemctl --user is-active --quiet "${SERVICE_NAME}"
#systemctl --user is-active --quiet "${WORKER_SERVICE_NAME}"

echo "Update completed ✅"
