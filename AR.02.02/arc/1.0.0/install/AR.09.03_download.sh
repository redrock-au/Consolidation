#!/usr/bin/ksh
#*******************************************************************************
#* 
#* $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/AR.09.03_download.sh 1849 2017-07-18 02:20:57Z svnuser $
#* 
#* Purpose : Downloads all FND custom configuration for RRAM Debtors and 
#*           Transactions Interfaces
#* History : 
#* 
#*     30-Jan-2015    Shannon Ryan     Initial Creation.
#*     20-Feb-2015    Shannon Ryan     Removed creation of CUSTOMER_INFORMATION_dff.ldt
#*     (See version control for history beyond Feb-2015)
#*
#* Notes   : execute with ./RRAM_download.sh <appspwd> 
#*
#********************************************************************************
if [ "$1" == "" ]
then
  echo "Usage RRAM_download.sh <apps password>"
  exit 1
fi
#---------------------------------------
# Arguments:
#  1 - Apps Password
#---------------------------------------
DBPASS=$1
LOG="$ARC_TOP/install/RRAM_download.log"

print "Downloading" >> $LOG
print "***********************************************" >> $LOG
print "Start Date: " + `date` + "\n" >> $LOG
print "***********************************************" >> $LOG


#---------------------------------------
# Concurrent Programs
#---------------------------------------
FNDLOAD apps/$DBPASS O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/install/RRAM_IMPORT_DEBTORS_cp.ldt PROGRAM \
   CONCURRENT_PROGRAM_NAME=RRAM_IMPORT_DEBTORS \
   APPLICATION_SHORT_NAME=ARC >>$LOG

FNDLOAD apps/$DBPASS O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct $ARC_TOP/install/RRAM_IMPORT_TRANS_cp.ldt PROGRAM \
   CONCURRENT_PROGRAM_NAME=RRAM_IMPORT_TRANS \
   APPLICATION_SHORT_NAME=ARC >>$LOG


#---------------------------------------
# Request Groups
#---------------------------------------
FNDLOAD apps/$DBPASS O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct $ARC_TOP/install/RRAM_RECEIVABLES_ALL_rg.ldt REQUEST_GROUP \
   REQUEST_GROUP_NAME="Receivables All" \
   APPLICATION_SHORT_NAME=AR >>$LOG


#---------------------------------------
# Descriptive Flexfields
#---------------------------------------
FNDLOAD apps/$DBPASS O Y DOWNLOAD $FND_TOP/patch/115/import/afffload.lct $ARC_TOP/install/ADDRESS_INFORMATION_dff.ldt DESC_FLEX \
   DESCRIPTIVE_FLEXFIELD_NAME=RA_ADDRESSES_HZ \
   APPLICATION_SHORT_NAME=AR >>$LOG

FNDLOAD apps/$DBPASS O Y DOWNLOAD $FND_TOP/patch/115/import/afffload.lct $ARC_TOP/install/INVOICE_LINE_INFORMATION_dff.ldt DESC_FLEX \
   DESCRIPTIVE_FLEXFIELD_NAME=RA_CUSTOMER_TRX_LINES \
   APPLICATION_SHORT_NAME=AR >>$LOG


print "End Download" >> $LOG
print "***********************************************" >> $LOG
print "End Date: " + `date` + "\n" >> $LOG
print "***********************************************" >> $LOG
