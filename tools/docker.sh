#!/bin/bash

docker/_list_images () {
  docker images | awk '{if(NR>1)print $1":"$2}'
}

docker/_ping_repo() {
  local host=$1
  local resp=$(curl --connect-timeout 1 $host/v1/_ping 2>/dev/null)
  if [ $? -gt 0 ] || [ ! "$resp" == "true" ]; then
    return 1
  fi
  return 0
}

docker/_parse_repo () {
  local repo=$1
  local parts=(${repo//\// })
  local host; local user; local nametag; local name; local tag

  if [ ${#parts[@]} -eq 1 ]; then
    host="central"
    user="root"
    nametag="${parts[0]}"
  elif [ ${#parts[@]} -eq 2 ]; then
    # No clue how to distinguish between the two. Seens Docker itself
    # also tries a ping. Obviously this will fail when a host is no
    # longer available...
    docker/_ping_repo ${parts[0]}
    if [ $? -eq 0 ]; then
      host="${parts[0]}"
      user="root"
      nametag="${parts[1]}"
    else
      host="central"
      user="${parts[0]}"
      nametag="${parts[1]}"
    fi
  elif [ ${#parts[@]} -eq 3 ]; then
    host="${parts[0]}"
    user="${parts[1]}"
    nametag="${parts[2]}"
  else
    echo "docker/_parse_repo: repo parameter invalid: $repo" 1>&2
    return 1
  fi

  if [[ $nametag =~ : ]]; then
    name="${nametag//:*/}"
    tag="${nametag//*:/}"
  else
    name="$nametag"
    tag="latest"
  fi

  echo "$host $user $name $tag"
}

# Return first matching image (if any)
#
docker/find_image () {
  local repo; repo=($(docker/_parse_repo $1))
  if [ $? -gt 0 ]; then return 1; fi
  local images=($(docker/_list_images))
  for image in "${images[@]}"; do
    local parsed; parsed=($(docker/_parse_repo ${image}))
    if [ "${repo[1]}" == "${parsed[1]}" ] \
               && [ "${repo[2]}" == "${parsed[2]}" ] \
               && [ "${repo[3]}" == "${parsed[3]}" ]; then
      echo "${image}"
      return 0
    fi
  done
  return 1
}

# Return list of matching images
#
docker/find_images () {
  local repo; repo=($(docker/_parse_repo $1))
  if [ $? -gt 0 ]; then return 1; fi
  local images=($(docker/_list_images))
  for image in "${images[@]}"; do
    local parsed; parsed=($(docker/_parse_repo ${image}))
    if [ "${repo[1]}" == "${parsed[1]}" ] \
               && [ "${repo[2]}" == "${parsed[2]}" ] \
               && [ "${repo[3]}" == "${parsed[3]}" ]; then
      echo "${image}"
    fi
  done
  return 0
}

# Push an image to all hosts
#
# If the repo contains a host it will be included in the hosts. Use
# "central" to push to the Docker Index.
#
# param repo  : [<host>/][<user>/]<name>[:<tag>]
# param hosts : [<host>[ <host>]]
#
# examples:
#
# docker/push_image 172.17.8.100:5000/inaetics/apt-cacher-service
# docker/push_image inaetics/apt-cacher-service 172.17.8.100:5000
#
docker/push_image () {

  local repo; repo=($(docker/_parse_repo $1))
  if [ $? -gt 0 ]; then return 1; fi

  local hosts=($2)
  local host=${repo[0]}
  local user=${repo[1]}
  local name=${repo[2]}
  local tag=${repo[3]}

  if [ ! "${host}" == "central" ]; then
    echo "docker/pull_image: Adding image name host to hosts: ${host}"
    hosts=( ${hosts[@]/${host}/} )
    hosts=("${host}" "${hosts[@]}")
  fi

  local imgpath="$user/$name:$tag"
  if [ "${user}" == "root" ]; then
    imgpath="$name:$tag"
  fi

  for host in ${hosts[@]}; do
    local imgspec="$host/$imgpath"
    if [ "${host}" == "central" ]; then
      imgspec="$imgpath"
    fi

    echo "docker/push_image: Pushing image to host: $imgspec"
    docker push $imgspec
    if [ $? -eq 0 ]; then
      echo "docker/pull_image: Sucessfully pushed image: $imgspec"
      return 0
    fi
  done

  echo "docker/push_image: Done pushing: $repository"
}

# Pull an image from any host
#
# If the repo contains a host it will be included in the hosts. Use
# "central" to pull from the Docker Index.

# param repo  : [<host>/][<user>/]<name>[:<tag>]
# param hosts : [<host>[ <host>]]
#
# examples:
#
# docker/pull_image 172.17.8.100:5000/inaetics/apt-cacher-service
# docker/pull_image inaetics/apt-cacher-service 172.17.8.100:5000
# docker/pull_image 172.17.8.100:5001/inaetics/apt-cacher-service "172.17.8.100:5002 central"
#
docker/pull_image () {

  local repo; repo=($(docker/_parse_repo $1))
  if [ $? -gt 0 ]; then return 1; fi

  local hosts=($2)
  local host=${repo[0]}
  local user=${repo[1]}
  local name=${repo[2]}
  local tag=${repo[3]}

  if [ ! "${host}" == "central" ]; then
    echo "docker/pull_image: Adding image name host to hosts: ${host}" 1>&2
    hosts=( ${hosts[@]/${host}/} )
    hosts=("${host}" "${hosts[@]}")
  fi

  local imgpath="$user/$name:$tag"
  if [ "${user}" == "root" ]; then
    imgpath="$name:$tag"
  fi

  for host in ${hosts[@]}; do
    local imgspec="$host/$imgpath"
    if [ "${host}" == "central" ]; then
      imgspec="$imgpath"
    fi
    echo "docker/pull_image: Pulling image from host: $imgspec" 1>&2
    docker pull $imgspec 1>&2
    if [ $? -eq 0 ]; then
      echo "docker/pull_image: Sucessfully pulled image: $imgspec" 1>&2
      echo $imgspec
      return 0
    fi
  done

  echo "docker/pull_image: Failed to pull image from any repository" 1>&2
  return 1
}

