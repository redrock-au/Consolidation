#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.03.01/arc/1.0.0/install/AR.02.03_install.sh 2558 2017-09-19 04:46:44Z svnuser $
# --------------------------------------------------------------
# Install script for AR.02.03 AR Receipts Inbound Interface
#   Usage: AR.02.03_install.sh <apps_pwd> | tee AR.02.03_install.log
# --------------------------------------------------------------
CEMLI=AR.02.03

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh <apps_pwd>"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# == 1 ]
then
  APPSLOGIN=apps/$1
else
  usage
fi

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAR_RECEIPTS_INTERFACE_STG.sql
  @./sql/XXAR_RECEIPTS_INTERFACE_TFM.sql
  @./sql/XXAR_RECEIPTS_RECORD_ID_S.sql
  @./sql/XXAR_RECALL_INTERFACE_HDR_STG.sql
  @./sql/XXAR_RECALL_INTERFACE_STG.sql
  @./sql/XXAR_RECEIPT_INTERFACE_PKG.pks
  show errors
  @./sql/XXAR_RECEIPT_INTERFACE_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$ARC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARRECINT.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARRECINTACK.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/Receivables_All_RG.ldt -
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
