#!/bin/sh

# Fail if error
set -e

## Max heap to 50% of container limit. Default is only 25% with Java17
echo >>${CONFIG_INSTANCE_DIR}/etc/artemis.profile
echo 'JAVA_ARGS="$JAVA_ARGS -XX:MaxRAMPercentage=50"' >>${CONFIG_INSTANCE_DIR}/etc/artemis.profile

## Get extra env variables from mounted ConfigMap and Secret if exists. It's a way to use env specific vars (e.g. SECURITY_INVALIDATION_INTERVAL) in this file or in artemis.profile
for config_dir in /amq/extra/configmaps/broker-env-vars /amq/extra/secrets/broker-env-vars-secret;
do
    if [ -d $config_dir ]; then
        for config_file in $config_dir/*;
        do
            echo "Source env variables from $config_file"
            source $config_file
            echo "source $config_file" >>${CONFIG_INSTANCE_DIR}/etc/artemis.profile
        done
    fi
done

## BROKER.XML ##
# Single line sed
echo "Disable critical-analyzer"
sed -i 's|<critical-analyzer>.*<\/critical-analyzer>|<critical-analyzer>false</critical-analyzer>|' ${CONFIG_INSTANCE_DIR}/etc/broker.xml

# Multi line sed
SECURITY_INVALIDATION_INTERVAL=${SECURITY_INVALIDATION_INTERVAL:-120000}
echo "Security cache time $SECURITY_INVALIDATION_INTERVAL"
sed -i ':a;N;$!ba s|<security-settings>|<security-invalidation-interval>'$SECURITY_INVALIDATION_INTERVAL'</security-invalidation-interval>\n      <security-settings>|' ${CONFIG_INSTANCE_DIR}/etc/broker.xml
cat ${CONFIG_INSTANCE_DIR}/etc/broker.xml

## LOGGING.PROPERTIES ##
# Modify existing logger
echo "Enable log rotation 3x200MB"
sed -i 's/handler.FILE=.*/handler.FILE=org.jboss.logmanager.handlers.SizeRotatingFileHandler/' ${CONFIG_INSTANCE_DIR}/etc/logging.properties
sed -i 's/handler.FILE.properties=.*/handler.FILE.properties=append,autoFlush,rotateSize,maxBackupIndex,fileName/' ${CONFIG_INSTANCE_DIR}/etc/logging.properties
sed -i 's/handler.FILE.suffix=.*/handler.FILE.rotateSize=200000000\nhandler.FILE.maxBackupIndex=3/' ${CONFIG_INSTANCE_DIR}/etc/logging.properties
cat ${CONFIG_INSTANCE_DIR}/etc/logging.properties

# Add new logger - SYSLOG - https://access.redhat.com/webassets/avalon/d/red-hat-jboss-enterprise-application-platform/7.0.0/javadocs/org/jboss/logmanager/handlers/SyslogHandler.html
if [ -n "$SYSLOG_SERVERHOSTNAME" ]; then
echo "Add SYSLOG appender to logging.properties"
# Define new handler
echo "
handler.SYSLOG=org.jboss.logmanager.handlers.SyslogHandler
handler.SYSLOG.properties=appName,hostname,serverHostname,port,protocol,syslogType,useCountingFraming
handler.SYSLOG.serverHostname=${SYSLOG_SERVERHOSTNAME}
handler.SYSLOG.level=${SYSLOG_LEVEL:-DEBUG}
handler.SYSLOG.protocol=${SYSLOG_PROTOCOL:-TCP}
handler.SYSLOG.port=${SYSLOG_PORT:-514}
handler.SYSLOG.useCountingFraming=${SYSLOG_USECOUNTINGFRAMING:-false}
handler.SYSLOG.syslogType=${SYSLOG_SYSLOGTYPE:-RFC5424}
handler.SYSLOG.appName=${SYSLOG_APPNAME:-AMQ}
handler.SYSLOG.formatter=PATTERN
" >>${CONFIG_INSTANCE_DIR}/etc/logging.properties
# Append to handlers
sed -i 's/logger.handlers=.*/&,SYSLOG/' ${CONFIG_INSTANCE_DIR}/etc/logging.properties
fi

## LOGIN.CONFIG ##
echo "Enable certificate-based authentication"
sed -i ':a;N;$!ba s/certauth {[^}]*};//' ${CONFIG_INSTANCE_DIR}/etc/login.config
echo "
certauth {
    org.apache.activemq.artemis.spi.core.security.jaas.TextFileCertificateLoginModule required
        debug=true
        reload=true
        org.apache.activemq.jaas.textfiledn.user=cert-users.properties
        org.apache.activemq.jaas.textfiledn.role=cert-roles.properties;
};" >>${CONFIG_INSTANCE_DIR}/etc/login.config
cat ${CONFIG_INSTANCE_DIR}/etc/login.config


## Add files from ConfigMap (e.g. cert-users.properties and cert-roles.properties)
ADD_FILES=/amq/extra/configmaps/broker-add-files
if [ -d "$ADD_FILES" ]; then
    echo "Add files from ConfigMap $ADD_FILES to ${CONFIG_INSTANCE_DIR}/etc:"
    # Link so updates in ConfigMap are applied without Pod restart
    ln -fvs $ADD_FILES/* ${CONFIG_INSTANCE_DIR}/etc/
    # Or copy
    # cp -f $ADD_FILES/* ${CONFIG_INSTANCE_DIR}/etc/
fi
ls -las ${CONFIG_INSTANCE_DIR}/etc

