SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := menu

# Personal values (subscription, admin accounts) live in .env, see .env.example.
-include .env

AZ_RESOURCE_GROUP ?= mpetitRG
AZ_LOCATION       ?= francecentral
CLUSTER_NAME      ?= aks-gitlab-runners
GITLAB_PROJECT    ?= WhiteMuush/gitlab-runner-on-azure
# Numeric id, so the Terraform state address needs no URL-encoded project path.
GITLAB_PROJECT_ID ?= 87248404
DOMAIN            ?= gitlab-runner-mpetit.francecentral.cloudapp.azure.com
# Storage account for the Velero backups.
BACKUP_STORAGE_ACCOUNT ?= stmpetitvelero
LOG_FILE          ?= .logs/pipeline.log

export AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP AZ_LOCATION CLUSTER_NAME CLUSTER_ADMINS
export DOMAIN GITLAB_PROJECT GITLAB_PROJECT_ID GITLAB_USER GITLAB_TOKEN GITLAB_RUNNER_TOKEN LOG_FILE CONFIRM

# Same values handed to Terraform, so the Makefile stays the single source of configuration.
export TF_VAR_subscription_id     = $(AZ_SUBSCRIPTION_ID)
export TF_VAR_resource_group_name = $(AZ_RESOURCE_GROUP)
export TF_VAR_cluster_name        = $(CLUSTER_NAME)
export TF_VAR_backup_storage_account = $(BACKUP_STORAGE_ACCOUNT)

include makefiles/setup.mk
include makefiles/infra.mk
include makefiles/cluster.mk
include makefiles/status.mk
include makefiles/runner.mk
include makefiles/grafana.mk
include makefiles/dev.mk
