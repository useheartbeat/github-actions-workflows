#!/usr/bin/env bash
#---------------------------------------------------#
# <Evan Lobeto>
#---------------------------------------------------#
set -x

env=$1
region=$2
namespace=$3
ecr_repo=$4
image_hash=$5

if [[ -z ${env} || -z ${region} || -z ${namespace} || -z ${ecr_repo} || -z ${image_hash} ]]; then
  echo "Missing required input variable to scripts/helmfile-deploy.sh"
  exit 1
fi

# deploy test pods to test namespace
export AWS_DEFAULT_REGION=${region}


(helm plugin ls |grep "^s3\s") || (helm plugin install https://github.com/hypnoglow/helm-s3.git --version 0.13.0)
(helm plugin ls |grep "^diff\s") || (helm plugin install https://github.com/databus23/helm-diff)

AWS_DEFAULT_REGION=us-east-1 helm repo add hbh s3://hbh-helm-charts 

ns=${namespace}-${ecr_repo}-${short_hash}

(kubectl get ns | grep ${ns}) || (kubectl create namespace ${ns})

env=${env} ns=${ns} region=${region} image_tag=${short_hash} helmfile -f stable/${ecr_repo}.yaml apply

echo "Image Hash: ${image_hash}"
pod_name=$(kubectl get pods -n ${ns} -o json -l app=${ecr_repo} --sort-by=.metadata.creationTimestamp |jq -r '.items[]| "\(.metadata.name) \(.spec.containers[].image)"'|grep ${image_hash}|head -n1|awk '{print $1}')
if [[ -z ${pod_name} ]]; then
    echo "Missing pod name from k8s output, something is wrong"
    exit 1
fi

test_if_running(){
    kubectl -n ${ns} get pod ${pod_name} -o jsonpath="Name: {.metadata.name} Status: {.status.phase}"|grep "Running" &>/dev/null
}

until test_if_running; do
    echo "Pod is not in running state yet, waiting..."
    sleep 2
done

echo "Pod is in running state, proceeding"

# avoid logging secrets
set +x
# avoid exiting script on error on the test invocation, to
# ensure that this script downloads the test files before
# exiting, as it's especially important to get test results
# on failure
set +e 
kubectl -n ${ns} exec -t ${pod_name} -- sh -c \
  "bash -x ./main.sh test"
status_code=$?
# continue verbose logging
set -x
# exit on any failed line from here on
set -e

# copy junit results into jenkins so we can analyze them w/junit plugin
kubectl -n ${ns} exec ${pod_name} -- tar cf - build/test-results/test | tar xf - -C .


AWS_DEFAULT_REGION=us-east-1 helm repo add hbh s3://hbh-helm-charts 

env=${env} ns=${ns} region=${region} image_tag=${short_hash} helmfile -f stable/${ecr_repo}.yaml destroy

kubectl delete namespace ${ns}

# exit with the status code returned by test invocation
exit $status_code
