#!/bin/bash
source /opt/hiddify-manager/scripts/common/utils.sh
source /opt/hiddify-manager/services/mysql/mysql_utils.sh
cd "$(dirname -- "$0")"

ensure_hiddify_data_dirs
ensure_mysql_data_dirs
install_package mariadb-server

MYSQL_PASS="$(ensure_mysql_password)"
migrate_mysql_datadir "$(current_mysql_datadir)" "$(hiddify_mysql_datadir)"
configure_mysql_server
start_mysql_server

# Secure root only on first password generation; always sync panel user to password file
if [ "${HIDDIFY_MYSQL_PASS_IS_NEW:-0}" = "1" ]; then
    setup_mysql_panel_user "$MYSQL_PASS"
else
    sync_mysql_panel_user "$MYSQL_PASS"
fi
