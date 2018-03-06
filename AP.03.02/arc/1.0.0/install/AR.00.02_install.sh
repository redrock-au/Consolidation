#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.02/arc/1.0.0/install/AR.00.02_install.sh 1820 2017-07-18 00:18:19Z svnuser $
# --------------------------------------------------------------
# Install script for AR.00.01 AR Customer Inbound Interface
#   Usage: AR.00.02_install.sh apps_pwd | tee AR.00.01_install.log
# --------------------------------------------------------------
CEMLI=AR.00.02

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AR.00.01_install.log"
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
  @./sql/XXAR_OPEN_INVOICES_CONV_STG_DDL.sql
  @./sql/XXAR_OPEN_INVOICES_CONV_TFM_DDL.sql
  @./sql/XXAR_OPEN_INV_CONV_RECORD_ID_S_DDL.sql
  @./sql/XXAR_OPEN_INVOICES_CONV_PKG.pks
  show errors
  @./sql/XXAR_OPEN_INVOICES_CONV_PKG.pkb
  show errors
  EXIT
EOF
fi

# Application Setup
if [ "$TIER_DB" = "YES" ]
then
   FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVCONV_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
   FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $ARC_TOP/import/XXARINVCONVRQG_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
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