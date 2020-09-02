#!/bin/bash
#
# Small check that get gata from IoT Open Lynx
#
# Copyright (C) 2019  IoT Open One AB
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# For printf below
LC_NUMERIC=C
LC_COLLATE=C

usage() {
	cat << __END__
check_lynx v0.9

Monitor values of functions in IoT Open Lynx platform

Usage:
check_lynx -u <url> -k <key> -i <installation_id> -f <function_id> [ options ]

Options:
 -h, --help
    Print this help
 -u, --url
    URL to lynx, e.g. https://lynx.iotopen.se
 -k, --api-key
    API-Key to Lynx (get it from user profile in Lynx
 -i, --installation
    Installation id from Lynx
 -f, --function
    Function id from Lynx
 -a, --max-age
    Maximal age of the value in seconds. Renders CRITICAL if too old. (optional)
 -w, --warning
    Warning threshold (optional)
 -c, --critical
    Critical threshold (optional)
 -m, --min
    Minimal expected value (optional)
 -M, --man
    Maximal expected value (optional)

Thresholds:
The thresholds can be given as arguments or set as metadata in Lynx. They should
then have the same names as the long arguments. Like below:

max-age,warning,critical,min and max

If they are given both in Lynx and as parameters as above then the parameters will
be used.

If only critical or warning is set it will raise an alarm if higher or equal to 
the threshold.

If both warning and critical is used it will raise an alarm above or equal if 
critical is higher than warning and below if warning is higher than critical.

Min and max values:
The min and max values are only written in perfdata.

Questions:
Contact IoT Open at support@iotopen.se

__END__
	exit 0
}

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    usage
    ;;
    -u|--url)
    URL="$2"
    shift # past argument
    shift # past value
    ;;
    -k|--api-key)
    API_KEY="$2"
    shift # past argument
    shift # past value
    ;;
    -i|--installation)
    INSTALLATION="$2"
    shift # past argument
    shift # past value
    ;;
    -f|--function)
    FUNCTION="$2"
    shift # past argument
    shift # past value
    ;;
    -a|--max-age)
    MAX_AGE="$2"
    shift # past argument
    shift # past value
    ;;
    -w|--warning)
    WARNING="$2"
    shift # past argument
    shift # past value
    ;;
    -c|--critical)
    CRITICAL="$2"
    shift # past argument
    shift # past value
    ;;
    -m|--min)
    MIN="$2"
    shift # past argument
    shift # past value
    ;;
    -M|--max)
    MAX="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
	    echo "Unknown argument $key"
	    exit 3
    ;;
esac
done

# Check parameters
if [ "$URL" == ""  ]; then
	echo "Missing URL. Use -h or --help for usage"
	exit
fi

if [ "$FUNCTION" == ""  ]; then
	echo "Missing Function. Use -h or --help for usage"
	exit
fi

if [ "$INSTALLATION" == ""  ]; then
	echo "Missing Installation. Use -h or --help for usage"
	exit
fi

if [ "$API_KEY" == ""  ]; then
	echo "Missing API-Key. Use -h or --help for usage"
	exit
fi



# Get functionx json.
FUNCX=$(curl -s $URL/api/v2/functionx/$INSTALLATION?id=$FUNCTION -X GET -u monitoring:$API_KEY -H Content-Type: application/json)

