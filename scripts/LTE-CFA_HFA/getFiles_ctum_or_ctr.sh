#!/bin/bash


# Initialize some variables
fileTimeZone="+0000" #Timezone offset on the filenames
OFFSET_INPUT=0

declare -a FILE_TO_BE_PROCESSED_ARRAY

## Hardcoded Values ##
RPL=900


## Functions ##

usage_msg()
{
	echo "Usage: $0

		# Mandatory Fields
		-i <source data directory> # This directory should contain the input files within sub directories called Day_1, Day_2 etc
		-n <unique node name> # This name should be the unique node name

		# Optional Fields
		-c  <Path to the cep directory> #If Session Browser is required and there is a CEP server located with the demo system. 
		-o <eniq collection directory for node> # Default: Automatically obtained from mzsh workflow export if not set.
		-h <hour string eg +0100> # Default: 0000
		-l <log output directory, optional> Default: Logging disabled if not set
        -r <ROP value, eg 60 (for files collected every 1 min), 900 (for files collected every 15 min)> # Default 900

		# Fixed Day Loading, set both options to enable fixed day loading instead of live loading (requires mapToInternalSGEH to have date hardcoded)
		-d <Source data directory day to use, eg 4>
		-f <fixed_date to simulate, eg 20111231>
		-a <Additional directory that the files will be copied to>
		-u <Update the header for celltrace files> # Location for the temporary (intermediate) files are to be updated"
	exit 1
}

check_owner()
{
	if [[ ! `id | grep dcuser` ]]
	then
		echo "ERROR: You must be dcuser to run this script"
		exit 1
	fi
}

check_args()
{

	########## Mandatory fields check ##################################

	if [[ -z $nodeName ]]
	then
		echo "ERROR: You must set the node name using -n <unique node name>"
		usage_msg
	fi

	if [[ -z ${referenceFilesLocation} ]]
        then
                echo "ERROR: You must set the source data directory using -i <source data directory>"
                usage_msg
        fi

	#####################################################################


	########### Fixed date check ######

	if [[ -z $WORKING_DAY_NO ]] && [[ ! -z $FIXED_DATE ]]
	then
		echo "ERROR: If -f is set, -d must also be set"
		usage_msg
	fi

	if [[ ! -z $WORKING_DAY_NO ]] && [[ -z $FIXED_DATE ]]
        then
		echo "ERROR: If -d is set, -f must also be set"
		usage_msg
        fi


	##### Set the referenceFilesLocation related fields

	if [[ ! -d ${referenceFilesLocation} ]]
	then
	        echo "ERROR: References files directory ${referenceFilesLocation} doesn't exist.....Please check the path...exiting"
	        exit 1
	fi

	

	###### If the log directory was set

	if [[ "$logFileOutputDir" != "" ]]
	then
		mkdir -p $logFileOutputDir 2>/dev/null
		if [[ -d "$logFileOutputDir" ]]
		then
			LOGGING_ENABLED="yes"
		else
			echo "ERROR: The Log output directory $logFileOutputDir doesn't exist...please check it"
			exit 1
		fi
	fi

	
	## Now check if the output directory exists

	if [ ! -d "${outputPath}" ]
	then
	    echo "Output Path Directory '{outputPath}'doesn't exist... Please check the path... exiting"
        exit 1
	fi
	
	if [[ "$additionalOutputDir" != "" ]]
	then
		if [ ! -d "${additionalOutputDir}" ]
		then
			echo "Additional Output Path Directory '${additionalOutputDir}' doesn't exist... Please check the path... exiting"
			exit 1
		fi
	fi
	
}

check_already_running ()
{
	if ( set -C; echo "$$" > "$LOCKFILE") 2> /dev/null;
        then
                trap 'rm -f "$LOCKFILE"; exit $?' INT TERM EXIT
	else
		echo "getFile must already be running, the lockfile $LOCKFILE already exists..."
		exit 0
	fi
}

getNewTime() {

        YYMM=`echo $1 | cut -c1-6`
        DD=`echo $1 | cut -c7,8`
        hh=`echo $1 | cut -c9,10`
        mm=`echo $1 | cut -c11,12`
        ss=`echo $1 | cut -c13,14`

        Inseconds=`expr $hh \* 3600  + $mm \*  60  + $ss `
        newTimeInseconds=`expr $Inseconds $3 $2`

        seconds=`expr $newTimeInseconds % 60`
        minute_tmp=`expr $newTimeInseconds % 3600`
        minute=`expr $minute_tmp / 60`
        hour_tmp=`expr $newTimeInseconds / 3600 `
        hour=`expr $hour_tmp % 24`

#Days rollover

        add_days=`expr $hour_tmp / 24`
        DD=`expr $DD + $add_days`

        newTime=`printf "%02d%02d%02d%02d" $DD $hour $minute $seconds`

        echo ${YYMM}$newTime

}

