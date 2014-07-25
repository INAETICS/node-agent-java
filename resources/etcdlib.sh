#!/bin/bash
#
# Bash Etcd client library 
#
# (C) 2014 INAETICS, <www.inaetics.org> - Apache License v2.

etcd/get () {
  echo "[DEBUG] $FUNCNAME - $@" 1>&2
  local url="$2/v2/keys$1"
  local resp=`curl -s --connect-timeout 1 $url`
  if [ ! $? -eq 0 ]; then 
    echo "etcd/get - Failed connect to etcd: $url" 1>&2
    return 1
  fi
  if [ "$resp" == "" ]; then 
    echo "etcd/get - Failed get response from etcd: $url" 1>&2
    return 1
  fi
  local code=`echo $resp | jq 'if .echoCode != null then .echoCode else empty end' | tr -d "\""`
  local mesg=`echo $resp | jq 'if .message != null then .message else empty end' | tr -d "\""`
  if [ ! "$code" == "" ]; then 
    echo "etcd/get - $mesg ($code): $url" 1>&2
    return 1
  fi
  echo $resp
}

etcd/keys () {
  echo "[DEBUG] $FUNCNAME - $@" 1>&2
  echo $(etcd/get $1 $2) | jq 'if .node.nodes != null then .node.nodes[].key else empty end' | tr -d "\""
}

etcd/value () {
  echo "[DEBUG] $FUNCNAME - $@" 1>&2
  echo $(etcd/get $1 $2) | jq '.node.value' | tr -d "\""
}

etcd/values () {
  echo "[DEBUG] $FUNCNAME - $@" 1>&2
  for key in $(etcd/keys $1 $2)
  do
    echo $(etcd/value $key $2)
  done
}

