#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
WEBAPP_DEFAULT_PATH="/var/lib/tomcat9/webapps/ROOT.war"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
    case $key in
        -nginx)
            INSTALL_NGINX="$2"
            shift
            shift
            ;;
        -db|-mongo|-mongodb)
            INSTALL_MONGODB="$2"
            shift
            shift
            ;;
        -db.host)
            DB_HOST="$2"
            shift
            shift
            ;;
        -db.port)
            DB_PORT="$2"
            shift
            shift
            ;;
        -db.name) 
            DB_NAME="$2"
            shift
            shift
            ;;
        -db.user)
            DB_USER="$2"
            shift
            shift
            ;;
        -db.pass|-db.password|-db.pwd)
            DB_PASSWORD="$2"
            shift
            shift
            ;;
        -files)
            FILES_ROOT="$2"
            shift
            shift
            ;;
        -webapp)
            WEBAPP_PATH="$2"
            shift
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

while [[ -z $INSTALL_NGINX ]]
do
    read -p "Install NginX(y|n)? " -n1 answer;
    if [[ $answer = 'y' || $answer = 'Y' ]]; then
        INSTALL_NGINX="yes"
    elif [[ $answer = 'n' || $answer = 'N' ]]; then
        INSTALL_NGINX="no"
    fi
    echo
done
while [[ -z $INSTALL_MONGODB ]]
do
    read -p "Install MongoDB(y|n)? " -n1 answer;
    if [[ $answer = 'y' || $answer = 'Y' ]]; then
        INSTALL_MONGODB="yes"
    elif [[ $answer = 'n' || $answer = 'N' ]]; then
        INSTALL_MONGODB="no"
    fi
    echo
done

if [ -z $FILES_ROOT ]; then
    read -p "MiDM Files path(/MiDM): " FILES_ROOT;
    if [ -z $FILES_ROOT ]; then
        FILES_ROOT="/MiDM"
    fi
fi

if [ -z $WEBAPP_PATH ]; then
    read -p "Webapp file path(include file name): " WEBAPP_PATH;
fi

if [ -z $DB_HOST ]; then
    read -p "DB Host address or domain name(127.0.0.1): " DB_HOST;
    if [ -z $DB_HOST ]; then
        DB_HOST="127.0.0.1"
    fi
fi
if [ -z $DB_PORT ]; then
    read -p "DB Port(27017): " DB_PORT;
    if [ -z $DB_PORT ]; then
        DB_PORT=27017
    fi
fi
while [[ -z $DB_NAME ]]
do
    read -p "DB name: " DB_NAME;
done
while [[ -z $DB_USER ]]
do
    read -p "DB user name: " DB_USER;
done
while [[ -z $DB_PASSWORD ]]
do
    read -p "DB user password: " DB_PASSWORD;
done
echo
echo "============================================================"
echo "Setup MiDM Host in Ubuntu 20.04"
echo "============================================================"
echo "Install NginX:        $INSTALL_NGINX"
echo "Install MongoDB:      $INSTALL_MONGODB"
echo "MiDM file path:       $FILES_ROOT"
if [ -z $WEBAPP_PATH ]; then
    echo "Webapp file path: <Default tomcat webapp folder>"
else
    echo "Webapp file path: $WEBAPP_PATH"
fi
echo "Database configuration:"
echo "  - Host:             $DB_HOST"
echo "  - Port:             $DB_PORT"
echo "  - DB Name:          $DB_NAME"
echo "  - User name:        $DB_USER"
echo "  - User password:    $DB_PASSWORD"
echo "------------------------------------------------------------"
echo

while [[ -z $SETUP ]]
do
    read -p "Continue to setup host(y|n)? " -n1 answer;
    if [[ $answer = 'y' || $answer = 'Y' ]]; then
        SETUP="yes"
    elif [[ $answer = 'n' || $answer = 'N' ]]; then
        SETUP="no"
    fi
    echo
done

if [ $SETUP = 'no' ]; then
    echo "MiDM host setup has been canceled."
    echo
    exit 1
fi

echo "------------------------------------------------------------"
echo "MiDM host setup has been started. It will take a few minutes."
echo "Do not power off the host until setting finished."
echo "------------------------------------------------------------"
echo

mkdir -p $FILES_ROOT
# Generate MiDM properties
mkdir /etc/MiDM
cat > /etc/MiDM/midm.properties <<EOF
mongo.host = $DB_HOST
mongo.port = $DB_PORT
mongo.dbname = $DB_NAME
mongo.username = $DB_USER
mongo.password = $DB_PASSWORD
EOF

echo "- MiDM Properties was generated."
echo "- Updating installed packages."
apt-get update -y -qq
echo "- Installing JAVA 11."
# Install JAVA
apt install -y -qq default-jdk
# Configure JAVA home
echo "JAVA_HOME=\"/usr/lib/jvm/java-11-openjdk-amd64\"" >> /etc/environment
source /etc/environment
echo "- JAVA 11 has been installed."

if [[ $INSTALL_MONGODB == "yes" ]]; then
    # Install MongoDB
    echo "- Installing MongoDB 4"
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update -y -qq
    apt-get install -y -qq mongodb-org
    service mongod start
    systemctl enable mongod
    sleep 2
    # Generate DB and add administrator
    mongo $DB_NAME --eval "db.createUser({user:'$DB_USER', pwd:'$DB_PASSWORD', roles:['readWrite','dbAdmin']})"
    mongorestore --quiet -h=$DB_HOST:$DB_PORT -d $DB_NAME -u=$DB_USER -p=$DB_PASSWORD --drop --gzip --archive=$SCRIPT_DIR/mongodb/resources.gz
fi

# Install Tomcat 9
echo "- Installing Tomcat 9"
apt install -y -qq tomcat9
rm -rf /var/lib/tomcat9/webapps/ROOT
service tomcat stop
chown -R tomcat:tomcat $FILES_ROOT
sleep 2
# Deploy latest webapp file.
if [ -z $WEBAPP_PATH ]; then
    WEBAPP_PATH="/var/lib/tomcat9/webapps/ROOT.war"
elif [[ $WEBAPP_PATH != $WEBAPP_DEFAULT_PATH ]]; then
    mkdir -p $(dirname "$WEBAPP_PATH")
    cp $SCRIPT_DIR/tomcat9/server.xml /etc/tomcat9/server.xml
    cat > /etc/tomcat9/Catalina/localhost/ROOT.xml <<EOF
<Context 
  docBase="$WEBAPP_PATH" 
  path="" 
  reloadable="false" 
/>
EOF
fi
echo "- Tomcat 9 has been installed. The webapp will be deployed."
wget -O $WEBAPP_PATH https://midmtest.mic.com.tw/store/webapp/latest
echo "- The webapp has been deployed."
sleep 3
echo "- Restarting Tomcat 9 service."
service tomcat start

if [[ $INSTALL_NGINX == "yes" ]]; then
    echo "- Installing NginX"
    apt install -y -qq nginx
    cp -rfR $SCRIPT_DIR/nginx /etc/
    service nginx reload
    echo "- NginX has been installed."
fi

# Configure Firewall.
echo "- Configuring firewall to allow http/https, ssh."
apt install -y -qq net-tools
ufw allow ssh
ufw allow 'Nginx Full'
# ufw allow 'Nginx HTTP'
# ufw allow 'Nginx HTTPS'
ufw enable
echo "- Firewall has been configured."

echo
echo "============================================================"
echo "Congratulation, the MiDM host setup has been finished."
echo "Browse the host to make sure whether the host works."
echo "You should need to configure the ssl for security."
echo "============================================================"
echo
