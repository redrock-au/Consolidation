#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.01/poc/1.0.0/install/PO.12.01_install.sh 2466 2017-09-06 07:00:01Z svnuser $
# --------------------------------------------------------------
# Install script for PO.12.01 DEDJTR Contract Extract Inbound from CMS
#   Usage: PO.12.01_install.sh apps_pwd | tee PO.12.01_install.log
# --------------------------------------------------------------
CEMLI=PO.12.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee PO.12.01_install.log"
  exit 1
}

# ------------------------------------------------------------
# Validate parameters
# ------------------------------------------------------------
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

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------

if [ "$TIER_DB" = "YES" ]
then

$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @$POC_TOP/install/sql/XXPO_CONTRACTS_ALL.sql
  @$POC_TOP/install/sql/XXPO_CONTRACTS_STG.sql
  @$POC_TOP/install/sql/XXPO_CONTRACTS_TFM.sql
  @$POC_TOP/install/sql/XXPO_DELETE_CUSTOM_EO.sql
  @$POC_TOP/install/sql/POC_ENQUIRIES_CONTACT_LOV_V.sql
  @$POC_TOP/install/sql/XXPO_CONTRACT_RECORD_ID_S.sql
  @$POC_TOP/install/sql/XXPO_CMS_INT_PKG.pks
  show errors
  @$POC_TOP/install/sql/XXPO_CMS_INT_PKG.pkb
  show errors
  @$POC_TOP/install/sql/XXPO_CONTRACTS_PKG.pks
  show errors
  @$POC_TOP/install/sql/XXPO_CONTRACTS_PKG.pkb
  show errors
EOF

fi

# Application Setup
IMPORTDIR=$POC_TOP/import

if [ "$TIER_DB" = "YES" ]
then

cd $POC_TOP/install

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $IMPORTDIR/XXPO_CMS_CHECKSUM_ERR_MSG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $IMPORTDIR/XXPOCMSINT_CP.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $IMPORTDIR/XXPOCMSINT_REQG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $IMPORTDIR/XXPO_CMS_LOV_ENABLED.ldt

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

cd $POC_TOP/install

cp -p $POC_TOP/java/oracle/apps/icx/por/req/webui/CheckoutSummaryCO.java $JAVA_TOP/oracle/apps/icx/por/req/webui/

cp -p $POC_TOP/java/doi/oracle/apps/icx/por/req/server/CMSLovAMImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/req/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/req/server/CMSLovVOImpl.java $JAVA_TOP/doi/oracle/apps/icx/por/req/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/req/webui/CMSLovCO.java      $JAVA_TOP/doi/oracle/apps/icx/por/req/webui/

cp -p $POC_TOP/java/doi/oracle/apps/icx/por/req/server/CMSLovVO.xml $JAVA_TOP/doi/oracle/apps/icx/por/req/server/
cp -p $POC_TOP/java/doi/oracle/apps/icx/por/req/server/CMSLovAM.xml $JAVA_TOP/doi/oracle/apps/icx/por/req/server/

echo "Java Files Copy Completed"

#Compile java Files 
echo "Compiling java files .."

cd $JAVA_TOP/oracle/apps/icx/por/req/webui/
javac -Xlint $JAVA_TOP/oracle/apps/icx/por/req/webui/CheckoutSummaryCO.java
echo "Note: Please ignore above 3 warings...."

cd    $JAVA_TOP/doi/oracle/apps/icx/por/req/server/
javac $JAVA_TOP/doi/oracle/apps/icx/por/req/server/CMSLovAMImpl.java
javac $JAVA_TOP/doi/oracle/apps/icx/por/req/server/CMSLovVOImpl.java

cd $JAVA_TOP/doi/oracle/apps/icx/por/req/webui/
javac $JAVA_TOP/doi/oracle/apps/icx/por/req/webui/CMSLovCO.java

echo "Compiling java files completed"

cd $POC_TOP/install

#Import Pages and Regions
if [ "$TIER_DB" = "YES" ]
then

echo "Importing Pages and Regions .."
java oracle.jrad.tools.xml.importer.XMLImporter \
$POC_TOP/mds/doi/oracle/apps/icx/por/req/webui/CMSLovRN.xml \
-username apps \
-password $APPSPWD \
-dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" \
-rootdir $POC_TOP/mds/
echo "Importing Pages and Completed"

java oracle.jrad.tools.xml.importer.XMLImporter $CUSTOM_TOP/oaf_personalization/oracle/apps/icx/por/req/webui/customizations/site/0/CheckoutSummaryPG.xml -username apps -password $APPSPWD -dbconnection "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=$DBHOST)(PORT=$DBPORT))(CONNECT_DATA=(SID=$DBSID)))" -rootdir $CUSTOM_TOP/oaf_personalization/ -rootPackage "/"

fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
