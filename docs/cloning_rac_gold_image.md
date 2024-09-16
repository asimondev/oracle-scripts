# RAC Out-Of-Place Cloning and Patching.

At first you have do download the the files from GitHub repository: [Oracle Database Scripts](https://github.com/asimondev/oracle-scripts). Usually you would download the latest release 
on left side of this page. The downloaded TAR file can be copied to the database servers. In 
this example all scripts are unpacked in the directory */home/oracle/oracle_scripts*.

This example uses 2 nodes RAC (rkol7rac1a and rkol7rac1b). The Grid Infrastructure 
was already patched to 19.24. The database software runs Oracle 19.18.

```
oracle@rkol7rac1a> opatch lspatches
34786990;OJVM RELEASE UPDATE: 19.18.0.0.230117 (34786990)
34768559;OCW RELEASE UPDATE 19.18.0.0.0 (34768559)
34765931;DATABASE RELEASE UPDATE : 19.18.0.0.230117 (REL-JAN230131) (34765931)

OPatch succeeded.
```

## Creating a gold image for the existing ORACLE_HOME.

After setting the Oracle environment the gold image will be created in the 
directory */u01/oracle/images*.

```
oracle@rkol7rac1a> mkdir /u01/oracle/images

oracle@rkol7rac1a> ls -l /u01/oracle/images
total 0

oracle@rkol7rac1a> cd $ORACLE_HOME
oracle@rkol7rac1a> ./runInstaller -silent -createGoldImage -destinationLocation /u01/oracle/images
Launching Oracle Database Setup Wizard...

Successfully Setup Software.
Gold Image location: /u01/oracle/images/db_home_2024-09-14_09-24-48PM.zip
```

We can noch rename this gold image.
```
oracle@rkol7rac1a> cd /u01/oracle/images
oracle@rkol7rac1a> ls -lh *
-rw-r--r-- 1 oracle oinstall 4,4G 14. Sep 21:30 db_home_2024-09-14_09-24-48PM.zip

oracle@rkol7rac1a> mv db_home_2024-09-14_09-24-48PM.zip rac_19.18.zip

oracle@rkol7rac1a> ls 
rac_19.18.zip
```

## Creating a new ORACLE_HOME using the gold image.

### Creating installation environment files.

At first we have to create the installation files for the new ORACLE_HOME.

```
oracle@rkol7rac1a> cd ~/env

oracle@rkol7rac1a> cat inst_rac19b 
#!/bin/bash

export LANG=en_US.UTF-8

export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/rac19b
export TMP=/tmp
export TMPDIR=/tmp
umask 022

oracle@rkol7rac1a> cat rac19b
#!/bin/bash

export LANG=en_US.UTF-8

export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/rac19b
export ORACLE_SID=cdba011

export NLS_LANG=american_america.al32utf8

export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export ORACLE_PATH=~/sql:.
export SQLPATH=~/sql:.
export VISUAL=/bin/vi

export oh=$ORACLE_HOME

oracle@rkol7rac1a> 

oracle@rkol7db1> chmod 755 *rac19b

oracle@rkol7rac1a> ls -l *rac19b
-rwxr-xr-x 1 oracle oinstall 153 14. Sep 21:36 inst_rac19b
-rwxr-xr-x 1 oracle oinstall 366 14. Sep 21:36 rac19b
```

We can copy these files to the second node as well.
```
oracle@rkol7rac1a> scp *rac19b rkol7rac1b:$PWD
inst_rac19b                                   100%  153   201.1KB/s   00:00    
rac19b                                        100%  366   625.0KB/s   00:00    
oracle@rkol7rac1a> 
```

### Checking UNIX groups.

The current UNIX groups for the *oracle* user are:
```
oracle@rkol7rac1a> id
uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),10002(asmdba),54322(dba),54323(oper),54324(backupdba),54325(dgdba),54326(kmdba),54330(racdba)
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
environment file for the new ORACLE_HOME. The default UNIX groups will be used. The 
installation will be done on the local RAC node only.

```
oracle@rkol7rac1a> pwd
/home/oracle/oracle_scripts

oracle@rkol7rac1a> cd install_db19c/
oracle@rkol7rac1a> 

oracle@rkol7rac1a> ./install_base.sh -h
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

oracle@rkol7rac1a> ./install_base.sh -e ~/env/inst_rac19b -i /u01/oracle/images/rac_19.18.zip -r -l
...
As a root user, execute the following script(s):
	1. /u01/oracle/rac19b/root.sh

Execute /u01/oracle/rac19b/root.sh on the following nodes: 
[rkol7rac1a]
...
Successfully Setup Software with warning(s).
...
```

Now we have to run *root.sh* script as root user on this node.

```
[root@rkol7rac1a db19]# /u01/oracle/rac19b/root.sh
Check /u01/oracle/rac19b/install/root_rkol7rac1a.nichtsimon.de_2024-09-14_21-55-28-686258780.log for the output of root script
[root@rkol7rac1a db19]# 
```

## Patching the new ORACLE_HOME to 19.24.

In this example will install 19.24 DB RU and 19.24 OJVM. 

### OPatch installation.

At first we will set the new environment and replace *opatch* with the new version.
```
oracle@rkol7rac1a> . ~/env/rac19b

oracle@rkol7rac1a> cd $ORACLE_HOME

oracle@rkol7rac1a> unzip -o /home/oracle/patches/2024-07/p6880880_190000_Linux-x86-64.zip 
```

### DB RU 19.24 installation.

Because of RAC we will use GI RU 19.24 to install both database and OCW release update.

At first we will unpack the GI RU 19.24 in the new */u01/oracle/patches/gi_ru_2024_07* directory.

```
oracle@rkol7rac1a> mkdir /u01/oracle/patches/gi_ru_2024_07
oracle@rkol7rac1a> cd /u01/oracle/patches/gi_ru_2024_07

oracle@rkol7rac1a> unzip /home/oracle/patches/2024-07/p36582629_190000_Linux-x86-64.zip
...
oracle@rkol7rac1a> ls -ld /u01/oracle/patches/gi_ru_2024_07/*
drwxr-x--- 8 oracle oinstall    4096 13. Jul  23:20 /u01/oracle/patches/gi_ru_2024_07/36582629
-rw-rw-r-- 1 oracle oinstall 2470333 16. Jul  13:34 /u01/oracle/patches/gi_ru_2024_07/PatchSearch.xml
```

We are ready to patch this new ORACLE_HOME as *root* user.

```
[root@rkol7rac1a ~]# export PATH=/u01/oracle/rac19b/OPatch:$PATH

[root@rkol7rac1a ~]# which opatchauto
/u01/oracle/rac19b/OPatch/opatchauto

[root@rkol7rac1a ~]# cd /u01/oracle/patches/gi_ru_2024_07/36582629

[root@rkol7rac1a 36582629]# opatchauto apply /u01/oracle/patches/gi_ru_2024_07/36582629 -oh /u01/oracle/rac19b
...
--------------------------------Summary--------------------------------

Patching is completed successfully. Please find the summary as follows:

Host:rkol7rac1a
RAC Home:/u01/oracle/rac19b
Version:19.0.0.0.0
Summary:

==Following patches were SKIPPED:

Patch: /u01/oracle/patches/gi_ru_2024_07/36582629/36590554
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /u01/oracle/patches/gi_ru_2024_07/36582629/36758186
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /u01/oracle/patches/gi_ru_2024_07/36582629/36648174
Reason: This patch is not applicable to this specified target type - "rac_database"


==Following patches were SUCCESSFULLY applied:

Patch: /u01/oracle/patches/gi_ru_2024_07/36582629/36582781
Log: /u01/oracle/rac19b/cfgtoollogs/opatchauto/core/opatch/opatch2024-09-14_22-10-37PM_1.log

Patch: /u01/oracle/patches/gi_ru_2024_07/36582629/36587798
Log: /u01/oracle/rac19b/cfgtoollogs/opatchauto/core/opatch/opatch2024-09-14_22-10-37PM_1.log
```

### OJVM 12.24 installation.

```
oracle@rkol7rac1a> mkdir /u01/oracle/patches/ojvm_2024_07
oracle@rkol7rac1a> cd /u01/oracle/patches/ojvm_2024_07

oracle@rkol7rac1a> unzip  /home/oracle/patches/2024-07/p36414915_190000_Linux-x86-64.zip 
...
oracle@rkol7rac1a> cd 36414915/

oracle@rkol7rac1a> . ~/env/rac19b
oracle@rkol7rac1a> 

oracle@rkol7rac1a> $ORACLE_HOME/OPatch/opatch apply -local
...
Patching component oracle.javavm.client, 19.0.0.0.0...
Patch 36414915 successfully applied.
...
```

The local node *rkol7rac1a* is patched. 

## Creating a new gold image of 19.24 ORACLE_HOME.

At first we should check the installed patches in this ORACLE_HOME. All patches should be from 
19.24 DB RU.

```
oracle@rkol7rac1a> $ORACLE_HOME/OPatch/opatch lspatches
36414915;OJVM RELEASE UPDATE: 19.24.0.0.240716 (36414915)
36587798;OCW RELEASE UPDATE 19.24.0.0.0 (36587798)
36582781;Database Release Update : 19.24.0.0.240716 (36582781)

OPatch succeeded.
```

All required patches are installed in this ORACLE_HOME. So we can create a new gold image 
from it.

```
oracle@rkol7rac1a> cd $ORACLE_HOME
oracle@rkol7rac1a> ./runInstaller -silent -createGoldImage -destinationLocation /u01/oracle/images
Launching Oracle Database Setup Wizard...

Successfully Setup Software.
Gold Image location: /u01/oracle/images/db_home_2024-09-14_10-27-06PM.zip

oracle@rkol7rac1a> cd /u01/oracle/images/

oracle@rkol7rac1a> ls -lh
total 11G
-rw-r--r-- 1 oracle oinstall 5,9G 14. Sep 22:34 db_home_2024-09-14_10-27-06PM.zip
-rw-r--r-- 1 oracle oinstall 4,4G 14. Sep 21:30 rac_19.18.zip

oracle@rkol7rac1a> mv db_home_2024-09-14_10-27-06PM.zip rac_19.24.zip
oracle@rkol7rac1a> 

oracle@rkol7rac1a> ls
rac_19.18.zip  rac_19.24.zip
```

We can use this new 19.24 gold image *rac_19.24.zip* for new installations on the 
same or other servers.


### Deleting the local ORACLE_HOME.

The current 19.24 installation was done for creating a new gold image. We don't need this
local ORACLE_HOME any more. So have to deinstall it.

```
oracle@rkol7rac1a> . ~/env/rac19b

oracle@rkol7rac1a> $ORACLE_HOME/deinstall/deinstall
...
```

### Creating a new ORACLE_HOME using the new 19.24 gold image.

```
oracle@rkol7rac1a> cd oracle_scripts/
oracle@rkol7rac1a> cd install_db19c/

racle@rkol7rac1a> pwd
/home/oracle/oracle_scripts/install_db19c

oracle@rkol7rac1a> ./install_base.sh -e ~/env/inst_rac19b -i /u01/oracle/images/rac_19.24.zip -r 
...
As a root user, execute the following script(s):
	1. /u01/oracle/rac19b/root.sh

Execute /u01/oracle/rac19b/root.sh on the following nodes: 
[rkol7rac1a, rkol7rac1b]


Successfully Setup Software with warning(s).
...
```

We have to run *root.sh* script as *root* user on both nodes:

First node:
```
[root@rkol7rac1a ~]# /u01/oracle/rac19b/root.sh
Check /u01/oracle/rac19b/install/root_rkol7rac1a.nichtsimon.de_2024-09-14_22-50-16-972996116.log for the output of root script
[root@rkol7rac1a ~]# 
```

Second node:
```
root@rkol7rac1b db19]# /u01/oracle/rac19b/root.sh
Check /u01/oracle/rac19b/install/root_rkol7rac1b.nichtsimon.de_2024-09-14_22-51-11-215523949.log for the output of root script
[root@rkol7rac1b db19]# 
```

We can re-check the installed patches:
```
oracle@rkol7rac1a> . ~/env/rac19b

oracle@rkol7rac1a> $ORACLE_HOME/OPatch/opatch lspatches
36414915;OJVM RELEASE UPDATE: 19.24.0.0.240716 (36414915)
36587798;OCW RELEASE UPDATE 19.24.0.0.0 (36587798)
36582781;Database Release Update : 19.24.0.0.240716 (36582781)

OPatch succeeded.
```

### Further steps.

* You have to copy the network files from the old *$ORACLE_HOME/network/admin* to the 
new directory. 
 * If the different nodes have different network files, you have to copy these
files from the corresponding node.
 * Some network files contain the current ORACLE_HOME. In this case you would have to 
modify such files to specify the new ORACLE_HOME.

