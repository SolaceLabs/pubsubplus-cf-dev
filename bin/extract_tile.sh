#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export CMD_NAME=`basename $0`

export BASIC_USAGE_PARAMS="-t solace-messaging*.pivotal "

export TEMP_DIR=$(mktemp -d)

function cleanupTemp() {
 if [ -d $TEMP_DIR ]; then
    rm -rf $TEMP_DIR
 fi
}
trap cleanupTemp EXIT INT TERM HUP

function showUsage() {
  echo
  echo "Usage: $CMD_NAME $BASIC_USAGE_PARAMS " $1
  echo
}

function missingRequired() {
  echo
  echo "Some required argument(s) were missing."
  echo 

  showUsage
  exit 1
}

if (($# == 0)); then
  missingRequired
fi

while getopts :t:h opt; do
    case $opt in
      t)
        export TILE_FILE=$OPTARG
      ;;
      h)
        showUsage
        exit 0
      ;;
      \?)
      echo
      echo "Invalid option: -$OPTARG" >&2
      echo
      showUsage
      exit 1
      ;;
      :)
      echo
      echo "Option -$OPTARG requires an argument." >&2
      echo
      case $OPTARG in
          A)
    	    showUsage "$OPTIONAL_USAGE_PARAMS"
          ;;
          N)
            showUsage "$OPTIONAL_USAGE_PARAMS"
          ;;
          \?)
            showUsage
          ;;
      esac
      exit 1
      ;;
  esac
done

missing_required=0

if [ -z $TILE_FILE ]; then
   echo
   echo "A Tile file name is missing"
   missing_required=1;
fi

if [ ! -f $TILE_FILE ]; then
   echo
   echo "The tile file $TILE_FILE does not exist?!"
   missing_required=1;
fi

## Derived values

export TILE_VERSION=$( basename $TILE_FILE | sed 's/solace-messaging-//g' | sed 's/\.pivotal//g' )
export TEMPLATE_VERSION=$( basename $TILE_FILE | sed 's/solace-messaging-//g' | sed 's/\.pivotal//g' | awk -F\- '{ print $1 }' )

export TILE_FILE_PATH=$(readlink -f "$TILE_FILE")
export WORKSPACE=${WORKSPACE-`dirname $TILE_FILE_PATH`}

export TEMPLATE_DIR=$SCRIPTPATH/../templates/$TEMPLATE_VERSION 

if [ ! -d $TEMPLATE_DIR ]; then
   echo 
   echo "Required templates seem to be missing for version $TEMPLATE_VERSION"
   echo "Unable to locate templates , expected in $TEMPLATE_DIR"
   missing_required=1;
fi

if ((missing_required)); then
   missingRequired
fi

echo "TILE_FILE         $TILE_FILE"
echo "TILE_VERSION      $TILE_VERSION"
echo "TEMPLATE_VERSION  $TEMPLATE_VERSION"

echo "Extracting contents to $WORKSPACE/releases"

if [ -d $WORKSPACE/releases ]; then
 echo "Clean up of old releases"
 rm -rf $WORKSPACE/releases
fi

unzip -d $WORKSPACE $TILE_FILE releases/*.tgz

( 
  cd $TEMP_DIR
  echo "Looking for $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz"
  mkdir -p solace-messaging-${TILE_VERSION} 
  echo "Extrating contents of solace-messaging-${TILE_VERSION}.tgz"
  ( cd solace-messaging-${TILE_VERSION}; tar -xzf $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz )

  SB_JAR=$(tar -tzf solace-messaging-${TILE_VERSION}/packages/solace_messaging.tgz | grep jar)
  echo "Detected Solace Service Broker jar path $SB_JAR"
  tar -xOzf solace-messaging-${TILE_VERSION}/packages/solace_messaging.tgz $SB_JAR > $WORKSPACE/releases/solace-messaging.jar
  echo "Extracted Solace Service Broker to $WORKSPACE/releases/solace-messaging.jar"

  ( cd solace-messaging-${TILE_VERSION}; tar -xzf $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz )
  ( cd solace-messaging-${TILE_VERSION}/packages; tar -xzf solace_messaging.tgz )
  sed -i 's/java_buildpack_offline/java_buildpack/' solace-messaging-${TILE_VERSION}/packages/solace_messaging/manifest.yml
  echo "memory: 1024M" >> solace-messaging-${TILE_VERSION}/packages/solace_messaging/manifest.yml
  echo "Keeping a copy of the service broker manifest as $WORKSPACE/service-broker-manifest.yml"
  cp solace-messaging-${TILE_VERSION}/packages/solace_messaging/manifest.yml $WORKSPACE/service-broker-manifest.yml

  ( 
    cd solace-messaging-${TILE_VERSION}/jobs
    mkdir deploy-all
    cd deploy-all
    tar -xzf ../deploy-all.tgz 
    echo "Modified deploy-all to use 1gb mysql plan"
    sed -i 's/SVC_PLAN\=\"\"/SVC_PLAN\=\"1gb\"/' templates/deploy-all.sh.erb
    echo "Repackaged deploy-all.tgz"
    tar -czf ../deploy-all.tgz ./
    cd ..
    rm -rf deploy-all
  )

  ## Package and cleanup
  ( 
    cd solace-messaging-${TILE_VERSION}/packages
    tar -czf solace_messaging.tgz packaging solace_messaging 
    rm -f packaging
    rm -rf solace_messaging 
  )


  echo "Repackaging solace-messaging-${TILE_VERSION}.tgz"
  ( cd solace-messaging-${TILE_VERSION}; tar -czf $WORKSPACE/releases/solace-messaging-${TILE_VERSION}.tgz . )

  if [ -f $TEMPLATE_DIR/trusted.crt ]; then
	 echo "Copy $TEMPLATE_DIR/trusted.crt $WORKSPACE"
	 cp $TEMPLATE_DIR/trusted.crt $WORKSPACE
  fi

  echo "Extracting is completed"
)

