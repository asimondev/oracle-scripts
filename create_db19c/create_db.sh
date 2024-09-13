#!/usr/bin/bash -x
#
# Author: Andrej Simon
#
# This scripts create 19c database using dbca. 
#

PROG="create_db.sh"
ENV_FILE=""
DB_TYPE="default"
SCRIPTS_DIR="$(dirname $BASH_SOURCE)"
FRA_SIZE=25000
FRA=""
DATA=""
DB_DIR="/u01/oracle/databases/19c"
FRA_DG="FRA"
DATA_DG="DATA"
PWD="oracle"
CDB="noncdb"
DB=""
DB_NAME=""
DB_UNIQUE_NAME=""
SID=""
RAC=""
NODES=""
RAC_NODES=""
RECO=""
RSP_FILE=""
TMPL_FILE=""
INIT_PARAMS=""
DEFAULT_CDB_SGA="8192"
DEFAULT_CDB_PGA="2048"
DEFAULT_NONCDB_SGA="4096"
DEFAULT_NONCDB_PGA="1024"
CHARSET=""
DRY_RUN=""

function usage {
  cat<<EOF
Usage: $PROG -d DbName [-u DbUniqueName -c -n RAC_Nodes -r -t DBType -e EnvFile -p Password -i InitParams -f FRA -g DATA -z FRASizeMB -s CharacterSet -h -j]
  -c: CDB database (default: non-CDB database)
  -d: database name (DB_NAME.DB_DOMAIN)
  -e: file with environment variables ORACLE_BASE, ORACLE_HOME, PATH  
  -f: FRA ASM Diskgroup or FRA directory (default RAC: ${FRA_DG})
  -g: database directory or DATA ASM Diskgroup (default: ${DB_DIR}; RAC: $DATA_DG)
  -h: print usage  
  -i: comma separated init.ora parameters 
  -j: print but do not execute the commands (just print)
  -n: RAC nodes
  -p: database password (default oracle)
  -r: RAC database
  -s: database character set (default: AL32UTF8)
  -t: database template type {default | custom | TemplatePath} (default: default)
  -u: database unique name (default: database name)
  -z: FRA size im MB (default: ${FRA_SIZE})
  
EOF

  exit 1
}

function set_response_file {
  if [ -z "$RAC" ]; then
    RSP_FILE=db19c_dbca_${CDB}.rsp
    if [ $DB_TYPE = "default" ]; then
      TMPL_FILE=$ORACLE_HOME/assistants/dbca/templates/General_Purpose.dbc
    elif [ $DB_TYPE = "custom" ]; then
      TMPL_FILE=$ORACLE_HOME/assistants/dbca/templates/New_Database.dbt
    else
      if -f "$DB_TYPE" ; then
        TMPL_FILE=$DB_TYPE
      else
        echo "Error: can not find template file $DB_TYPE"
        exit 1
      fi
    fi
  else
    if [ $DB_TYPE = "default" ]; then
      TMPL_FILE=$ORACLE_HOME/assistants/dbca/templates/General_Purpose.dbc
      RSP_FILE=rac19c_dbca_${CDB}_${DB_TYPE}.rsp
    elif [ $DB_TYPE = "custom" ]; then
      TMPL_FILE=$ORACLE_HOME/assistants/dbca/templates/New_Database.dbt
      RSP_FILE=rac19c_dbca_${CDB}_${DB_TYPE}.rsp
    else
      if -f "$DB_TYPE" ; then
        TMPL_FILE=$ORACLE_HOME/assistants/dbca/templates/General_Purpose.dbc
        RSP_FILE=rac19c_dbca_${CDB}_default.rsp
      else
        echo "Error: can not find template file $DB_TYPE"
        exit 1
      fi
    fi
  fi
}

function check_memory {
  local cdb=$1
  local params=""
  local free_mem="2048"

  local mem="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
  ((mem=mem/1024))

  if [ $cdb = "cdb" ]; then
    (( mem > (DEFAULT_CDB_SGA + DEFAULT_CDB_PGA + free_mem) )) && return
    params="sga_target=4096M,pga_aggragate_target=1024M"
  else
    (( mem > (DEFAULT_NONCDB_SGA + DEFAULT_NONCDB_PGA + free_mem) )) && return
    params="sga_target=2048M,pga_aggragate_target=1024M"
  fi

  if [ -n $params ]; then
    [ -n "$INIT_PARAMS" ] && INIT_PARAMS="${INIT_PARAMS},"
    INIT_PARAMS="${INIT_PARAMS}${params}"
  fi
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

  local nodes=""
  while read node ; do
    [ -n "$nodes" ] && nodes="${nodes},"
    nodes="${nodes}${node}"
  done < $olsnodes

  RAC_NODES="$nodes"
}


