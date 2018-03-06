#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/install/PO.01.01_install.sh 1607 2017-07-10 01:20:42Z svnuser $
# --------------------------------------------------------------
# Install script for PO.01.01 Receivable Transactions Interface
#   Usage: PO.01.01_install.sh apps_pwd | tee PO.01.01_install.log
# --------------------------------------------------------------
CEMLI=PO.01.01

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

echo "Compiling Custom.pll .."

f60gen module=$FNDC_TOP/resource/DOICUSTOM.pll userid=$APPSLOGIN module_type=LIBRARY module_access=FILE compile_all=YES output_file=$FNDC_TOP/resource/DOICUSTOM.plx

echo "Completed Compiling Custom.pll"

if [ $TIER_DB = YES ]
then
# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/POC_IP5_CUSTOM.pks
  show errors
  @./sql/POC_IP5_CUSTOM.pkb
  show errors
  @./sql/poc_gst.pks
  show errors
  @./sql/poc_gst.pkb
  show errors
  @./sql/POC_POAPPRV_WF.pkb
  show errors
  @./sql/POC_DOC_NOTIFICATION.pkb
  show errors
EOF

# Application Setup Messages

FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/POC_PO_PRINT_STATEMENT1.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/POC_PO_PRINT_STATEMENT2.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/POC_PO_PRINT_STATEMENT3.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN O Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $POC_TOP/import/POC_PO_PRINT_STATEMENT4.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

# Application Setup Concurrent Programs

FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $POC_TOP/import/POCEPOXML.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $POC_TOP/import/POCNOTIFXML.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $POC_TOP/import/POCNOTIF_EMAIL.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE

# Data Definitions
FNDLOAD $APPSLOGIN O Y UPLOAD $XDO_TOP/patch/115/import/xdotmpl.lct $POC_TOP/import/POCEPOXML_DD.ldt 

#Request Group
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $POC_TOP/import/PO_ALL_REPORTS.ldt

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
-LOG_FILE PO.01.01_install.log 

fi
# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
chmod 775 $POC_TOP/bin/POCNOTIFEMAIL.prog
cd $POC_TOP/bin/
rm -rf POCNOTIFEMAIL
ln -s $FND_TOP/bin/fndcpesr POCNOTIFEMAIL

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0