if [ "oc get subscription.operators.coreos.com amq-broker-rhel8 -o jsonpath='{.spec.installPlanApproval}')" == "Manual" ]; then
  echo 'Waiting for InstallPlan to show up.'
  WHILECMD='[ -z "$(oc get installplan -l operators.coreos.com/amq-broker-rhel8.myproject -oname)" ]'
  timeout 15m sh -c "while $WHILECMD; do echo Waiting; sleep 10; done"

  # There should be only one InstallPlan if pre-install.sh was run at the beginnig.
  installplans=$(oc get installplan -l operators.coreos.com/amq-broker-rhel8.myproject -oname)
  if [ -z "$installplans"]; then
    echo "No InstallPlan was found for operator with label operators.coreos.com/amq-broker-rhel8.myproject. This indicates a failure about operator installation."
    exit 1
  fi
  
  for installplan in $installplans
  do
    if [ "$(oc get $installplan -o jsonpath='{.spec.approved}')" == "false" ]; then
      echo "Approving install plan $installplan"
      oc patch $installplan --type=json -p='[{"op":"replace","path": "/spec/approved", "value": true}]'
    else
      echo "Install Plan '$installplan' already approved"
    fi
  done
fi