# Get topic (must be a topic_read)
TOPIC=$(echo $FUNCX | jq .meta.topic_read | tr -d \")
NAME=$(echo $FUNCX | jq .meta.name | tr -d \")
FORMAT=$(echo $FUNCX | jq .meta.format | tr -d \")
TYPE=$(echo $FUNCX | jq .type | tr -d \")


# Get thresholds from command line or lynx

if [ "$WARNING" == "" ]; then
	WARNING=$(echo $FUNCX | jq .meta.warning | tr -d \")
fi	

if [ "$CRITICAL" == "" ]; then
	CRITICAL=$(echo $FUNCX | jq .meta.critical | tr -d \")
fi	

if [ "$MIN" == "" ]; then
	MIN=$(echo $FUNCX | jq .meta.min | tr -d \")
fi	

if [ "$MAX" == "" ]; then
	MAX=$(echo $FUNCX | jq .meta.max | tr -d \")
fi	

if [ "$MAX_AGE" == "" ]; then
	MAX_AGE=$(echo $FUNCX | jq .meta.max_age | tr -d \")
fi	

if [ "$MAX_AGE" == "null" ]; then
	MAX_AGE=""
fi


if [ "$WARNING" == "null" ]; then
	WARNING=""
fi

if [ "$CRITICAL" == "null" ]; then
	CRITICAL=""
fi

if [ "$MIN" == "null" ]; then
	MIN=""
fi

if [ "$MAX" == "null" ]; then
	MAX=""
fi

if [ "$FORMAT" == "null" ]; then
	FORMAT=""
fi


# Get value and timestamp from log
STATS=$(curl -s $URL/api/v2/status/$INSTALLATION -X GET -u monitoring:$API_KEY -H Content-Type: application/json | jq -c .[] | grep $TOPIC)
echo curl -s $URL/api/v2/status/$INSTALLATION -X GET -u monitoring:$API_KEY -H Content-Type: application/json 
if [ -z "$STATS" ]; then
	echo Could not get stats for $NAME
	exit 3
fi
VALUE=$(echo $STATS | jq .value)
if [ $? -ne 0 ]; then
	echo Could not get value
	exit 3
fi
TS=$(echo $STATS | jq .timestamp)
NOW=$(date +%s)
AGE=$(echo "($NOW - $TS)/1" | bc) # The division by one is to round to integer

if [ "$FORMAT" != "" ]; then
	VALUE_FORMATTED=$(printf $FORMAT $VALUE)
else
	VALUE_FORMATTED=$VALUE
fi

if [ "$MAX_AGE" != "" ]; then
	if [ "$AGE" -gt "$MAX_AGE" ]; then
		stat=CRITICAL
		ret=2
		echo "Lynx $stat: $NAME is STALE by ${AGE}s|$TYPE=$VALUE;$WARNING;$CRITICAL;$MIN;$MAX age=${AGE}s"
		exit $ret
	fi
fi

# Five cases, 
#
# No WARNING or CRITICAL
# Only CRITICAL (Alert if higher than critical)
# Only WARNING (Alert if highern than warning)
# CRITICAL > WARNING (Alert if higher)
# CRITICAL < WARNING (Alert if lower)


if [ "$CRITICAL" == "" -a "$WARNING" == "" ]; then
	stat=OK
	ret=0
	echo "Lynx $stat: $NAME: $VALUE_FORMATTED|$TYPE=$VALUE;$WARNING;$CRITICAL;$MIN;$MAX age=${AGE}s"
	exit $ret
fi

if [ "$CRITICAL" != "" -a "$WARNING" == "" ]; then
	if (( $(echo "$VALUE >= $CRITICAL" | bc -l) )); then
		stat=CRITICAL
		ret=2
	else
		stat=OK
		ret=0
	fi
	echo "Lynx $stat: $NAME: $VALUE_FORMATTED|$TYPE=$VALUE;$WARNING;$CRITICAL;$MIN;$MAX age=${AGE}s"
	exit $ret
fi

if [ "$WARNING" != "" -a "$CRITICAL" == "" ]; then
	if (( $(echo "$VALUE >= $WARNING" | bc -l) )); then
		stat=WARNING
		ret=1
	else
		stat=OK
		ret=0
	fi
	echo "Lynx $stat: $NAME: $VALUE_FORMATTED|$TYPE=$VALUE;$WARNING;$CRITICAL;$MIN;$MAX age=${AGE}s"
	exit $ret
fi


if [ "$WARNING" -lt "$CRITICAL" ]; then
	if (( $(echo "$VALUE >= $WARNING" | bc -l) )); then
		stat=WARNING
		ret=1
		if (( $(echo "$VALUE >= $CRITICAL" | bc -l) )); then
			stat=CRITICAL
			ret=2
		fi
	else
		stat=OK
		ret=0
	fi
	echo "Lynx $stat: $NAME: $VALUE_FORMATTED|$TYPE=$VALUE;$WARNING;$CRITICAL;$MIN;$MAX age=${AGE}s"
	exit $ret
fi

if [ "$WARNING" -gt "$CRITICAL" ]; then
	if (( $(echo "$VALUE <= $WARNING" | bc -l) )); then
		stat=WARNING
		ret=1
		if (( $(echo "$VALUE <= $CRITICAL" | bc -l) )); then
			stat=CRITICAL
			ret=2
		fi
	else
		stat=OK
		ret=0
	fi
	echo "Lynx $stat: $NAME: $VALUE_FORMATTED|$TYPE=$VALUE;$WARNING;$CRITICAL;$MIN;$MAX age=${AGE}s"
	exit $ret
fi
