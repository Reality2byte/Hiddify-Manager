# Redis helpers — source after scripts/common/utils.sh

function hiddify_redis_pass_file() {
    echo "$HIDDIFY_DATA/redis/redis_pass"
}

function hiddify_redis_live_conf() {
    echo "$HIDDIFY_DATA/redis/redis.conf"
}

function ensure_redis_data_dirs() {
    mkdir -p "$HIDDIFY_DATA/redis"
    chown redis:redis "$HIDDIFY_DATA/redis" 2>/dev/null || true
}

function redis_pass_from_conf() {
    local conf="$1"
    local pass=""
    [ -f "$conf" ] || return 1
    pass="$(grep '^requirepass ' "$conf" 2>/dev/null | awk '{print $2}' | tail -n1 || true)"
    [ -n "$pass" ] || return 1
    printf '%s\n' "$pass"
}

function get_redis_password() {
    cat "$(hiddify_redis_pass_file)"
}

# Idempotent Redis durable state under data/.
# - Password file: created once (migrate from conf requirepass, else generate)
# - Live conf: copied from package template once; requirepass injected only when
#   missing or when --sync is passed (install-time repairs / password changes)
function ensure_redis_data() {
    ensure_redis_data_dirs
    local force_sync=0
    if [ "${1:-}" = "--sync" ]; then
        force_sync=1
        shift
    fi
    local pass_file live_conf template pass
    pass_file="$(hiddify_redis_pass_file)"
    live_conf="$(hiddify_redis_live_conf)"
    template="${1:-$HIDDIFY_SERVICES/redis/redis.conf}"

    if [ ! -f "$pass_file" ]; then
        pass="$(redis_pass_from_conf "$live_conf" || redis_pass_from_conf "$template" || true)"
        [ -n "$pass" ] || pass="$(hiddify_random_password)"
        echo "$pass" >"$pass_file"
        chmod 600 "$pass_file"
    fi

    # Keep packaged template free of secrets
    sed -i '/^requirepass /d' "$template" 2>/dev/null || true

    if [ ! -f "$live_conf" ]; then
        cp "$template" "$live_conf"
        force_sync=1
    fi

    if [ "$force_sync" = 1 ] || ! grep -q '^requirepass ' "$live_conf"; then
        sed -i '/^requirepass /d' "$live_conf"
        echo "requirepass $(cat "$pass_file")" >>"$live_conf"
    fi
    chmod 600 "$live_conf" "$pass_file"
    chown redis:redis "$live_conf" "$pass_file" 2>/dev/null || true
}
