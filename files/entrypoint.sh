#!/bin/bash

MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
[ -z "$MYSQL_HOST" ] && MYSQL_HOST=db
[ -z "$MYSQL_PORT" ] && MYSQL_PORT=3306
[ -z "$MYSQL_USER" ] && MYSQL_USER=misp
[ -z "$MYSQL_PASSWORD" ] && MYSQL_PASSWORD=example
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE=misp
[ -z "$REDIS_FQDN" ] && REDIS_FQDN=redis
[ -z "$MISP_MODULES_FQDN" ] && MISP_MODULES_FQDN="http://misp-modules"
[ -z "$MYSQLCMD" ] && MYSQLCMD="mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -P $MYSQL_PORT -h $MYSQL_HOST -r -N  $MYSQL_DATABASE"

setup_cake_config(){
    sed -i "s/'host' => 'localhost'.*/'host' => '$REDIS_FQDN',          \/\/ Redis server hostname/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"
    sed -i "s/'host' => '127.0.0.1'.*/'host' => '$REDIS_FQDN',          \/\/ Redis server hostname/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"
}

init_misp_files(){
    if [ ! -f /var/www/MISP/app/files/INIT ]; then
        cp -R /var/www/MISP/app/files.dist/* /var/www/MISP/app/files
        touch /var/www/MISP/app/files/INIT
    fi
}

init_ssl() {
    if [[ (! -f /etc/nginx/certs/cert.pem) || (! -f /etc/nginx/certs/key.pem) ]];
    then
        cd /etc/nginx/certs
        openssl req -x509 -subj '/CN=localhost' -nodes -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365
    fi
}

init_mysql(){
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    RETRY=100
    until [ $(isDBup) -eq 0 ] || [ $RETRY -le 0 ] ; do
        echo "Waiting for database to come up"
        sleep 5
        RETRY=$(( RETRY - 1))
    done
    if [ $RETRY -le 0 ]; then
        >&2 echo "Error: Could not connect to Database on $MYSQL_HOST:$MYSQL_PORT"
        exit 1
    fi

    if [ $(isDBinitDone) -eq 0 ]; then
        echo "Database has already been initialized"
    else
        echo "Database has not been initialized, importing MySQL scheme..."
        $MYSQLCMD < /var/www/MISP/INSTALL/MYSQL.sql
    fi
}

sync_files(){
    for DIR in $(ls /var/www/MISP/app/files.dist); do
        rsync -azh -p -g -o --delete "/var/www/MISP/app/files.dist/$DIR" "/var/www/MISP/app/files/"
    done
}

# Things that should ALWAYS happen
#echo "Configure Cake | Change Redis host to $REDIS_FQDN ... " && setup_cake_config

# Things we should do if we're configuring MISP via ENV
#echo "Configure MISP | Initialize misp base config..." && init_misp_config2

#echo "Configure MISP | Sync app files..." && sync_files

# Work around https://github.com/MISP/MISP/issues/5608
if [[ ! -f /var/www/MISP/PyMISP/pymisp/data/describeTypes.json ]]; then
    mkdir -p /var/www/MISP/PyMISP/pymisp/data/
    ln -s /usr/local/lib/python3.7/dist-packages/pymisp/data/describeTypes.json /var/www/MISP/PyMISP/pymisp/data/describeTypes.json
fi

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf