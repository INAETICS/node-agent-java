# Image builder code
#
# NOTE: this logic is expected to move
# to a generic builder at some point.
#

BUILDER_ROOT="/tmp/image-builder"

builder/_locate_services () {
  local svckey=$1

  if [ "$svckey" == "" ]; then
    echo "builder/_locate_services: Svckey param required" 1>&2
    echo ""
    return 1
  fi
  
  local etcdctl=$(which etcdctl)
  if [ "$etcdctl" == "" ]; then
    echo "builder/_locate_services: Etcdctl not available" 1>&2
    echo ""
    return 1
  fi

  local services=($($etcdctl ls $svckey))
  for service in ${services[@]}; do
    echo $($etcdctl get $service) | tr -d "\""
  done
}

builder/_locate_jdkarchive () {
 echo `tools/java-installer/java-download`
}

builder/build_image () {
  local imagename=$1
  local sourcedir=$2

  echo "builder/build_image: Building image $imagename from $sourcedir"
 
  if [ ! -d "$sourcedir" ]; then 
    echo "builder/build_image: No such dir: $sourcedir" 1>&2
    return 1
  fi

  if [ ! -f "$sourcedir/Dockerfile" ]; then i
    echo "builder/build_image: No Dockerfile found: $sourcedir" 1>&2
    return 1
  fi

  if [ "$imagename" == "" ]; then
    echo "builder_build_image: Image name reguired!" 1>&2
    return 1
  fi

  if [ ! -d "$BUILDER_ROOT" ]; then
    mkdir $BUILDER_ROOT
  fi

  local safename=$(echo "$imagename" | sed 's/\//\_/g')
  local builddir="$BUILDER_ROOT/$safename"
  if [ ! -d $builddir ]; then
    mkdir $builddir
  fi

  echo "builder/build_image: Using build directory $builddir"

  rsync -a $sourcedir $builddir
  rsync -a . $builddir

  grep "##APT_PROXY" $builddir/Dockerfile >/dev/null
  if [ $? -eq 0 ]; then
    echo "builder/build_image: Dockerfile requests Apt proxy"

    local services=($(builder/_locate_services "/inaetics/apt-cacher-service"))
    if [ ${#services[@]} -eq 0 ]; then 
      echo "builder/build_image: No Apt Proxy available"
    else
      echo "builder/build_image: Inserting Apt Proxy at ${services[0]}"
      sed -i "/##APT_PROXY/ a\\
        RUN echo \"Acquire::http::Proxy \\\\\"http://${services[@]}\\\\\";\" \
          > /etc/apt/apt.conf.d/01proxy" \
        $builddir/Dockerfile
    fi
  else
    echo "builder/build_image: Dockerfile does not request Apt proxy"
  fi

  grep "##JDK_INSTALL" $builddir/Dockerfile >/dev/null
  if [ $? -eq 0 ]; then
    echo "builder/build_image: Dockerfile requests JDK install"
    local jdkarchive=$(builder/_locate_jdkarchive)
    if [ ! "$jdkarchive" == "" ]; then
      echo "builder/build_image: Inserting JDK install from $jdkarchive"
      rsync -a $jdkarchive $builddir/tools/java-installer
      sed -i "/##JDK_INSTALL/ a\\
        ADD tools/java-installer /tmp/java-installer/\n \
        RUN /tmp/java-installer/java-install; rm -Rf /tmp/java-installer" \
        $builddir/Dockerfile
    else
      echo "builder/build_image: Dockerfile does not request JDK install"
    fi
  fi

  docker build -t $imagename $builddir
  if [ $? -gt 0 ]; then
    echo "builder/build_image: Failed building $imagename"
    return 1
  fi
  echo "builder/build_image: Done building $imagename"
}

builder/deploy_image () {
  local imagename=$1
  
  if [ "$imagename" == "" ]; then
    echo "builder/deploy_image: Image name reguired!" 1>&2
    return 1
  fi
  echo "builder/deploy_image: Deploying image $imagename"

  local services=($(builder/_locate_services "/inaetics/docker-registry-service"))
  if [ ${#services[@]} -eq 0 ]; then 
    echo "builder/deploy_image: No Docker registries available"
  else
    for service in ${services[@]}
    do
      echo "builder/deploy_image: Deploying $imagename to $service"
      docker tag $imagename $service/$imagename
      docker push $service/$imagename
    done
  fi
  echo "builder/deploy_image: Done deploying $imagename"
}
