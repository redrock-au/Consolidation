#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.01.02/apc/1.0.0/install/AP.01.02_install.sh 1083 2017-06-21 05:55:08Z sryan $
# --------------------------------------------------------------
# Install script for AP.01.01 Receivable Transactions Interface
#   Usage: AP.01.01_install.sh apps_pwd | tee AP.01.01_install.log
# --------------------------------------------------------------
CEMLI=AP.01.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AP.01.01_install.log"
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
# Application Setup

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $APC_TOP/import/APCINVAMTRPT.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

#Request Group
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $APC_TOP/import/DOT_ALL_REPORTS_AP.ldt
fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0