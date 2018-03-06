#!/usr/bin/ksh
#*******************************************************************************
#* 
#* $Header: svn://d02584/consolrepos/branches/AR.03.02/arc/1.0.0/install/AR.09.03_install.sh 1830 2017-07-18 00:26:50Z svnuser $
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
# Concurrent Programs
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/RRAM_IMPORT_DEBTORS_cp.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/RRAM_IMPORT_TRANS_cp.ldt >>$LOG
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/import/XXAR_RRAM_STATUS_UPD.ldt >>$LOG
fi

#---------------------------------------
# Request Groups
#---------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct $ARC_TOP/import/RRAM_RECEIVABLES_ALL_rg.ldt >>$LOG
fi

#---------------------------------------
# Descriptive Flexfields
#---------------------------------------
# To be defined manually by functional resource as per BR.100
#FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $ARC_TOP/import/ADDRESS_INFORMATION_dff.ldt >>$LOG
#FNDLOAD apps/$DBPASS O Y UPLOAD $FND_TOP/patch/115/import/afffload.lct $ARC_TOP/import/INVOICE_LINE_INFORMATION_dff.ldt >>$LOG


print "End Installation"
print "***********************************************"
print "End Date: " + `date` + "\n"
print "***********************************************"
