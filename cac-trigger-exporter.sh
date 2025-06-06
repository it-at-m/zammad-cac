#!/bin/bash

echo "Stelle sicher, dass du dich zuvor per 'oc login' am Cluster angemeldet hast."

# Überprüfen, ob der Trigger-Name als Argument übergeben wurde
if [ "$#" -ne 2 ]; then
    echo "❌ Usage: $0 <zammad-namespace> <trigger-name>"
    exit 1
fi

PROJECT="$1"
TRIGGER_NAME="$2"
RAILS_POD_LABEL="app.kubernetes.io/component=zammad-railsserver"

# Ins richtige Projekt wechseln
oc project "$PROJECT" || { echo "❌ Konnte nicht zu Projekt $PROJECT wechseln."; exit 1; }

# Pod-Namen eines aktuellen Railsservers herausfinden
RAILS_POD=$(oc get pods -l "$RAILS_POD_LABEL" -o name | head -n 1 | cut -d '/' -f 2)
if [ -z "$RAILS_POD" ]; then
    echo "❌ Kein \"rails\"-Pod gefunden."
    exit 1
fi

# Trigger extrahieren und in eine JSON-Datei schreiben
echo "Versuche Trigger <$TRIGGER_NAME> zu laden..."
oc rsh "$RAILS_POD" rails runner "require 'pp'; result = Trigger.find_by(name: '$TRIGGER_NAME').attributes; pp result if result" > rails_output.txt || { echo "❌ Konnte Trigger <$TRIGGER_NAME> nicht laden."; exit 1; }

# Logausgaben (mit I... am Anfang) entfernen und in trigger.ruby schreiben
grep -v '^I' rails_output.txt > trigger.ruby
rm rails_output.txt

# Group_IDs für Source- und Target-Group herausparsen und Namen heraussuchen

triggerWithoutWhitespace=$(tr -d '\n' < trigger.ruby)
SOURCE_GROUP_ID_REGEX='"ticket\.group_id"=>\s*\{"operator"=>\s*"is",\s*"value"=>\s*\[([0-9]+)\]'
TARGET_GROUP_ID_REGEX='"perform"=>\s*\{"ticket\.group_id"=>\s*\{"value"=>\s*([0-9]+)\}\}'

if [[ $triggerWithoutWhitespace =~ $SOURCE_GROUP_ID_REGEX ]]
then
    SOURCE_GROUP_ID="${BASH_REMATCH[1]}"
else
    echo "❌ Sourcegroup-ID konnte nicht ermittelt werden."
    exit 1
fi

if [[ $triggerWithoutWhitespace =~ $TARGET_GROUP_ID_REGEX ]]
then
    TARGET_GROUP_ID="${BASH_REMATCH[1]}"
else
    echo "❌ Targetgroup-ID konnte nicht ermittelt werden."
    exit 1
fi

echo "Versuche Name von Sourcegroup <$SOURCE_GROUP_ID> zu laden..."
oc rsh "$RAILS_POD" rails runner "require 'pp'; result = Group.find_by_id($SOURCE_GROUP_ID).name_last; pp result if result" > sg_output.txt || { echo "❌ Konnte Sourcegroup <$SOURCE_GROUP_ID> nicht laden."; exit 1; }
SOURCE_GROUP_NAME=$(grep -v '^I' sg_output.txt | cut -d "\"" -f 2)
rm sg_output.txt
echo "Versuche Name von Targetgroup <$TARGET_GROUP_ID> zu laden..."
oc rsh "$RAILS_POD" rails runner "require 'pp'; result = Group.find_by_id($TARGET_GROUP_ID).name_last; pp result if result" > tg_output.txt || { echo "❌ Konnte Targetgroup <$TARGET_GROUP_ID> nicht laden."; exit 1; }
TARGET_GROUP_NAME=$(grep -v '^I' tg_output.txt | cut -d "\"" -f 2)
rm tg_output.txt

echo "SOURCE_GROUP_NAME: $SOURCE_GROUP_NAME"
echo "TARGET_GROUP_NAME: $TARGET_GROUP_NAME"

# IDs ersetzen mit lookup
python cac-trigger-replacer.py --input trigger.ruby --output trigger_cac_ready.ruby --source-group $SOURCE_GROUP_NAME --target-group $TARGET_GROUP_NAME

rm trigger.ruby

echo "✅ Export erfolgreich. Ergebnis --> trigger_cac_ready.ruby"