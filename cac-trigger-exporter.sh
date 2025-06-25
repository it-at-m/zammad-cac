#!/bin/bash

echo "Make sure you're logged in to your Openshift-cluster first."

# Überprüfen, ob der Trigger-Name als Argument übergeben wurde
if [ "$#" -ne 2 ]; then
    echo "❌ Usage: $0 <zammad-namespace> <trigger-name>"
    exit 1
fi

PROJECT="$1"
TRIGGER_NAME="$2"
RAILS_POD_LABEL="app.kubernetes.io/component=zammad-railsserver"

# Ins richtige Projekt wechseln
oc project "$PROJECT" || { echo "❌ Couldn't change to project $PROJECT."; exit 1; }

# Pod-Namen eines aktuellen Railsservers herausfinden
RAILS_POD=$(oc get pods -l "$RAILS_POD_LABEL" -o name | head -n 1 | cut -d '/' -f 2)
if [ -z "$RAILS_POD" ]; then
    echo "❌ Kein \"rails\"-Pod gefunden."
    exit 1
fi

# Trigger extrahieren und in eine JSON-Datei schreiben
echo "Trying to load trigger <$TRIGGER_NAME> ..."
oc rsh "$RAILS_POD" rails runner "require 'pp'; result = Trigger.find_by(name: '$TRIGGER_NAME').attributes; pp result if result" > rails_output.txt || { echo "❌ Couldn't load trigger <$TRIGGER_NAME>."; exit 1; }

# Logausgaben (mit I... am Anfang) entfernen und in trigger.ruby schreiben
grep -v '^I' rails_output.txt > trigger.ruby
rm rails_output.txt

# Group_IDs für Source- und Target-Group herausparsen und Namen heraussuchen

triggerWithoutWhitespace=$(tr -d '\n' < trigger.ruby)
SOURCE_GROUP_ID_REGEX='"ticket\.group_id"=>[[:space:]]*\{"operator"=>[[:space:]]*"is",[[:space:]]*"value"=>[[:space:]]*\[?"?([0-9]+)"?\]?'
TARGET_GROUP_ID_REGEX='"perform"[[:space:]]*=>[[:space:]]*\{"ticket\.group_id"=>[[:space:]]*\{"value"=>[[:space:]]*\[?"?([0-9]+)"?\]?\}'

if [[ $triggerWithoutWhitespace =~ $SOURCE_GROUP_ID_REGEX ]]
then
    SOURCE_GROUP_ID="${BASH_REMATCH[1]}"
else
    echo "❌ Sourcegroup-ID couldn't be evaluated."
    exit 1
fi

if [[ $triggerWithoutWhitespace =~ $TARGET_GROUP_ID_REGEX ]]
then
    TARGET_GROUP_ID="${BASH_REMATCH[1]}"
else
    echo "❌ Targetgroup-ID couldn't be evaluated."
    exit 1
fi

echo "Trying to load name of sourcegroup <$SOURCE_GROUP_ID>..."
oc rsh "$RAILS_POD" rails runner "require 'pp'; result = Group.find_by_id($SOURCE_GROUP_ID).name_last; pp result if result" > sg_output.txt || { echo "❌ Couldn't load sourcegroup <$SOURCE_GROUP_ID>."; exit 1; }
SOURCE_GROUP_NAME=$(grep -v '^I' sg_output.txt | cut -d "\"" -f 2)
rm sg_output.txt
echo "Trying to load name of targetgroup <$TARGET_GROUP_ID>..."
oc rsh "$RAILS_POD" rails runner "require 'pp'; result = Group.find_by_id($TARGET_GROUP_ID).name_last; pp result if result" > tg_output.txt || { echo "❌ Couldn't load targetgroup <$TARGET_GROUP_ID>."; exit 1; }
TARGET_GROUP_NAME=$(grep -v '^I' tg_output.txt | cut -d "\"" -f 2)
rm tg_output.txt

echo "SOURCE_GROUP_NAME: $SOURCE_GROUP_NAME"
echo "TARGET_GROUP_NAME: $TARGET_GROUP_NAME"

# IDs ersetzen mit lookup
python cac-trigger-replacer.py --input trigger.ruby --output trigger_cac_ready.ruby --source-group $SOURCE_GROUP_NAME --target-group $TARGET_GROUP_NAME

rm trigger.ruby

echo "✅ Export completed successfully. Result --> trigger_cac_ready.ruby"