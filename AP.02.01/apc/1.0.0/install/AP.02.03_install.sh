#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.01/apc/1.0.0/install/AP.02.03_install.sh 1781 2017-07-14 05:29:33Z svnuser $
# --------------------------------------------------------------
# Install script for AP.02.03 Payment Outbound Interface
#   Usage: AP.02.03_install.sh <apps_pwd> | tee AP.02.03_install.log
# --------------------------------------------------------------
CEMLI=AP.02.03

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
  @./sql/XXAP_PAYMENT_OUT_INT_PKG.pks
  show errors
  @./sql/XXAP_PAYMENT_OUT_INT_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$APC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXAP_PAYMENT_OUT_INT.ldt -
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
