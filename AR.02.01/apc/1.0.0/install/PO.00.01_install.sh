#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.01/apc/1.0.0/install/PO.00.01_install.sh 2371 2017-08-31 01:11:38Z svnuser $
# --------------------------------------------------------------
# Install script for PO.00.01 Supplier Conversion
#   Usage: PO.00.01_install.sh <apps_pwd> | tee PO.00.01_install.log
# --------------------------------------------------------------
CEMLI=PO.00.01

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
  @./sql/XXAP_SUPPLIER_CONV_STG.sql
  @./sql/XXAP_SUPPLIER_CONV_TFM.sql
  @./sql/XXAP_SUPPLIER_CONV_RECORD_ID_S.sql
  @./sql/XXAP_SUPPLIER_CONV_PKG.pks
  show errors
  @./sql/XXAP_SUPPLIER_CONV_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$APC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXAPSUPCONV.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXAPSUPCONVUPD.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcprset.lct $IMPORTDIR/XXAP_SUPPLIER_CONV_SET.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/DOT_ALL_REPORTS_AP.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcprset.lct $IMPORTDIR/XXAP_SUPPLIER_CONV_SET_LNK.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
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
