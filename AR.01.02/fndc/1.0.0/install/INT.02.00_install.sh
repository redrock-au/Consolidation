#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.02/fndc/1.0.0/install/INT.02.00_install.sh 2365 2017-08-30 05:13:46Z svnuser $
# --------------------------------------------------------------
# Install script for INT.02.00 Interface Framework Common Program Routines
#   Usage: INT.02.00_install.sh <apps_pwd> | tee INT.02.00_install.log
# --------------------------------------------------------------
CEMLI=INT.02.00

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
  @./sql/XXINT_INTERFACE_CTL_DDL.sql
  @../admin/sql/dot_common_int_alter_ddl.sql
  @./sql/DOT_COMMON_INT_PKG.pkb
  show errors
  @./sql/XXINT_FILE_UTIL.sql
  show errors
  @./sql/XXINT_COMMON_PKG.pks
  show errors
  @./sql/XXINT_COMMON_PKG.pkb
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
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXINTIFR_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXINTSQLLDR_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $IMPORTDIR/XXINTPATH_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $IMPORTDIR/XXINTPATHALL_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $IMPORTDIR/XXINT_DEFAULT_RETENTION_CFG.ldt -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/DOT_CMNINT_INT_ERR_RPT_XML.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/DOT_CMNINT_INT_RUN_RPT_XML.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/DOT_CMNINT_INT_RUN_PROCESS.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD APPS/$APPSPWD 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXINTARBATS_CFG.ldt -
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
chmod 775 $FNDC_TOP/bin/XXINTIFR.prog
chmod 775 $FNDC_TOP/bin/XXINTSQLLDR.prog
ln -s $FND_TOP/bin/fndcpesr $FNDC_TOP/bin/XXINTIFR
ln -s $FND_TOP/bin/fndcpesr $FNDC_TOP/bin/XXINTSQLLDR

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
