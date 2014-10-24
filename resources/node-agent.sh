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
LOG_DEBUG=true

#
# Libs
#
source etcdctl.sh

# Wraps a function call to redirect or filter stdout/stderr
# depending on the debug setting
#   args: $@ - the wrapped call
#   return: the wrapped call's return
_call () {
  if [ "$LOG_DEBUG" != "true"  ]; then
    $@ &> /dev/null
    return $?
  else
    $@ 2>&1 | awk '{print "[DEBUG] "$0}' >&2
    return ${PIPESTATUS[0]}
  fi
}

# Echo a debug message to stderr, perpending each line
# with a debug prefix.
#   args: $@ - the echo args
_dbg() {
  if [ "$LOG_DEBUG" == "true" ]; then
    echo $@ | awk '{print "[DEBUG] "$0}' >&2
  fi
}

# Echo a log message to stderr, perpending each line
# with a info prefix.
#   args: $@ - the echo args
_log() {
  echo $@ | awk '{print "[INFO] "$0}' >&2
}


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
  local cmd="java \
    -Dagent.identification.agentid=$agent_id \
    -Dagent.discovery.serverurls=http://$current_provisioning_service \
    -Dorg.osgi.service.http.port=8080\
    -Damdatu.remote.logging.level=5\
    -Damdatu.remote.console.level=5\
    -Dorg.amdatu.remote.discovery.etcd.host=$agent_ipv4\
    -Dorg.amdatu.remote.discovery.etcd.connecturl=http://$ETCDCTL_PEERS\
    -Dorg.amdatu.remote.discovery.etcd.rootpath=/discovery \
    -Dorg.amdatu.remote.admin.http.host=$agent_ipv4\
    -Dgosh.args=--nointeractive \
    -jar org.apache.ace.agent.launcher.felix.jar -v framework.org.osgi.framework.system.packages.extra=sun.misc"

  _dbg $cmd
  $cmd &
  agent_pid=$!

  etcd/put "/inaetics/node-agent-service/$agent_id" "$agent_ipv4:$agent_port"
}

stop_agent () {
  etcd/rm "/inaetics/node-agent-service/$agent_id"
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
  # get docker id
  agent_id=`cat /proc/self/cgroup | grep -o  -e "docker-.*.scope" | head -n 1 | sed "s/docker-\(.*\).scope/\\1/"`
fi
if [ "$agent_id" == "" ]; then
  echo "agent_id param required!"
  exit 1
fi

agent_ipv4=$2
if [ "$agent_ipv4" == "" ]; then
  # get IP from env variable set by kubernetes
  agent_ipv4=$SERVICE_HOST
fi
if [ "$agent_ipv4" == "" ]; then
  echo "agent_ipv4 param required!"
  exit 1
fi

# get port from env variable set by kubernetes pod config
agent_port=$HOSTPORT
if [ "$agent_port" == "" ]; then
  agent_port=8080
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
