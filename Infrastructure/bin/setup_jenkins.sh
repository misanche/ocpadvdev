#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student
# Go to Jenkins project
oc project ${GUID}-jenkins
# Add roles to jenkins user in ${GUID}-jenkins
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-jenkins
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-jenkins
# Create the Jenkins app
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi -n ${GUID}-jenkins
oc set resources dc/jenkins --limits=cpu=1 --requests=memory=2Gi,cpu=1 -n ${GUID}-jenkins
# Create custom Jenkins Slave pod
cat ./Dockerfile | oc new-build --name=jenkins-slave-appdev --dockerfile=- -n ${GUID}-jenkins

oc set probe dc/jenkins -n $GUID-jenkins --liveness --failure-threshold 8 --initial-delay-seconds 600 -- echo ok
oc set probe dc/jenkins -n $GUID-jenkins --readiness --failure-threshold 8 --initial-delay-seconds 360 --get-url=http://:8080/login

while : ; do
    echo "Checking if Jenkins is Ready..."
    oc get pod -n ${GUID}-jenkins | grep jenkins | grep -v build | grep -v deploy |grep "1/1.*Running"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
    sleep 10
done


#echo "Create pipelines for mlbparks, nationalparks and parksmap"
#oc create -f ./Infrastructure/templates/pipelines/mlbparks-pipeline.yaml 
#oc create -f ./Infrastructure/templates/pipelines/nationalparks-pipeline.yaml 
#oc create -f ./Infrastructure/templates/pipelines/parksmap-pipeline.yaml 

echo "Set new pipelines based on ${REPO} - ${GUID} - ${CLUSTER}"
# Don't know why env vars are not created automatically
oc new-build ${REPO} --name=mlbparks-pipeline --strategy=pipeline --context-dir=./MLBParks -l app=pipeline -n ${GUID}-jenkins
oc env bc/mlbparks-pipeline GUID=${GUID} CLUSTER=${CLUSTER} -n ${GUID}-jenkins
oc cancel-build mlbparks-pipeline-1 -n ${GUID}-jenkins
oc new-build ${REPO} --name=nationalparks-pipeline --strategy=pipeline --context-dir=./Nationalparks -l app=pipeline -n ${GUID}-jenkins
oc env bc/nationalparks-pipeline GUID=${GUID} CLUSTER=${CLUSTER} -n ${GUID}-jenkins
oc cancel-build nationalparks-pipeline-1 -n ${GUID}-jenkins
oc new-build ${REPO} --name=parksmap-pipeline --strategy=pipeline --context-dir=./ParksMap -l app=pipeline -n ${GUID}-jenkins
oc env bc/parksmap-pipeline GUID=${GUID} CLUSTER=${CLUSTER} -n ${GUID}-jenkins
oc cancel-build parksmap-pipeline-1 -n ${GUID}-jenkins





