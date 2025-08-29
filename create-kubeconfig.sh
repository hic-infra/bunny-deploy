#!/bin/sh
set -eu

# https://stackoverflow.com/questions/29832037/how-to-get-script-directory-in-posix-sh/29835459#29835459
cd $(dirname  -- "$0")/eks-cluster
KUBECONFIG_FILE=../kubeconfig
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name) --kubeconfig "$KUBECONFIG_FILE"
