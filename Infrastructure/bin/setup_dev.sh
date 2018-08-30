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
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-jenkins
oc policy add-role-to-user view --serviceaccount=default
echo "Create mongodb from template"
oc new-app -f ./Infrastructure/templates/mongodb_dev.yaml
echo "create mongodb configmap"
oc create configmap mongodb-configmap --from-literal DB_HOST=mongodb --from-literal DB_PORT=27017 --from-literal DB_USERNAME=mongodb --from-literal DB_PASSWORD=mongodb --from-literal DB_NAME=parks
echo "Create MLBParks"
# Build Config
oc new-build --binary=true --allow-missing-images=true --image-stream=jboss-eap70-openshift:1.7 --name mlbparks -l app=mlbparks
#  Create mlbparks-configmap
oc create configmap mlbparks-configmap --from-literal APPNAME="MLB Parks (Dev)"
# Create mlbparks app.
oc new-app -l app=mlbparks --image-stream=7077-parks-dev/mlbparks:latest --allow-missing-imagestream-tags=true --name=mlbparks
# Update environment vars
oc set env dc/mlbparks --from=configmap/mlbparks-configmap
oc set env dc/mlbparks --from=configmap/mongodb-configmap
# Deployment hooks
oc set triggers dc/mlbparks --remove-all
# Expose the dc
oc expose dc mlbparks --port 8080
# Expose the svc
oc expose svc mlbparks --labels="type=parksmap-backend"
# Set readiness and liveness probes
oc set probe dc/mlbparks --liveness --failure-threshold=4 --initial-delay-seconds=35 -- echo ok
oc set probe dc/mlbparks --readiness --get-url=http://:8080/ws/healthz/ --failure-threshold=4 --initial-delay-seconds=60

echo "Create Nationalparks"
oc new-build --binary=true --allow-missing-images=true --image-stream=redhat-openjdk18-openshift:1.2 --name=nationalparks -l app=nationalparks
# Create configmap
oc create configmap nationalparks-configmap --from-literal APPNAME="National Parks (Dev)"
# Create Nationalparks app
oc new-app -l app=nationalparks --image-stream=7077-parks-dev/nationalparks:latest --allow-missing-imagestream-tags=true --name=nationalparks
# Modify dc with configmap values
oc set env dc/nationalparks --from=configmap/nationalparks-configmap
oc set env dc/nationalparks --from=configmap/mongodb-configmap
# Remove all the trigers
oc set triggers dc/nationalparks --remove-all
# Expose dc
oc expose dc nationalparks --port 8080
# Expose svc
oc expose svc nationalparks -l "type=parksmap-backend"
# Liveness and probes 
oc set probe dc/nationalparks --liveness --failure-threshold=4 --initial-delay-seconds=35 -- echo ok
oc set probe dc/nationalparks --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url='http://:8080/ws/healthz/'

echo "Create ParksMap"
# Create the bc
oc new-build --name=parksmap --image-stream=redhat-openjdk18-openshift:1.2 --allow-missing-imagestream-tags=true --binary=true -l app=parksmap
# Create configmap
oc create configmap parksmap-configmap --from-literal APPNAME="ParksMap (Dev)"
# Create new app
oc new-app --image-stream=7077-parks-dev/parksmap:latest --allow-missing-imagestream-tags --name=parksmap -l app=parksmap
# Set env vars from configmap
oc set env dc/parksmap --from=configmap/parksmap-configmap
# Remove triggers
oc set triggers dc/parksmap --remove-all
# Setup liveness probes
oc set probe dc/parksmap --liveness --initial-delay-seconds=35 --failure-threshold=4 -- echo ok
oc set probe dc/parksmap --readiness --initial-delay-seconds=60 --failure-threshold=4 --get-url='http://:8080/ws/healthz/'
# Expose dc and routes
oc expose dc parksmap --port 8080
oc expose svc parksmap