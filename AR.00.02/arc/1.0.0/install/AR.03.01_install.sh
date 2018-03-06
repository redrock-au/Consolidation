#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.00.02/arc/1.0.0/install/AR.03.01_install.sh 2379 2017-08-31 04:02:33Z svnuser $
# --------------------------------------------------------------
# Install script for AR.03.01 CRN Generator
#   Usage: AR.03.01_install.sh <apps_pwd> | tee AR.03.01_install.log
# --------------------------------------------------------------
CEMLI=AR.03.01

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
# none

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$ARC_TOP/import
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/affrmcus.lct $IMPORTDIR/XXARXTWMAI_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
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
