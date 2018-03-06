#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/FSC-5983_install.sh 3066 2017-11-28 06:24:56Z svnuser $
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
  @./sql/XXAR_INVOICES_INTERFACE_PKG.pkb
  show errors
  EXIT
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
