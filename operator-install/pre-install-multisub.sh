# Delete all other Subscriptions to avoid unwanted upgrades. 
oc delete subscription.operators.coreos.com --all
# Delete all InstallPlans
oc delete installplan.operators.coreos.com --all
# Delete the ClusterServiceVersion that we're reinstalling to avoid "clusterserviceversion exists and is not referenced by a subscription" error. This also deletes the running operator.
oc delete csv -l operator-activemqartemis