mySubroutine()
{
    timeInSeconds=`expr $1 \* 3600 + $2 \* 60 + $3`
    adjustValue=`expr $timeInSeconds % $RPL`
    sleepTill=`expr $RPL - $adjustValue`
    echo $sleepTill
}



liveLoadData()
{

while [ 1 ]
do

  if [[ "$LOGGING_ENABLED" == "yes" ]]
  then
        MYDATE=`date '+%d-%m-20%y'`
        MYLOG="${logFileOutputDir}/getFile_${nodeName}-$MYDATE.log"

        if [ ! -f $MYLOG ]
        then
                touch $MYLOG
        fi

  else
        MYLOG=/dev/null
  fi

    # Figure out the day
    SECONDS_SINCE_1970=`perl -e 'print int(time)'`
    DAYS_SINCE_1970=`expr $SECONDS_SINCE_1970 / 86400`

	# Figure out the number of days on the fly
	NUMBER_OF_DAYS=`ls ${referenceFilesLocation} | grep -c "Day_"`

    DAY_MOD=`expr $DAYS_SINCE_1970 % $NUMBER_OF_DAYS`

	# Offset calculation
	DAY_OFFSET=`expr $DAY_MOD + $OFFSET_INPUT + $NUMBER_OF_DAYS + $NUMBER_OF_DAYS + $NUMBER_OF_DAYS`
	DAY_MOD=`expr $DAY_OFFSET % $NUMBER_OF_DAYS`

#	echo day offset is $DAY_OFFSET
#	echo day mod is $DAY_MOD

	# Can't start at day 0, so always add 1 to the number
	DAY_MOD=`expr $DAY_MOD + 1`

    WORKING_DAY="Day_${DAY_MOD}"
    echo "The value of WORKING_DAY is "$WORKING_DAY >> $MYLOG 
    ######

    DATENOW=`date '+20%y%m%d%H%M%S'`
    hh=`echo $DATENOW | cut -c9,10`
    mm=`echo $DATENOW | cut -c11,12`
    ss=`echo $DATENOW | cut -c13,14`
    #echo "$hh $mm $ss"

    timeToSleep=`mySubroutine $hh $mm $ss`
    #echo "timeToSleep=$timeToSleep"

    echo "waiting "$timeToSleep" seconds" >> $MYLOG
    sleep $timeToSleep
    #echo "Please wait while I generate files for you...."

    newTimeStamp=`getNewTime $DATENOW $timeToSleep +`
    #echo $newTimeStamp
    beginTimeStamp=`getNewTime $newTimeStamp $RPL -`
	
	#Current file date
    currentFileDate=`echo $newTimeStamp | cut -c1-8`
    fn2="."
    fn3=`echo $beginTimeStamp | cut -c9-12`
    #fileTimeZone="+0100"
    fn5="-"
    fn6=`echo $newTimeStamp | cut -c9-12`
    fn7="_"


    
echo "DEBUG-> currentFileDate: "${currentFileDate}

    findstrg="A*.${fn3}*${fn6}*"

       

echo "DEBUG-> referenceFilesLocation="${referenceFilesLocation}
echo "DEBUG-> findstrg="${findstrg}
echo "DEBUG-> find command is => find "${referenceFilesLocation}/$WORKING_DAY/" -type f -name "${findstrg}""
		
		
		##Get a list of files that need to be processed
		#FILE_TO_BE_PROCESSED=`find "${referenceFilesLocation}/$WORKING_DAY/" -type f -name "${findstrg}"`
		##Convert the string into an array 
		#FILE_TO_BE_PROCESSED_ARRAY=($FILE_TO_BE_PROCESSED)
		
		
		if [ -d "${referenceFilesLocation}/$WORKING_DAY/" ]; then
			# Control will enter here if $DIRECTORY exists.
			echo "Directory ...'"${referenceFilesLocation}"/$WORKING_DAY/' exists!" | tee -a $MYLOG
		fi
		
				
		countRetries=0;
		while [ $countRetries -ne 5 ]
		do
			#Get a list of files that need to be processed
			FILE_TO_BE_PROCESSED=`find "${referenceFilesLocation}/$WORKING_DAY/" -type f -name "${findstrg}"`
			#Convert the string into an array 
			FILE_TO_BE_PROCESSED_ARRAY=($FILE_TO_BE_PROCESSED)
						
			if [[ ${#FILE_TO_BE_PROCESSED_ARRAY[@]} -gt 0 ]]
			then 
				break
			fi
			
			let countRetries+=1
		done
		
		
		
		
		
echo "DEBUG-> Starting copying ( ${#FILE_TO_BE_PROCESSED_ARRAY[@]} ) files ="`date '+%d-%m-20%y_%H:%M:%S'`
        if [[ ${#FILE_TO_BE_PROCESSED_ARRAY[@]} -gt 0 ]]
        then
                #******************************************************
				
			for existingFilesPathAndName in "${FILE_TO_BE_PROCESSED_ARRAY[@]}"
		do
			
#echo "DEBUG-> echo ${existingFileNameOnly} | sed -e s/${existingFileDate}/${currentFileDate}/g"
				
		existingFileNameOnly=`basename $existingFilesPathAndName`
		existingFileDate=`echo "${existingFileNameOnly}" | sed -e 's/^.*A\([0-9]\{8\}\).*./\1/'`
		newFileName=`echo ${existingFileNameOnly} | sed -e s/${existingFileDate}/${currentFileDate}/g`
			
			if [[ -d "$updateHeader" ]]
			then
				tmpIntermediateLocation="${updateHeader}"
				mkdir -p ${tmpIntermediateLocation}
				echo "Copying file ${existingFilesPathAndName} to ${tmpIntermediateLocation}/${newFileName}" >> $MYLOG
				
				cp ${existingFilesPathAndName} ${tmpIntermediateLocation}/${newFileName}
				echo "Updating the header for the file ${tmpIntermediateLocation}/${newFileName} and outputting to the final location ${outputPath}" >> $MYLOG
				#echo "./UpdateHeaderDate_Celltrace.pl -i "${tmpIntermediateLocation}/${newFileName}" -o "${outputPath}"/ -l OFF"  >> $MYLOG
				/usr/bin/perl /eniq/backup/ATandT/UpdateHeaderDate_Celltrace.pl -i "${tmpIntermediateLocation}/${newFileName}" -o "${outputPath}"/ -l OFF
			
			else
				echo "Copying file ${existingFilesPathAndName} to ${outputPath}/${newFileName}" >> $MYLOG
				cp ${existingFilesPathAndName} ${outputPath}/${newFileName}
			fi
			

			
			
			#This is not needed yet... could be used for LTEES
			#if [[ -d "$additionalOutputDir" ]]
			#then
		    #		echo "Copying file ${existingFilesPathAndName} to ${additionalOutputDir}/${newFileName}" >> $MYLOG
			#	cp ${existingFilesPathAndName} ${additionalOutputDir}/${newFileName}
			#fi

		done
		
echo "DEBUG-> Finished copying files ="`date '+%d-%m-20%y_%H:%M:%S'`
				
				#******************************************************
        else
                echo "Sorry....No files found for string '"$findstrg"' in '"${referenceFilesLocation}"/$WORKING_DAY/'... Please check the directory." | tee -a $MYLOG
        fi

done
}





################# Start of the script execution ##################
while getopts "i:o:h:l:n:d:f:r:k:s:a:u:" arg
do
    case $arg in
        i) referenceFilesLocation="$OPTARG"
            ;;
        o) outputPath="$OPTARG"
            ;;
        h) fileTimeZone="$OPTARG"
            ;;
        l) logFileOutputDir="$OPTARG"
            ;;
        n) nodeName="$OPTARG"
            ;;
		d) WORKING_DAY_NO="$OPTARG"
			;;
		f) FIXED_DATE="$OPTARG"
			;;
		r) RPL="$OPTARG"
			;;
		a) additionalOutputDir="$OPTARG"
			;;
		k) OFFSET_INPUT="$OPTARG"
			;;
		u) updateHeader="$OPTARG"
			;;
        \?) usage_msg
            exit 1
            ;;
    esac
done
#All time needs to be calculated as UTC/GMT
export TZ=utc
LOCKFILE=/tmp/.lock_$nodeName
check_owner
check_args
check_already_running
liveLoadData


