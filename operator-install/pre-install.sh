# Delete all other Subscriptions to avoid unwanted upgrades. This will also remove all InstallPlans
oc delete subscription --all
# Delete the ClusterServiceVersion that we're reinstalling to avoid "clusterserviceversion exists and is not referenced by a subscription" error. This also deletes the running operator.
oc delete csv -l operator-activemqartemis
