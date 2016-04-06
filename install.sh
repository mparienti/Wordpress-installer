#!/bin/bash
#
# install a wordpress

set -e

# Some variable you can modify
GET_WORDPRESS="wget --quiet http://wordpress.org/latest.tar.gz"
MYSQL_CMD=mysql
DEFAULT_DATABASE_HOST=localhost

usage() {
    echo "$(basename ${0}) -d <install-dir> (others options…)"
    echo ""
    echo "Other options:"
    echo "-t target_directory (default: current directory)"
    echo "-q: use this option to run the script in quiet mode: nothing will be displayed, unless an error happens"
    echo "-d database_name (default: random)"
    echo "-d database_user (default: random)"
    echo "-p database_password (default: random)"
    echo "-o database_host (default: ${DEFAULT_DATABASE_HOST})"
    echo "-c: create database (default: no) - You must have the right mysql perms to do so"
    echo "-w: create database user (default: no) - You must have the right mysql perms to do so"
}

log() {
    if [ -n "${QUIET}" ]; then
        return
    fi
    printf "$@"
    printf "\n"
}

eprintf()
{
    >&2 printf "$@"
    >&2 printf "\n"
}

# $1: if set the size of the string (default: 32 caracters)
# $2: if set return only alphabetics caracters
random_string() {
    local size=32
    local regexp='a-zA-Z0-9'
    if [ -n "${1}" ]; then
        size=${1}
    fi
    if [ -n "${2}" ]; then
        regexp=${2}
    fi
    echo $(cat /dev/urandom | tr -dc $regexp | fold -w $size | head -n 1)
}

download_extract() {
    log "Install wordpress into ${INSTALL_DIR} directory"
    if [ -f latest.tar.gz ]; then
        eprintf "File latest.tar.gz already present in current directory.\nPlease delete it.\n"
        exit 2
    fi
    if [ -f "${INSTALL_DIR}" ] || [ -d "${INSTALL_DIR}" ]; then
        eprintf "${INSTALL_DIR} already present in current directory.\nPlease delete it.\n"
        exit 2
    fi
    if [ -n "${TARGET_DIRECTORY}" ] ; then
        if ! [ -w "${TARGET_DIRECTORY}" ] ; then
            eprintf  "${TARGET_DIRECTORY}/${INSTALL_DIR} no writable"
            exit 2
        fi
        if [ -f "${TARGET_DIRECTORY}/${INSTALL_DIR}" ] || [ -d "${TARGET_DIRECTORY}/${INSTALL_DIR}" ]; then
            eprintf "${TARGET_DIRECTORY}/${INSTALL_DIR} already exists.\nPlease delete it.\n"
            exit 2
        fi
    fi
    $GET_WORDPRESS
    log "WordPress source downloaded"
    tar -xzf latest.tar.gz
    log "WordPress uncompressed"
    rm latest.tar.gz
    rm wordpress/readme.html
    rm wordpress/license.txt
    mv wordpress "${INSTALL_DIR}"
}

configure_setting() {
    local random

    if [ -z "${DATABASE_NAME}" ]; then
        DATABASE_NAME=$(random_string 16 'a-zA-Z')
    fi
    if [ -z "${DATABASE_USER}" ]; then
        DATABASE_USER=$(random_string 16 'a-zA-Z')
    fi
    if [ -z "${DATABASE_HOST}" ]; then
        DATABASE_HOST=${DEFAULT_DATABASE_HOST}
    fi
    if [ -z "${DATABASE_PASSWORD}" ]; then
        DATABASE_PASSWORD=$(random_string)
    fi
    cd ${INSTALL_DIR}
    cp wp-config-sample.php wp-config.php
    log "Configure database"
    sed -i "s/database_name_here/${DATABASE_NAME}/" wp-config.php
    sed -i "s/username_here/${DATABASE_USER}/" wp-config.php
    sed -i "s/password_here/${DATABASE_PASSWORD}/" wp-config.php
    sed -i "s/localhost/${DATABASE_HOST}/" wp-config.php
    log "Generate random strings (salts & keys)"
    while [ -n "$(grep 'put your unique phrase here' wp-config.php)" ] ;
    do
        random=$(random_string 64 '[a-zA-Z0-9_@#%^*():;`.,\]\[{}]')
        sed -i "0,/put your unique phrase here/{s/put your unique phrase here/${random}/}" wp-config.php
    done
    cd ..
}

create_database() {
    echo "CREATE DATABASE IF NOT EXISTS ${DATABASE_NAME}" | $MYSQL_CMD -h ${DATABASE_HOST};
}

create_database_user() {
    if [ "${DATABASE_HOST}"  == "localhost" ]; then
        echo "CREATE USER '${DATABASE_USER}'@'localhost' IDENTIFIED BY '${DATABASE_PASSWORD}';" | $MYSQL_CMD -h ${DATABASE_HOST}
        echo "GRANT ALL PRIVILEGES ON ${DATABASE_NAME}.* TO '${DATABASE_USER}'@'localhost';" | $MYSQL_CMD -h ${DATABASE_HOST}
    else
        echo "CREATE USER '${DATABASE_USER}'@'%' IDENTIFIED BY '${DATABASE_PASSWORD}';" | $MYSQL_CMD -h ${DATABASE_HOST}
        echo "GRANT ALL PRIVILEGES ON ${DATABASE_NAME}.* TO '${DATABASE_USER}'@'%';" | $MYSQL_CMD -h ${DATABASE_HOST}
    fi
    echo "FLUSH PRIVILEGES;" | $MYSQL_CMD -h ${DATABASE_HOST}
}

if [ -z ${1} ]; then
    usage
    exit 1
fi


while getopts hqcwd:t:d:u:p:o: OPT; do
    case "$OPT" in
        h)
            usage
            exit 0
            ;;
        q)
            readonly QUIET=yes
            ;;
        d)
            readonly INSTALL_DIR=${OPTARG}
            ;;
        c)
            readonly CREATE_DATABASE=yes
            ;;
        w)
            readonly CREATE_DATABASE_USER=yes
            ;;
        t)
            readonly TARGET_DIRECTORY=${OPTARG}
            ;;
        d)
            readonly DATABASE_NAME=${OPTARG}
            ;;
        u)
            readonly DATABASE_USER=${OPTARG}
            ;;
        p)
            readonly DATABASE_PASSWORD=${OPTARG}
            ;;
        o)
            readonly DATABASE_HOST=${OPTARG}
            ;;
        *)
            eprintf  "Unknown option: ${OPTARG}"
            ;;
    esac
done

download_extract

configure_setting

if [ -n "${CREATE_DATABASE}" ]; then
    create_database
fi

if [ -n "${CREATE_DATABASE_USER}" ]; then
    create_database_user
fi

if [ -n "${TARGET_DIRECTORY}" ]; then
    mv "${INSTALL_DIR}"  "${TARGET_DIRECTORY}"
fi

log "Wordpress sucessfully installed"

exit 0
