#!/bin/bash
#
# Start scrip for the Node Agent
#
# (C) 2014 INAETICS, <www.inaetics.org> - Apache License v2.

cd $(dirname $0)

#
# Config
#
PROVISIONING_NAMESPACE="/inaetics/node-provisioning-service"
UPDATE_INTERVAL=60
RETRY_INTERVAL=20

#
# Libs
#
source etcdlib.sh

#
# State
#
current_provisioning_service=""
located_provisioning_service=""
agent_pid=""

#
# Functions
#

# Locate the provisioning service in etcd.
#  args: $1 - <current service>, prefer if present
#  echo: <new service>, may be same as current
#  return: 0, if no errors
#    1, if etcd lookup fails
locate_provisioning_service () {
  located_provisioning_service=""
  local provisioning_services=($(etcd/values $PROVISIONING_NAMESPACE $ETCD_HOST))
  if [ $? -ne 0 ]; then
    return 1
  fi
  if [ "$current_provisioning_service" != "" ]; then
    for provisioning_service in ${provisioning_services[@]}; do
      if [ "$current_provisioning_service" == "$provisioning_service" ]; then
        located_provisioning_service=$current_provisioning_service
        return 0
      fi
    done
  fi
  if [ ${#provisioning_services[@]} -gt 0 ]; then
    located_provisioning_service=${provisioning_services[0]}
  fi
  return 0
}

start_agent () {
  java \
    -Dagent.identification.agentid=$agent_id \
    -Dagent.discovery.serverurls=http://$current_provisioning_service \
    -Dorg.osgi.service.http.port=8080\
    -Damdatu.remote.logging.level=5\
    -Dorg.amdatu.remote.discovery.etcd.connecturl=http://$ETCD_HOST\
    -Dorg.amdatu.remote.discovery.etcd.rootpath=/discovery \
    -Dgosh.args=--nointeractive \
    -jar org.apache.ace.agent.launcher.felix.jar -v framework.org.osgi.framework.system.packages.extra=sun.misc &
  agent_pid=$!
}

stop_agent () {
  if [ "$agent_pid" != "" ]; then
    kill -SIGTERM $agent_pid
    agent_pid=""
  fi
}

clean_up () {
    echo "Running cleanup.."
    stop_agent
    exit 0
}

#
# Main
#
trap clean_up SIGHUP SIGINT SIGTERM

agent_id=$1
if [ "$agent_id" == "" ]; then
  echo "agent_id param required!"
  exit 1
fi

while true; do

  locate_provisioning_service
  if [ $? -ne 0 ]; then
    echo "Locating provisioning services in etcd failed. Keeping current state.." 1>&2
  else
    if [ "$current_provisioning_service" != "$located_provisioning_service" ]; then
      echo "Provisioning service changed: $current_provisioning_service -> $located_provisioning_service"
      current_provisioning_service=$located_provisioning_service

      if [ "$current_provisioning_service" == "" ]; then
        if [ "$agent_pid" != "" ]; then
          echo "Stopping agent.."
          stop_agent
        fi
      else
        if [ "$agent_pid" != "" ]; then
          echo "Restarting agent..."
          stop_agent
          start_agent
        else
          echo "Starting agent..."
          start_agent
        fi
      fi
    fi
  fi

  if [ "$agent_pid" == "" ]; then
    echo "agent waiting for provisioning service.."
    echo "Will retry in $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL &
    wait $!
    
  else
    echo "agent running with provisioning $current_provisioning_service"
    echo "Will update in $UPDATE_INTERVAL seconds..."
    sleep $UPDATE_INTERVAL &
    wait $!
  fi

done
