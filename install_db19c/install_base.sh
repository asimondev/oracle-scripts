#!/usr/bin/bash -x
#
# Author: Andrej Simon
#
# This scripts install base database release. For 19c you can use any
# available gold image instead of the base installation zip file.
#

function usage {
  cat<<EOF
Usage: $PROG [-f BaseResponseFile -g Groups -e EnvFile -i GoldImage -v OracleInventoryPath [-r {-l | -n RAC-Nodes}] -p -h] 
  -e: file with environment variables ORACLE_BASE, ORACLE_HOME, PATH  
  -f: base response file (default: base_install_db19c.rsp for single instance)
  -g : groups {default | oinstall_dba | dba | custom}
  -h: print usage
  -i: gold image for 19c installations (default: base 19c)
  -l: local RAC node only.
  -n: RAC nodes for installation (default: all RAC nodes).
  -p: do not ignore prereq failures (default: -ignorePrereqFailure)
  -r: RAC 
  -v: Oracle Inventory path (default: inventory_loc from /etc/oraInst.loc)

EOF

  exit 1
}

PROG="install_base.sh"
DB_VER=""
ENV_FILE=""
INSTALL_DIR="$(dirname $BASH_SOURCE)"
RUN_INSTALLER=""

BASE_ZIP_FILE=""
BASE_RSP_FILE=""
DB_RSP_FILE="base_install_db19c.rsp"
RAC_RSP_FILE="base_install_rac19c.rsp"

GOLD_IMAGE="base"

ORACLE_INVENTORY=""

ORACLE_GROUPS="default"

IGNORE_PREREQ="yes"
RAC=""
RAC_NODES=""
LOCAL_NODE="no"

function check_inventory {
  if [ -n "$ORACLE_INVENTORY" ]; then
    if [ ! -d $ORACLE_INVENTORY ]; then
      if ! mkdir $ORACLE_INVENTORY ; then
        echo "Error: can not create Oracle inventory directory: $ORACLE_INVENTORY"
        exit 1
      fi
    fi

    return
  fi

  local inv="$(grep 'inventory_loc' /etc/oraInst.loc)"
  if [ -n "$inv" ]; then
    ORACLE_INVENTORY=${inv#inventory_loc=}
    return
  fi

  echo "Error: Oracle Inventory not found"
  exit 1
}

function check_groups {
  if [ -z "$ORACLE_GROUPS" ]; then
    echo "Error: mandatory parameter groups must be set"
    exit 1
  fi

  case $ORACLE_GROUPS in
    default)
      OINSTALL_GROUP=oinstall
      OSOPER_GROUP=""
      BACKUP_GROUP=backupdba
      DATAGUARD_GROUP=dgdba
      OKM_GROUP=kmdba
      RAC_GROUP=racdba
      ;;

    oinstall_dba)
      OINSTALL_GROUP=oinstall
      OSOPER_GROUP=dba
      BACKUP_GROUP=dba
      DATAGUARD_GROUP=dba
      OKM_GROUP=dba
      RAC_GROUP=dba
      ;;

    dba)
      OINSTALL_GROUP=dba
      OSOPER_GROUP=dba
      BACKUP_GROUP=dba
      DATAGUARD_GROUP=dba
      OKM_GROUP=dba
      RAC_GROUP=dba
      ;;

    custom)
      OINSTALL_GROUP=oinstall
      OSOPER_GROUP=""
      BACKUP_GROUP=dba
      DATAGUARD_GROUP=dba
      OKM_GROUP=dba
      RAC_GROUP=dba
      ;;

    *)
      echo "Error: unknown group parameter"
      exit 1
      ;;
  esac
}

function check_obase_ohome {
  if [ -z "$ORACLE_BASE" ]; then
    echo "Error: variable ORACLE_BASE must be set"
    exit 1
  fi

  if [ -z "$ORACLE_HOME" ]; then
    echo "Error: variable ORACLE_HOME must be set"
    exit 1
  fi
}

