#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/FSC-5720_install.sh 3173 2017-12-12 05:28:14Z svnuser $
# --------------------------------------------------------------
#
# Install script to update CEMLI GL.03.01 GL Cash Balancing
#   Usage: FSC-5720_install.sh <apps_pwd> | tee FSC-5720_install.log
# 
# Includes fixes for:
# FSC-5720: The program called RUN AP to GL Post fails to correctly account for Corporate Card invoice transactions
# FSC-5795: GL overnight RUN_AP payment program needs to be looked at as it does not pick up all Pay Groups. Currently picking up S Bank only
# FSC-5823: The Journal Interface has a journal that has been successfully imported, but is still in the journal interface
# FSC-5899: There is a discrepancy in tax and creditor entry in the cash balancing journal for an AP Credit Note
# FSC-5998: The trade receipts Q entity SAU entries do not reconcile correctly - Receivables Cash Balancing Missing entries
#
# --------------------------------------------------------------

CEMLI=GL.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-5720_install.sh <apps_pwd>"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# == 1 ]
then
  APPSLOGIN=apps/$1
else
  usage
fi

echo "Installing updates to $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------

if [ "$TIER_DB" = "YES" ]
then
$ORACLE_HOME/bin/sqlplus -s $APPSLOGIN <<EOF
  SET DEFINE OFF
  @./sql/XXGL_CASH_BAL_RULES_UPLOAD.sql
  @./sql/XXGL_CASH_BAL_PKG.pks
  show errors
  @./sql/XXGL_CASH_BAL_PKG.pkb
  show errors
EOF
fi

# --------------------------------------------------------------
# File permissions and symbolic links
# --------------------------------------------------------------
# None

# --------------------------------------------------------------
# Copy to source directory
# --------------------------------------------------------------
# None

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
