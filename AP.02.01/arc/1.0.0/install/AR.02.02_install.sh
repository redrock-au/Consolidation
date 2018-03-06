#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/AR.02.02_install.sh 1427 2017-07-04 07:19:13Z svnuser $
# --------------------------------------------------------------
# Install script for AR.02.02 AR Customer Inbound Interface
#   Usage: AR.02.02_install.sh apps_pwd | tee AR.02.02_install.log
# --------------------------------------------------------------
CEMLI=AR.02.02

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AR.02.02_install.log"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# = 1 ]
then
  APPSPWD=$1
else
  usage
fi

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"


APPSLOGIN=APPS/$APPSPWD

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  $ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAR_CUSTOMER_INTERFACE_STG_DDL.sql
  @./sql/XXAR_CUSTOMER_INTERFACE_TFM_DDL.sql
  @./sql/XXAR_CUSTOMER_INT_RECORD_ID_S_DDL.sql
  @./sql/XXAR_CUSTOMER_INTERFACE_PKG.pks
  show errors
  @./sql/XXAR_CUSTOMER_INTERFACE_PKG.pkb
  show errors
  EXIT
EOF
fi

# Application Setup
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$ARC_TOP/import
  FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARCUSTIMPT_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXARCUSTIMPTRQG_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

# --------------------------------------------------------------
# OA HTML
# --------------------------------------------------------------
# Copy java Files
# Controllers

#VO/AM 

#Pages / Regions


#Compile java Files 


#Import Pages and Regions


#Import Personalization

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0