#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.03/apc/1.0.0/install/FSC-5956_install.sh 2985 2017-11-15 02:52:12Z svnuser $
# --------------------------------------------------------------
# Install script for AP.03.01 Receivable Transactions Interface
#   Usage: FSC-5956_install.sh apps_pwd | tee AP.03.01_install.log
# --------------------------------------------------------------
CEMLI=AP.03.01

DBHOST=`echo 'cat //dbhost/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBPORT=`echo 'cat //dbport/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
DBSID=`echo 'cat //dbsid/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`
TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: $CEMLI_install.sh apps_pwd | tee AP.03.01_install.log"
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
# Database objects Views and Packages
# --------------------------------------------------------------
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAP_INVOICE_IMPORT_PKG.pkb
EOF
fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0