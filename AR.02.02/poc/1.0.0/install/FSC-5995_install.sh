#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.02/poc/1.0.0/install/FSC-5995_install.sh 3066 2017-11-28 06:24:56Z svnuser $
# --------------------------------------------------------------
# Install script for PO.04.02 Receivable Transactions Interface
#   Usage: FSC-5995_install.sh apps_pwd | tee FSC-5995_install.log
# --------------------------------------------------------------
CEMLI=PO.04.02

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

# --------------------------------------------------------------
# OA HTML
# --------------------------------------------------------------

cp -p $POC_TOP/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/

echo "Copy DoiRcvSrchCO.java file completed"
echo "Compiling ..."

javac $JAVA_TOP/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java

echo "Compile java file completed"

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
