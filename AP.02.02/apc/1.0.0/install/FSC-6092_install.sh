#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.02/apc/1.0.0/install/FSC-6092_install.sh 3162 2017-12-11 04:11:23Z dart $
# --------------------------------------------------------------
# Install script for AP.02.02 Supplier Outbound Interface
#   Usage: FSC-6092_install.sh <apps_pwd> | tee FSC-6092_install.log
# --------------------------------------------------------------
CEMLI=AP.02.02

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6092_install.sh <apps_pwd>"
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

echo "Installing $CEMLI (FSC-6092)"
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
  @./sql/XXAP_SUPPLIER_OUT_INT_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
