: ${1?"Must supply attendee CSV path as an argument"}

FOO_NO_WHITESPACE="$(echo -e "${FOO}" | tr -d '[:space:]')"
while IFS="," read -r ATTENDEE ATTENDEE_EMAIL AD_EMAIL AD_UID PREFIX JUMPBOX_IP READY
do
  export READY_TRIMMED="$(echo -e "${READY}" | tr -d '[:space:]')"
  if [[ $READY_TRIMMED == "Yes" ]]; then
    echo "Attendee: $ATTENDEE"
    echo "Attendee Email: $ATTENDEE_EMAIL"
    echo "Azure AD Email: $AD_EMAIL"
    echo "Azure AZ UID: $AD_UID"
    echo "Env Prefix: $PREFIX"
    echo "Jumpbox: $JUMPBOX_IP"

    echo "Deleting TSB Objects"
    PREFIX=$PREFIX envsubst < 01-multi-tenancy/01-workspaces.yaml | tctl delete -f - 

    echo "Apps from k8s"
    echo "--Cleaning tier1--"
    PREFIX=$PREFIX envsubst < 02-app-deploy/tier1/cluster-t1.yaml | kubectl --context tier1 delete -f -
    echo "--Cleaning cloud-a-01--"
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-a-01/app.yaml | kubectl --context cloud-a-01 delete -f -
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-a-01/cluster-ingress-gw.yaml | kubectl --context cloud-a-01 delete -f -
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-a-01/app-marketdata.yaml | kubectl --context cloud-a-01 delete -f -
    PREFIX=$PREFIX envsubst < 08-app-security-egress/02-egress-gw.yaml | kubectl --context cloud-a-01 delete -f -
    echo "--Cleaning cloud-a-02--"
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-a-02/app.yaml | kubectl --context cloud-a-02 delete -f -
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-a-02/cluster-ingress-gw.yaml | kubectl --context cloud-a-02 delete -f -
    PREFIX=$PREFIX envsubst < 08-app-security-egress/02-egress-gw.yaml | kubectl --context cloud-a-02 delete -f -
    echo "--Cleaning cloud-b-01--"
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-b-01/app.yaml | kubectl --context cloud-b-01 delete -f -
    PREFIX=$PREFIX envsubst < 02-app-deploy/cloud-b-01/cluster-ingress-gw.yaml | kubectl --context cloud-b-01 delete -f -
    PREFIX=$PREFIX envsubst < 08-app-security-egress/02-egress-gw.yaml | kubectl --context cloud-b-01 delete -f -

    PREFIX=$PREFIX tctl delete tenant $PREFIX-workshop
    

  else
    echo "Skipping env for attendee: $ATTENDEE.  Not Ready"
  fi 
done < <(tail -n +2 $1)
