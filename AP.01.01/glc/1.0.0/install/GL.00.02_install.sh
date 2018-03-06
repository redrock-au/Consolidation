#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.01.01/glc/1.0.0/install/GL.00.02_install.sh 1822 2017-07-18 00:19:16Z svnuser $
# --------------------------------------------------------------
# Install script for GL.00.02 GL Account Balance Conversion
#   Usage: GL.00.02_install.sh <apps_pwd> | tee GL.00.02_install.log
# --------------------------------------------------------------
CEMLI=GL.00.02

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
  @./sql/XXGL_COA_DSDBI_BAL_RECID_SEQ_DDL.sql
  @./sql/XXGL_COA_DSDBI_BALANCES_STG_DDL.sql
  @./sql/XXGL_COA_DSDBI_BALANCES_TFM_DDL.sql
  @./sql/XXGL_ACCT_BALANCE_CONV_PKG.pks
  show errors
  @./sql/XXGL_ACCT_BALANCE_CONV_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $GLC_TOP/import/XXGLACCBAL_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $GLC_TOP/import/XXGLACCBALRQG_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
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