function check_env {
  if [ -z "$ORACLE_INVENTORY" ]; then
    echo "Error: inventory directory must be set."
    exit 1
  fi

  if [ -d $ORACLE_HOME ]; then
    if ls ${ORACLE_HOME}/* 1>/dev/null 2>&1; then
      echo "Error: ORACLE_HOME ($ORACLE_HOME) must be empty."
      exit 1
    fi
  else
    if ! mkdir -p $ORACLE_HOME ; then
      echo "Error: can not create ORACLE_HOME."
      exit 1
    fi
  fi

  if [ -z "$OINSTALL_GROUP" ]; then
    echo "Error: OINSTALL_GROUP name must be set."
    exit 1
  fi

  if [ -z "$BACKUP_GROUP" ]; then
    echo "Error: BACKUP_GROUP name must be set."
    exit 1
  fi

  if [ -z "$DATAGUARD_GROUP" ]; then
    echo "Error: DATAGUARD_GROUP name must be set."
    exit 1
  fi

  if [ -z "$OKM_GROUP" ]; then
    echo "Error: OKM_GROUP name must be set."
    exit 1
  fi

  if [ -z "$RAC_GROUP" ]; then
    echo "Error: RAC_GROUP name must be set."
    exit 1
  fi

  if [ -z "$BASE_ZIP_FILE" ] || [ ! -f $BASE_ZIP_FILE ]; then
    echo "Error: Can not find installation zip file."
    exit 1
  fi

  if [ -z " " ] || [ ! -f $BASE_RSP_FILE ]; then
    echo "Error: Can not find installation response file."
    exit 1
  fi

}

function setup_rac {
  [ -z "$RAC" ] && return

  local crsd_bin="$(ps -e -o command | grep '[c]rsd.bin')"
  if [ -z "$crsd_bin" ]; then
    echo "Error: can not find path of GI installation."
    exit 1
  fi

  local grid_bin="$(dirname ${crsd_bin% *})"
  local olsnodes="/tmp/olsnodes$$.out"
  if ! $grid_bin/olsnodes > $olsnodes ; then
    echo "Error: can not run olsnodes command"
    exit 1
  fi

  if [ $LOCAL_NODE = "yes" ]; then
    RAC_NODES="$(hostname -s)"
    return
  fi

  local nodes=""
  while read node ; do
    [ -n "$nodes" ] && nodes="${nodes},"
    nodes="${nodes}${node}"
  done < $olsnodes

  RAC_NODES="$nodes"
}

function install_db_home {
  local rsp_file="$(mktemp -t install_db_XXX).rsp"
  [ -n "$RAC" ] && setup_rac
  setup_rsp_file $rsp_file

  if ! cd $ORACLE_HOME ; then
    echo "Error: can not cd to $ORACLE_HOME."
    exit 1
  fi

  if ! unzip $BASE_ZIP_FILE 1>/dev/null ; then
    echo "Error: can not unzip installation zip file."
    exit 1
  fi

  RUN_INSTALLER="$ORACLE_HOME/runInstaller"
  if [ "$IGNORE_PREREQ" = "yes" ]; then
    RUN_INSTALLER="$RUN_INSTALLER -ignorePrereqFailure "
  fi 

  $RUN_INSTALLER -silent -force -waitforcompletion \
      -responsefile $rsp_file  && \
      echo "Installation was done successfully."

  local rc=$?

  rm $rsp_file 1>/dev/null 2>&1

  if [ $rc = "6" ]; then
    echo "*** Return code after runInstall.sh is 6. Changing it to 0. ***"
    rc=0
  fi

  if [ $rc = "0" ] && [ -d /opt/oracle.cellos ]; then
    echo "*** Exadata only: "
    echo "Consider copying the files from the existing ORACLE_HOME/assistants/dbca/templates to the new $ORACLE_HOME/assistants/dbca/templates directory."
  fi
  
  return $rc
}

function setup_rsp_file {
  local rsp_file=$1

  if ! cp $BASE_RSP_FILE $rsp_file ; then
    echo "Error: can not create local response file."
    exit 1
  fi

  # Replace strings in response file.
  sed -i -e "s|###ORACLE_INVENTORY###|$ORACLE_INVENTORY|g" $rsp_file
  sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g" $rsp_file
  sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g" $rsp_file
  sed -i -e "s|###OINSTALL_GROUP###|$OINSTALL_GROUP|g" $rsp_file
  sed -i -e "s|###OSOPER_GROUP###|$OSOPER_GROUP|g" $rsp_file
  sed -i -e "s|###BACKUP_GROUP###|$BACKUP_GROUP|g" $rsp_file
  sed -i -e "s|###DATAGUARD_GROUP###|$DATAGUARD_GROUP|g" $rsp_file
  sed -i -e "s|###OKM_GROUP###|$OKM_GROUP|g" $rsp_file
  sed -i -e "s|###RAC_GROUP###|$RAC_GROUP|g" $rsp_file

  if [ -n "$RAC" ]; then
    sed -i -e "s|###ORACLE_NODES###|$RAC_NODES|g" $rsp_file
  fi
}


while getopts "e:f:g:hi:lprv:" opt; do

  case $opt in
    e) ENV_FILE="$OPTARG" ;;
    f) BASE_RSP_FILE="$OPTARG" ;;
    g) ORACLE_GROUPS="$OPTARG" ;;    
    h) usage ;;
    i) BASE_ZIP_FILE="$OPTARG" ;;
    l) LOCAL_NODE="yes" ;;
    p) IGNORE_PREREQ="no" ;;
    r) RAC="yes" ;;
    v) ORACLE_INVENTORY="$OPTARG" ;;
    *) 
      echo "Error: unknown program option"
      exit 1
      ;;
  esac

done

if [ -n "$ENV_FILE" ]; then
  if ! source $ENV_FILE ; then
    echo "Error: can not run environment file: $ENV_FILE"
    exit 1
  fi
fi

if [ -z "$BASE_RSP_FILE" ]; then
  if [ "$RAC" = "yes" ]; then
    BASE_RSP_FILE=$RAC_RSP_FILE
  else
    BASE_RSP_FILE=$DB_RSP_FILE
  fi
fi
check_inventory
check_groups
check_obase_ohome
check_env

install_db_home
