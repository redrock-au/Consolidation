#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.02/arc/1.0.0/install/AR.00.01_install.sh 1607 2017-07-10 01:20:42Z svnuser $
# --------------------------------------------------------------
# Install script for AR.00.01 AR Customer Inbound Interface
#   Usage: AR.00.01_install.sh apps_pwd | tee AR.00.01_install.log
# --------------------------------------------------------------
CEMLI=AR.00.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh <apps_pwd> | tee AR.00.01_install.log"
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
  @./sql/XXAR_CUSTOMER_CONVERSION_STG_DDL.sql
  @./sql/XXAR_CUSTOMER_CONVERSION_TFM_DDL.sql
  @./sql/XXAR_CUST_CONV_RECCORD_ID_S_DDL.sql
  @./sql/XXAR_CUSTOMER_CONVERSION_PKG.pks
  show errors
  @./sql/XXAR_CUSTOMER_CONVERSION_PKG.pkb
  show errors
  EXIT
EOF
fi

# Application Setup
if [ "$TIER_DB" = "YES" ]
then
   FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARCUSTCV_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
   FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $ARC_TOP/import/XXARCUSTCVRQG_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0