while getopts "cd:e:f:g:hi:jn:p:rs:t:u:z:" opt; do
  case $opt in
    c) CDB="cdb" ;;
    d) DB_NAME="$OPTARG" ;;
    e) ENV_FILE="$OPTARG" ;;
    f) FRA="$OPTARG" ;;
    g) DATA="$OPTARG" ;;
    h) usage ;;
    i) INIT_PARAMS="$OPTARG" ;;
    j) DRY_RUN="YES" ;;
    n) NODES="$OPTARG" ;;
    p) PWD="$OPTARG" ;;
    r) RAC="yes" ;;
    s) CHARSET="$OPTARG" ;;
    t) DB_TYPE="$OPTARG" ;;
    u) DB_UNIQUE_NAME="$OPTARG" ;;
    z) FRA_SIZE="$OPTARG" ;;
    *)
      echo "Error: unknown program option"
      exit 1
      ;;
  esac
done

if [ -z "$DB_NAME" ] && [ -z "$DB_UNIQUE_NAME" ]; then
  echo "Error: missing mandatory parameter(s)"
  usage
fi

if [ -z "$RAC" ]; then
  [ -z "$DATA" ] && DATA=$DB_DIR
else
  [ -z "$DATA" ] && DATA=$DATA_DG
  [ -z "$FRA" ]  && FRA=$FRA_DG
fi

if [ -z "$RAC" ] ; then
  if ! [ -d $DATA ]; then
    if ! mkdir -p $DATA ; then
      echo "Error: can not create database directory $DATA"
      exit 1
    fi
  fi

  if ! [ -d $FRA ]; then
    if ! mkdir -p $FRA ; then
      echo "Error: can not create FRA directory $FRA"
      exit 1
    fi
  fi
fi

if [ -n "$ENV_FILE" ]; then
  if ! source $ENV_FILE ; then
    echo "Error: can not run environment file: $ENV_FILE"
    exit 1
  fi
fi

check_obase_ohome
setup_rac
set_response_file

if [ ! -f $RSP_FILE ]; then
  echo "Error: database response file $RSP_FILE not found."
  exit 1
fi

if [ ! -f $TMPL_FILE ]; then
  echo "Error: database template file $TMPL_FILE not found."
  exit 1
fi

OMF="-useOMF true"
DBCA_CDB=""
TEMPLATE_NAME=" -templateName $TMPL_FILE "
DATAFILE_DEST="-datafileDestination $DATA"


RAC_OPTONS=""
if [ -n "$RAC" ]; then
  DATAFILE_DEST="-storageType ASM -datafileDestination +${DATA}"
  RECO="-recoveryAreaDestination +${FRA} -recoveryAreaSize $FRA_SIZE"
  [ -n "$NODES" ] && RAC_NODES=$NODES
  RAC_OPTIONS="-nodelist ${RAC_NODES}"
fi

check_memory $CDB

if [ -n "$DB_UNIQUE_NAME" ]; then
  if [ -n "$DB_NAME" ]; then
    SID=$DB_NAME
    [ -n "$INIT_PARAMS" ] && INIT_PARAMS="${INIT_PARAMS},"
    INIT_PARAMS="${INIT_PARAMS}db_name=${DB_NAME%%.*},db_unique_name=${DB_UNIQUE_NAME%%.*}"
  else
    SID=$DB_UNIQUE_NAME
  fi
else
  DB_UNIQUE_NAME=$DB_NAME
  SID=$DB_NAME
fi
SID=${SID%%.*}

[ -n "$INIT_PARAMS" ] && INIT_PARAMS="-initParams ${INIT_PARAMS}"

if [ -z "$RAC" ]; then
  if [ -n "$FRA" ]; then
    RECO="-recoveryAreaDestination $FRA"
  fi 
  RECO="${RECO} -recoveryAreaSize ${FRA_SIZE}"
fi

if [ -n "$CHARSET" ]; then
  CHARSET="-characterSet $CHARSET"
fi

DBCA_CMD=$(echo "dbca -createDatabase -silent $CHARSET \
 -responseFile $RSP_FILE \
 -gdbName $DB_NAME -sid $SID \
 -sysPassword $PWD -systemPassword $PWD \
 $DATAFILE_DEST $RAC_OPTIONS $INIT_PARAMS $RECO \
 $TEMPLATE_NAME $DBCA_CDB $OMF")

if [ -n "$DRY_RUN" ]; then
  echo -e "\n=====> Response file: $RSP_FILE"
  cat $RSP_FILE
  echo -e "\n=====> DBCA command:"
  echo "$DBCA_CMD"
  exit 
fi

if $DBCA_CMD ; then
  echo -e "\nDatabase $DB_UNIQUE_NAME created successfully.\n"
else
  echo -e "\nDatabase $DB_UNIQUE_NAME could not be created.\n"
fi
