#!/bin/bash

# Copyright © 2016-2019 Mozg. All rights reserved.

## Deploy && Re-Deploy
# ls && rm -fr magento backdoor composer.lock && composer install -vvv

## Re-Deploy - 1
# sudo service apache2 restart && sudo service php7.2-fpm restart
# Obs. update "MAGE_CRYPT" `cat magento/app/etc/env.php`
# ls && mv magento magento-18
# rm -fr backdoor composer.lock && composer install -vvv

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
#set -Eeuxo pipefail
set -Eeu
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
function error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    echo "ERROR in ${JOB} : line ${LASTLINE} with exit code ${LASTERR}"
    exit 1
}
trap 'error ${LINENO} ${?}' ERR

#

function setVars {

  RED='\033[0;31m'
  NC='\033[0m' # No Color
  echo -e "${RED} ${FUNCNAME[0]} ${NC}"

  SOURCE_DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
  echo "SOURCE_DIR: $SOURCE_DIR"
  echo "SHELL: $SHELL"
  echo "TERM: $TERM"

  # Reset
  RESETCOLOR='\e[0m'       # Text Reset

  # Regular Colors
  BLACK='\e[0;30m'        # Black
  RED='\e[0;31m'          # Red
  GREEN='\e[0;32m'        # Green
  YELLOW='\e[0;33m'       # Yellow
  BLUE='\e[0;34m'         # Blue
  PURPLE='\e[0;35m'       # Purple
  CYAN='\e[0;36m'         # Cyan
  WHITE='\e[0;37m'        # White

  # Background
  ONBLACK='\e[40m'       # Black
  ONRED='\e[41m'         # Red
  ONGREEN='\e[42m'       # Green
  ONYELLOW='\e[43m'      # Yellow
  ONBLUE='\e[44m'        # Blue
  ONPURPLE='\e[45m'      # Purple
  ONCYAN='\e[46m'        # Cyan
  ONWHITE='\e[47m'       # White

  # Nice defaults
  NOW_2_FILE=$(date +%Y-%m-%d_%H-%M-%S)
  DATE_EN_US=$(date '+%Y-%m-%d %H:%M:%S')
  DATE_PT_BR=$(date '+%d/%m/%Y %H:%M:%S')

}

setVars

#

function test {
  fnc_before ${FUNCNAME[0]}
  echio "SUCCESS"
  fnc_after
}

function dotenv {
  set -a
  [ -f "$1" ] && . "$1"
  set +a
}

# https://stackoverflow.com/questions/1007538/check-if-a-function-exists-from-a-bash-script?lq=1
function function_exists {
  FUNCTION_NAME=$1
  [ -z "$FUNCTION_NAME" ] && return 1
  declare -F "$FUNCTION_NAME" > /dev/null 2>&1
  return $?
}

# https://unix.stackexchange.com/questions/212183/how-do-i-check-if-a-variable-exists-in-an-if-statement
has_declare() { # check if variable is set at all
    local "$@" # inject 'name' argument in local scope
    &>/dev/null declare -p "$name" # return 0 when var is present
}

function echio {
  local MESSAGE="$1"
  local COLOR=${2:-$GREEN}
  echo -e "${COLOR}${MESSAGE}${RESETCOLOR}"
}

function fnc_before {
  local _FUNCNAME="$1 {"
  echo -e "${ONBLUE}${_FUNCNAME}${RESETCOLOR}"
}

function fnc_after {
  echo -e "${ONBLUE}}${RESETCOLOR}"
}

# methods

function cd_magento_dir {

  fnc_before ${FUNCNAME[0]}

  pwd && cd $SOURCE_DIR/magento && pwd

  fnc_after

}

cd_magento_dir

function is_magento_dir {

  fnc_before ${FUNCNAME[0]}

  echio "pwd"

  pwd

  if [ ! -d "phpserver" ] ; then # if directory not exits
    echio "phpserver not exists"
    exit
  fi

  fnc_after

}

is_magento_dir

