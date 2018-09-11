#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student

# go to project
oc project ${GUID}-parks-dev

echo "Set Permissions"
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-dev
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-dev
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-dev
echo "Create mongodb from template"
oc new-app -f ./Infrastructure/templates/mongodb_dev.yaml -n ${GUID}-parks-dev
echo "create mongodb configmap"
oc create configmap mongodb-configmap --from-literal DB_HOST=mongodb --from-literal DB_PORT=27017 --from-literal DB_USERNAME=mongodb --from-literal DB_PASSWORD=mongodb --from-literal DB_NAME=parks -n ${GUID}-parks-dev
echo "Create MLBParks"
# Build Config
oc new-build --binary=true --allow-missing-images=true --image-stream=jboss-eap70-openshift:1.7 --name mlbparks -l app=mlbparks -n ${GUID}-parks-dev
#  Create mlbparks-configmap
oc create configmap mlbparks-configmap --from-literal APPNAME="MLB Parks (Dev)" -n ${GUID}-parks-dev
# Create mlbparks app.
oc new-app -l app=mlbparks --image-stream=${GUID}-parks-dev/mlbparks:latest --allow-missing-imagestream-tags=true --name=mlbparks -n ${GUID}-parks-dev
# Update environment vars
oc set env dc/mlbparks --from=configmap/mlbparks-configmap -n ${GUID}-parks-dev
oc set env dc/mlbparks --from=configmap/mongodb-configmap -n ${GUID}-parks-dev
# Deployment hooks
oc set triggers dc/mlbparks --remove-all -n ${GUID}-parks-dev
# Expose the dc
oc expose dc mlbparks --port 8080 -n ${GUID}-parks-dev
# Expose the svc
oc expose svc mlbparks --labels="type=parksmap-backend" -n ${GUID}-parks-dev
# Set readiness and liveness probes
oc set probe dc/mlbparks --liveness --failure-threshold=4 -n ${GUID}-parks-dev --initial-delay-seconds=35 -- echo ok
oc set probe dc/mlbparks --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=4 --initial-delay-seconds=60 -n ${GUID}-parks-dev
oc set deployment-hook dc/mlbparks -n ${GUID}-parks-dev --post -- curl -s http://mlbparks:8080/ws/data/load/ 

echo "Create Nationalparks"
oc new-build --binary=true --allow-missing-images=true --image-stream=redhat-openjdk18-openshift:1.2 --name=nationalparks -l app=nationalparks -n ${GUID}-parks-dev
# Create configmap
oc create configmap nationalparks-configmap --from-literal APPNAME="National Parks (Dev)" -n ${GUID}-parks-dev
# Create Nationalparks app
oc new-app -l app=nationalparks --image-stream=${GUID}-parks-dev/nationalparks:latest --allow-missing-imagestream-tags=true --name=nationalparks -n ${GUID}-parks-dev
# Modify dc with configmap values
oc set env dc/nationalparks --from=configmap/nationalparks-configmap -n ${GUID}-parks-dev
oc set env dc/nationalparks --from=configmap/mongodb-configmap -n ${GUID}-parks-dev
# Remove all the trigers
oc set triggers dc/nationalparks --remove-all -n ${GUID}-parks-dev
# Expose dc
oc expose dc nationalparks --port 8080 -n ${GUID}-parks-dev
# Expose svc
oc expose svc nationalparks -l "type=parksmap-backend" -n ${GUID}-parks-dev
# Liveness and probes 
oc set probe dc/nationalparks --liveness --failure-threshold=4 -n ${GUID}-parks-dev --initial-delay-seconds=35 -- echo ok
oc set probe dc/nationalparks --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url='http://:8080/ws/healthz/' -n ${GUID}-parks-dev
oc set deployment-hook dc/nationalparks -n ${GUID}-parks-dev --post -- curl -s http://mlbparks:8080/ws/data/load/ 

echo "Create ParksMap"
# Create the bc
oc new-build --name=parksmap --image-stream=redhat-openjdk18-openshift:1.2 --allow-missing-imagestream-tags=true --binary=true -l app=parksmap -n ${GUID}-parks-dev
# Create configmap
oc create configmap parksmap-configmap --from-literal APPNAME="ParksMap (Dev)" -n ${GUID}-parks-dev
# Create new app
oc new-app --image-stream=${GUID}-parks-dev/parksmap:latest --allow-missing-imagestream-tags --name=parksmap -l app=parksmap -n ${GUID}-parks-dev
# Set env vars from configmap
oc set env dc/parksmap --from=configmap/parksmap-configmap -n ${GUID}-parks-dev
# Remove triggers
oc set triggers dc/parksmap --remove-all -n ${GUID}-parks-dev
# Setup liveness probes
oc set probe dc/parksmap --liveness --initial-delay-seconds=35 -n ${GUID}-parks-dev --failure-threshold=4 -- echo ok
oc set probe dc/parksmap --readiness --initial-delay-seconds=60 --failure-threshold=4 --get-url='http://:8080/ws/healthz/' -n ${GUID}-parks-dev
# Expose dc and routes
oc expose dc parksmap --port 8080 -n ${GUID}-parks-dev
oc expose svc parksmap -n ${GUID}-parks-dev