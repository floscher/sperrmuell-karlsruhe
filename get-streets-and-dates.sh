#!/bin/bash


ICAL_FILE='sperrmuell-karlsruhe.ics'

if [ -f "$ICAL_FILE" ]; then
  read -p "Die Datei $ICAL_FILE existiert bereits. Soll sie überschrieben werden? (j/N) " answer
  case $answer in
    [Jj]* ) ;;
    * ) exit 1;;
  esac
fi

echo 'BEGIN:VCALENDAR' > $ICAL_FILE
echo 'VERSION:2.0' >> $ICAL_FILE
echo 'PRODID:github.com/meyermarcel' >> $ICAL_FILE

SERVER=$1
URL="${SERVER}/service/abfall/akal/akal.php"

optionRegex='<option[^>]+value=([0-9]+)[^>]*>([^<]+)</option>'
STREETS=`curl -g "$URL?von=A&bis=%5B"  2>/dev/null | grep -oE "$optionRegex" 2>/dev/null `

echo "$(echo "$STREETS" | wc -l) Einträge geladen."
echo "Extrahiere Straßennamen…"

STREET_IDS=()
STREET_NAMES=()

while read -r street; do
  STREET_IDS+=("$(echo $street | sed -r "s~$optionRegex~\1~")")
  STREET_NAMES+=("$(echo $street | sed -r "s~$optionRegex~\2~")")
  printf '∙'
done <<< "$STREETS"

echo
echo "${#STREET_NAMES[@]} Straßennamen extrahiert."

COUNTER=1

for i in "${!STREET_IDS[@]}"; do
  dateRegex="Sperrmüllabholung[[:space:]]*<\/td>[[:space:]]*<td valign=top>[[:space:]]*<b>[[:space:]]*([0-9]{2})\.([0-9]{2})\.([0-9]{4})"
  dateMatch=`curl -g --request POST "$URL?von=A&bis=%5B" --data-urlencode "strasse=${STREET_IDS[$i]}&anzeigen=anzeigen" 2>/dev/null | grep -oE "$dateRegex"`
  DATE=`echo "$dateMatch" | sed -r "s~$dateRegex~\3\2\1~"`

  if [ -z $DATE ]; then
    printf "\nKein Datum gefunden für ${STREET_NAMES[$i]}\n\n"
  else
    echo 'BEGIN:VEVENT' >> $ICAL_FILE
    echo "UID:sperrmuell-karlsruhe-${STREET_IDS[$i]}@github.com/meyermarcel" >> $ICAL_FILE
    echo "DTSTAMP:$(date +%Y%m%dT%H%M%SZ)" >> $ICAL_FILE
    echo "SUMMARY:${STREET_NAMES[$i]}" >> $ICAL_FILE
    echo "LOCATION:${STREET_NAMES[$i]}\\nKarlsruhe\\, Germany" >> $ICAL_FILE
    echo "DTSTART;VALUE=DATE:$DATE" >> $ICAL_FILE
    echo "DTEND;VALUE=DATE:$DATE" >> $ICAL_FILE
    echo 'END:VEVENT' >> $ICAL_FILE

    echo "$(( 100 * $COUNTER / ${#STREET_IDS[@]} ))% ($COUNTER/${#STREET_IDS[@]}) in $ICAL_FILE gespeichert: $DATE ${STREET_NAMES[$i]}"
  fi
  COUNTER=$((COUNTER+1))
done

echo 'END:VCALENDAR' >> $ICAL_FILE
