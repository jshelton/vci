#!/bin/sh


#####################################
#
# Name: [verifyImport.sh]
#
# Author: Joshua Shelton
#
# Created: 2014
#
# Description:
# -----------
#
# [Verifies imported pictures and video from cameras to make sure
# they're not corrupt (having trouble with cameras) before deleting
# original.]
#
#
# Comments:
# --------
#
# [Use in conjunction with verifyImport bash function and its bash
# completion for easiest access to newest installed folders.]
#
#
# Inspiration Source: 
# ----------- ------
#
# [Had problems with some corrupt image files.]
#
#
# Improvements:
# ------------
#
#   [Evaluate new (name not in database, modification date changed)
#   first (then check md5 chksum)]
#
#   [Solve problem with MD5 taking too long (is SHA faster?)]:
#     - Requre a tag to verify chksum that files are correct
#     - do checksum on a different thread to not hold up other files
#       - this will need a new way of displaying results
#       - will need to make sure database can handle writes/reads from
#         multiple threads
#
#   [Watch a folder for new files]
#
#   [Centralized database for system (in addition to folder specific)]
#     - store all EXIF file data in database, as well as path
#     - may be able to find duplicates accross multiple systems by comparing md5
#
#   [Read EXIF data and allow to move to new path according to
#   criteria]
#
#   [Save data on local database (UUID), and modification dates, so
#   identify duplicate folders]
#
#   [Report on duplicates found]
#     - Offer to delete duplicates (?)
#
#   [Only evaluate images/only evaluate video]
#
# Modified (Change Log):
# ---------------------
#   - [2015-06-25]:  Added this description
#
#   - [2016-03-25]:  Added check previously failing images.
#
#   - [2016-04-04]:
#
#   - [2016-12-26]: Ignore directories in input
#
#   - [2017-06-22]: Fix issue where rechecking files from before where they already
#                   passed (select files not OK'ed instead of NO in database)
#   - [2019-06-30]: Add argument to check previous files that failed
##

_OPTIONS=$1
_FNAME=$2

_DEBUG="off"

ERROR_LOG="error.log"
VERSION="0.1.2"

LOG_FILE="success.log.txt"
DB_FILE="mediaConsistency.db"
MASTER_DB_FILE="$HOME/mediaConsistencyDatabase.db"

STD_IN_FLAT=0
RECHECK_OLD=0

function DEBUG()
{
	[ "$_DEBUG" == "on" ] && $@
}

function DEBUG_TEST()
{
	eval " [ $@ ] "
	RUN_RESULT=$?
	
	if [ $RUN_RESULT = 0 ]; then
		RESULT="TRUE"
	else
		RESULT="FALSE"
	fi
	
	[ "$_DEBUG" == "on" ] && echo "TEST [$@]: $RESULT"
}

function usage()
{

# Script Name...
	echo "${0##/*/}:"

# Usage for script...
	echo "usage: ${0##/*/} [-tv] <name of file>"
	echo

# Description for script...
#REPLACE NEXT LINE
	echo "\t ...Description of script..."
	echo

# Switch descriptions... 
	echo "Options: "
	echo "-t, --read-from-stdin\t: To read files from standard input instead"

	echo "-v, --version\t: print script version."
	echo 


}



# Verify that all the dependencies exist



### Begining of Process Arguments ---

# To get help
if [[ "$_OPTIONS" = "-h" || "$_OPTIONS" = "--help" ]]; then
	usage
	exit
# Option 1
elif [[ "$_OPTIONS" = "-t" || "$_OPTIONS" = "--read-from-stdin" ]]; then
    DEBUG echo "option 2"
    STD_IN_FLAT=1
# Option 3
elif [[ "$_OPTIONS" = "-a" || "$_OPTIONS" = "--recheck-old" ]]; then # disabled temporarily (also not implemented in usage)
    DEBUG echo "option 3"
    RECHECK_OLD=1
# Option 2
elif [[ "$_OPTIONS" = "-v" || "$_OPTIONS" = "--version" ]]; then
    echo $VERSION
    exit

# ...Enter Switches here...

fi

# Default
# if a valid filename is the first argument, then ignore all other switches.
if [[ ! -e $_FNAME && -e $1 ]]; then
	_FNAME=$1
fi

### End of Process Arguments ---


### Begin of Program ---

cleanup ()
{
kill -s SIGTERM $!
exit 0
}

trap cleanup SIGINT

## No more Error Logs
if [ -e "$ERROR_LOG" ]; then rm -f "$ERROR_LOG" ; fi
#touch "$ERROR_LOG"

if [ -e "$LOG_FILE" ]; then rm -f "$ERROR_LOG" ; fi
#touch "$LOG_FILE"