function load_dotenv {

  fnc_before ${FUNCNAME[0]}

  echio "env RDS_"
  env | grep ^RDS_ || true

  if has_declare name="AWS_PATH" ; then
    echo "variable present: AWS_PATH=$AWS_PATH"
  else

    local ENV_FILE="$SOURCE_DIR/.env"

    echio "Loading in the shell: ${ENV_FILE}"

    dotenv "${ENV_FILE}"

    echio "env RDS_"
    env | grep ^RDS_ || true

    echio "env MAGE_"
    env | grep ^MAGE_ || true

  fi

  fnc_after

}

function post_update_cmd { # post-update-cmd: occurs after the update command has been executed, or after the install command has been executed without a lock file present.
# Na heroku o Mysql ainda não foi instalado nesse ponto

fnc_before ${FUNCNAME[0]}

#pre_debug
# bash ./app.sh post_update_cmd

echio "ls -lah pub/media"

ls -lah pub/media

if has_declare name="AWS_PATH" ; then
  echo "variable present: AWS_PATH=$AWS_PATH"
  echio "composer require"
  /opt/elasticbeanstalk/support/composer.phar require thaiphan/magento-s3
fi

echio "backdoor"

[[ ! -d "../backdoor" ]] || { mkdir ../backdoor ; }

if [ -d vendor/prasathmani/tinyfilemanager ]; then
  echio "prasathmani/tinyfilemanager"
  cp -fr vendor/prasathmani/tinyfilemanager ../backdoor
fi

if [ -d vendor/maycowa/commando ]; then
  echio "maycowa/commando"
  cp -fr vendor/maycowa/commando ../backdoor
fi

profile

fnc_after

}

function post_install_cmd { # post-install-cmd: occurs after the install command has been executed with a lock file present.

fnc_before ${FUNCNAME[0]}

post_update_cmd

fnc_after

}

function postdeploy { # postdeploy command. Use this to run any one-time setup tasks that make the app, and any databases, ready and useful for testing.

fnc_before ${FUNCNAME[0]}

post_update_cmd # post-update-cmd: occurs after the update command has been executed, or after the install command has been executed without a lock file present.

fnc_after

}

function profile { # Heroku, During startup, the container starts a bash shell that runs any code in $HOME/.profile before executing the dynos command. You can put bash code in this file to manipulate the initial environment, at runtime, for all dyno types in your app.

  fnc_before ${FUNCNAME[0]}

  #echio "Na Heroku ao executar o profile não funciona o cache:disable" "$ONRED"
  #exit

  magento_before_install_set_permission

  magento_switch_symlinks_static_resources

  echio "check mysql"

  if type mysql >/dev/null 2>&1; then

    echio "mysql installed"

    mysql_select_admin_user

    if [ -z "$MYSQL_SELECT_ADMIN_USER" ]; then
      magento_install
    fi

  else
    echio "mysql not installed" "$ONRED"
  fi

  echio "magento_after_install"

  #if [ ! -f "../.env" ] ; then # if file not exits, only hosts ...
    #if [ ! -f "app/etc/env.php" ] ; then # if file not exits
      magento_after_install
    #fi
  #fi

  magento_after_install_set_permission

  echio "https://devdocs.magento.com/guides/v2.3/install-gde/install/post-install-config.html"

  echio "php bin/magento cron:install --force"

  #php bin/magento cron:install --force

  echio "crontab -l"

  crontab -l

  echio "https://devdocs.magento.com/guides/v2.3/install-gde/install/post-install-umask.html"

  echo 022 > magento_umask

  echio "pwd"

  pwd

  echio 'Get the permissions of a file in octal format:'

  stat -c "%a %n" var

  stat var

  [ -w var ] && echo "Writable" || echo "Not Writable"

  if [ ! -f "../n98-magerun2.phar" ]; then # if file not exist
    echio "n98-magerun2"
    #../n98-magerun2.phar db:status
    #../n98-magerun2.phar sys:check
    #../n98-magerun2.phar sys:info
  fi

  echio "-" "${ONYELLOW}"
  echio "-" "${ONCYAN}"

  fnc_after

}

