#!/bin/bash
export CI=true \
export TRAVIS_COMMIT=`git rev-parse --short HEAD` \
export TRAVIS_BRANCH=`git rev-parse --abbrev-ref HEAD` \
export REACT_APP_API_BASE_URL=http://localhost:8080 \
export PACT_BROKER_BASE_URL=http://pact-broker:9292 \
export PACT_BROKER_BASIC_AUTH_USERNAME="d966ded9e2f54160a0a09fd4c9520543" \
export PACT_BROKER_BASIC_AUTH_PASSWORD="1b587a8bf460160d5c0da479b2dace88" \

function fake_ci {
    make fake_ci
}

if [[ $1 == "ci" ]]; then
    fake_ci
fi

if [[ $1 == "test:pact" ]]; then
    yarn test:pact
fi

if [[ $1 == "can_i_deploy" ]]; then
    make can_i_deploy TARGET=$2
fi

if [[ $1 == "deploy_to" ]]; then
    make deploy_to TARGET=$2
fi

if [[ $1 == "delete_by_tag" ]]; then
    echo $2
    curl --location --request DELETE "http://localhost:9292/pacts/provider/pactflow-example-provider/consumer/pactflow-example-consumer/tag/$2" \
    --header 'Authorization: Basic ZDk2NmRlZDllMmY1NDE2MGEwYTA5ZmQ0Yzk1MjA1NDM6MWI1ODdhOGJmNDYwMTYwZDVjMGRhNDc5YjJkYWNlODg='
fi