#!/usr/bin/env bash

echo "Deleting TSB Objects"
envsubst < 01-multi-tenancy/01-workspaces.yaml | tctl delete -f - 

echo "Apps from k8s"
echo "--Cleaning tier1--"
envsubst < 02-app-deploy/tier1/cluster-t1.yaml | kubectl --context tier1 delete -f -
echo "--Cleaning cloud-a-01--"
envsubst < 02-app-deploy/cloud-a-01/app.yaml | kubectl --context cloud-a-01 delete -f -
envsubst < 02-app-deploy/cloud-a-01/cluster-ingress-gw.yaml | kubectl --context cloud-a-01 delete -f -
echo "--Cleaning cloud-a-02--"
envsubst < 02-app-deploy/cloud-a-02/app.yaml | kubectl --context cloud-a-02 delete -f -
envsubst < 02-app-deploy/cloud-a-02/cluster-ingress-gw.yaml | kubectl --context cloud-a-02 delete -f -
echo "--Cleaning cloud-b-01--"
envsubst < 02-app-deploy/cloud-b-01/app.yaml | kubectl --context cloud-b-01 delete -f -
envsubst < 02-app-deploy/cloud-b-01/cluster-ingress-gw.yaml | kubectl --context cloud-b-01 delete -f -