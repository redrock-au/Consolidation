#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.00.02/apc/1.0.0/install/AP.03.01_install.sh 1496 2017-07-05 07:15:13Z svnuser $
# --------------------------------------------------------------
# Install script for AP.03.01 Receivable Transactions Interface
#   Usage: AP.03.01_install.sh apps_pwd | tee AP.03.01_install.log
# --------------------------------------------------------------
CEMLI=AP.03.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AP.03.01_install.log"
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


APPSLOGIN=APPS/$APPSPWD

if [ $TIER_DB = YES ]
then
# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
echo "Installing tables and sequences as this tier is identified as database tier"
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAP_INV_SCANNED_FILE.sql
  @./sql/XXAP_KOFAX_INV_STG.sql
  @./sql/XXAP_REQ_EMAIL_ITEM_KEY_S.sql
  @./sql/XXAP_INV_IMPORT_CREATES_TYPES_DDL.sql
  show errors
EOF
fi

if [ $TIER_DB = YES ]
then
# --------------------------------------------------------------
# Database objects Views and Packages
# --------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @$POC_TOP/install/sql/XXPO_ELIGIBLE_REQUESTORS_V.sql
  @./sql/XXAP_INVOICE_IMPORT_PKG.pks
  show errors
  @./sql/XXAP_INVOICE_IMPORT_PKG.pkb
  show errors
  @./sql/XXAP_KOFAX_INTEGRATION_PKG.pks
  show errors
  @./sql/XXAP_KOFAX_INTEGRATION_PKG.pkb
  show errors
EOF
fi

if [ $TIER_DB = YES ]
then
# Application Setup Messages

FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_AMT_IN_GST.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_CURR.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_GST_AMT.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_GST_CODE.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_INVAMT_EXGST.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_INVDATE.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_INVNUM.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_INVRCVDT.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_OU_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_PO_HEADER_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_PO_INV.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_PREP_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_REQ_NO_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_INVOICE_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_V_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $APC_TOP/import/XXAP_INV_IMP_MISS_VSITE_ID.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_EMAIL_BODY_PART1.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_EMAIL_BODY_PART2.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_EMAIL_SUBJECT.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_MUL_EMAIL_BODY_PART1.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_MUL_EMAIL_BODY_PART2.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_REM_EMAIL_BODY_PART1.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_REM_EMAIL_BODY_PART2.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_REM_EMAIL_SUBJECT.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_REM_MUL_EMAIL_BODYP1.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXPO_RCPT_REM_MUL_EMAIL_BODYP2.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE


# Application Setup Concurrent Programs

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $POC_TOP/import/XXPORECNOTIF.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $APC_TOP/import/XXAPINVIMPORT.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $APC_TOP/import/XXAP_DEL_KOFAX_INVOICE.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

#Request Group
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $APC_TOP/import/DOT_ALL_REPORTS_AP.ldt

#Workflow
WFLOAD $APPSLOGIN 0 Y UPLOAD $POC_TOP/workflow/POCRECNO.wft
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