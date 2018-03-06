#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.01/fndc/1.0.0/install/FND.03.01_install.sh 2241 2017-08-22 06:05:14Z svnuser $
# --------------------------------------------------------------
# Install script for FND.03.01 Interface Framework Common Program Routines
#   Usage: FND.03.01_install.sh <apps_pwd> | tee FND.03.01_install.log
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
  @./sql/XXFND_GENERIC_PKG.pks
  show errors
  @./sql/XXFND_GENERIC_PKG.pkb
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
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXFNDEMAILUPD.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXSYSADMINREPORTS_RG.ldt -
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
