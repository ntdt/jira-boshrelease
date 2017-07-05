#!/usr/bin/env bash

set -e # exit immediately if a simple command exits with a non-zero status
set -u # report the usage of uninitialized variables

JOB_NAME=$1
output_label=${2:-${JOB_NAME}}

export JOB_DIR=/var/vcap/jobs/$JOB_NAME
chmod 755 $JOB_DIR # to access file via symlink
source $JOB_DIR/data/properties.sh
source $JOB_DIR/helpers/ctl_utils.sh
source $JOB_DIR/helpers/ctl_mountnfs.sh
redirect_output ${output_label}
export HOME=${HOME:-/home/vcap}


# Setup the PATH and LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-''} # default to empty
for package_dir in $(ls -d /var/vcap/packages/*)
do
  has_busybox=0
  # Add all packages' /bin & /sbin into $PATH
  for package_bin_dir in $(ls -d ${package_dir}/*bin)
  do
    # Do not add any packages that use busybox, as impacts builtin commands and
    # is often used for different architecture (via containers)
    if [ -f ${package_bin_dir}/busybox ]
    then
      has_busybox=1
    else
      export PATH=${package_bin_dir}:$PATH
    fi
  done
  if [ "$has_busybox" == "0" ] && [ -d ${package_dir}/lib ]
  then
    export LD_LIBRARY_PATH=${package_dir}/lib:$LD_LIBRARY_PATH
  fi
done

# Setup log, run and tmp folders

export RUN_DIR=/var/vcap/sys/run/$JOB_NAME
export LOG_DIR=/var/vcap/sys/log/$JOB_NAME
export TMP_DIR=/var/vcap/sys/tmp/$JOB_NAME
export STORE_DIR=/var/vcap/store/$JOB_NAME
for dir in $RUN_DIR $LOG_DIR $TMP_DIR $STORE_DIR
do
  mkdir -p ${dir}
  chown vcap:vcap ${dir}
  chmod 775 ${dir}
done
export TMPDIR=$TMP_DIR

export C_INCLUDE_PATH=/var/vcap/packages/mysqlclient/include/mysql:/var/vcap/packages/sqlite/include:/var/vcap/packages/libpq/include
export LIBRARY_PATH=/var/vcap/packages/mysqlclient/lib/mysql:/var/vcap/packages/sqlite/lib:/var/vcap/packages/libpq/lib

jreversion=<%= p("jira.java_version") %>
if [[ -d /var/vcap/packages/java/$jreversion ]]
then
  export JAVA_HOME="/var/vcap/packages/java/$jreversion"
fi

# setup CLASSPATH for all jars/ folders within packages
export CLASSPATH=${CLASSPATH:-''} # default to empty
for java_jar in $(ls -d /var/vcap/packages/*/*/*.jar)
do
  export CLASSPATH=${java_jar}:$CLASSPATH
done

JAVA_HOME=/var/vcap/packages/java/<%= p("jira.java_version") %>/jre

#Create jira Home Direrctory
JIRA_HOME=/var/vcap/store/jira/home
MOUNTPOINT=$JIRA_HOME/shared
if [ -d "$JIRA_HOME" ]; then
    echo "directory $JIRA_HOME already exist"
else
    mkdir -p $JIRA_HOME/shared
fi



# RUNUSER: The user to run jira Server as.
RUNUSER=vcap

# JIRA_HOME: Path to the jira home directory
NAME=jira
JIRA_INSTALLDIR=/var/vcap/packages/jira/installdir
PIDFILE=$JIRA_HOME/var/vcap/packages/jira/installdir/work/catalina.pid

file=$JIRA_HOME/shared/jira.properties
if [ -d "$file" ]; then
	rm -rf $JIRA_HOME/jira-config.properties
    echo "directory $JIRA_HOME/jira-config.properties already exist so will be deleted"	
fi



cp -rf /var/vcap/jobs/jira/config/jira-config.properties $JIRA_HOME/jira-config.properties
cp -rf /var/vcap/jobs/jira/config/setenv.sh $JIRA_INSTALLDIR/bin/setenv.sh
cp -rf /var/vcap/jobs/jira/config/config.sh $JIRA_INSTALLDIR/bin/config.sh



chown -R $RUNUSER:$RUNUSER $JIRA_HOME $JIRA_INSTALLDIR 
run_with_home() {
        su - "$RUNUSER" -c "export JAVA_HOME=${JAVA_HOME};export PATH=$PATH:${JAVA_HOME}/bin;export JIRA_HOME=${JIRA_HOME};${JIRA_INSTALLDIR}/bin/$1"
}
run_with_home() {
        su - "$RUNUSER" -c "export JAVA_HOME=${JAVA_HOME};export PATH=$PATH:${JAVA_HOME}/bin;export JIRA_HOME=${JIRA_HOME};${JIRA_INSTALLDIR}/bin/$1"
}

#
# Function that starts the daemon/service
#
do_start()
{
    echo "HA="
    echo <%= p("jira.enable_ha") %> 
    if [ <%= p("jira.enable_ha") %> = true ]; then
      mount_nfs
      sleep 5
    fi
    run_with_home start-jira.sh
}

#
# Function that stops the daemon/service
do_stop()
{
    echo ${PIDFILE}
    if [ -e ${PIDFILE} ]; then
      run_with_home stop-jira.sh 
      kill_and_wait ${PIDFILE}
    else
      log_failure_msg "$NAME is not running."
    fi
    umount_nfs
}

echo '$PATH' $PATH
