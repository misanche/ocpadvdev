#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"

echo "Go to project $GUID-sonarqube"
oc project ${GUID}-sonarqube


# Import nexus Imagestream
#oc import-image sonarqube --from=wkulhanek/sonarqube:6.7.4 --confirm

# tag the image
#oc tag sonarqube ${GUID}-sonarqube/sonarqube:6.7.4

# Code to set up the SonarQube project.
# Ideally just calls a template
oc new-app -f ./Infrastructure/templates/sonarqube_db.yaml -n ${GUID}-parks-prod
oc new-app -f ./Infrastructure/templates/sonarqube.yaml -n ${GUID}-parks-prod
# To be Implemented by Student
