#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.00.02/arc/1.0.0/install/AR.03.02_install.sh 1470 2017-07-05 00:33:23Z svnuser $
# --------------------------------------------------------------
# Install script for AR.03.02 Receivable Transactions Interface
#   Usage: AR.03.02_install.sh <apps_pwd> | tee AR.03.02_install.log
# --------------------------------------------------------------
CEMLI=AR.03.02

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

##concurrent programs 
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARDOXPRT_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARSEMAIL_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVPSCOPY_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXARINVPSMERGEF_CP.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE


#----------------------------------------
## Data definition and template
#----------------------------------------

FNDLOAD $APPSLOGIN 0 Y UPLOAD $XDO_TOP/patch/115/import/xdotmpl.lct $ARC_TOP/import/XXARINVPSREM_TEMP_DEF.ldt

#----------------------------------------
## Attach RFT Template to above template
#----------------------------------------

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE XXARINVPSREM \
-XDO_FILE_TYPE RTF \
-FILE_NAME $ARC_TOP/admin/import/DEDJTR_External_Invoice.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME ARC \
-NLS_LANG American_America.WE8ISO8859P1 \
-TERRITORY US \
-CUSTOM_MODE FORCE \
-LOG_FILE AR.03.02_install.log 

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE XXARINVPSREMEC \
-XDO_FILE_TYPE RTF \
-FILE_NAME $ARC_TOP/admin/import/DEDJTR_External_Credit_Memo.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME ARC \
-NLS_LANG American_America.WE8ISO8859P1 \
-TERRITORY US \
-CUSTOM_MODE FORCE \
-LOG_FILE AR.03.02_install.log 

fi

#------------------------------------------
## Create symbolic links for host programs
#------------------------------------------
cd $ARC_TOP/bin
##
chmod 775 XXARINVPSMERGEF.prog
chmod 775 XXARINVPSCOPY.prog
chmod 775 XXARDOXPRT.prog
##
rm -rf XXARINVPSMERGEF
rm -rf XXARINVPSCOPY
rm -rf XXARDOXPRT
##
ln -s $FND_TOP/bin/fndcpesr XXARINVPSMERGEF
ln -s $FND_TOP/bin/fndcpesr XXARINVPSCOPY
ln -s $FND_TOP/bin/fndcpesr XXARDOXPRT	

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
