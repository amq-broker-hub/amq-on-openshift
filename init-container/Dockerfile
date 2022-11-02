FROM registry.redhat.io/amq7/amq-broker-init-rhel8:7.10-28

ADD ./post-config.sh /amq/scripts/post-config.sh

RUN chmod +x /amq/scripts/post-config.sh