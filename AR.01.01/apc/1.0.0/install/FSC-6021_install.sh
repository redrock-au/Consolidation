#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/apc/1.0.0/install/FSC-6021_install.sh 3173 2017-12-12 05:28:14Z svnuser $
# ------------------------------------------------------------------------
# Install script for AP.03.01 Receivable Transactions Interface
#   Usage: FSC-6021_install.sh apps_pwd | tee FSC-6021_install.log
#
# This patch includes fixes and enhancements (ARELLAD 07/12/2017):
# FSC-6021: Rounding issue on Oracle PO balance check returned to Kofax
# FSC-6017: Add Tolerance to Oracle Function to check PO Balance passed 
#           back to Kofax
# FSC-6020: Kofax Duplicate invoice Number can be released *Note: Should also validate the staging table 
# FSC-6062: Duplicate Invoice# error shown even though it is not a duplicate
# FSC-5907: KOFAX Rules for "Possible Duplicate Invoice"
# ------------------------------------------------------------------------
CEMLI=AP.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-6021_install.sh apps_pwd | tee FSC-6021_install.log"
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

echo "Installing FSC-6021 $CEMLI"
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
  @./sql/XXAP_KOFAX_INTEGRATION_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# none

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
