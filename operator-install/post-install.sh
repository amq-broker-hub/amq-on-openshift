# This scripts checks if "startingCSV" is set on the Subscription and in that case approves only the InstallPlan with the wanted CSV

if [[ "$(oc get subscription.operators.coreos.com amq-broker-rhel8 -o jsonpath='{.spec.installPlanApproval}')" == "Manual" ]]; then
  echo 'Wait for InstallPlan'
  WHILECMD='[ -z "$(oc get subscriptions.operators.coreos.com amq-broker-rhel8 -o jsonpath={.status.installPlanRef.name})" ]'
  timeout 5m sh -c "while $WHILECMD; do echo Waiting; sleep 10; done"

  # Get last InstallPlan for Subscription
  installplan=$(oc get subscriptions.operators.coreos.com amq-broker-rhel8 -o jsonpath={.status.installPlanRef.name})
  # No InstallPlan found
  if [ -z "$installplan" ]; then
    echo "No InstallPlan was found for subscription amq-broker-rhel8. This indicates a failure about operator installation."
    exit 1
  fi

  # If startingCSV is set, patch InstallPlan only with matching "clusterServiceVersionNames" to avoid unexpected upgrades.
  startingCSV=$(oc get subscription.operators.coreos.com amq-broker-rhel8 -o jsonpath='{.spec.startingCSV}')
  if [ -n "$startingCSV" ]; then
    echo "Check if InstallPlan $installplan has CSV $startingCSV"
    installplan=$(oc get installplan.operators.coreos.com $installplan -ojson | jq -r 'select( .spec.clusterServiceVersionNames[] | contains("'$startingCSV'")) | .metadata.name')
    # No InstallPlan found
    if [ -z "$installplan" ]; then
      echo "InstallPlan doesn't have expected CSV $startingCSV. Won't approve."
      exit 0
    fi
  fi
  
  # Approve the InstallPlan
  if [[ "$(oc get installplan.operators.coreos.com $installplan -o jsonpath='{.spec.approved}')" == "false" ]]; then
    echo "Approving InstallPlan $installplan"
    oc patch installplan.operators.coreos.com $installplan --type=json -p='[{"op":"replace","path": "/spec/approved", "value": true}]'
  else
    echo "InstallPlan $installplan was already approved"
  fi
  
fi