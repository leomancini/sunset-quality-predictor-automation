#!/usr/bin/env bash

# Private Variables
TIMELAPSE_SERVER_USER=
TIMELAPSE_SERVER_IP=
TIMELAPSE_SERVER_ROOT=
SUNSET_API_PROXY_URL=
PUBLISH_SERVER_USER=
PUBLISH_SERVER_IP=
PUBLISH_SERVER_HISTORY_URL=
PUBLISH_SERVER_HISTORY_DIRECTORY=
PUBLISH_SERVER_URL=
UPLOAD_PASSWORD=

# Public Variables
RUNTIME=$(date +%s)
RED='\033[0;31m'
GREEN='\033[1;92m'
CYAN='\033[1;96m'
PURPLE='\033[1;95m'
NC='\033[0m'

# Check flags
while getopts d: flag
do
    case "${flag}" in
        d) DATE=${OPTARG};;
    esac
done

if [ -z ${DATE+x} ]; then
    DATE=$(date +"%Y-%m-%d")
fi

# Run script for specified date
printf "\nChecking for existing timelapse video for ${PURPLE}$DATE${NC}...\n"

SUNSET_ALREADY_PUBLISHED=$(($(curl --silent -I $PUBLISH_SERVER_HISTORY_URL/$DATE.mp4 \
    | grep -E "^HTTP" \
    | awk -F " " '{print $2}') == 200))

if [ "$SUNSET_ALREADY_PUBLISHED" = 0 ]; then
    printf "No existing timelapse video found...\n"
    printf "Getting sunset time for ${PURPLE}$DATE${NC} in New York...\n"

    SUNSET_TIME=$(curl --silent "$SUNSET_API_PROXY_URL?date=$DATE" | jq -r '.results.sunset')
    SUNSET_TIME_ET=$(TZ=US/Eastern gdate -d "$SUNSET_TIME")
    SUNSET_TIME_ET_MINS_BEFORE=$(TZ=US/Eastern gdate -d "$SUNSET_TIME_ET - 60 minutes" +'%F-%H-%M')
    SUNSET_TIME_ET_MINS_AFTER=$(TZ=US/Eastern gdate -d "$SUNSET_TIME_ET + 60 minutes" +'%F-%H-%M')

    CAMERA="SKYLINE"
    START=$SUNSET_TIME_ET_MINS_BEFORE
    END=$SUNSET_TIME_ET_MINS_AFTER
    FPS=20

    printf "Initializing variables...\n\n"

    echo "Date: $DATE";
    echo "Sunset Time: $SUNSET_TIME_ET";
    echo "Camera: $CAMERA";
    echo "Start: $START";
    echo "End: $END";
    echo "FPS: $FPS";

    printf "\n"

    IMG_TYPE=jpg
    CAMERA_FORMATTED=$(echo $CAMERA | tr 'a-z' 'A-Z')
    TIMELAPSE_SERVER_IP_PATH=$TIMELAPSE_SERVER_ROOT/nest-cam-timelapse/images/$CAMERA_FORMATTED

    printf "Creating temporary directory on local machine...\n"

    mkdir -p ./.auto-timelapse-temp/
    mkdir ./.auto-timelapse-temp/$RUNTIME/

    printf "Creating temporary directory on remote host machine...\n"

    ssh $TIMELAPSE_SERVER_USER@$TIMELAPSE_SERVER_IP "mkdir -p /$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/ && mkdir /$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/$RUNTIME/"

    printf "Building list of images to download...\n"

    # Based on: https://stackoverflow.com/questions/4434782/loop-from-start-date-to-end-date-in-mac-os-x-shell-script
    sDateTs=`date -j -f "%Y-%m-%d-%H-%M" $START "+%s"`
    eDateTs=`date -j -f "%Y-%m-%d-%H-%M" $END "+%s"`
    dateTs=$sDateTs
    offset=60
    i=0

    while [ "$dateTs" -le "$eDateTs" ]
    do
        date=`date -j -f "%s" $dateTs "+%Y-%m-%d-%H-%M"`
        echo "/$TIMELAPSE_SERVER_IP_PATH/$date.$IMG_TYPE" >> ./.auto-timelapse-temp/$RUNTIME/images.txt
        dateTs=$(($dateTs+$offset))
        ((i=i+1))
    done

    printf "Copying list of images to remote host machine...\n"

    scp -q ./.auto-timelapse-temp/$RUNTIME/images.txt $TIMELAPSE_SERVER_USER@$TIMELAPSE_SERVER_IP:/$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/$RUNTIME/

    printf "Packaging ${PURPLE}$i${NC} images into archive file...\n"

    ssh $TIMELAPSE_SERVER_USER@$TIMELAPSE_SERVER_IP "tar -cf /$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/$RUNTIME/images.tar -T /$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/$RUNTIME/images.txt > /dev/null 2>&1"

    printf "${CYAN}Downloading images for range${NC} ${PURPLE}$START${NC} ${CYAN}through${NC} ${PURPLE}$END${NC}${CYAN}...${NC}\n\n"

    scp -T $TIMELAPSE_SERVER_USER@$TIMELAPSE_SERVER_IP:"/$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/$RUNTIME/images.tar" ./.auto-timelapse-temp/$RUNTIME/

    printf "\n${GREEN}# # # # FINISHED DOWNLOADING IMAGES # # # #${NC}\n\n"

    printf "Unpacking archive file...\n"

    tar -xf ./.auto-timelapse-temp/$RUNTIME/images.tar -C ./.auto-timelapse-temp/$RUNTIME/

    printf "${CYAN}Starting timelapse creation...${NC}\n\n"

    ffmpeg -loglevel error -stats -r $FPS -pattern_type glob -i "./.auto-timelapse-temp/$RUNTIME/$TIMELAPSE_SERVER_IP_PATH/*.jpg" -s 1280x720 -vcodec libx264 ./.auto-timelapse-temp/$DATE.mp4

    printf "\n${GREEN}# # # # FINISHED TIMELAPSE CREATION # # # #${NC}\n\n"

    printf "${CYAN}Uploading to public server...${NC}\n\n"

    scp ./.auto-timelapse-temp/$DATE.mp4 $PUBLISH_SERVER_USER@$PUBLISH_SERVER_IP:$PUBLISH_SERVER_HISTORY_DIRECTORY/$DATE.mp4

    printf "\nWaiting for upload to finish...\n"

    sleep 30

    printf "${CYAN}Posting to Instagram...${NC}\n\n"

    curl "$PUBLISH_SERVER_URL?date=$DATE&password=$UPLOAD_PASSWORD"

    printf "\n\nCleaning up...\n"

    ssh $TIMELAPSE_SERVER_USER@$TIMELAPSE_SERVER_IP "rm -r /$TIMELAPSE_SERVER_ROOT/.auto-timelapse-temp/"

    rm -r ./.auto-timelapse-temp/

    printf "\n${GREEN}# # # # TIMELAPSE VIDEO PUBLISHED FOR $DATE # # # #${GREEN}\n\n"
else
    printf "\n${CYAN}# # # # TIMELAPSE VIDEO ALREADY PUBLISHED FOR $DATE # # # #${CYAN}\n\n"
fi
