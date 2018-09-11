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
echo "Grant permissions"
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-prod

echo "Create MongoDB"
oc new-app -f ./Infrastructure/templates/mongodb_prod.yaml -n ${GUID}-parks-prod

while : ; do
    echo "Checking if MongoDB-0'' Replica is Ready..."
    oc get pod -n ${GUID}-parks-prod|grep 'mongodb-0'|grep -v deploy|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
    sleep 10
done

while : ; do
    echo "Checking if MongoDB-1 Replica is Ready..."
    oc get pod -n ${GUID}-parks-prod|grep 'mongodb-1'|grep -v deploy|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
    sleep 10
done

while : ; do
    echo "Checking if MongoDB-2 Replica is Ready..."
    oc get pod -n ${GUID}-parks-prod|grep 'mongodb-2'|grep -v deploy|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
    sleep 10
done

echo "Create ConfiMaps"
oc create configmap mongodb-configmap --from-literal DB_HOST=mongodb --from-literal DB_PORT=27017 --from-literal DB_USERNAME=mongodb --from-literal DB_PASSWORD=mongodb --from-literal DB_NAME=parks --from-literal DB_REPLICASET=rs0 -n ${GUID}-parks-prod
oc create configmap mlbparks-green-configmap --from-literal APPNAME="MLB Parks (Green)" -n ${GUID}-parks-prod
oc create configmap mlbparks-blue-configmap --from-literal APPNAME="MLB Parks (Blue)" -n ${GUID}-parks-prod
oc create configmap nationalparks-green-configmap --from-literal APPNAME="National Parks (Green)" -n ${GUID}-parks-prod
oc create configmap nationalparks-blue-configmap --from-literal APPNAME="National Parks (Blue)" -n ${GUID}-parks-prod
oc create configmap parksmap-green-configmap --from-literal APPNAME="ParksMap (Green)" -n ${GUID}-parks-prod
oc create configmap parksmap-blue-configmap --from-literal APPNAME="ParksMap (Blue)" -n ${GUID}-parks-prod

echo "Crate mlbparks App"
echo "Create Green"
oc new-app ${GUID}-parks-prod/mlbparks:0.0 -l app=mlbparks-green --allow-missing-imagestream-tags=true --allow-missing-images=true --name=mlbparks-green -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod
oc rollout cancel dc/mlbparks-green -n ${GUID}-parks-prod
oc set env dc/mlbparks-green --from=configmap/mongodb-configmap -n ${GUID}-parks-prod
oc set env dc/mlbparks-green --from=configmap/mlbparks-green-configmap -n ${GUID}-parks-prod
oc patch dc/mlbparks-green -p='{"spec": {"strategy": {"type": "Recreate"}}}' -n ${GUID}-parks-prod
oc expose dc mlbparks-green --port 8080 -n ${GUID}-parks-prod
oc set probe dc/mlbparks-green --liveness --failure-threshold=4 -n ${GUID}-parks-prod --initial-delay-seconds=35 -- echo ok
oc set probe dc/mlbparks-green --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/" -n ${GUID}-parks-prod
oc set deployment-hook dc/mlbparks-green -n ${GUID}-parks-prod --post -- curl -s http://mlbparks:8080/ws/data/load/ 

echo "Create Blue"
oc new-app ${GUID}-parks-prod/mlbparks:0.0 -l app=mlbparks-blue  --allow-missing-imagestream-tags=true --allow-missing-images=true --name=mlbparks-blue -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-blue --remove-all -n ${GUID}-parks-prod
oc rollout cancel dc/mlbparks-blue -n ${GUID}-parks-prod
oc set env dc/mlbparks-blue --from=configmap/mongodb-configmap -n ${GUID}-parks-prod
oc set env dc/mlbparks-blue --from=configmap/mlbparks-blue-configmap -n ${GUID}-parks-prod
oc patch dc/mlbparks-blue -p '{"spec": {"strategy": {"type": "Recreate"}}}' -n ${GUID}-parks-prod
oc expose dc mlbparks-blue --port 8080 -n ${GUID}-parks-prod
oc set probe dc/mlbparks-blue --liveness --failure-threshold=4 -n ${GUID}-parks-prod --initial-delay-seconds=35 -- echo ok 
oc set probe dc/mlbparks-blue --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/" -n ${GUID}-parks-prod

