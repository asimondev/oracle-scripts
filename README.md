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


