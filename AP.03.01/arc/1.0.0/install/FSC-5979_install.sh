#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/FSC-5979_install.sh 2960 2017-11-13 23:18:47Z svnuser $
# --------------------------------------------------------------
# Install script for AR.01.01 Receivable Transactions Interface
#   Usage: AR.01.01_install.sh <apps_pwd> | tee AR.01.01_install.log
# --------------------------------------------------------------
CEMLI=AR.01.01

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

APPSLOGIN=apps/$APPSPWD

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------


# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------


echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0

