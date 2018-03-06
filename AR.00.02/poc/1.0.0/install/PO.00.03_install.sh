#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.00.02/poc/1.0.0/install/PO.00.03_install.sh 2379 2017-08-31 04:02:33Z svnuser $
# --------------------------------------------------------------
# Install script for PO.00.03 DEDJTR Open Purchase Order Conversion
#   Usage: PO.00.03_install.sh <apps_pwd> | tee PO.00.03_install.log
# --------------------------------------------------------------
CEMLI=PO.00.03

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: ${CEMLI}_install.sh <apps_pwd>"
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
  PROMPT Running XXPO_POREQ_CONV_STG.sql
  @./sql/XXPO_POREQ_CONV_STG.sql

  PROMPT Running XXPO_POREQ_CONV_TFM.sql
  @./sql/XXPO_POREQ_CONV_TFM.sql

  PROMPT Running XXPO_POREQ_RECORD_ID_S.sql
  @./sql/XXPO_POREQ_RECORD_ID_S.sql

  PROMPT Running XXPO_POREQ_CONV_PKG.pks
  @./sql/XXPO_POREQ_CONV_PKG.pks
  show errors

  PROMPT Running XXPO_POREQ_CONV_PKG.pkb
  @./sql/XXPO_POREQ_CONV_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$POC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXPO_POREQ_CONV.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXPO_POREQ_WF_RETRY.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXPO_POREQ_APPROVE.ldt -
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXPO_POREQ_CONV_RG.ldt -
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
