#!/bin/sh
set -eu

NC='\033[0m' # No Color
Light_Green='\033[1;32m'  
STARTMSG="[ENTRYPOINT_CRON]"
# Syslog is used remove the color options!
[ "${LOG_SYSLOG_ENABLED-}" = "no" ] && STARTMSG="${Light_Green}$STARTMSG${NC}"


# Functions
echo (){
    command echo "$STARTMSG $*"
}

# Exception Handling
    # Stop cronjob if it should be disabled
[ "${CRON_ENABLE-}" = "false" ] && echo "Stop cron job. Because it should be disabled." && exit 0
    # Allow to start the script only as www-data user
[ "$(whoami)" != "www-data" ] && echo "Please restart the script as www-data. Exit now." && exit 1


# Environment Variables
INTERVAL=${CRON_INTERVAL:-'3600'}
USER_ID=${CRON_USER_ID:-'1'} 
SERVER_IDS=${CRON_SERVER_IDS:-'1'}

#
#   MAIN
#

#
# Check if Apache2 is available
#
    # Function to check if apache2 is available
URL="https://localhost/users/login"
isApache2up() {
    curl -fsk -w "%{http_code}" "$URL" -o /dev/null
}
    # Try 100 times to reach Apache2, after this exit with error.
RETRY=100
SLEEP_TIMER=5
# shellcheck disable=SC2046
until [ $(isApache2up) -eq 302 ] || [ $(isApache2up) -eq 200 ] || [ $RETRY -le 0 ] ; do
    echo "Waiting for Apache2 to come up, next try in $SLEEP_TIMER seconds... $RETRY / 100"
    sleep "$SLEEP_TIMER"
    SLEEP_TIMER="$(expr $SLEEP_TIMER + 5)"
    # shellcheck disable=SC2004
    RETRY=$(( $RETRY - 1))
done
    # Check if RETRY=0 then exit or start workers script
if [ $RETRY -le 0 ]; then
    >&2 echo "Error: Could not connect to Apache2 on $URL"
    exit 1
else
    # wait for the first round
    echo "Wait $INTERVAL seconds, then start the first intervall." && sleep "$INTERVAL" 
    # start cron job
    echo "Start cron job" && misp_cron "$INTERVAL" "$USER_ID" "$SERVER_IDS"
fi

