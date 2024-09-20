# Oracle Database Scripts  

Version: 1.0.6

This repository contains Bash scripts for installing Oracle database software and creating
a new database in silent mode. The scripts were tested on Oracle Linux only.

If you want to use these scripts you have to execute the following steps:

1. Click on the text labeled with *"Latest"* on the link side of this GitHub repository.
1. Download the *oracle_scripts.tar* file. This file contains Bash scripts and response files.
1. Copy this file to the target database server (for instance into the */tmp* directory). `scp oracle_scripts.tar ServerName:/tmp`
1. Create a new directory (for instance */home/oracle/oracle_scripts*") and unpack the *oracle_scripts.tar* file in this directory.
```
mkdir /home/oracle/oracle_scripts
cd /home/oracle/scripts
tar xvf /tmp/oracle_scripts.tar
```

The database software installation script *install_base.sh* is located in 
the *install_db19* directory. The database creation script *create_db.sh* is in the
*create_db19* directory. All scripts can be used both for the single instance and RAC. 

## Database Software Installation.

In Oracle 19c the database software installation is based on software images. You 
always run the database installation using either the base 19c release image or your
own gold image. You can create a new gold image from the existing database installation 
(ORACLE_HOME) using the Oracle installer *runInstaller*.

### Creating a New Gold Image.

After installing and patchting a new ORACLE_HOME you could create a gold image from it. Usually you would do it before placing any files into $ORACLE_HOME/dbs or $ORACLE_HOME/network/admin directories.

    cd $ORACLE_HOME
    ./runInstaller -silent -createGoldImage -destinationLocation DirectoryName

### Using Installation Script.

You can use both base image and custom gold image to install using **install_base.sh** script. Script parameters:  

    Usage: install_base.sh [-f BaseResponseFile -g Groups -e EnvFile -i GoldImage -v OracleInventoryPath -r -p -h] 
      -e: file with environment variables ORACLE_BASE, ORACLE_HOME, PATH  
      -f: base response file (default: base_install_db19c.rsp for single instance and base_install_rac19c.rsp for RAC)
      -g : groups {default | oinstall_dba | dba | custom}
      -h: print usage
      -i: gold image for 19c installations (default: base 19c)
      -p: do not ignore prereq failures (default: -ignorePrereqFailure)
      -r: RAC 
      -v: Oracle Inventory path (default: inventory_loc from /etc/oraInst.loc)

Oracle installation needs some base environment variables. You can set them on your own or provide a script, which will be executed during installation. Here is an example:  

    cat ~/env/inst_db19a
    #!/bin/bash

    export ORACLE_BASE=/u01/oracle
    export ORACLE_HOME=$ORACLE_BASE/db19a
    export TMP=/tmp
    export TMPDIR=/tmp
    umask 022

The recommended way is to use different groups for oracle user. But some DBAs prefer to use *oinstall* and *dba* groups only or just *dba* group. Use the option **-g** in such a case. 
If you have some specific groups, you should choose *custom* group option and modify 
the **install_base.sh** script on youself.

You can see your current UNIX groups using **id** LINUX command. If you want to clone the 
existing $ORACLE_HOME, you should check the file *$ORACLE_HOME/rdbms/lib/config.c* for the
used groups.

The first Oracle database installation on the server does not have */etc/oraInst.loc* file. In this case you should use **-v** option to set the Oracle Inventory directory.

### Examples.

#### Base Release Oracle Database 19c.

The base release zip file can be used as gold image for the first installation. So the installation of the base release could be set using the provided script with the
environment variables:

    ./install_base.sh -e ~/env/inst_db19a -i /stage/Oracle/db19c/LINUX.X64_193000_db_home.zip

Check for the message *Successfully Setup Software with warning(s).* and run *root.sh* script as root user.

You can use **-r** option to install the database software on all nodes in a RAC cluster:

    ./install_base.sh -r -e ~/env/inst_db19a -i /stage/Oracle/db19c/LINUX.X64_193000_db_home.zip

Do not forget to run *root.sh* script as root on the corresponding server(s).

#### Using Existing Gold Image.

Before using the gold image you have to check the user's groups and environment variables (see above). After that you can use the existing image for the new installation:


    ./install_base.sh -e ~/env/inst_db19b -i /stage/Oracle/db19c/images/db19.12_ru2021jul.zip

Do not forget to run *root.sh* script as root on the corresponding server(s).

### Further documentation.

[Installing and cloning of database homes](https://github.com/asimondev/oracle-scripts/blob/master/docs/installing_and_cloning.md)

## Database Creation.

Oracle *DBCA* tool needs some Oracle environment variables. You can set them on your own or provide a script, which will be executed before database creation. Here is an example:  

```
oracle@rkol7db1> cat ~/env/db19a
#!/bin/bash

export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/db19a
export ORACLE_SID=a01

export NLS_LANG=american_america.al32utf8

export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export ORACLE_PATH=~/sql:.
export SQLPATH=~/sql:.
export VISUAL=/bin/vi
oracle@rkol7db1> 

oracle@rkol7db1> chmod 755 ~/env/db19a
oracle@rkol7db1> 
```

### create_db.sh Script Description

The script **create_db.sh** uses Oracle *DBCA* tool for creating a new database. This script
uses different response files and database templates depending on the option. This script 
can be used for both single instance and RAC database. It also creates both non-CDB and
CDB databases.

Script parameters are:  

```
Usage: create_db.sh -d DbName [-u DbUniqueName -c -n RAC_Nodes -r -t DBType -e EnvFile -p Password -i InitParams -f FRA -g DATA -z FRASizeMB -s CharacterSet -a DBCA_Options -h -j]
  -a: Additional DBCA options for -createDatabase
  -c: CDB database (default: non-CDB database)
  -d: database name (DB_NAME.DB_DOMAIN)
  -e: file with environment variables ORACLE_BASE, ORACLE_HOME, PATH  
  -f: FRA ASM disk group or FRA directory (default RAC: FRA)
  -g: database directory or DATA ASM disk group (default: /u01/oracle/databases/19c; RAC: DATA)
  -h: print usage  
  -i: comma separated init.ora parameters 
  -j: print but do not execute the commands (just print)
  -n: RAC nodes
  -p: database password (default oracle)
  -r: RAC database
  -s: database character set (default: AL32UTF8)
  -t: database template type {default | custom | TemplatePath} (default: default)
  -u: database unique name (default: database name)
  -z: FRA size im MB (default: 25000)
```

### Examples

#### Single instance non CDB database.

    ./create_db.sh -d mydb -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra  

This will create a mydb database with the database unique name *mydb_dc1*. The domain parameter is empty. The environment file *~/env/db19a* contains Oracle environment variables (ORACLE_BASE, ORACLE_HOME, NLS_LANG, PATH, LD_LIBRARY_PATH etc). This database does not use ASM. Datafiles will be placed using OMF in the default directory */u01/oracle/databases/19c*. FRA is */u01/oracle/databases/fra* and it's max size is *5000* MB.

If you want to specify a domain name, you have to add it to the database name option **-d**.

    ./create_db.sh -d mydb.world.com -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra  

#### Single instance CDB database.

Use **-c** option to create a CDB database:

    ./create_db.sh -c -d mydb.world.com -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra -g /u01/oracle/databases

This will create a CDB database *mydb.world.com* with the unique name *mydb_dc1*. The database uses OMF and the files will be placed into the directory */u01/oracle/databases*.


#### Create a CDB RAC database.

Use **-r** and **-c** options to create a CDB RAC database.

    ./create_db.sh -c -r -d mydb.world.com -u mydb_ffm -e ~/env/rac19a  -f fra -g data -z 1000 

This will create a new CDB RAC database with database name **mydb**, domain name **world.com** and database unique name **mydb_ffm**. The database files will be located into the ASM disk groups DATA and FRA.

### Further documentation.

[Database creation](https://github.com/asimondev/oracle-scripts/blob/master/docs/database_creation.md)

