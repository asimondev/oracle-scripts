# Installing And Cloning Of Database Homes

The script **install_db.sh** is located in *install_db19* directory.

In Oracle 19c the database software installation is based on software images. You 
always run the database installation using either the base 19c release image or your
own gold image. You can create a new gold image from the existing database installation 
(ORACLE_HOME) using the Oracle installer *runInstaller*.

## Creating a New Gold Image.

After installing and patchting a new ORACLE_HOME you could create a gold image from it. Usually you would do it before placing any files into $ORACLE_HOME/dbs or $ORACLE_HOME/network/admin directories.

    cd $ORACLE_HOME
    ./runInstaller -silent -createGoldImage -destinationLocation DirectoryName

## Using Installation Script install_base.sh.

You can use both base image and custom gold image to install using **install_base.sh** script. Script parameters are:  

    Usage: install_base.sh [-f BaseResponseFile -g Groups -e EnvFile -i GoldImage -v OracleInventoryPath -r -p -h] 
      -e: file with environment variables ORACLE_BASE, ORACLE_HOME, PATH  
      -f: base response file (default: base_install_db19c.rsp for single instance and base_install_rac19c.rsp for RAC)
      -g : groups {default | oinstall_dba | dba | custom}
      -h: print usage
      -i: gold image for 19c installations (default: base 19c)
      -p: do not ignore prereq failures (default: -ignorePrereqFailure)
      -r: RAC 
      -v: Oracle Inventory path (default: inventory_loc from /etc/oraInst.loc)


The first Oracle database installation on the server does not have */etc/oraInst.loc* file. In this case you should use **-v** option to set the Oracle Inventory directory.

## Environment Variables.

Oracle installation needs some base environment variables. You can set them on your own or provide a script, which will be executed during installation. Here is an example:  

    cat ~/env/inst_db19a
    #!/bin/bash

    export ORACLE_BASE=/u01/oracle
    export ORACLE_HOME=$ORACLE_BASE/db19a
    export TMP=/tmp
    export TMPDIR=/tmp
    umask 022


## Checking UNIX Groups.

You can check the current UNIX groups for the *oracle* with the following command.
```
oracle@rkol7rac1a> id
uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),10002(asmdba),54322(dba),54323(oper),54324(backupdba),54325(dgdba),54326(kmdba),54330(racdba)
```

If you are unsure about the used UNIX groups in the previous ORACLE_HOME installation, 
you should check them this way:

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

In this example these are the default groups, so that we can use default values 
( **-g default** option of **install_base.sh**). 

Some DBAs prefer to use *oinstall* and *dba* groups only or just *dba* group. You 
should use the option **-g oinstall_dba** or **-g dba** in such cases.

If you use some specific UNIX groups, you should use **-g custom** parameter of 
**install_base.sh** and modify this file. Please look for the Bash function 
**check_groups** and set your specific groups in this part of script:

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

## Examples.

### Base Release Oracle Database 19c.

The base release zip file can be used as gold image for the first installation. So the installation of the base release could be done using the provided script with the
environment variables:

    ./install_base.sh -e ~/env/inst_db19a -i /stage/Oracle/db19c/LINUX.X64_193000_db_home.zip

Check for the message *Successfully Setup Software with warning(s).* and run *root.sh* script as root user.

You can use **-r** option to install the database software on all nodes in a RAC cluster:

    ./install_base.sh -r -e ~/env/inst_db19a -i /stage/Oracle/db19c/LINUX.X64_193000_db_home.zip

Do not forget to run *root.sh* script as root on the corresponding server(s).

### Using Existing Gold Image.

Before using the gold image you have to check the user's groups and environment variables (see above). After that you can use the existing image for the new installation:

    ./install_base.sh -e ~/env/inst_db19b -i /stage/Oracle/db19c/images/db19.12_ru2021jul.zip

Do not forget to run *root.sh* script as root on the corresponding server(s).

### Exadata.

Default Exadata RDBMS installation puts some cluster specific scripts (cluster nodes, ASM disk group names) into the *$ORACLE_HOME/assistants/dbca/templates* directory. If you use the gold image from another node, you usually would copy this directory from the existing one to the new created ORACLE_HOME:

    cd $ORACLE_HOME/assistants/dbca/templates
    cp /u01/app/oracle/product/19.0.0.0/dbhome_1/assistants/dbca/templates/* .

Usually you would like to copy these files to all other cluster nodes as well:

    for host in ... ; do
    scp * $host:$PWD
    done

## How to delete the existing ORACLE_HOME?

Please re-check, that the corresponding Oracle environment variables are set to the **old**
and not to the **current** ORACLE_HOME.

You can delete the existing ORACLE_HOME using the following command:

`$ORACLE_HOME/deinstall/deinstall`

## Further documentation.

[Cloning of database homes](https://github.com/asimondev/oracle-scripts/blob/master/docs/cloning.md)


