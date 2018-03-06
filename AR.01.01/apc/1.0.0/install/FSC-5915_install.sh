#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/apc/1.0.0/install/FSC-5915_install.sh 3078 2017-11-29 23:44:15Z svnuser $
# --------------------------------------------------------------
# Install script for AP.02.02 Supplier Outbound Interface
#   Usage: FSC-5915_install.sh <apps_pwd> | tee FSC-5915_install.log
# --------------------------------------------------------------
CEMLI=AP.02.02

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-5915_install.sh <apps_pwd> | tee FSC-5915_install.log"
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
