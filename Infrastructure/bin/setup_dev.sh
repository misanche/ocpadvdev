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

echo "Create mongodb from template"
oc new-app -f ./Infrastructure/templates/mongodb_dev.yaml
echo "Create MLBParks from template"
oc new-app -f ./Infrastructure/templates/mlbparks_dev.yaml
echo "Create Nationalparks from template"
oc new-app -f ./Infrastructure/templates/nationalparks_dev.yaml
echo "Create ParksMap from template"
oc new-app -f ./Infrastructure/templates/parksmap_dev.yaml