#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AP.03.01/apc/1.0.0/install/FSC-6114_install.sh 3194 2017-12-19 04:26:35Z dart $
# --------------------------------------------------------------
# Install script for AP.03.01 Receivable Transactions Interface
#   Usage: FSC-6114_install.sh apps_pwd | tee FSC-6114_install.log
#   arellanod 2017/12/19
# --------------------------------------------------------------
CEMLI=AP.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6114_install.sh apps_pwd | tee FSC-6114_install.log"
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
