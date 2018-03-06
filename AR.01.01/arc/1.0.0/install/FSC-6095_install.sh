#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/FSC-6095_install.sh 3175 2017-12-12 06:02:30Z dart $
# --------------------------------------------------------------
# Install script for AR.01.01 Receivable Transactions Interface
#   Usage: FSC-6095_install.sh <apps_pwd> | tee FSC-6095_install.log
#   Re-apply changes arellanod 2017/12/12 1.0
# --------------------------------------------------------------
CEMLI=AR.01.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6095_install.sh <apps_pwd>"
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

APPSLOGIN=apps/$APPSPWD

echo "Installing $CEMLI (FSC-6095)"
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
  @./sql/XXAR_PRINT_INVOICES_V.sql
  show errors
  @./sql/XXAR_PRINT_INVOICES_PKG.pkb
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
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXARINVPSREM_CP.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