function get_owner_group {

  fnc_before ${FUNCNAME[0]}

  echio "OWNER & GROUP"

  OWNER=$(whoami)

  echio "OWNER: $OWNER" "$ONCYAN"

  if has_declare name="AWS_PATH" ; then
    echo "variable present: AWS_PATH=$AWS_PATH"
    #OWNER='ec2-user'
    OWNER='webapp'
  fi

  echio "OWNER: $OWNER" "$ONCYAN"

  GROUP=$( ps aux | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1 ) || true

  echio "reads the exit status of the last command executed: $?"
  echio "$?" "$ONCYAN"

  echio "GROUP: $GROUP" "$ONCYAN"

  echio "groups"

  groups

  echio "groups OWNER"

  groups $OWNER

  echio "groups GROUP"

  groups $GROUP

  fnc_after

  }

function magento_before_install_set_permission {

  fnc_before ${FUNCNAME[0]}

  get_owner_group

  echio "https://devdocs.magento.com/guides/v2.3/install-gde/prereq/file-system-perms.html"

  echio "Set pre-installation file system ownership and permissions"

  echio "Set permissions for shared hosting (one user)

  This section discusses how to set pre-installation permissions if you log in to the Magento server as the same user that also runs the web server. This type of setup is common in shared hosting environments.

  To set ownership and permissions for a one-user system:"

  #find var generated vendor pub/static pub/media app/etc -type f -exec chmod u+w {} +
  #find var generated vendor pub/static pub/media app/etc -type d -exec chmod u+w {} +
  #chmod u+x bin/magento

  echio "Set ownership and permissions for two users

  This section discusses how to set ownership and permissions for your own server or a private hosting setup. In this type of setup, you typically cannot log in as, or switch to, the web server user. You typically log in as one user and run the web server as a different user.

  To set ownership and permissions for a two-user system:"

  echio "To confirm your user is a member of the web server group:"

  groups $OWNER

  echio "The following sample result shows the user’s primary ($OWNER) and secondary ($GROUP) groups."

  echio "magento_user : magento_user apache"

  echio "Set ownership and permissions for the shared group

  To set ownership and permissions before you install the Magento software:"

  echo "Fixing permissions for development/build environment"

  echo "magento_permission_reset"

  #rm -rf var/cache/ var/composer_home/ var/generation/ var/page_cache/ var/view_preprocessed/ var/log/ var/tmp pub/media/catalog/product/cache/ pub/static/frontend generated
  #find . -type f -exec chmod 644 {} \;
  #find . -type d -exec chmod 755 {} \;

  echio 'https://devdocs.magento.com/guides/v2.3/config-guide/prod/prod_file-sys-perms.html'

  echio "To set setgid and permissions for developer mode:"

  find var generated pub/static pub/media app/etc -type f -exec chmod g+w {} +
  find var generated pub/static pub/media app/etc -type d -exec chmod g+ws {} +

  echio "To make files and directories writable so you can update components and upgrade the Magento software:"

  find app/code lib var generated vendor pub/static pub/media app/etc \( -type d -or -type f \) -exec chmod g+w {} + && chmod o+rwx app/etc/env.php

  echo "chown"
  #chown -R :www-data .
  #chown -R :$GROUP $SOURCE_DIR/magento
  chown -R $OWNER:$GROUP $SOURCE_DIR/magento

  echo "chmod"
  chmod u+x bin/magento

  #if [ "$(whoami)" == "marcio" ]; then
    #sudo chmod -R 777 .
  #fi

  fnc_after

}

function magento_switch_symlinks_static_resources {

  fnc_before ${FUNCNAME[0]}

  echio "grep -ri"

  (grep -ri 'Symlink' app/etc/di.xml) || true

  echio "grep -rl"

  (grep -rl 'Symlink' app/etc/di.xml | xargs sed -i "s/Symlink/Copy/g") || true

  echio "grep -ri"

  (grep -ri 'Symlink' app/etc/di.xml) || true

  fnc_after

}

function mysql_show_tables {

  fnc_before ${FUNCNAME[0]}

  load_dotenv

  MYSQL_SHOW_TABLES=`mysql -h "${RDS_HOSTNAME}" -P "${RDS_PORT}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" "${RDS_DB_NAME}" -N -e "SHOW TABLES"`

  echio "-"

  #echo $MYSQL_SHOW_TABLES

  fnc_after

}

function mysql_select_admin_user {

  fnc_before ${FUNCNAME[0]}

  load_dotenv

  MYSQL_SELECT_ADMIN_USER=$(mysql -h "${RDS_HOSTNAME}" -P "${RDS_PORT}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" "${RDS_DB_NAME}" -N -e "SELECT * FROM admin_user") || true

  echio "-"

  echo $MYSQL_SELECT_ADMIN_USER

  fnc_after

}

