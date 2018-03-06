#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/poc/1.0.0/install/FSC-6004_install.sh 3195 2017-12-19 04:28:02Z svnuser $
# --------------------------------------------------------------
# Install FSC-6004 bug fix for PO.04.02
#   Usage: FSC-6004_install.sh apps_pwd | tee FSC-6004_install.log
# --------------------------------------------------------------
CEMLI=PO.04.02

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6004_install.sh apps_pwd | tee FSC-6004_install.log"
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

echo "Installing $CEMLI (FSC-6004)"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

APPSLOGIN=APPS/$APPSPWD

# -----------------------------------
# OA Framework Personalization
# -----------------------------------

if [ $TIER_DB = YES ] 
then

echo "Import OA Framework Personalization on PTV org"

java oracle.jrad.tools.xml.importer.XMLImporter \
$CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/org/610/IcxPorRcvRvwPG.xml \
-username apps \
-password $APPSPWD \
-dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" \
-rootdir $CUSTOM_TOP/oaf_personalization/ \
-rootPackage "/"

echo "Import OA Framework Personalization on TSC org"

java oracle.jrad.tools.xml.importer.XMLImporter \
$CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/org/710/IcxPorRcvRvwPG.xml \
-username apps \
-password $APPSPWD \
-dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" \
-rootdir $CUSTOM_TOP/oaf_personalization/ \
-rootPackage "/"

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
