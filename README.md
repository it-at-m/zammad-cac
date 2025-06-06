Exporter for the Zammad object types Trigger, Role and Group. 

* Remote connection to Openshift via OC-Tools command line to the correct project / namespace
* Find out the current rails server pod name via "oc get pods"
* Execute Rails command via "oc rsh <railsserver-pod> rails runner ..." to output objects or obtain the names of objects referenced by ID
* Replace IDs via search/replace with lookup functions + names
* Save as a local file

# Usage

```bash
./cac-trigger-exporter.sh <zammad-namespace> <trigger-name>
```
