#!/bin/bash

# COMMAND LINE VARIABLES
#enviroment FIRST ARGUMENT 
# Ex: dev | sit | uat
env=$1
# deploy port SECOND ARGUMENT
# Ex: 8090 | 8091 | 8092 
serverPort=$2
# THIRD ARGUMENT project name, deploy folder name and jar name
projectName=$3 #spring-boot
# FOURTH ARGUMENT external config file name
# Ex: application-localhost.yml
configFile=$4


#### CONFIGURABLE VARIABLES ######
#destination absolute path. It must be pre created or you can
# improve this script to create if not exists
destAbsPath=/home/smalldok/release/$projectName/$env
backupPath=/home/smalldok/backup
#configFolder=resources
##############################################################

#####
##### DONT CHANGE HERE ##############
#jar file
# $WORKSPACE is a jenkins var
#sourFile=$WORKSPACE/api/build/libs/$projectName*.jar
sourFile=/home/smalldok/build/$projectName*.jar
destFile=$destAbsPath/$projectName.jar

#config files folder
#sourConfigFolder=$WORKSPACE/$configFolder*
#destConfigFolder=$destAbsPath/$configFolder

#properties=--spring.config.location=$destAbsPath/$configFolder/$configFile
properties="--server.port=$serverPort --spring.profiles.active=$env"

#CONSTANTS
logFile=initServer.log
dstLogFile=$destAbsPath/$logFile
#whatToFind="Started Application in"
whatToFind="Started "
msgLogFileCreated="$logFile created"
msgBuffer="Buffering: "
msgAppStarted="Application Started... exiting buffer!"

### FUNCTIONS
##############
function stopServer(){
    echo " "
    echo "Stoping process on port: $serverPort"
	pid=`ps -ef | grep $projectName.jar | grep -v grep | awk '{print $2}'`
	if [ -n "$pid" ]
	then
	   kill -9 $pid
	fi
    echo " "
}
backupFile=""
function backup(){
	echo " "
	if [ -f "$destFile" ]
	then
	   backupFile="$backupPath/$projectName.jar.`date +%Y%m%d%H%M%S`"
	   cp $destFile $backupFile
	   echo "backup [$destFile] -> [$backupFile]"
	fi
	echo " "
}

function deleteFiles(){
    echo "Deleting $destFile"
    rm -rf $destFile
    #echo "Deleting $destConfigFolder"
    #rm -rf $destConfigFolder
    echo "Deleting $dstLogFile"
    rm -rf $dstLogFile
    echo " "
}

function copyFiles(){
    echo "Copying files from $sourFile"
    cp $sourFile $destFile
    #echo "Copying files from $sourConfigFolder"
    #cp -r $sourConfigFolder $destConfigFolder
    echo " "
}

JAVA_OPTS=""
JAVA_MEM_OPTS=""
JAVA_DEBUG_OPTS=""
JAVA_JMX_OPTS=""
function run(){
	JAVA_OPTS=" -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true"
	JAVA_MEM_OPTS=""
	BITS=`java -version 2>&1 | grep -i 64-bit`
	if [ -n "$BITS" ]; then
		JAVA_MEM_OPTS=" -server -Xmx1g -Xms1g -Xmn512m -XX:PermSize=512m -Xss256k -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:LargePageSizeInBytes=128m -XX:+UseFastAccessorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=70 "
	else
		JAVA_MEM_OPTS=" -server -Xms1g -Xmx2g -XX:PermSize=1024m -XX:SurvivorRatio=2 -XX:+UseParallelGC "
	fi
	JAVA_DEBUG_OPTS=""
	if [ "$1" = "debug" ]; then
		JAVA_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=5566,server=y,suspend=n "
	fi
	JAVA_JMX_OPTS=""
	if [ "$1" = "jmx" ]; then
		JAVA_JMX_OPTS=" -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false "
	fi
   #echo "java -jar $destFile $properties" | at now + 1 minutes
   touch $dstLogFile | chmod 777 $dstLogFile
   nohup nice java $JAVA_OPTS $JAVA_MEM_OPTS $JAVA_DEBUG_OPTS $JAVA_JMX_OPTS -jar $destFile $properties $> $dstLogFile 2>&1 &
   echo "COMMAND: nohup nice java -jar $destFile $properties $> $dstLogFile 2>&1 &"
   echo " "
}
function changeFilePermission(){
    echo "Changing File Permission: chmod 777 $destFile"
    chmod 777 $destFile
    echo " "
}   

function watch(){
    tail -f $dstLogFile |
        while IFS= read line
        do
            echo "$msgBuffer" "$line"

            if [[ "$line" == *"$whatToFind"* ]]; then
                echo $msgAppStarted
                pkill  tail
            fi
        done
}

### FUNCTIONS CALLS
#####################
# Use Example of this file. Args: enviroment | port | project name | external resourcce
# BUILD_ID=dontKillMe /path/to/this/file/api-deploy.sh dev 8082 spring-boot application-localhost.yml

# 1 - stop server on port ...
stopServer
backup
# 2 - delete destinations folder content
deleteFiles

# 3 - copy files to deploy dir
copyFiles

changeFilePermission
# 4 - start server
run

# 5 - watch loading messages until  ($whatToFind) message is found
watch