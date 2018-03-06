#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.03/fndc/1.0.0/install/FSC-5981_install.sh 2985 2017-11-15 02:52:12Z svnuser $
# --------------------------------------------------------------
# Install script for FND.03.01 Interface Framework Common Program Routines
#   Usage: FSC-5981_install.sh <apps_pwd> | tee FND.03.01_install.log
# --------------------------------------------------------------
CEMLI=FND.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh <apps_pwd>"
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

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
$ORACLE_HOME/bin/sqlplus -s APPS/$APPSPWD <<EOF
  SET DEFINE OFF
  @./sql/XXFND_GENERIC_PKG.pkb
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
#none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
