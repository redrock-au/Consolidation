#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/apc/1.0.0/install/FSC-5999_install.sh 3173 2017-12-12 05:28:14Z svnuser $
# --------------------------------------------------------------
# Install script for AP.03.01 Receivable Transactions Interface
#   Usage: FSC-5999_install.sh apps_pwd | tee FSC-5999_install.log
#   Refine details of the process output and message logs (FSC-5999)
# --------------------------------------------------------------
CEMLI=AP.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-5999_install.sh apps_pwd | tee FSC-5999_install.log"
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

# --------------------------------------------------------------
# Database objects Views and Packages
# --------------------------------------------------------------
if [ $TIER_DB = YES ]
then
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXAP_INVOICE_IMPORT_PKG.pkb
  show errors
EOF
fi

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
