#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.01.01/arc/1.0.0/install/AR.02.04_install.sh 1074 2017-06-21 05:34:42Z svnuser $
# --------------------------------------------------------------
# Install script for AR.02.04 Receivables Open Items
#   Usage: AR.02.04_install.sh <apps_pwd> | tee AR.02.04_install.log
# --------------------------------------------------------------
CEMLI=AR.02.04

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
  APPSPWD=$1
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
$ORACLE_HOME/bin/sqlplus -s APPS/$APPSPWD <<EOF
  SET DEFINE OFF
  @./sql/XXAR_OPEN_ITEMS_DISABLE_DML.sql
  @./sql/XXAR_OPEN_ITEMS_SEQ_DDL.sql
  @./sql/XXAR_OPEN_ITEMS_STG_DDL.sql
  @./sql/XXAR_OPEN_ITEMS_TFM_DDL.sql
  @./sql/XXAR_PAYMENT_NOTICES_B_DDL.sql
  @./sql/XXAR_PAYMENT_STATUS_V_DDL.sql
  @./sql/XXAR_RECEIPT_DETAILS_V_DDL.sql
  @./sql/XXAR_OPEN_ITEMS_INTERFACE_PKG.pks
  show errors
  @./sql/XXAR_OPEN_ITEMS_INTERFACE_PKG.pkb
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$ARC_TOP/import
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARITEMSIMP_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARXITEMS_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXARALLREQGR_CFG.ldt -
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
