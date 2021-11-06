# Oracle Database Scripts  

## Installation scripts  

### Gold images (19c)  

#### Creating gold images

After installing and patchting a new ORACLE_HOME you could create a gold image from it. Usually you would do it before placing any files into $ORACLE_HOME/dbs or $ORACLE_HOME/network/admin directories.

    cd $ORACLE_HOME
    ./runInstaller -silent -createGoldImage -destinationLocation DirectoryName


#### Using gold images

You can use both base image and custom gold image to install using **install_base.sh** script. Script parameters:  

    Usage: install_base.sh [-f BaseResponseFile -g Groups -e EnvFile -i GoldImage -v OracleInventoryPath -r -p -h] 
      -e: file with environment variables ORACLE_BASE, ORACLE_HOME, PATH  
      -f: base response file (default: base_install_db19c.rsp for single instance)
      -g : groups {default | oinstall_dba | dba}
      -h: print usage
      -i: gold image for 19c installations (default: base 19c)
      -p: do not ignore prereq failures (default: -ignorePrereqFailure)
      -r: RAC 
      -v: Oracle Inventory path (default: inventory_loc from /etc/oraInst.loc)

Oracle installation needs some base environment variables. You can set them on your own or provide a scripts, which will be executed during before installation. Here is an example:  

    cat ~/env/inst_db19a
    #!/bin/bash

    export ORACLE_BASE=/u01/oracle
    export ORACLE_HOME=$ORACLE_BASE/db19a
    export TMP=/tmp
    export TMPDIR=/tmp
    umask 022

The recommended way is to use different groups for oracle user. But some DBAs prefer to use oinstall & dba or just dba group. Use the option **-g** in such a case. If you have some specific groups, you should choose *custom* group option and modify this **install_base.sh** script.

The first Oracle database installation on the server does not have */etc/oraInst.loc* file. In this case you should use **-v** option to set the Oracle Inventory directory.


#### Examples

Before first installation you shoud check the user's group:

    oracle@rkol7db2> id 
    uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),54322(dba),54323(oper),54324(backupdba),54325(dgdba),54326(kmdba),54330(racdba)

So this user can install using the default group option. 

The ORACLE environment variables could be set either before starting the script or in the source file (*inst_db19a*):

```
oracle@rkol7db2> cat ~/env/inst_db19a
#!/bin/bash
export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/db19a
export TMP=/tmp
export TMPDIR=/tmp
umask 022
```

##### Base Release  

The base release zip file can be used as gold image for the first installation. So the installation of base release could be down with using the provided script with environment variables:

    ./install_base.sh -e ~/env/inst_db19a -i /stage/Oracle/db19c/LINUX.X64_193000_db_home.zip

Check for the message *Successfully Setup Software with warning(s).* and run *root.sh* script as root user.

##### Creating New Gold Image

After installing required patches the ORACLE_HOME you can use it as a new gold image. You have to set the Oracle environment and run the following steps:  

    mkdir /u01/oracle/images
    cd $ORACLE_HOME
    ./runInstaller -silent -createGoldImage -destinationLocation /u01/oracle/images
    Launching Oracle Database Setup Wizard...

    Successfully Setup Software.
    Gold Image location: /u01/oracle/images/db_home_2021-11-06_08-49-45AM.zip

Usually you would rename the gold image after that:

    cd /u01/oracle/images
    mv db_home_2021-11-06_08-49-45AM.zip db19.12_ru2021jul.zip

This gold image can now be used on the same or other servers for new installation.

##### Using Existing Gold Image

Before using the gold image you have to check the user's groups and environment variables (see above). After that you can use the existing image for the new installation:


    ./install_base.sh -e ~/env/inst_db19b -i /stage/Oracle/db19c/images/db19.12_ru2021jul.zip

Do not forget to run *root.sh* script as root node on every node!

##### Exadata

Default Exadata RDBMS installation puts some cluster specific scripts (cluster nodes, ASM disk group names) into the *$ORACLE_HOME/assistants/dbca/templates* directory. If you use the gold image from another node, you usually would copy this directory from the existing one to the new created ORACLE_HOME:

    cd $ORACLE_HOME/assistants/dbca/templates
    cp /u01/app/oracle/product/19.0.0.0/dbhome_1/assistants/dbca/templates/* .

Usually you would like to copy these files to all other cluster nodes as well:

    for host in ... ; do
    scp * $host:$PWD
    done