if [ ! -e "$DB_FILE" ]; then
#    sqlite3 "$DB_FILE" "create table files(name varchar(300), type char(3), camera varchar(30), status varchar(30), chksum varchar(32), created datetime default current_timestamp);create table version(versionNumber varchar(30), created creationDate default current_timestamp); insert into version(versionNumber) values($VERSION);"
    sqlite3 "$DB_FILE" "create table files(name varchar(300), type char(3), camera varchar(30), status varchar(30), chksum varchar(32), created datetime default current_timestamp); create table version(versionNumber varchar(30), created creationDate default current_timestamp); insert into version(versionNumber) values('$VERSION');"
fi
    
ERRORS=""

checkFile()
{
    if [ -z "$1" -o ! -e "$1" -o -d "$1" ]; then
	return -1;
    else
	i="$1"
	dbi=$(echo "$1"|sed "s/'/''/g")
    fi
    
    printf " [  ] :$i\r"; 
    
    echo "$i:" > "$ERROR_LOG"
    #    chksum=$(md5 "$i"|awk -F=  '{gsub(/^[ \t]+/,"",$2);print $2}')
    chksum=$(md5 "$i"|awk  '{print $4}')

    


    if [ 0 = $(sqlite3 "$DB_FILE" "select count(name) from files where chksum is '$chksum';") ]; then
	
	

	#    ffmpeg -v error -i "$i" -f null - 2> "$ERROR_LOG" 
	#    jpeginfo -c "i" 2> "$ERROR_LOG"
##	ffmpeg -err_detect explode -i "$i" -f null - 2> "$ERROR_LOG"
	ffmpeg -err_detect explode -i "$i" -f null - 2> /dev/null
	
	
	if [ $? == 0 ]; then  
	    printf " [OK] :$i\n"; 
	    sqlite3 "$DB_FILE" "insert into files(name,status,chksum) values('$dbi','OK','$chksum');"

	else
	    sqlite3 "$DB_FILE" "insert into files(name,status,chksum) values('$dbi','NO','$chksum');"
	    printf "+[NO] :$i\n"; 
		ERRORS="$ERRORS "
	    # mv "$i" $HOME/.Trash/; 
	fi; 
	

    else 
	read status name <<< $(sqlite3 "$DB_FILE" "select status, name from files where chksum is '$chksum' ORDER by created DESC;" | tr '|' ' ')

	if [ $status == "OK" ]; then
	    printf " [OK]d:$i (duplicate of $name)\n"
	elif [ $status == "NO" ]; then
	    printf "+[NO]+:$i\n"
		ERRORS="$ERRORS "
	else
	    printf " +$status:$i\n"
   	    # mv "$i" $HOME/.Trash/; 
	fi
    fi
}

if [ ${STD_IN_FLAT} == 1 ]; then
    while read line; do

	if [[ "$ile"  =~ ^.*\.Spotlight\.*$ ]]; then continue; fi
	pushd $(dirname "$line")
	checkFile $(basename "$line")
	popd
    done
fi


scriptBasename=`basename $0`
TMPFILE=`mktemp -q /tmp/${scriptBasename}.XXXXXX`
TMPFILE2=`mktemp -q /tmp/${scriptBasename}.XXXXXX`

if [ $? -ne 0 ]; then
    echo "$0: Can't create temp file, exiting..."
    exit 1
fi


## New Files
sqlite3 "mediaConsistency.db" "select name from files"| perl -ne 'for$i(0..1){print}' > "$TMPFILE"
(for name in "$@"; do if [ -f "$name" ] ; then echo $name; fi ; done) >> "$TMPFILE"

filesToCheck=$(cat "$TMPFILE"|sort |uniq -u)



## First do files that are newly analyzed (not in database)
for i in $filesToCheck; do 
    if [ "$i" != "$ERROR_LOG" -a "$i" != "$LOG_FILE" -a "$i" != "$DB_FILE"  ] ; then
    	checkFile "$i"
	fi
done


if [[ "$ERRORS" != "" ]]; then
    printf "Errors from new Files:\n$ERRORS"
#  echo "No files reporting errors"
# else
fi


## Now do ones that didn't pass last time and check

if [ ${RECHECK_OLD} == 0 ] ; then 

    # Files that failed before
    # Here we changed to checking for not OK instead of NO because some files appear
    # several times when they were not completely copied yet -June 22, 2017
    sqlite3 "mediaConsistency.db" "select name from files where name not like '%AAE' and status = 'NO' and name not in (select name from files where status = 'OK' )"| perl -ne 'for$i(0..1){print}' > "$TMPFILE2"
    (for name in "$@"; do if [ -f "$name" ] ; then echo $name; fi ; done) >> "$TMPFILE2"
    filesToCheck2=$(cat "$TMPFILE2"|sort |uniq -d)
    
    ERRORS=""
    echo "Rechecking files from before:"
    for i in $filesToCheck2; do 
	if [ "$i" != "$ERROR_LOG" -a "$i" != "$LOG_FILE" -a "$i" != "$DB_FILE" ] ; then
    	    checkFile "$i"
	fi
    done

    if [[ "$ERRORS" != "" ]]; then
	printf "Files reporting errors:\n$ERRORS"
	#  echo "No files reporting errors"
	# else
    fi
    
fi






### End of Program ---

DEBUG echo "DONE"


