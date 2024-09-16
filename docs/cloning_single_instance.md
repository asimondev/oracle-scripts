# Sinlge Instance Out-Of-Place Cloning and Patching.

At first you have do download the the files from GitHub repository: [Oracle Database Scripts](https://github.com/asimondev/oracle-scripts). Usually you would download the latest release 
on left side of this page. The downloaded TAR file can be copied to the database servers. In 
this example all scripts are unpacked in the directory */home/oracle/oracle_scripts*.

## Creating a gold image for the existing ORACLE_HOME.

After setting the Oracle environment the gold image will be created in the 
directory */u01/oracle/images*.

```
oracle@rkol7db1> mkdir /u01/oracle/images

oracle@rkol7db1> ls -l /u01/oracle/images
total 0

oracle@rkol7db1> cd $ORACLE_HOME
oracle@rkol7db1> ./runInstaller -silent -createGoldImage -destinationLocation /u01/oracle/images
Launching Oracle Database Setup Wizard...

Successfully Setup Software.
Gold Image location: /u01/oracle/images/db_home_2024-09-14_09-24-48PM.zip
```

We can noch rename this gold image.
```
oracle@rkol7db1> cd /u01/oracle/images
oracle@rkol7db1> ls -lh *
-rw-r--r-- 1 oracle oinstall 4,4G 14. Sep 21:30 db_home_2024-09-14_09-24-48PM.zip

oracle@rkol7db1> mv db_home_2024-09-14_09-24-48PM.zip db_19.18.zip

oracle@rkol7db1> ls 
db_19.18.zip
```

## Creating a new ORACLE_HOME using the gold image.

### Creating installation environment files.

At first we have to create the installation files for the new ORACLE_HOME.

```
oracle@rkol7db1> pwd
/home/oracle/env

oracle@rkol7db1> cat inst_db19f
#!/bin/bash

export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/db19f
export TMP=/tmp
export TMPDIR=/tmp
umask 022

oracle@rkol7db1> cat db19f
#!/bin/bash

export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/db19f
unset ORACLE_SID

export NLS_LANG=american_america.al32utf8

export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export ORACLE_PATH=~/sql:.
export SQLPATH=~/sql:.
export VISUAL=/bin/vi

export oh=$ORACLE_HOME

oracle@rkol7db1> chmod 755 *db19f

oracle@rkol7db1> ls -l *db19f
-rwxr-xr-x 1 oracle oinstall 331 16. Sep  10:42 db19f
-rwxr-xr-x 1 oracle oinstall 127 16. Sep  10:42 inst_db19f
```

### Checking UNIX groups.

The current UNIX groups for the *oracle* user are:
```
oracle@rkol7db1> id
uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),54322(dba),54323(oper),54324(backupdba),54325(dgdba),54326(kmdba),54330(racdba)
```

If you are unsure about the used UNIX groups in the previous ORACLE_HOME installation, 
you should check it now:

```
oracle@rkol7db1> cat $ORACLE_HOME/rdbms/lib/config.c

/*  SS_DBA_GRP defines the UNIX group ID for sqldba adminstrative access.  */
/*  Refer to the Installation and User's Guide for further information.  */

/* IMPORTANT: this file needs to be in sync with
              rdbms/src/server/osds/config.c, specifically regarding the
              number of elements in the ss_dba_grp array.
 */
...

#define SS_DBA_GRP "dba"
#define SS_OPER_GRP ""
#define SS_ASM_GRP ""
#define SS_BKP_GRP "backupdba"
#define SS_DGD_GRP "dgdba"
#define SS_KMT_GRP "kmdba"
#define SS_RAC_GRP "racdba"

const char * const ss_dba_grp[] = 
     {SS_DBA_GRP, SS_OPER_GRP, SS_ASM_GRP,
      SS_BKP_GRP, SS_DGD_GRP, SS_KMT_GRP,
      SS_RAC_GRP};   

```

In this case these are the default groups, so that we can use default values. If you use
some specific UNIX groups, you should use **-g custom** parameter of **install_base.sh** 
and modify this file. Please look for the Bash function **check_groups** and set your 
specific groups in this part of script:

```

    custom)
      OINSTALL_GROUP=oinstall
      OSOPER_GROUP=""
      BACKUP_GROUP=dba
      DATAGUARD_GROUP=dba
      OKM_GROUP=dba
      RAC_GROUP=dba
      ;;

```

### Create a new ORACLE_HOME using the gold image.

Now we can start the database installation using the gold image and the 
environment file for the new ORACLE_HOME. The default UNIX groups will be used.

```
oracle@rkol7db1> pwd
/home/oracle/oracle_scripts

oracle@rkol7db1> cd install_db19c/
oracle@rkol7db1> 

oracle@rkol7db1> ./install_base.sh -h
...
Usage: install_base.sh [-f BaseResponseFile -g Groups ] -e EnvFile -i GoldImage [-v OracleInventoryPath -r {-l | -n RAC-Nodes}] -p -h] 
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

oracle@rkol7db1> ./install_base.sh -e ~/env/inst_db19f -i /u01/oracle/images/db_19.18.zip
...
As a root user, execute the following script(s):
	1. /u01/oracle/db19f/root.sh

Execute /u01/oracle/db19f/root.sh on the following nodes: 
[rkol7db1]
...
Successfully Setup Software with warning(s).
...
```

Now we have to run *root.sh* script as root user on this node.
```
[root@rkol7db1 ~]# /u01/oracle/db19f/root.sh
Check /u01/oracle/db19f/install/root_rkol7db1.nichtsimon.de_2024-09-16_11-08-11-868988839.log for the output of root script
[root@rkol7db1 ~]# 
```

## Patching the new ORACLE_HOME to 19.24.

In this example will install 19.24 DB RU and 19.24 OJVM.

### OPatch installation.

At first we will set the new environment and replace *opatch* with the new version.
```
oracle@rkol7db1> . ~/env/db19f

oracle@rkol7db1> cd $ORACLE_HOME

oracle@rkol7db1> unzip -o /home/oracle/patches/2024-07/p6880880_190000_Linux-x86-64.zip 
```

### DB RU 19.24 installation.

Now we can unpack the DB RU 19.24 in the new */u01/oracle/patches/db_ru_2024_07* directory.

```
oracle@rkol7db1> mkdir -p /u01/oracle/patches

oracle@rkol7db1> cd /u01/oracle/patches
oracle@rkol7db1> 

oracle@rkol7db1> mkdir /u01/oracle/patches/db_ru_2024_07
oracle@rkol7db1> cd /u01/oracle/patches/db_ru_2024_07

oracle@rkol7db1> unzip /home/oracle/patches/2024-07/p36582781_190000_Linux-x86-64.zip 
...
oracle@rkol7db1> ls
36582781  PatchSearch.xml
oracle@rkol7db1> 

```

We are ready to patch this ORACLE_HOME with DB DU 19.24.
```
oracle@rkol7db1> pwd
/u01/oracle/patches/db_ru_2024_07
oracle@rkol7db1> 

oracle@rkol7db1> cd 36582781/

oracle@rkol7db1> $ORACLE_HOME/OPatch/opatch apply 
...
Patch 36582781 successfully applied.
...

OPatch succeeded.
```

### OJVM 12.24 installation.

```
oracle@rkol7db1> cd /u01/oracle/patches

oracle@rkol7db1> mkdir ojvm_2024_07
oracle@rkol7db1> cd ojvm_2024_07/
oracle@rkol7db1> 

oracle@rkol7db1> unzip /home/oracle/patches/2024-07/p36414915_190000_Linux-x86-64.zip 

oracle@rkol7db1> cd 36414915/

oracle@rkol7db1> $ORACLE_HOME/OPatch/opatch apply
...
Patch 36414915 successfully applied.
...
OPatch succeeded.
```

## Creating a new gold image of 19.24 ORACLE_HOME.

At first we should check the installed patches in this ORACLE_HOME. All patches should be from 
19.24 DB RU.
```
oracle@rkol7db1> $ORACLE_HOME/OPatch/opatch lspatches
36414915;OJVM RELEASE UPDATE: 19.24.0.0.240716 (36414915)
36582781;Database Release Update : 19.24.0.0.240716 (36582781)
29585399;OCW RELEASE UPDATE 19.3.0.0.0 (29585399)

OPatch succeeded.
```

All required patches are installed in this ORACLE_HOME. So we can create a new gold image 
from it.
```
oracle@rkol7db1> cd $ORACLE_HOME
oracle@rkol7db1> ./runInstaller -silent -createGoldImage -destinationLocation /u01/oracle/images
Launching Oracle Database Setup Wizard...

Successfully Setup Software.
Gold Image location: /u01/oracle/images/db_home_2024-09-16_11-53-37AM.zip

oracle@rkol7db1> cd /u01/oracle/images/

oracle@rkol7db1> ls -lh
total 13G
-rw-r--r-- 1 oracle oinstall 5,8G 16. Sep  10:35 db_19.18.zip
-rw-r--r-- 1 oracle oinstall 7,0G 16. Sep  12:01 db_home_2024-09-16_11-53-37AM.zip

oracle@rkol7db1> mv db_home_2024-09-16_11-53-37AM.zip db_19.24.zip
oracle@rkol7db1> 
````

We can use this new 19.24 gold image *db_19.24.zip* for new installations on the 
same or other servers.


## Further steps for gold image installations.

 * You have to copy the network files from the old *$ORACLE_HOME/network/admin* to the 
new directory. 
 * If the different nodes have different network files, you have to copy these
files from the corresponding node.
 * Some network files contain the current ORACLE_HOME. In this case you would have to 
modify such files to specify the new ORACLE_HOME.
 * Don't forget to copy SPFILEs, password files and Data Guard Broker configuration files.