function magento_install {

  fnc_before ${FUNCNAME[0]}

  load_dotenv

  echio "pwd"

  pwd

  echio "php bin/magento setup:install"

php bin/magento setup:install \
--base-url="$MAGE_URL" \
--db-host="${RDS_HOSTNAME}:${RDS_PORT}" \
--db-name="${RDS_DB_NAME}" \
--db-user="${RDS_USERNAME}" \
--db-password="${RDS_PASSWORD}" \
--backend-frontname="admin" \
--admin-firstname="Marcio" \
--admin-lastname="Amorim" \
--admin-email="mailer@mozg.com.br" \
--admin-user="admin" \
--admin-password="123456a" \
--language="pt_BR" \
--currency="BRL" \
--timezone="America/Sao_Paulo" \
--use-rewrites="1"

echio "-"

#after_install

echio "https://magenticians.com/why-magento-2-is-slow/"

# php bin/magento config:show dev/js/merge_files

#php bin/magento config:set catalog/frontend/flat_catalog_product 1
#php bin/magento config:set dev/js/enable_js_bundling 1 # Production
#php bin/magento config:set dev/js/merge_files 1
#php bin/magento config:set dev/js/minify_files 1
#php bin/magento config:set dev/css/merge_css_files 1
#php bin/magento config:set dev/css/minify_files 1
#php bin/magento config:set dev/static/sign 0

fnc_after

}

function magento_after_install {

  # bash ./app.sh magento_after_install

  fnc_before ${FUNCNAME[0]}

  create_env_file

  create_config_file

  #magento_build

  magento_deploy

  fnc_after

}

function create_env_file {

  fnc_before ${FUNCNAME[0]}

  if [ -f "app/etc/env.php" ]; then
    fnc_after
    return 0
  fi

  load_dotenv

  cp $SOURCE_DIR/env.php $SOURCE_DIR/magento/app/etc/

  #php -d memory_limit=-1 bin/magento setup:config:set --backend-frontname "admin" --db-host "${RDS_HOSTNAME}:${RDS_PORT}" --db-name "${RDS_DB_NAME}" --db-user "${RDS_USERNAME}" --db-engine "innodb" --db-password "${RDS_PASSWORD}" --db-prefix "" --db-model "mysql4" --session-save "files" --no-interaction

  MAGENTO_ADMIN_URL="admin"
  MAGENTO_CRYPT="${MAGE_CRYPT}"

  if [ -z "$MAGENTO_CRYPT" ]; then
    echo "FAILED: MAGENTO_CRYPT"
    exit
  fi

  MAGENTO_DB_HOST="${RDS_HOSTNAME}:${RDS_PORT}"
  MAGENTO_DB_NAME="${RDS_DB_NAME}"
  MAGENTO_DB_USER="${RDS_USERNAME}"
  MAGENTO_DB_PASSWORD="${RDS_PASSWORD}"

  MAGE_MODE="${MAGE_MODE}"

  MAGENTO_SESSION_HOST=""
  MAGENTO_SESSION_PORT=""
  MAGENTO_SESSION_DATABASE=""

  MAGENTO_CACHE_HOST=""
  MAGENTO_CACHE_PORT=""
  MAGENTO_CACHE_DATABASE=""

  MAGENTO_WEBCACHE_HOST=""

  sed -i "s/{{MAGENTO_ADMIN_URL}}/${MAGENTO_ADMIN_URL:-admin}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_CRYPT}}/${MAGENTO_CRYPT}/g" $SOURCE_DIR/magento/app/etc/env.php

  sed -i "s/{{MAGENTO_DB_HOST}}/${MAGENTO_DB_HOST}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_DB_NAME}}/${MAGENTO_DB_NAME}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_DB_USER}}/${MAGENTO_DB_USER}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_DB_PASSWORD}}/${MAGENTO_DB_PASSWORD}/g" $SOURCE_DIR/magento/app/etc/env.php

  sed -i "s/{{MAGE_MODE}}/${MAGE_MODE}/g" $SOURCE_DIR/magento/app/etc/env.php

  sed -i "s/{{MAGENTO_SESSION_HOST}}/${MAGENTO_SESSION_HOST}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_SESSION_PORT}}/${MAGENTO_SESSION_PORT}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_SESSION_DATABASE}}/${MAGENTO_SESSION_DATABASE}/g" $SOURCE_DIR/magento/app/etc/env.php

  sed -i "s/{{MAGENTO_CACHE_HOST}}/${MAGENTO_CACHE_HOST}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_CACHE_PORT}}/${MAGENTO_CACHE_PORT}/g" $SOURCE_DIR/magento/app/etc/env.php
  sed -i "s/{{MAGENTO_CACHE_DATABASE}}/${MAGENTO_CACHE_DATABASE}/g" $SOURCE_DIR/magento/app/etc/env.php

  sed -i "s/{{MAGENTO_WEBCACHE_HOST}}/${MAGENTO_WEBCACHE_HOST}/g" $SOURCE_DIR/magento/app/etc/env.php

  fnc_after

}

