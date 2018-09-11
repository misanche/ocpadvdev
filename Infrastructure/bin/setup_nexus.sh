#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

echo "Add roles"
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-nexus
# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Import nexus Imagestream
#oc import-image nexus3 --from=sonatype/nexus3 --confirm

# tag the image
#oc tag sonatype/nexus3 ${GUID}-nexus/nexus3:latest

# Ideally just calls a template
oc new-app -f ./Infrastructure/templates/nexus.yaml -n ${GUID}-nexus

# To be Implemented by Student

#Check until is up
while : ; do
    echo "Checking if Nexus is Ready..."
    oc get pod -n ${GUID}-nexus|grep '\-1\-'|grep -v deploy|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
    sleep 10
done

echo "configure now"
chmod +x ./Infrastructure/bin/nexus_configuration.sh
./Infrastructure/bin/nexus_configuration.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus )
