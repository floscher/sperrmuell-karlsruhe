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

FIRST_LETTER=A
CALENDAR_EVENT_INDEX=0

for SECOND_LETTER in {{B..Z},'['} ; do
    COUNT=$(($(curl -g "${URL}?von=${FIRST_LETTER}&bis=${SECOND_LETTER}" 2> /dev/null | grep -o 'option value=' | wc -l) + 1))

    printf "\nVerfügbare Straßen, die mit dem Buchstaben ${FIRST_LETTER} beginnen (Anzahl: ${COUNT}), werden geladen:\n"


    for ((i = 1; i <= $COUNT; i++)) ; do
        HTML_STREET_DATE=$(curl -g --request POST "${URL}?von=${FIRST_LETTER}&bis=${SECOND_LETTER}" --data-urlencode "strasse=${i}&anzeigen=anzeigen" 2> /dev/null)
        STREET=$(echo ${HTML_STREET_DATE} | ack -o "(?<=<H1 align=left><a href='/service/abfall/akal/akal\.php\?strasse=)[^'>]*")
        DATE=$(echo ${HTML_STREET_DATE} | ack -o "(?<=Sperrmüllabholung<\/td><td valign=top><b>)[^ <]*")

        if [[ $DATE =~ [0-9]{2}\.[0-9]{2}\.[0-9]{4}$ ]]
            then

            DAY=$(echo ${DATE} | cut -c1-2)
            MONTH=$(echo ${DATE} | cut -c4-5)
            YEAR=$(echo ${DATE} | cut -c7-10)

        
            echo 'BEGIN:VEVENT' >> $ICAL_FILE
            echo "UID:sperrmuell-karlsruhe-${CALENDAR_EVENT_INDEX}@github.com/meyermarcel" >> $ICAL_FILE
            echo "DTSTAMP:$(date +%Y%m%dT%H%M%SZ)" >> $ICAL_FILE
            echo "SUMMARY:${STREET}" >> $ICAL_FILE
            echo "LOCATION:${STREET}\\nKarlsruhe\\, Germany" >> $ICAL_FILE
            echo "DTSTART;VALUE=DATE:${YEAR}${MONTH}${DAY}" >> $ICAL_FILE
            echo "DTEND;VALUE=DATE:${YEAR}${MONTH}${DAY}" >> $ICAL_FILE
            echo 'END:VEVENT' >> $ICAL_FILE

            echo "(${i}/${COUNT}) in ${ICAL_FILE} gespeichert: ${DATE} ${STREET}"

            CALENDAR_EVENT_INDEX=$[CALENDAR_EVENT_INDEX + 1]

        fi
    done

    FIRST_LETTER=$SECOND_LETTER
done

echo 'END:VCALENDAR' >> $ICAL_FILE
