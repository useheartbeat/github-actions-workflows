#!/usr/bin/env bash
#---------------------------------------------------#
# <Christopher Stobie> 
#---------------------------------------------------#

if [[ -z ${GH_TOKEN} ]]; then
    echo "Missing required variable GH_TOKEN"
    exit 1
fi

echo "Building container"
docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG --build-arg githubUsername=hbh-github --build-arg githubToken=$GH_TOKEN .

echo "Pushing container to ECR"
docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
