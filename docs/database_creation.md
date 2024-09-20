# Database Creation With create_db.sh Script.

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

## create_db.sh Script Description.

The script **create_db.sh** is located in *create_db19* directory. This script uses 
Oracle *DBCA* tool for creating a new database. The script provides different response 
files and database templates depending on the option. *create_db.sh*
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

## Examples

### Single Instance non-CDB Database.

    ./create_db.sh -d mydb -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra  

This will create a mydb database with the database unique name *mydb_dc1*. The domain parameter is empty. The environment file *~/env/db19a* contains Oracle environment variables (ORACLE_BASE, ORACLE_HOME, NLS_LANG, PATH, LD_LIBRARY_PATH etc). This database does not use ASM. Datafiles will be placed using OMF in the default directory */u01/oracle/databases/19c*. FRA is */u01/oracle/databases/fra* and it's max size is *5000* MB.

If you want to specify a domain name, you have to add it to the database name option **-d**.

    ./create_db.sh -d mydb.world.com -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra  

### Single Instance CDB Database.

Use **-c** option to create a CDB database:

    ./create_db.sh -c -d mydb.world.com -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra -g /u01/oracle/databases

This will create a CDB database *mydb.world.com* with the unique name *mydb_dc1*. The database uses OMF and the files will be placed into the directory */u01/oracle/databases*.


### CDB RAC Database.

Use **-r** and **-c** options to create a CDB RAC database.

    ./create_db.sh -c -r -d mydb.world.com -u mydb_ffm -e ~/env/rac19a  -f fra -g data -z 1000 

This will create a new CDB RAC database with database name **mydb**, domain name **world.com** and database unique name **mydb_ffm**. The database files will be located into the ASM disk groups DATA and FRA.

### CDB RAC Database On a Subset of Cluster Nodes.

Sometimes you don't want to create RAC database instances on all cluster nodes. In such a 
case you can specify the node names using **-n** option. Say, you have a RAC cluster with 
4 nodes: rac1, rac2, rac3 and rac4.

    ./create_db.sh -c -r -d mydb.world.com -u mydb_ffm -e ~/env/rac19a -n rac1,rac2 -f fra -g data -z 1000 

This command will create a new CDB RAC database on the cluster nodes *rac1* and *rac2* only.

### CDB RAC database With Specific Character Set.

Use **-r** and **-c** options to create a CDB RAC database.

    ./create_db.sh -c -r -d mydb.world.com -u mydb_ffm -e ~/env/rac19a  -f fra -g data -z 1000 -s WE8ISO8859P1

This will create a new CDB RAC database with database name **mydb**, domain name **world.com** and database unique name **mydb_ffm**. The database files will be located into the ASM diskgroups DATA and FRA. The database will use the **WE8ISO8859P1** character set.

### Single Instance CDB Database With Non-default Database Block Size.

The default template type uses *$ORACLE_HOME/assistants/dbca/templates/General_Purpose.dbc* 
DBCA template. This template restores database files with 8KB database block size. If you
want to specify different block size, you have to use both the init.ora parameter 
(**-i** option) and the database template type parameter (**-t** option). The *custom* 
template type uses the *$ORACLE_HOME/assistants/dbca/templates/New_Database.dbt* 
DBCA template, which creates a new database running all catalog scripts.

    ./create_db.sh -c -d mydb.world.com -u mydb_dc1 -e ~/env/db19a -z 5000 -f /u01/oracle/databases/fra -g /u01/oracle/databases -i db_block_size=16384 -t custom

### Single Instance CDB Database With Specific DBCA Option(s). 

**create_db.sh** script can't provide all *DBCA* options. Sometimes you would like to 
use a specific option. In this case you should use **-a** option. For instance, you 
would like to prevent installing some database options on the new database. In this case
you need to use the *DBCA* option *-dbOpions*.

```
./create_db.sh -d mydb.world.com -t custom -e ~/env/db19c -f /u01/oracle/databases/fra -g /u01/oracle/databases/db19 -z 1000 -a '-dbOptions "DV:false,OLS:false,APEX:false,ORACLE_TEXT:false,OMS:false,CWMLITE:false"'
```

If you want to disable some database options you have to use the **-t custom** option of 
**create_db.sh** script. In this example, the following database options will not be 
installed:
- Oracle Label Security (OLS)
- Database Vault (DV)
- APEX
- Oracle Text
- Oracle Management Server (OMS)
- Oracle OLAP (CWMLITE)

### Troubleshooting.

Sometimes you would like to check the *DBCA* command and *DBCA* response file before 
creating a new database. In this case you should use the option **-j** (just print). The
script **create_db.sh** will prepare execution, print out the response file and the 
*DBCA* command and exit.

## How to delete a database using DBCA?

You can delete a database using DBCA from the command line. The database must be
up and running and you have to know the *SYS* database user password. The *-silent*
option will run the *dbca* command immediately.

### Single instance database:

`dbca -silent -deleteDatabase -sourceDB mydb -sysDBAUserName sys -sysDBAPassword oracle`

This command will delete the database with the $ORACLE_SID *mydb* using the *SYS* user with the password *oracle*.

### RAC database:

Please use the value of DB_UNIQUE_NAME parameter instead of $ORACLE_SID.

`dbca -silent -deleteDatabase -sourceDB mydb_primary -sysDBAUserName sys -sysDBAPassword oracle`

This command will delete the RAC database with the database unique 
name *mydb_primary*.
