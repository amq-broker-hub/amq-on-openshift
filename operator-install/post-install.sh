# This scripts checks if "startingCSV" is set on the Subscription and in that case approves only the InstallPlan with the wanted CSV

if [ "oc get subscription.operators.coreos.com amq-broker-rhel8 -o jsonpath='{.spec.installPlanApproval}')" == "Manual" ]; then
  echo 'Waiting for InstallPlan to show up.'
  WHILECMD='[ -z "$(oc get installplan -l operators.coreos.com/amq-broker-rhel8.myproject -oname)" ]'
  timeout 15m sh -c "while $WHILECMD; do echo Waiting; sleep 10; done"

  # Search InstallPlan based on startingCSV
  startingCSV=$(oc get subscription.operators.coreos.com amq-broker-rhel8 -o jsonpath='{.spec.startingCSV}')
  if [ -z "$startingCSV" ]; then
    # no startingCSV: check all InstallPlans
    installplans=$(oc get installplan -l operators.coreos.com/amq-broker-rhel8.myproject -oname)
  else
    # startingCSV is set: get the InstallPlan with matching "clusterServiceVersionNames" to avoid unexpected upgrades.
    # This should return max one InstallPlan, unless multiple operators are installed in the same namespace
    installplans=$(oc get ip -ojson | jq -r '.items[] | select( .spec.clusterServiceVersionNames[] | contains("amq-broker-operator.v7.11.0-opr-2"))  | .metadata.name')
    # Could also filter for "approved == false" in one command, then we wouldn't need to check later
    #installplans=$(oc get ip -ojson | jq -r '.items[] | select( (.spec.clusterServiceVersionNames[] | contains("amq-broker-operator.v7.11.0-opr-3")) and .spec.approved == false )  | .metadata.name')
  fi
  
  # No InstallPlan found
  if [ -z "$installplans"]; then
    echo "No InstallPlan was found for operator with label operators.coreos.com/amq-broker-rhel8.myproject. This indicates a failure about operator installation."
    exit 1
  fi
  
  # Approve the InstallPlans
  for installplan in $installplans
  do
    if [ "$(oc get $installplan -o jsonpath='{.spec.approved}')" == "false" ]; then
      echo "Approving install plan $installplan"
      oc patch $installplan --type=json -p='[{"op":"replace","path": "/spec/approved", "value": true}]'
    else
      echo "Install Plan '$installplan' was already approved"
    fi
  done

fi