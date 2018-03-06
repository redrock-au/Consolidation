#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/AR.01.01_install.sh 1427 2017-07-04 07:19:13Z svnuser $
# --------------------------------------------------------------
# Install script for AR.01.01 Receivable Transactions Interface
#   Usage: AR.01.01_install.sh <apps_pwd> | tee AR.01.01_install.log
# --------------------------------------------------------------
CEMLI=AR.01.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
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

APPSLOGIN=apps/$APPSPWD

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
  @$ARC_TOP/install/sql/XXAR_PRINT_INVOICES_V.sql
  show errors
  @$ARC_TOP/install/sql/XXAR_CHECKDIGIT_UTIL_PKG.pks
  show errors
  @$ARC_TOP/install/sql/XXAR_CHECKDIGIT_UTIL_PKG.pkb
  show errors
  @$ARC_TOP/install/sql/XXAR_PRINT_INVOICES_PKG.pks
  show errors
  @$ARC_TOP/install/sql/XXAR_PRINT_INVOICES_PKG.pkb
  show errors
  EXIT
EOF

# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------

##concurrent programs 
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVPSDISB_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVPSDISN_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVPSDIS_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVPSREM_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

## Request group
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $ARC_TOP/import/XXAR_DEDJTR_PRINT_INVOICES_RG.ldt

## Form function
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afsload.lct $ARC_TOP/import/XXAR_FNDRSRUN_DEDJTR_INV_FUNC.ldt

## Menu
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afsload.lct $ARC_TOP/import/XXAR_PRINT_GUI_MENU.ldt

## Message
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $ARC_TOP/import/XXAR_INVPS_EXTERNAL_INV_MSG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

## Profile
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $ARC_TOP/import/XXAR_TRX_PRINT_LIMIT_PROF.ldt

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0

