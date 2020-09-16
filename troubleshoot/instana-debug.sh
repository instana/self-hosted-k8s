#!/bin/bash

#### usage
usage() {
  echo "usage: instana-debug --since=6h"
}

#### variables
since=24h
out_folder=instana-debug
out_file=instana-debug
selector_instana=-lapplication=instana
output_name_only=--output=jsonpath={.items..metadata.name}

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
    echo " CTRL-C executed"
  fi
}

#### prepare

create_directories() {
  rm -rf $out_folder

  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    mkdir -p $out_folder/pods/$ns
    mkdir -p $out_folder/configmaps/$ns
    mkdir -p $out_folder/deployments/$ns
  done
}

create_tar_gz() {
  echo "tar -czf instana-debug.tar.gz $out_folder"
  ts="$(date +"%F-%T%")"
  tar -czf instana-debug-$ts.tar.gz $out_folder
  rm -rf $out_folder
}

#### collect

get_version() {
  echo "get version"
  kubectl version --output=json &> $out_folder/kubernetes_version.json
}

get_endpoints() {
  echo "get endpoints"
  kubectl get endpoints --all-namespaces &> $out_folder/endpoints.txt
}

get_namespaces() {
  echo "get namespaces"
  kubectl get namespaces --all-namespaces &> $out_folder/namespaces.txt
}

gather_pods() {
  kubectl get pods --all-namespaces $selector_instana &> $out_folder/pods/pods.txt
  for i in "${!NAMESPACES[@]}"; do
    ns=${NAMESPACES[$i]}
    gather_pods_ns $ns
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

  #TODO $selector_instana
  for cm in $(kubectl get configmaps -n $namespace $output_name_only); do
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
  done

}

echo "let's go ..."

create_directories

get_version
get_endpoints
get_namespaces

gather_pods
gather_configmaps
gather_deployments

create_tar_gz

echo "done after $SECONDS sec."
