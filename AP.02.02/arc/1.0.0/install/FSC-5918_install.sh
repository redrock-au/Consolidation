#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.02/arc/1.0.0/install/FSC-5918_install.sh 2999 2017-11-17 04:36:48Z svnuser $
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
  @./sql/XXAR_RECEIPT_INTERFACE_PKG.pkb
  show errors
EOF
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
