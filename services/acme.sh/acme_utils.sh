# ACME install helpers — source after scripts/common/utils.sh

function acme_lib_dir() {
    echo "$HIDDIFY_SERVICES/acme.sh/lib"
}

function acme_data_dir() {
    echo "$HIDDIFY_DATA/services/acme.sh"
}

function acme_config_home() {
    echo "$(acme_data_dir)/config"
}

function acme_cert_home() {
    echo "$(acme_data_dir)/certs"
}

function ensure_acme_data_dirs() {
    mkdir -p "$(acme_lib_dir)" "$(acme_config_home)" "$(acme_cert_home)" "$(acme_data_dir)/www"
}

function migrate_acme_durable_state() {
    local acme_lib acme_data config_home cert_home wrong_lib
    acme_lib="$(acme_lib_dir)"
    acme_data="$(acme_data_dir)"
    config_home="$(acme_config_home)"
    cert_home="$(acme_cert_home)"
    wrong_lib="$acme_data/lib"

    ensure_acme_data_dirs

    if [ -L "$acme_lib" ]; then
        rm -f "$acme_lib"
        mkdir -p "$acme_lib"
    fi

    # Previous revision mistakenly put the whole lib under data/
    if [ -d "$wrong_lib" ] && [ ! -L "$wrong_lib" ]; then
        if [ ! -x "$acme_lib/acme.sh" ] && [ -x "$wrong_lib/acme.sh" ]; then
            find "$wrong_lib" -mindepth 1 -maxdepth 1 \
                ! -name data ! -name certs \
                -exec cp -a {} "$acme_lib/" \;
        fi
        if [ -d "$wrong_lib/data" ] && [ -z "$(ls -A "$config_home" 2>/dev/null)" ]; then
            cp -a "$wrong_lib/data/." "$config_home/"
        fi
        if [ -d "$wrong_lib/certs" ] && [ -z "$(ls -A "$cert_home" 2>/dev/null)" ]; then
            cp -a "$wrong_lib/certs/." "$cert_home/"
        fi
        rm -rf "$wrong_lib"
    fi

    if [ -d "$acme_lib/data" ] && [ ! -L "$acme_lib/data" ]; then
        if [ -z "$(ls -A "$config_home" 2>/dev/null)" ]; then
            cp -a "$acme_lib/data/." "$config_home/"
        fi
        rm -rf "$acme_lib/data"
    fi
    if [ -d "$acme_lib/certs" ] && [ ! -L "$acme_lib/certs" ]; then
        if [ -z "$(ls -A "$cert_home" 2>/dev/null)" ]; then
            cp -a "$acme_lib/certs/." "$cert_home/"
        fi
        rm -rf "$acme_lib/certs"
    fi
}

function write_acme_env() {
    local acme_lib config_home cert_home
    acme_lib="$(acme_lib_dir)"
    config_home="$(acme_config_home)"
    cert_home="$(acme_cert_home)"
    cat >"$acme_lib/acme.sh.env" <<EOF
export LE_WORKING_DIR="$acme_lib"
export LE_CONFIG_HOME="$config_home"
export LE_CERT_HOME="$cert_home"
alias acme.sh="$acme_lib/acme.sh --config-home '$config_home' --cert-home '$cert_home'"
EOF
}

function install_acme_online() {
    local email="${1:?}"
    # Do not pipe args through get.acme.sh: it treats $1 as email=... so
    # `--home /path` becomes `----home` and install fails.
    curl -sL "https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh" |
        sh -s -- --install-online \
            --home "$(acme_lib_dir)" \
            --config-home "$(acme_config_home)" \
            --cert-home "$(acme_cert_home)" \
            --nocron \
            --noprofile \
            --email "$email"
}

function patch_acme_retry_overload() {
    local acme_sh
    acme_sh="$(acme_lib_dir)/acme.sh"
    if [ -x "$acme_sh" ] && ! grep -q 'return 10; fi' "$acme_sh"; then
        sed -i 's|_sleep_overload_retry_sec=$_retryafter|_sleep_overload_retry_sec=$_retryafter; if [[ "$_retryafter" > 20 ]];then return 10; fi|g' "$acme_sh"
    fi
}

function fix_acme_legacy_webroot_paths() {
    find "$(acme_config_home)" "$(acme_cert_home)" -type f -name '*.conf' 2>/dev/null -exec \
        sed -i 's|/opt/hiddify-manager/acme.sh/www/|/opt/hiddify-manager/data/services/acme.sh/www/|g' {} +
}
