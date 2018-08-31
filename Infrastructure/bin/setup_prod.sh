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