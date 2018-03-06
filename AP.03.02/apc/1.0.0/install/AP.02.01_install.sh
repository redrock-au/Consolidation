#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.02/apc/1.0.0/install/AP.02.01_install.sh 1071 2017-06-21 05:16:54Z svnuser $
# --------------------------------------------------------------
# Install script for AP.02.01 Payables Invoice Interface
#   Usage: AP.02.01_install.sh <apps_pwd> | tee AP.02.01_install.log
# --------------------------------------------------------------
CEMLI=AP.02.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: ${CEMLI}_install.sh <apps_pwd>"
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
  @./sql/XXAP_INVOICES_INTERFACE_STG.sql
  @./sql/XXAP_INVOICES_INTERFACE_TFM.sql
  @./sql/XXAP_INVOICES_RECORD_ID_S.sql
  @./sql/XXAP_INVOICE_INTERFACE_PKG.pks
  show errors
  @./sql/XXAP_INVOICE_INTERFACE_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$APC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXAPINVINT.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/DOT_ALL_REPORTS_AP.ldt -
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
