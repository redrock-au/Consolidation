#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.02/glc/1.0.0/install/GL.02.01_install.sh 1820 2017-07-18 00:18:19Z svnuser $
# --------------------------------------------------------------
# Install script for GL.02.01 CHRIS21 Payroll Accrual Interface
#   Usage: GL.02.01_install.sh <apps_pwd> | tee GL.02.01_install.log
# --------------------------------------------------------------
CEMLI=GL.02.01

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
  APPSLOGIN=apps/$1
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
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXGL_PAYROLL_HEADER_STG.sql
  @./sql/XXGL_PAYROLL_DETAIL_STG.sql
  @./sql/XXGL_PAYROLL_TRAILER_STG.sql
  @./sql/XXGL_PAYROLL_DETAIL_DEL.sql
  @./sql/XXGL_PAYROLL_DETAIL_TFM.sql
  @./sql/XXGL_PAYROLL_DETAIL_TMP.sql
  @./sql/XXGL_PAYROLL_RECORD_ID_S.sql
  @./sql/XXGL_RULE_PKG.pks
  show errors
  @./sql/XXGL_RULE_PKG.pkb
  show errors
  @./sql/XXGL_PAYROLL_PKG.pks
  show errors
  @./sql/XXGL_PAYROLL_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$GLC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $IMPORTDIR/FND_COMMON_LOOKUPS.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $IMPORTDIR/XXGL_RULE_PKG_SYNTAX.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/affrmcus.lct $IMPORTDIR/XXFND_FNDLVMCL.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGL_PAY_ACCR_INT.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGL_PAYROLL_INT.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/GL_CONCURRENT_PROGRAM_GROUP.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXGL_CHRIS_ACC_DEDJTR_GL_RULES.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXGL_CHRIS_DEDJTR_GL_RULES.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXGL_CHRIS_TSC_GL_RULES.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct $IMPORTDIR/XXGL_CHRIS_ACC_TSC_GL_RULES.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
fi

# --------------------------------------------------------------
# Data Fixes
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @../sql/XXGL_DEDJTR_GL_RULES_UPD.sql
  commit;
EOF
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
cp ../sql/emprpt.sql $PRODS

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
