#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.09.03/arc/1.0.0/install/AR.01.02_install.sh 2689 2017-10-05 04:37:59Z svnuser $
# --------------------------------------------------------------
# Install script for AR.01.02 Print Statements
#   Usage: AR.01.02_install.sh apps_pwd | tee AR.01.02_install.log
# --------------------------------------------------------------
CEMLI=AR.01.02

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AR.01.02_install.log"
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

# Application Setup Messages

# Application Setup Concurrent Programs

# Data Definitions

# Request Group

# RTF Template
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE ARXSGP  \
-XDO_FILE_TYPE RTF \
-FILE_NAME $ARC_TOP/admin/import/DOT_AR_Statement_Document.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME AR \
-NLS_LANG American_America.WE8ISO8859P1 \
-CUSTOM_MODE FORCE \
-LOG_FILE AR.01.02_install.log 

java oracle.apps.xdo.oa.util.XDOLoader UPLOAD \
-DB_USERNAME apps \
-DB_PASSWORD $APPSPWD \
-JDBC_CONNECTION $DBHOST:$DBPORT:$DBSID \
-LOB_TYPE TEMPLATE \
-LOB_CODE ARXSGP_SUBTEMPLATE \
-XDO_FILE_TYPE RTF \
-FILE_NAME $ARC_TOP/admin/import/DOT_AR_Statement_SubTemplate.rtf \
-LANGUAGE en \
-APPS_SHORT_NAME ARC \
-NLS_LANG American_America.WE8ISO8859P1 \
-CUSTOM_MODE FORCE \
-LOG_FILE AR.01.02_install.log 

fi
# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------

rm $AR_TOP/reports/US/ARXSGPO.rdf
ln -s $ARC_TOP/reports/US/ARCSGPO.rdf $AR_TOP/reports/US/ARXSGPO.rdf

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0