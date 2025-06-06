Exporter for the Zammad [object](https://admin-docs.zammad.org/en/latest/system/objects.html) types [Trigger](https://admin-docs.zammad.org/en/latest/manage/trigger.html), [Role](https://admin-docs.zammad.org/en/latest/manage/roles/index.html) and [Group](https://admin-docs.zammad.org/en/latest/manage/groups/index.html).

* Remote connection to Openshift via [openshift-cli-oc](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/cli_tools/openshift-cli-oc#cli-getting-started) to the correct project / namespace
* Find out the current rails server pod name via "oc get pods"
* Execute Rails command via "oc rsh <railsserver-pod> rails runner ..." to output objects or obtain the names of objects referenced by ID
* Replace IDs via search/replace with lookup functions + names
* Save as a local file

# Usage

```bash
./cac-trigger-exporter.sh <zammad-namespace> <trigger-name>
```