echo "Create National Parks"
echo "Create Green"
oc new-app ${GUID}-parks-prod/nationalparks:0.0  -l app=nationalparks-green --allow-missing-imagestream-tags=true --allow-missing-images=true --name=nationalparks-green -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod
oc patch dc/nationalparks-green -p '{"spec": {"strategy": {"type": "Recreate"}}}' -n ${GUID}-parks-prod
oc rollout cancel dc/nationalparks-green -n ${GUID}-parks-prod
oc set env dc/nationalparks-green --from=configmap/mongodb-configmap -n ${GUID}-parks-prod
oc set env dc/nationalparks-green --from=configmap/nationalparks-green-configmap -n ${GUID}-parks-prod
oc expose dc nationalparks-green --port 8080 -n ${GUID}-parks-prod
oc set probe dc/nationalparks-green --liveness --failure-threshold=4 -n ${GUID}-parks-prod --initial-delay-seconds=35 -- echo ok
oc set probe dc/nationalparks-green --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/" -n ${GUID}-parks-prod
oc set deployment-hook dc/nationalparks-green -n ${GUID}-parks-prod --post -- curl -s http://mlbparks:8080/ws/data/load/ 

echo "Create Blue"
oc new-app ${GUID}-parks-prod/nationalparks:0.0  -l app=nationalparks-blue --allow-missing-imagestream-tags=true --allow-missing-images=true --name=nationalparks-blue -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc patch dc/nationalparks-blue -p '{"spec": {"strategy": {"type": "Recreate"}}}' -n ${GUID}-parks-prod
oc rollout cancel dc/nationalparks-blue -n ${GUID}-parks-prod
oc set env dc/nationalparks-blue --from=configmap/mongodb-configmap -n ${GUID}-parks-prod
oc set env dc/nationalparks-blue --from=configmap/nationalparks-blue-configmap -n ${GUID}-parks-prod
oc expose dc nationalparks-blue --port 8080 -n ${GUID}-parks-prod
oc set probe dc/nationalparks-blue --liveness --failure-threshold=4 -n ${GUID}-parks-prod --initial-delay-seconds=35 -- echo ok
oc set probe dc/nationalparks-blue --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/" -n ${GUID}-parks-prod

echo "Create ParksMap"
echo "Create Green"
oc new-app ${GUID}-parks-prod/parksmap:0.0  -l app=parksmap-green --allow-missing-imagestream-tags=true --allow-missing-images=true --name=parksmap-green -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod
oc patch dc/parksmap-green -p '{"spec": {"strategy": {"type": "Recreate"}}}' -n ${GUID}-parks-prod
oc rollout cancel dc/parksmap-green -n ${GUID}-parks-prod
oc set env dc/parksmap-green --from=configmap/mongodb-configmap -n ${GUID}-parks-prod
oc set env dc/parksmap-green --from=configmap/parksmap-green-configmap -n ${GUID}-parks-prod
oc expose dc parksmap-green --port 8080 -n ${GUID}-parks-prod
oc set probe dc/parksmap-green --liveness --failure-threshold=4 -n ${GUID}-parks-prod --initial-delay-seconds=35 -- echo ok
oc set probe dc/parksmap-green --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/" -n ${GUID}-parks-prod

echo "Create Blue"
oc new-app ${GUID}-parks-prod/parksmap:0.0  -l app=parksmap-blue --allow-missing-imagestream-tags=true --allow-missing-images=true --name=parksmap-blue -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc patch dc/parksmap-blue -p '{"spec": {"strategy": {"type": "Recreate"}}}' -n ${GUID}-parks-prod
oc rollout cancel dc/parksmap-blue -n ${GUID}-parks-prod
oc set env dc/parksmap-blue --from=configmap/mongodb-configmap -n ${GUID}-parks-prod
oc set env dc/parksmap-blue --from=configmap/parksmap-blue-configmap -n ${GUID}-parks-prod
oc expose dc parksmap-blue --port 8080 -n ${GUID}-parks-prod
oc set probe dc/parksmap-blue --liveness --failure-threshold=4 -n ${GUID}-parks-prod --initial-delay-seconds=35 -- echo ok
oc set probe dc/parksmap-blue --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/" -n ${GUID}-parks-prod

echo "Expose Green Services"
oc expose svc mlbparks-green --name=mlbparks -n ${GUID}-parks-prod
oc expose svc nationalparks-green --name=nationalparks -n ${GUID}-parks-prod
oc expose svc parksmap-green --name=parksmap -n ${GUID}-parks-prod