function create_config_file {

  fnc_before ${FUNCNAME[0]}

  echio "pwd"

  pwd

  if [ -f "app/etc/config.php" ]; then
    fnc_after
    return 0
  fi

  echio "module:enable"

  php bin/magento module:enable --all --clear-static-content

  fnc_after

}

function magento_deploy {

  # bash ../app.sh magento_deploy

  fnc_before ${FUNCNAME[0]}

  get_owner_group

  load_dotenv

  echio "SHOW DATABASES"

  mysql -h "${RDS_HOSTNAME}" -P "${RDS_PORT}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" -e 'SHOW DATABASES;'

  echio "deploy:mode:set"

  if has_declare name="AWS_PATH" ; then
    echo "variable present: AWS_PATH=$AWS_PATH"
    #MAGE_MODE="production"
    MAGE_MODE="developer"
  else
    MAGE_MODE="developer"
  fi

  #php bin/magento deploy:mode:set $MAGE_MODE

  #php bin/magento cache:flush

  echio "deploy:mode:show"
  #php bin/magento deploy:mode:show

  if [ "${MAGE_MODE}" == "production" ]; then # production / developer

    echio "setup"

    php bin/magento setup:upgrade --keep-generated #  -vvv
    php bin/magento setup:db-data:upgrade # -vvv
    php bin/magento setup:db-schema:upgrade # -vvv
    php bin/magento setup:db:status # -vvv
    php bin/magento setup:static-content:deploy en_US pt_BR -f # -vvv # -f is required if you are in development env)#

  fi

  if [ "${MAGE_MODE}" == "developer" ]; then

    echio "setup:upgrade"
    php bin/magento setup:upgrade

    echio "setup:db:status"
    #php bin/magento setup:db:status

    echio "cache"
    php bin/magento cache:disable
    php bin/magento cache:clean
    php bin/magento cache:flush
    php bin/magento cache:status

    echio "indexer"
    php bin/magento indexer:reindex
    php bin/magento indexer:status

    echio "maintenance:status"
    #php bin/magento maintenance:status

    echio "module:status"
    #php bin/magento module:status

  fi

  fnc_after

}

#

function download_n98_magerun2 {

  fnc_before ${FUNCNAME[0]}

  pwd

  [[ "$(command -v n98-magerun2)" ]] || { echo "n98-magerun2 is not installed" 1>&2 ; }
  [[ -f "./n98-magerun2.phar" ]] || { echo "n98-magerun2 local installed" 1>&2 ; }

  if [ ! -f "./n98-magerun2.phar" ]; then # if file not exist
    echio "n98-magerun2"
    wget https://files.magerun.net/n98-magerun2.phar
    chmod +x ./n98-magerun2.phar
  fi

  fnc_after

}

function run_n98_magerun2 {

  fnc_before ${FUNCNAME[0]}

  echio "check n98-magerun2"

  pwd

  #php bin/magento --version
  #../n98-magerun2.phar --version

  ../n98-magerun2.phar sys:check

  fnc_after

}

