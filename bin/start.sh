#!/bin/bash

#ROLE=0  (0:master, 1:slave 1, 2:slave2)
if [ -z $ROLE ]; then
  ROLE=0 
fi

if [ -z $ZK_NUM ]; then
  ZK_NUM=3 
fi

if [ -z $REPLIC_NUM ]; then
  REPLIC_NUM=0 
fi

if [ -z $BASE_REPLIC_PORT ]; then
  BASE_REPLIC_PORT=61619 
fi

let REPLIC_PORT=$BASE_REPLIC_PORT+$ROLE*10


let ZK_START=$ZK_NUM-1
ZK_STR="zookeeper-1:2181"

until [ $ZK_START -gt $ZK_NUM ]; do
  ZK_STR="$ZK_STR,zookeeper-$ZK_START:2181"
  let ZK_START+=1
done

echo "INFO: zookeeper string is $ZK_STR"

echo "INFO: building network broker config"

if [ -z $HUB_ID ]; then
  HUB_ID=1 
fi

if [ -z $NODE_ID ]; then
  NODE_ID=1 
fi



if [ -z $BROKER_NAME ]; then
  BROKER_NAME="edge$HUB_ID-$NODE_ID-$ROLE" 
fi



#openwire base port
if [ -z $BASE_PORT ]; then
  BASE_PORT=61616 
fi

let OPENWIRE_PORT=$BASE_PORT+$ROLE*10

#mqtt base port
if [ -z $MQTT_BASE_PORT ]; then
  MQTT_BASE_PORT=1883 
fi

let MQTT_PORT=$MQTT_BASE_PORT+$ROLE*10

#amqp base port
if [ -z $AMQP_BASE_PORT ]; then
  AMQP_BASE_PORT=5672 
fi

let AMQP_PORT=$AMQP_BASE_PORT+$ROLE*10

#stomp base port
if [ -z $STOMP_BASE_PORT ]; then
  STOMP_BASE_PORT=61613 
fi

let STOMP_PORT=$STOMP_BASE_PORT+$ROLE*10

#ws base port
if [ -z $WS_BASE_PORT ]; then
  WS_BASE_PORT=61614
fi

let WS_PORT=$WS_BASE_PORT+$ROLE*10

#hub openwire base port
if [ -z $HUB_BASE_PORT ]; then
  HUB_BASE_PORT=61716 
fi

let MASTER_PORT=$HUB_BASE_PORT
let SLAVE1_PORT=$MASTER_PORT+10
let SLAVE2_PORT=$SLAVE1_PORT+10

rm -rf nw.config

cat >> .nw.config << EOF
          <networkConnector
            name="topic-edge$HUB_ID-$NODE_ID->core$HUB_ID"
            uri="masterslave:(nio://core$HUB_ID-0:$MASTER_PORT,nio://core$HUB_ID-1:$SLAVE1_PORT,nio://core$HUB_ID-2:$SLAVE2_PORT)"
            duplex="true"
            decreaseNetworkConsumerPriority="false"
            networkTTL="3"
            conduitSubscriptions="true"
            suppressDuplicateQueueSubscriptions="true"
            dynamicOnly="true">
            <excludedDestinations>
              <queue physicalName=">" />
            </excludedDestinations>
          </networkConnector>
          <networkConnector
            name="queue-edge$HUB_ID-$NODE_ID->core$HUB_ID"
            uri="masterslave:(nio://core$HUB_ID-0:$MASTER_PORT,nio://core$HUB_ID-1:$SLAVE1_PORT,nio://core$HUB_ID-2:$SLAVE2_PORT)"
            duplex="true"
            decreaseNetworkConsumerPriority="false"
            networkTTL="3"
            conduitSubscriptions="true"
            suppressDuplicateQueueSubscriptions="true"
            dynamicOnly="true">
            <excludedDestinations>
              <topic physicalName=">" />
            </excludedDestinations>
          </networkConnector>
EOF

cat /activemq/conf/activemq.xml.tmp | \
    sed -e "s:%node.id%:$NODE_ID:g" | \
    sed -e "s:%broker.name%:$BROKER_NAME:g" | \
    sed -e "s:%leveldb.weight%:1:g" | \
    sed -e "s#%zk.str%#$ZK_STR#g" | \
    sed -e "s#%replic.num%#$REPLIC_NUM#g" | \
    sed -e "s#%replic.port%#$REPLIC_PORT#g" | \
    sed -e "s#%hub.id%#$HUB_ID#g" | \
    sed -e "s#%openwire.port%#$OPENWIRE_PORT#g" | \
    sed -e "s#%mqtt.port%#$MQTT_PORT#g" | \
    sed -e "s#%ws.port%#$WS_PORT#g" | \
    sed -e "s#%amqp.port%#$AMQP_PORT#g" | \
    sed -e "s#%stomp.port%#$STOMP_PORT#g" | \
    sed -e "/<networkConnectors>/r .nw.config" > \
    /activemq/conf/activemq.xml

rm -rf .nw.config

/activemq/bin/activemq console
