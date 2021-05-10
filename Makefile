#!make
include .env
# Default to the read only token - the read/write token will be present on Travis CI.
# It's set as a secure environment variable in the .travis.yml file
GITHUB_ORG="pactflow"
PACTICIPANT := "pactflow-example-consumer"
GITHUB_WEBHOOK_UUID := "04510dc1-7f0a-4ed2-997d-114bfa86f8ad"
PACT_CHANGED_WEBHOOK_UUID := "8e49caaa-0498-4cc1-9368-325de0812c8a"
PACT_CLI="docker run --rm --network microservice-contract-testing_default -v ${PWD}:${PWD} -e PACT_BROKER_BASE_URL -e PACT_BROKER_TOKEN -e PACT_BROKER_BASIC_AUTH_USERNAME -e PACT_BROKER_BASIC_AUTH_PASSWORD pactfoundation/pact-cli:latest"

TARGET = qa

all: test

## ====================
## CI tasks
## ====================

ci: test publish_pacts can_i_deploy
ci_nock: test_nock publish_pacts can_i_deploy

# Run the ci target from a developer machine with the environment variables
# set as if it was on Travis CI.
# Use this for quick feedback when playing around with your workflows.
fake_ci: .env
	make ci

fake_ci_nock: .env
	make ci_nock

deploy_with_new_tag: 


publish_pacts: .env
	@echo "\n========== STAGE: publish pacts ==========\n"
ifeq ($(TRAVIS_BRANCH),master)
	@"${PACT_CLI}" publish ${PWD}/pacts --consumer-app-version ${TRAVIS_COMMIT} --tag ${TRAVIS_BRANCH} -b ${PACT_BROKER_BASE_URL} -u ${PACT_BROKER_BASIC_AUTH_USERNAME} -p ${PACT_BROKER_BASIC_AUTH_PASSWORD}
else
	@"${PACT_CLI}" publish ${PWD}/pacts --consumer-app-version ${TRAVIS_COMMIT} --tag ${TRAVIS_BRANCH} new -b ${PACT_BROKER_BASE_URL} -u ${PACT_BROKER_BASIC_AUTH_USERNAME} -p ${PACT_BROKER_BASIC_AUTH_PASSWORD}
endif
 
## =====================
## Build/test tasks
## =====================

test: .env
	@echo "\n========== STAGE: test (pact) ==========\n"
	npm run test:pact

test_nock: .env
	@echo "\n========== STAGE: test (nock) ==========\n"
	npm run test:nock

## =====================
## Deploy tasks
## =====================

deploy_to: 
	make deploy_app TARGET=${TARGET}
	make tag_as TARGET=${TARGET}

no_deploy:
	@echo "Not deploying as not on master branch"

can_i_deploy: .env
	@echo "\n========== STAGE: can-i-deploy to  ${TARGET}? ==========\n"
	@"${PACT_CLI}" broker can-i-deploy \
	  --pacticipant ${PACTICIPANT} \
	  --version ${TRAVIS_COMMIT} \
	  --to ${TARGET} \
	  --retry-while-unknown 0 \
	  --retry-interval 10 \
	--broker-base-url ${PACT_BROKER_BASE_URL} -u ${PACT_BROKER_BASIC_AUTH_USERNAME} -p ${PACT_BROKER_BASIC_AUTH_PASSWORD}

deploy_app:
	@echo "\n========== STAGE: deploy to  ${TARGET} ==========\n"
	@echo "Deploying to ${TARGET}"

tag_as: .env
	@"${PACT_CLI}" broker create-version-tag --pacticipant ${PACTICIPANT} --version ${TRAVIS_COMMIT} --tag ${TARGET} -b ${PACT_BROKER_BASE_URL} -u ${PACT_BROKER_BASIC_AUTH_USERNAME} -p ${PACT_BROKER_BASIC_AUTH_PASSWORD}

## =====================
## Pactflow set up tasks
## =====================

# This should be called once before creating the webhook
# with the environment variable GITHUB_TOKEN set
create_github_token_secret:
	@curl -v -X POST ${PACT_BROKER_BASE_URL}/secrets \
	-H "Authorization: Bearer ${PACT_BROKER_TOKEN}" \
	-H "Content-Type: application/json" \
	-H "Accept: application/hal+json" \
	-d  "{\"name\":\"githubCommitStatusToken\",\"description\":\"Github token for updating commit statuses\",\"value\":\"${GITHUB_TOKEN}\"}"

# This webhook will update the Github commit status for this commit
# so that any PRs will get a status that shows what the status of
# the pact is.
create_or_update_github_webhook:
	@"${PACT_CLI}" \
	  broker create-or-update-webhook \
	  'https://api.github.com/repos/pactflow/example-consumer/statuses/$${pactbroker.consumerVersionNumber}' \
	  --header 'Content-Type: application/json' 'Accept: application/vnd.github.v3+json' 'Authorization: token $${user.githubCommitStatusToken}' \
	  --request POST \
	  --data @${PWD}/pactflow/github-commit-status-webhook.json \
	  --uuid ${GITHUB_WEBHOOK_UUID} \
	  --consumer ${PACTICIPANT} \
	  --contract-published \
	  --provider-verification-published \
	  --description "Github commit status webhook for ${PACTICIPANT}"

test_github_webhook:
	@curl -v -X POST ${PACT_BROKER_BASE_URL}/webhooks/${GITHUB_WEBHOOK_UUID}/execute -H "Authorization: Bearer ${PACT_BROKER_TOKEN}"


## ======================
## Travis CI set up tasks
## ======================

travis_login:
	@docker run --rm -v ${HOME}/.travis:/root/.travis -it lirantal/travis-cli login --pro

# Requires PACT_BROKER_TOKEN to be set
travis_encrypt_pact_broker_token:
	@docker run --rm -v ${HOME}/.travis:/root/.travis -v ${PWD}:${PWD} --workdir ${PWD} lirantal/travis-cli encrypt --pro PACT_BROKER_TOKEN="${PACT_BROKER_TOKEN}"

## ======================
## Misc
## ======================

.env:
	touch .env

output:
	mkdir -p ./pacts
	touch ./pacts/tmp

clean: output
	rm pacts/*