function magento_after_install_set_permission {

  fnc_before ${FUNCNAME[0]}

  if has_declare name="permission_success" ; then
   echo "variable present: permission_success=$permission_success"
  fi

  # FIX: Apache - Acesso aos arquivos de log
  # 1. Add your user to the www-data group.
  # sudo usermod -aG $GROUP $OWNER

  get_owner_group

  echio "https://devdocs.magento.com/guides/v2.3/install-gde/prereq/file-system-perms.html"

  echio "Set pre-installation file system ownership and permissions"

  echio "Set permissions for shared hosting (one user)

  This section discusses how to set pre-installation permissions if you log in to the Magento server as the same user that also runs the web server. This type of setup is common in shared hosting environments.

  To set ownership and permissions for a one-user system:"

  #find var generated vendor pub/static pub/media app/etc -type f -exec chmod u+w {} +
  #find var generated vendor pub/static pub/media app/etc -type d -exec chmod u+w {} +
  #chmod u+x bin/magento

  echio "Set ownership and permissions for two users

  This section discusses how to set ownership and permissions for your own server or a private hosting setup. In this type of setup, you typically cannot log in as, or switch to, the web server user. You typically log in as one user and run the web server as a different user.

  To set ownership and permissions for a two-user system:"

  echio "To confirm your user is a member of the web server group:"

  groups $OWNER

  echio "The following sample result shows the user’s primary ($OWNER) and secondary ($GROUP) groups."

  echio "magento_user : magento_user apache"

  echio "Set ownership and permissions for the shared group

  To set ownership and permissions before you install the Magento software:"

  echo "Fixing permissions for development/build environment"

  echo "magento_permission_reset"

  #rm -rf var/cache/ var/composer_home/ var/generation/ var/page_cache/ var/view_preprocessed/ var/log/ var/tmp pub/media/catalog/product/cache/ pub/static/frontend generated
  #find . -type f -exec chmod 644 {} \;
  #find . -type d -exec chmod 755 {} \;

  echio 'https://devdocs.magento.com/guides/v2.3/config-guide/prod/prod_file-sys-perms.html'

  echio "To set setgid and permissions for developer mode:"

  find var generated pub/static pub/media app/etc -type f -exec chmod g+w {} +
  find var generated pub/static pub/media app/etc -type d -exec chmod g+ws {} +

  echio "To make files and directories writable so you can update components and upgrade the Magento software:"

  find app/code lib var generated vendor pub/static pub/media app/etc \( -type d -or -type f \) -exec chmod g+w {} + && chmod o+rwx app/etc/env.php

  echo "chown"
  #chown -R :www-data .
  #chown -R :$GROUP $SOURCE_DIR/magento
  chown -R $OWNER:$GROUP $SOURCE_DIR/magento
  # chown $OWNER:$GROUP -R /var/app/current/magento/
  # chown marcio:www-data -R /home/marcio/dados/mozgbrasil/magento2/magento/
  # chown www-data:www-data -R /home/marcio/dados/mozgbrasil/magento2/magento/
  # chown ec2-user:webapp -R /var/app/current/

  echo "chmod"
  chmod u+x bin/magento

  #if [ "$(whoami)" == "marcio" ]; then
    #sudo chmod -R 777 $SOURCE_DIR/magento
  #fi

  fnc_after

  #

  permission_success='true'

  fnc_after

}

function release {
  fnc_before ${FUNCNAME[0]}
  fnc_after
}

function pre_debug {

fnc_before ${FUNCNAME[0]}

echio "pre_debug"

for i in `seq 11 20`; do
  echo "### $i"
  ls
  cp -fr magento-2 "magento-${i}"
  ls
done

exit

fnc_after

}

# https://github.com/salehawal/magento2-sysadmin/tree/master/bin

function magento_clean {

  fnc_before ${FUNCNAME[0]}

  echio ""

  rm -rf var/cache/ var/composer_home/ var/generation/ var/page_cache/ var/view_preprocessed/ var/log/ var/tmp pub/media/catalog/product/cache/ pub/static/frontend generated

  php bin/magento cache:disable
  php bin/magento cache:clean
  php bin/magento cache:flush
  php bin/magento cache:status

  chmod 777 -R *

  echo "Clean Done..."

  fnc_after

}

#

METHOD=${1}

if function_exists $METHOD; then
  $METHOD
else
  echio "Method not exists" "$ONRED"
fi
