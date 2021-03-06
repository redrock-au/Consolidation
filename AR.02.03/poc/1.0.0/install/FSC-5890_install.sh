#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.03/poc/1.0.0/install/FSC-5890_install.sh 2945 2017-11-10 04:55:39Z svnuser $
# --------------------------------------------------------------
# Install script for PO.01.01 Receivable Transactions Interface
#   Usage: PO.01.01_install.sh apps_pwd | tee PO.01.01_install.log
# --------------------------------------------------------------
CEMLI=FSC-5890

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee PO.01.01_install.log"
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

#RTF Template
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE POCEPOXML \
-XDO_FILE_TYPE RTF \
-FILE_NAME $POC_TOP/admin/import/DEDJTR_Purchase_Order_Print.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME POC \
-NLS_LANG American_America.WE8ISO8859P1 \
-TERRITORY US \
-CUSTOM_MODE FORCE \
-LOG_FILE FSC-5890_install.log 

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0