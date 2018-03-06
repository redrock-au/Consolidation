#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/apc/1.0.0/install/AP.03.02_install.sh 1262 2017-06-26 23:43:06Z svnuser $
# --------------------------------------------------------------
# Install script for AP.03.02 Kofax Pay On Receipt (ERS)
#   Usage: AP.03.02_install.sh apps_pwd | tee AP.03.02_install.log
# --------------------------------------------------------------
CEMLI=AP.03.02
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AP.03.02_install.log"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# -eq 1 ]
then
  APPSPWD=$1
else
  usage
fi

APPSLOGIN=APPS/$APPSPWD

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

if [ $TIER_DB = YES ] 
then
# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF 
  @./sql/DOT_PO_PAY_ON_RECEIPT_PKG.pkb
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
# none

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
