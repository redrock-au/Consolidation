#!/usr/bin/ksh
#*******************************************************************************
#* 
#* $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/AR.09.03_install.sh 2770 2017-10-10 23:47:18Z svnuser $
#* 
#* Purpose : Install all components for RRAM Debtors and Transactions Interfaces
#*
#* History : 
#* 
#*     30-Jan-2015    Shannon Ryan     Initial Creation.
#*     20-Feb-2015    Shannon Ryan     Removed CUSTOMER_INFORMATION_dff.ldt
#*     (See version control for history beyond Feb-2015)
#*
#* Notes   : execute with ./RRAM_install.sh <appspwd> <fmsmgrpwd> <systempwd> | tee <logfile>
#*
#********************************************************************************
#* $Id$
if [ $# != 3 ]
then
  echo "Usage RRAM_install.sh <apps password> <fmsmgr password> <system password> | tee <logfile>"
  exit 1
fi
#---------------------------------------
# Arguments:
#  1 - Apps Password
#  2 - Fmsmgr Password
#---------------------------------------
DBPASS=$1
FMSMGRPASS=$2
SYSTEMPASS=$3

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

print "Installing"
print "***********************************************"
print "Start Date: " + `date` + "\n"
print "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  CWD=`pwd`
  cd $ARC_TOP/install/$APPLSQL
$ORACLE_HOME/bin/sqlplus -s fmsmgr/$FMSMGRPASS <<EOF
  SET DEFINE OFF
  @RRAM_install_fmsmgr.sql
  conn apps/$DBPASS
  @RRAM_install_apps.sql
  conn system/$SYSTEMPASS
  @create_rram_user.sql
EOF
  cd $CWD
fi

#---------------------------------------
# Profile
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  FNDLOAD apps/$DBPASS 0 Y UPLOAD $FND_TOP/patch/115/import/afscprof.lct $ARC_TOP/import/ARC_RRAM_AUTOMATIC_EMAIL_RECIPIENTS.ldt >>LOG
fi

#---------------------------------------
# Concurrent Programs
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/RRAM_IMPORT_DEBTORS_cp.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/RRAM_IMPORT_TRANS_cp.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXAR_RRAM_STATUS_UPD.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXAR_RRAM_TRANS_STAGE_RPT_XML.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXAR_RRAM_INV_STATUS_RPT_XML.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/ARCRAMSSENDMAIL.ldt >>$LOG
fi

#---------------------------------------
# Data Definition
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  FNDLOAD apps/$DBPASS O Y UPLOAD $XDO_TOP/patch/115/import/xdotmpl.lct $ARC_TOP/import/XXAR_RRAM_INV_STATUS_RPT_XML_DD.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $XDO_TOP/patch/115/import/xdotmpl.lct $ARC_TOP/import/XXAR_RRAM_TRANS_STAGE_RPT_XML_DD.ldt >>$LOG 
fi

#---------------------------------------
# Data Template
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD -DB_USERNAME apps -DB_PASSWORD $DBPASS -JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID -LOB_TYPE DATA_TEMPLATE -LOB_CODE XXAR_RRAM_TRANS_STAGE_RPT_XML -XDO_FILE_TYPE XML -FILE_NAME $ARC_TOP/admin/import/XXAR_RRAM_TRANS_STAGE_RPT_XML.xml -APPS_SHORT_NAME ARC -NLS_LANG en -TERRITORY US -CUSTOM_MODE FORCE -LOG_FILE AR.09.03_install.log

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD -DB_USERNAME apps -DB_PASSWORD $DBPASS -JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID -LOB_TYPE DATA_TEMPLATE -LOB_CODE XXAR_RRAM_INV_STATUS_RPT_XML -XDO_FILE_TYPE XML -FILE_NAME $ARC_TOP/admin/import/XXAR_RRAM_INV_STATUS_RPT_XML.xml -APPS_SHORT_NAME ARC -NLS_LANG en -TERRITORY US -CUSTOM_MODE FORCE -LOG_FILE AR.09.03_install.log
fi

#---------------------------------------
# RTF Template
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $DBPASS \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE XXAR_RRAM_TRANS_STAGE_RPT_XML \
-XDO_FILE_TYPE RTF \
-FILE_NAME $ARC_TOP/admin/import/DEDJTR_RRAM_Transactions_Staging_Table_Extract.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME ARC \
-NLS_LANG American_America.WE8ISO8859P1 \
-TERRITORY 00 \
-CUSTOM_MODE FORCE \
-LOG_FILE AR.09.03_install.log  

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $DBPASS \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE XXAR_RRAM_INV_STATUS_RPT_XML \
-XDO_FILE_TYPE RTF \
-FILE_NAME $ARC_TOP/admin/import/DEDJTR_RRAM_Invoice_Status_Extract.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME ARC \
-NLS_LANG American_America.WE8ISO8859P1 \
-TERRITORY 00 \
-CUSTOM_MODE FORCE \
-LOG_FILE AR.09.03_install.log  

fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
chmod 775 $ARC_TOP/bin/ARCRAMSSENDMAIL.prog
cd $ARC_TOP/bin/
rm -rf ARCRAMSSENDMAIL
ln -s $FND_TOP/bin/fndcpesr ARCRAMSSENDMAIL

#---------------------------------------
# RTF Template
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $ARC_TOP/import/RRAM_RECEIVABLES_ALL_rg.ldt >>$LOG
fi

#---------------------------------------
# Workflow Business Events
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  java oracle.apps.fnd.wf.WFXLoad -u apps $DBPASS $DBHOST:$DBPORT:$DBSID thin US $AR_TOP/patch/115/xml/US/arcaple.wfx
fi

print "End Installation"
print "***********************************************"
print "End Date: " + `date` + "\n"
print "***********************************************"
