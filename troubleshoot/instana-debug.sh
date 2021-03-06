#!/bin/bash

#### usage

usage() {
  echo "usage: instana-debug [[-s since ] | [-h]]"
  echo ""
  echo "example: instana-debug --since=6h"
}

#### variables
out_folder=instana-debug
out_file=instana-debug
selector_instana=-lapplication=instana
output_name_only=--output=jsonpath={.items..metadata.name}
since=6h

while [ "$1" != "" ]; do
  case $1 in
    -s | --since )  shift
                    since="$1"
                    ;;
    -h | --help )   usage
                    exit
                    ;;
  esac
  shift
done

NAMESPACES=()
for ns in $(kubectl get namespaces --all-namespaces $output_name_only); do
    NAMESPACES+=($ns)
done

#### traps

trap ctrl_c INT
pid=-1

function ctrl_c() {
  if [ "$pid" != "-1" ]; then
    echo " CTRL-C executed, terminating $pid"
    kill -9 $pid
  else
    echo " CTRL-C executed, ignoring ..."
  fi
}

#### file handling

create_directories() {
  rm -rf $out_folder
  mkdir -p $out_folder/nodes
  mkdir -p $out_folder/crds

  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    mkdir -p $out_folder/pods/$ns
    mkdir -p $out_folder/cores/$ns
    mkdir -p $out_folder/units/$ns
    mkdir -p $out_folder/configmaps/$ns
    mkdir -p $out_folder/deployments/$ns
  done
}

create_tar_gz() {
  echo ""
  echo "tar -czf instana-debug.tar.gz $out_folder"
  ts="$(date +"%F-%T")"
  tar -czf instana-debug-$ts.tar.gz $out_folder
  echo " - $(pwd)/instana-debug-$ts.tar.gz"
  rm -rf $out_folder
}

#### collect

gather_common_info() {
  echo "gather common information"

  echo " - kubectl version"
  kubectl version --output=json &> $out_folder/kubernetes_version.json

  echo " - kubectl get customresourcedefinitions"
  kubectl get customresourcedefinitions cores.instana.io --output=json &> $out_folder/crds/cores.json
  kubectl get customresourcedefinitions units.instana.io --output=json &> $out_folder/crds/units.json

  echo " - kubectl get services"
  kubectl get services --all-namespaces &> $out_folder/services.txt

  echo " - kubectl get endpoints"
  kubectl get endpoints --all-namespaces &> $out_folder/endpoints.txt

  echo " - kubectl get namespaces"
  kubectl get namespaces --all-namespaces &> $out_folder/namespaces.txt

  echo " - kubectl get ingressses"
  kubectl get ingressses --all-namespaces &> $out_folder/ingressses.txt

  echo " - kubectl get storageclasses"
  kubectl get storageclasses --all-namespaces &> $out_folder/storageclasses.txt

  echo " - kubectl get secrets --field-selector type=kubernetes.io/dockerconfigjson"
  kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/dockerconfigjson &> $out_folder/dockerconfigjson.txt
}

gather_nodes() {
  echo "gather node information"
  kubectl get nodes --output=wide &> $out_folder/nodes/nodes.txt
  for node in $(kubectl get nodes $output_name_only); do
      echo " - kubectl get nodes $node"
      kubectl get nodes $node -ojson &> $out_folder/nodes/$node.json
      kubectl describe nodes $node &> $out_folder/nodes/$node.describe
  done
}

gather_pods() {
  kubectl get pods --all-namespaces $selector_instana &> $out_folder/pods/pods.txt
  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    gather_pods_ns $ns
  done
}

gather_cores() {
  kubectl get cores --all-namespaces &> $out_folder/cores/cores.txt
  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    gather_cores_ns $ns
  done
}

gather_cores_ns() {
  local namespace=$1
  echo "gather cores for $namespace"

  for core in $(kubectl get cores -n $namespace $output_name_only); do
      echo " - kubectl get cores $core -n $namespace"
      kubectl get cores $core -n $namespace -ojson &> $out_folder/cores/$namespace/$core.json
      kubectl describe cores $core -n $namespace &> $out_folder/cores/$namespace/$core.describe
  done
}

gather_units() {
  kubectl get units --all-namespaces &> $out_folder/units/units.txt
  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    gather_units_ns $ns
  done
}

gather_units_ns() {
  local namespace=$1
  echo "gather units for $namespace"

  for unit in $(kubectl get units -n $namespace $output_name_only); do
      echo " - kubectl get units $core -n $namespace"
      kubectl get units $core -n $namespace -ojson &> $out_folder/units/$namespace/$unit.json
      kubectl describe units $core -n $namespace &> $out_folder/units/$namespace/$unit.describe
  done
}

gather_pods_ns() {
  local namespace=$1
  local PODS=()
  echo "gather pods for $namespace"

  for pod in $(kubectl get pods -n $namespace $selector_instana $output_name_only); do
      PODS+=($pod)
  done

  for i in "${!PODS[@]}"; do
    pod=${PODS[$i]}
    echo " - kubectl get pods $pod -n $namespace"
    kubectl get pods $pod -n $namespace -ojson &> $out_folder/pods/$namespace/$pod.json
    kubectl describe pods $pod -n $namespace &> $out_folder/pods/$namespace/$pod.describe
  done

  for i in "${!PODS[@]}"; do
    pod=${PODS[$i]}
    echo " - kubectl logs $pod --since=$since -n $namespace"
    kubectl logs $pod --since=$since -n $namespace --ignore-errors=true &> $out_folder/pods/$namespace/$pod.log
  done
}

gather_configmaps() {
  kubectl get configmaps --all-namespaces $selector_instana &> $out_folder/configmaps/configmaps.txt
  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    gather_configmaps_ns $ns
  done
}

gather_configmaps_ns() {
  local namespace=$1
  echo "gather configmaps for $namespace"

  for cm in $(kubectl get configmaps -n $namespace $selector_instana $output_name_only); do
      echo " - kubectl get configmaps $cm -n $namespace"
      kubectl get configmaps $cm -n $namespace -ojson &> $out_folder/configmaps/$namespace/$cm.json
  done
}

gather_deployments() {
  kubectl get deployments --all-namespaces $selector_instana &> $out_folder/deployments/deployments.txt
  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    gather_deployments_ns $ns
  done
}

gather_deployments_ns() {
  local namespace=$1
  echo "gather deployments for $namespace"

  for dep in $(kubectl get deployments -n $namespace $selector_instana $output_name_only); do
      echo " - kubectl get deployments $dep -n $namespace"
      kubectl get deployments $dep -n $namespace -ojson &> $out_folder/deployments/$namespace/$dep.json
      kubectl describe deployments $dep -n $namespace &> $out_folder/deployments/$namespace/$dep.describe
  done
}

echo "running instana-debug ..."
echo ""

# prepare temp write data
create_directories

# common needed info
gather_common_info

# detailed no namespace
gather_nodes

# detailed per namespace
gather_pods
gather_cores
gather_units
gather_configmaps
gather_deployments

# build tar and clean
create_tar_gz

echo ""
echo "... instana-debug finished after $SECONDS sec."
