#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/fndc/1.0.0/install/FSC-5916_install.sh 3143 2017-12-07 05:34:25Z svnuser $
# --------------------------------------------------------------
# Install script for INT.02.00 Interface Framework Common Program Routines
#   Usage: FSC-5916_install.sh <apps_pwd> | tee FSC-5916_install.log
# --------------------------------------------------------------
CEMLI=INT.02.00

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $JIRA_install.sh <apps_pwd>"
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
  @./sql/DOT_COMMON_INT_PKG.pkb
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$FNDC_TOP/import
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXFND_SEND_NOTIFICATION.ldt -
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
