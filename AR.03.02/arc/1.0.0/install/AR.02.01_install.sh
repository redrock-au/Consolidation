#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.03.02/arc/1.0.0/install/AR.02.01_install.sh 1270 2017-06-27 00:16:38Z svnuser $
# --------------------------------------------------------------
# Install script for AR.02.01 Receivable Transactions Interface
#   Usage: AR.02.01_install.sh <apps_pwd> | tee AR.02.01_install.log
# --------------------------------------------------------------
CEMLI=AR.02.01

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
  @./sql/XXAR_INVOICES_INTERFACE_SEQ_DDL.sql
  @./sql/XXAR_INVOICES_INTERFACE_STG_DDL.sql
  @./sql/XXAR_INVOICES_INTERFACE_TFM_DDL.sql
  @./sql/XXAR_INVOICE_OUT_INT_LOG_DDL.sql
  @./sql/XXAR_INVOICES_INTERFACE_PKG.pks
  show errors
  @./sql/XXAR_INVOICES_INTERFACE_PKG.pkb
  show errors
  @./sql/XXAR_INV_OUTBOUND_PKG.pks
  show errors
  @./sql/XXAR_INV_OUTBOUND_PKG.pkb
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
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARFERAXTRX_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXARALLREQGR_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARINVOUTINT_CP.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXARINVOUTINT_REQG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
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


