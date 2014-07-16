#!/bin/bash

ORGDIR=`pwd`
cd $(dirname $0)

usage () {
  echo "nodeagent.sh <agentid>"
}


ETCD_HOST="http://172.17.8.201:4001"

agentid=$1
if [ "$agentid" == "" ]; then
  usage
  exit 1
fi

discovery=$2
if [ "$discovery" == "" ]; then
  usage
  exit 1
fi



java \
  -Dagent.identification.agentid=$agentid \
  -Dagent.discovery.serverurls=$discovery \
  -Dorg.osgi.service.http.port=8080\
  -Damdatu.remote.logging.level=5\
  -Dorg.amdatu.remote.discovery.etcd.connecturl=$ETCD_HOST\
  -Dorg.amdatu.remote.discovery.etcd.rootpath=/discovery \
  -Dgosh.args=--nointeractive \
  -jar org.apache.ace.agent.launcher.felix.jar -v framework.org.osgi.framework.system.packages.extra=sun.misc

cd $ORGDIR
