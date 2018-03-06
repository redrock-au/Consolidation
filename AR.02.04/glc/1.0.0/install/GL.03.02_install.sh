#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.04/glc/1.0.0/install/GL.03.02_install.sh 2108 2017-08-10 08:21:57Z svnuser $
# --------------------------------------------------------------
# Install script for GL.03.02 GL Chart of Accounts Extract
#   Usage: GL.03.02_install.sh <apps_pwd> | tee GL.03.02_install.log
# --------------------------------------------------------------
CEMLI=GL.03.02

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
  @./sql/XXGL_COA_EXTRACT_PKG.pks
  show errors
  @./sql/XXGL_COA_EXTRACT_PKG.pkb
  show errors
  EXIT
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$GLC_TOP/import
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGLCOACMS_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGLCOAXALL_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXGLCOAXPAR_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXGLREQGRP_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $IMPORTDIR/XXGLCOALDFF_CFG.ldt -
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
