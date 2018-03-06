#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.01.02/poc/1.0.0/install/PO.04.02_install.sh 1854 2017-07-18 03:24:17Z svnuser $
# --------------------------------------------------------------
# Install script for PO.04.02 Receivable Transactions Interface
#   Usage: PO.04.02_install.sh apps_pwd | tee PO.04.02_install.log
# --------------------------------------------------------------
CEMLI=PO.04.02

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee PO.04.02_install.log"
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
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/RCV_TRANSACTIONS_INTERFACE_T1.sql
  @./sql/XXPO_RCV_OAF_UTIL_PKG.pks
  show errors
  @./sql/XXPO_RCV_OAF_UTIL_PKG.pkb
  show errors
EOF
fi

if [ $TIER_DB = YES ] 
then
# Application Setup

FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXICX_POR_RCV_DELEGATE_MSG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXICX_POR_RCV_DUPL_INVOICE.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXICX_POR_RCV_INV_AMT_MISMATCH.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/XXICX_POR_RCV_INVOICE_MISSING.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

fi
# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

# --------------------------------------------------------------
# OA HTML
# --------------------------------------------------------------
# Copy java Files
# Controllers
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttLovCO.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvRvwCO.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/webui/RcvInfoCO.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvHomeCO.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/

#VO/AM 
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveItemsAMImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveReqItemsVOImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiInvAttachmentListVOImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceivePurchaseItemsVOImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveMyItemsVOImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/

#Pages / Regions
#cp -p $POC_TOP/mds/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttachmentLOVRN.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/

#Coyp VO and AM Files 
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveItemsAM.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveItemsTxnVO.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveReqItemsVO.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiInvAttachmentListVO.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceivePurchaseItemsVO.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveMyItemsVO.xml $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/

echo "Java Files Copy Completed"

#Copy Image File

cp -p $POC_TOP/images/pdf_icon1818.jpg $OA_MEDIA/

#Compile java Files 
echo "Compiling java files .."
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttLovCO.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/DoiRcvRvwCO.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/RcvInfoCO.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/DoiRcvHomeCO.java

javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/DoiInvAttachmentListVOImpl.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/DoiReceiveItemsAMImpl.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/DoiReceiveReqItemsVOImpl.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/DoiReceivePurchaseItemsVOImpl.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/server/DoiReceiveMyItemsVOImpl.java

echo "Compiling java files completed"

if [ $TIER_DB = YES ] 
then
#Import Pages and Regions

echo "Importing Pages and Regions .."
java oracle.jrad.tools.xml.importer.XMLImporter \
$POC_TOP/mds/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttachmentLOVRN.xml \
-username apps \
-password $APPSPWD \
-dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" \
-rootdir $POC_TOP/mds/
echo "Importing Pages and Completed"

#Import Personalization
echo "Importing Personalization .."
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/server/customizations/site/0/ReceiveReqItemsVO.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/server/customizations/site/0/ReceivePurchaseItemsVO.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/server/customizations/site/0/ReceiveMyItemsVO.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/function/POR_RECEIVE_ORDERS/IcxPorRcvSrchPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/org/101/IcxPorRcvInfoPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/responsibility/21584/IcxPorRcvInfoPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/responsibility/51398/IcxPorRcvInfoPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/site/0/IcxPorRcvConfPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/site/0/IcxPorRcvInfoPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/site/0/IcxPorRcvInfoiPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/site/0/IcxPorRcvRvwPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/site/0/IcxPorRcvSrchPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/rcv/webui/customizations/function/POR_RECEIVE_ORDERS/IcxPorRcvHomePG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/doi/oracle/apps/icx/por/rcv/webui/customizations/site/0/DoiInvAttachmentLOVRN.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"
echo "Importing Personalization completed"

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
