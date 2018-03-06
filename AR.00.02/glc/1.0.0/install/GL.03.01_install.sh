#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.00.02/glc/1.0.0/install/GL.03.01_install.sh 2379 2017-08-31 04:02:33Z svnuser $
# --------------------------------------------------------------
# Install script for GL.03.01 GL Cash Balancing
#   Usage: GL.03.01_install.sh <apps_pwd> | tee GL.03.01_install.log
# --------------------------------------------------------------
CEMLI=GL.03.01

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
  @./sql/XXGL_CASH_BAL_SEQ_DDL.sql
  @./sql/XXGL_CASH_BAL_RULES_STG_DDL.sql
  @./sql/XXGL_CASH_BAL_RULES_ALL_DDL.sql
  @./sql/XXGL_CASH_BAL_STG_DDL.sql
  @./sql/XXGL_CASH_BAL_TFM_DDL.sql
  @./sql/XXGL_CASH_BAL_CTL_DDL.sql
  @./sql/XXGL_CASH_BAL_CTL_DML.sql
  @./sql/XXGL_CASH_BAL_BATCHES_V_DDL.sql
  @./sql/XXGL_CASH_BAL_JOURNALS_V_DDL.sql
  @./sql/XXGL_CASH_BAL_PKG.pks
  show errors
  @./sql/XXGL_CASH_BAL_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$GLC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGLCSHBALRD_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGLCSHBALRU_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGLCASHBAL_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXGLCSHBALH_CFG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXGLREQGRP_CFG.ldt -
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
chmod +x $FNDC_TOP/bin/RUN_AP.prog
chmod +x $FNDC_TOP/bin/RUN_AP_POST.prog
chmod +x $FNDC_TOP/bin/RUN_AR_POST.prog
chmod +x $ARC_TOP/bin/RUN_AR_POST_ALL.prog
chmod +x $GLC_TOP/bin/CASHBAL_MISC_JNL.prog

rm $FNDC_TOP/bin/RUN_AP
rm $FNDC_TOP/bin/RUN_AP_POST
rm $FNDC_TOP/bin/RUN_AR_POST
rm $ARC_TOP/bin/RUN_AR_POST_ALL
rm $GLC_TOP/bin/CASHBAL_MISC_JNL

ln -s $FND_TOP/bin/fndcpesr $FNDC_TOP/bin/RUN_AP
ln -s $FND_TOP/bin/fndcpesr $FNDC_TOP/bin/RUN_AP_POST
ln -s $FND_TOP/bin/fndcpesr $FNDC_TOP/bin/RUN_AR_POST
ln -s $FND_TOP/bin/fndcpesr $ARC_TOP/bin/RUN_AR_POST_ALL
ln -s $FND_TOP/bin/fndcpesr $GLC_TOP/bin/CASHBAL_MISC_JNL

# --------------------------------------------------------------
# Copy to source directory
# --------------------------------------------------------------
cp -p $GLC_TOP/install/sql/cashbal_all_sources.sql $PRODS

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0

