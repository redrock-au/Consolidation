#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/apc/1.0.0/install/FSC-5907_install.sh 2937 2017-11-10 03:18:01Z dart $
# --------------------------------------------------------------
# Install script for AP.03.01 Receivable Transactions Interface
#   Usage: AP.03.01_install.sh apps_pwd | tee AP.03.01_install.log
# --------------------------------------------------------------
CEMLI=AP.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AP.03.01_install.log"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# = 1 ]
then
  APPSPWD=$1
else
  usage
fi

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"


APPSLOGIN=APPS/$APPSPWD

if [ $TIER_DB = YES ]
then
# --------------------------------------------------------------
# Database objects Views and Packages
# --------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAP_KOFAX_INTEGRATION_PKG.pkb
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
