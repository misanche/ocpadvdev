#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

# To be Implemented by Student
echo "Go to project ${GUID}-parks-prod"
oc project ${GUID}-parks-prod
echo "Grant permissions"
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user system:image-puller system:serviceaccounts:${GUID}-parks-prod -n 7077-parks-dev
oc policy add-role-to-user view --serviceaccount=default

echo "Create MongoDB"
oc new-app -f ./Infrastructure/templates/mongodb_prod.yaml
echo "Create ConfiMaps"
oc create configmap mongodb-configmap --from-literal DB_HOST=mongodb --from-literal DB_PORT=27017 --from-literal DB_USERNAME=mongodb --from-literal DB_PASSWORD=mongodb --from-literal DB_NAME=parks --from-literal DB_REPLICASET=rs0
oc create configmap mlbparks-green-configmap --from-literal APPNAME="MLB Parks (Green)"
oc create configmap mlbparks-blue-configmap --from-literal APPNAME="MLB Parks (Blue)"
oc create configmap nationalparks-green-configmap --from-literal APPNAME="National Parks (Green)"
oc create configmap nationalparks-blue-configmap --from-literal APPNAME="National Parks (Blue)"
oc create configmap parksmap-green-configmap --from-literal APPNAME="ParksMap (Green)"
oc create configmap parksmap-blue-configmap --from-literal APPNAME="ParksMap (Blue)"

echo "Crate mlbparks App"
echo "Create Green"
oc new-app -l 7077-parks-prod/mlbparks:0.0 app=mlbparks-green --allow-missing-imagestream-tags=true --allow-missing-images=true --name=mlbparks-green
oc rollout cancel dc/mlbparks-green
echo "Create Blue"
oc new-app -l 7077-parks-prod/mlbparks:0.0 app=mlbparks-blue  --allow-missing-imagestream-tags=true --name=mlbparks-blue
oc rollout cancel dc/mlbparks-blue