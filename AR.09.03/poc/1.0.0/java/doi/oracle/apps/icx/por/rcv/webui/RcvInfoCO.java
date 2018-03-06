// **********************************************************************
// doi.oracle.apps.icx.por.rcv.webui.RcvInfoCO
//
// Bruce Freshwater 27-FEB-2009
//
// Custom version of oracle.apps.icx.por.rcv.webui.RcvInfoCO
//
// Modified standard controller public method "processRequest()", by
// removing logic that IS required by DOT.
//
// The "Waybill" and "Packing Slip" fields/beans are always required,
// even for receiving "Amount Only" requisitions.
//
// As the custom logic REMOVES some the standard logic, we
// aren't able to simply extend the standard RcvInfoCO.
//
// This custom controller is, therefore, a copy of the standard
// RcvInfoCO (deployed to the custom DOI package).
//
// **********************************************************************

package doi.oracle.apps.icx.por.rcv.webui;

import oracle.apps.fnd.common.VersionInfo;
import oracle.apps.fnd.framework.OAApplicationModule;
import oracle.apps.fnd.framework.OAViewObject;
import oracle.apps.fnd.framework.webui.OAControllerImpl;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.icx.por.common.webui.DisplayUtil;
import oracle.jbo.domain.Number;

// ******************************************************
// Begin: ERS Customisation
// 28Jan2015 Mel Cruzado UXC Red Rock Consulting
// ******************************************************
import oracle.apps.fnd.framework.server.OADBTransaction;
import oracle.apps.fnd.framework.server.OADBTransactionImpl;
import oracle.jdbc.driver.OracleCallableStatement;
import oracle.apps.fnd.framework.OAException;
import oracle.apps.fnd.framework.OARow;
import java.sql.SQLException;
import java.sql.Types; 
import oracle.apps.fnd.framework.webui.beans.message.OAMessageTextInputBean;
import oracle.cabo.ui.UIConstants;

// ******************************************************
// End: ERS Customisation
// ******************************************************

// Added by Joy Pinto on 17-MAy-2017
import java.sql.PreparedStatement;
import java.sql.ResultSet;

public class RcvInfoCO extends OAControllerImpl
{

    public void processRequest(OAPageContext oapagecontext, OAWebBean oawebbean)
    {
        super.processRequest(oapagecontext, oawebbean);
        if(oapagecontext.isLoggingEnabled(2))
            oapagecontext.startTimedProcedure(this, "processRequest");
        DisplayUtil.hideBeanByProfile("USSGL_OPTION", "N", true, "TransactionCode", oawebbean, oapagecontext);
        int i = DisplayUtil.verifyRowExists(oapagecontext, oawebbean, "ReceiveItemsTxnVO");
        DisplayUtil.hideRadioGroupForSingleItem(i, "ApplyAllLines", null, oapagecontext, oawebbean);
        DisplayUtil.addNavigationBar("NavigationBar", 2, 1, 3, "NavigationCell", true, true, oapagecontext, oawebbean);
        DisplayUtil.setCancelDestination("CancelButton", oapagecontext, oawebbean);

        // Added by Joy Pinto on 08-May-2017            
        if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y") ) 
          { // Kofax enabled new code starts
           String invNumber = oapagecontext.getSessionValue("invNumber").toString();
           String invDate   = oapagecontext.getSessionValue("invDate").toString();    
           String itemDescription   = oapagecontext.getSessionValue("itemDescription").toString();
           OAMessageTextInputBean PackingSlip = (OAMessageTextInputBean)oawebbean.findChildRecursive("PackingSlip");
           OAMessageTextInputBean WaybillNum = (OAMessageTextInputBean)oawebbean.findChildRecursive("WaybillNum"); 
           OAMessageTextInputBean ReceiptComments = (OAMessageTextInputBean)oawebbean.findChildRecursive("ReceiptComments");        
           PackingSlip.setValue(oapagecontext, invNumber);
           WaybillNum.setValue(oapagecontext, invDate);
           if (oapagecontext.getSessionValue("overrideComments").toString().equals("Y"))
             {
               ReceiptComments.setValue(oapagecontext, itemDescription);
             }
           PackingSlip.setAttributeValue(UIConstants.DISABLED_ATTR, Boolean.TRUE);
           WaybillNum.setAttributeValue(UIConstants.DISABLED_ATTR, Boolean.TRUE);    
          }
        if(oapagecontext.isLoggingEnabled(2))
            oapagecontext.endTimedProcedure(this, "processRequest");
    }

    public void processFormRequest(OAPageContext oapagecontext, OAWebBean oawebbean)
    {
        if(oapagecontext.isLoggingEnabled(2))
            oapagecontext.startTimedProcedure(this, "processFormRequest");
        super.processFormRequest(oapagecontext, oawebbean);
        int i = DisplayUtil.retrievePageNavigationBarEvent("NavigationBar", oapagecontext, oawebbean);
        if(i == 3)
        {
          // ******************************************************
          // Begin: ERS Customisation
          // 28Jan2015 Mel Cruzado UXC Red Rock Consulting
          // ******************************************************
          // ReceiveItemsTxnVO.PackingSlip = Invoice Number
             
        //String invoiceNum        = oapagecontext.getParameter("PackingSlip"); 
        // The above line was commented out by Joy Pinto on 10-May-2017 because Packing slip is made as Read only
        // When the field is made Read only , oapagecontext.getParameter does not return value
        OAViewObject VO     = (OAViewObject)oapagecontext.getApplicationModule(oawebbean).findViewObject("ReceiveItemsTxnVO");
        OARow Row           = (OARow)VO.getCurrentRow();          
        String invoiceNum = String.valueOf(Row.getAttribute("PackingSlip"));
        
        String validationMessage = new String();   
        String ReceiptComments = "";
        if (invoiceNum != null)      
        {
          if(oapagecontext.isLoggingEnabled(2))
           {
           oapagecontext.writeDiagnostics(this, "processFormRequest: Validate Unique Invoice Number...", 1);
           }
          OAApplicationModule oam = oapagecontext.getApplicationModule(oawebbean);
          OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)oam.getTransaction();        

          OAViewObject trxVo     = (OAViewObject)oapagecontext.getApplicationModule(oawebbean).findViewObject("ReceiveItemsTxnVO");
          OARow trxRow           = (OARow)trxVo.getCurrentRow();

          String PoHeaderId      = String.valueOf(trxRow.getAttribute("PoHeaderId"));
          String OperatingUnitId = String.valueOf(trxRow.getAttribute("OperatingUnitId"));
          String SupplierId      = String.valueOf(trxRow.getAttribute("SupplierId"));
          String SupplierSiteId  = String.valueOf(trxRow.getAttribute("SupplierSiteId"));
          String PoLineLocationId = String.valueOf(trxRow.getAttribute("PoLineLocationId"));
          ReceiptComments         = String.valueOf(trxRow.getAttribute("ReceiptComments"));

          // Joy Pinto 10-May-2017 replace special characters from the string
           if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y")) {
           trxRow.setAttribute("ReceiptComments", ReceiptComments.replaceAll("[^a-zA-Z0-9,.!@#$%&* ]", ""));
           }

          oapagecontext.writeDiagnostics(this, "processFormRequest: invoiceNum      is " + invoiceNum,1);
          oapagecontext.writeDiagnostics(this, "processFormRequest: PoHeaderId      is " + PoHeaderId,1);
          oapagecontext.writeDiagnostics(this, "processFormRequest: OperatingUnitId is " + OperatingUnitId,1);
          oapagecontext.writeDiagnostics(this, "processFormRequest: SupplierId      is " + SupplierId,1);
          oapagecontext.writeDiagnostics(this, "processFormRequest: SupplierSiteId  is " + SupplierSiteId , 1);  
          oapagecontext.writeDiagnostics(this, "processFormRequest: PoLineLocationId is " + PoLineLocationId , 1);  

          oapagecontext.writeDiagnostics(this, "processFormRequest: Validate Unique Invoice Number...", 1);     
          String sqlCall = "begin :1 := doi_oaf_util_pkg.is_invoice_unique(p_po_header_id=>:2,p_org_id=>:3, p_vendor_id=>:4,p_vendor_site_id=>:5,p_invoice_num=>:6); end;";
          OracleCallableStatement ocs = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall,1); 
          try
          {
            ocs.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs.setString(2,PoHeaderId.toString());            
            ocs.setString(3,OperatingUnitId.toString());            
            ocs.setString(4,SupplierId.toString());            
            ocs.setString(5,SupplierSiteId.toString());            
            ocs.setString(6,invoiceNum);            
            ocs.execute();
            validationMessage = ocs.getString(1); 
            oapagecontext.writeDiagnostics(this, "processFormRequest: Callable Statement Returns validationMessage as " + validationMessage , 1);
            ocs.close();
           } //try
           catch(SQLException sqlexception)
            {
              throw OAException.wrapperException(sqlexception);
            } //sqlexception
           catch(Exception exception)
            {
            throw OAException.wrapperException(exception);
            }//exception
        
         if (validationMessage != null)   
           {
           OAException message = new OAException(validationMessage , OAException.ERROR);
           oapagecontext.putDialogMessage(message);  
           }
         }//invoiceNum != null
      
      
        //String invoiceDate       = oapagecontext.getParameter("WaybillNum");   
        // The above line was commented out by Joy Pinto on 10-May-2017 because PAcking slip is made as Read only
        // When the field is made Read only , oapagecontext.getParameter does not return value        
        String invoiceDate       = String.valueOf(Row.getAttribute("WaybillAirbillNum"));         
        String validationMessage2 = new String();           
       

        if (invoiceDate != null)      
         {
          if(oapagecontext.isLoggingEnabled(2))
           {
           oapagecontext.writeDiagnostics(this, "processFormRequest: Validate Invoice Date Format...", 1);
           }
          
          OAApplicationModule oam = oapagecontext.getApplicationModule(oawebbean);
          OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)oam.getTransaction();        

          OAViewObject trxVo     = (OAViewObject)oapagecontext.getApplicationModule(oawebbean).findViewObject("ReceiveItemsTxnVO");
          OARow trxRow           = (OARow)trxVo.getCurrentRow();

          oapagecontext.writeDiagnostics(this, "processFormRequest: Validate Invoice Date Format...", 1);
          oapagecontext.writeDiagnostics(this, "processFormRequest: invoiceDate     is " + invoiceDate,1);
          
          String sqlCall2 = "begin :1 := doi_oaf_util_pkg.is_invoice_date_valid(p_invoice_date=>:2); end;";
          OracleCallableStatement ocs2 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall2,1); 
          try
          {
            ocs2.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs2.setString(2,invoiceDate);            
            ocs2.execute();
            validationMessage2 = ocs2.getString(1); 
            oapagecontext.writeDiagnostics(this, "processFormRequest: Callable Statement Returns validationMessage2 as " + validationMessage2 , 1);
            ocs2.close();
           } //try
           catch(SQLException sqlexception)
            {
              throw OAException.wrapperException(sqlexception);
            } //sqlexception
           catch(Exception exception)
            {
            throw OAException.wrapperException(exception);
            }//exception
        
        if (validationMessage2 != null)   
           {
           OAException message = new OAException(validationMessage2 , OAException.ERROR);
           oapagecontext.putDialogMessage(message);  
           }      

          }//invoiceDate != null
         
       // ******************************************************
       // End: ERS Customisation
       // ******************************************************                     
     
          //else
          //{
          //28Jan2015 Mel Cruzado UXC Red Rock Consulting
          //Call setPoLineAttributes to populate new attributes
          //setPoLineAttributes(oapagecontext, oawebbean);       


      //call updateReceiptItems when there is no validation message for invoice number and invoice date 
    
       updateReceiptItems(oapagecontext, oawebbean);
       String s = oapagecontext.getParameter("ApplyAllLines");
       String s2 = null;
         if("N".equals(s))
                s2 = "ICXPOR_RCV_INFOITEM_PAGE";
         else
                s2 = "ICXPOR_RCV_REVIEW_PAGE";
               oapagecontext.setForwardURL(s2, (byte)0, null, null, true, "N", (byte)1);
           //}
        }

        if(i == 1)
        {
            String s1 = (String)oapagecontext.getTransactionValue("ExpressReceivingReqs");
            if(oapagecontext.isLoggingEnabled(1))
                oapagecontext.writeDiagnostics(this, "processFormRequest: value of expressReceiving is " + s1, 1);
            if("Y".equals(s1))
            {
                oapagecontext.removeTransactionValue("ExpressReceivingReqs");
                Number number = (Number)((OAViewObject)oapagecontext.getApplicationModule(oawebbean).findViewObject("ReceiveItemsTxnVO")).invokeMethod("getReqHeaderId");
                if(oapagecontext.isLoggingEnabled(1))
                    oapagecontext.writeDiagnostics(this, "processFormRequest: value of reqHeaderId is " + number, 1);
                oapagecontext.putParameter("reqHeaderId", number);
                oapagecontext.putParameter("ExpressRcvFromHomePage", "Y");
            }
            oapagecontext.putParameter("RcvBackButton", "Y");
            oapagecontext.setForwardURL("ICXPOR_RCV_SRCH_PAGE", (byte)0, null, null, true, "N", (byte)1);
        }
        if(oapagecontext.isLoggingEnabled(2))
            oapagecontext.endTimedProcedure(this, "processFormRequest");
    }

    private void updateReceiptItems(OAPageContext oapagecontext, OAWebBean oawebbean)
    {
        if(oapagecontext.isLoggingEnabled(2))
            oapagecontext.startTimedProcedure(this, "updateReceiptItems");
        ((OAViewObject)oapagecontext.getApplicationModule(oawebbean).findViewObject("ReceiveItemsTxnVO")).invokeMethod("updateReceiptItems");
        if(oapagecontext.isLoggingEnabled(2))
            oapagecontext.endTimedProcedure(this, "updateReceiptItems");
    }

    public RcvInfoCO()
    {
    }

    public String isOrgKofaxEnabled(OAWebBean oawebbean,OAPageContext oapagecontext) 
    { 
     String iskofaxEnabled = "";
     PreparedStatement ps = null;
     OAApplicationModule am = oapagecontext.getApplicationModule(oawebbean);
        try {
            ps = am.getOADBTransaction().getJdbcConnection().prepareStatement("select nvl(fnd_profile.VALUE_SPECIFIC(NAME => 'POC_KOFAX_ENABLED',ORG_ID => :1),'N') kofax_enabled from dual");
            ps.setInt(1, oapagecontext.getOrgId());
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                if (rs.getString("kofax_enabled") != null) {
                    iskofaxEnabled = rs.getString("kofax_enabled");                  
                }
            }
          } catch (SQLException sq) {
            throw new OAException("Custom Exception " + sq, OAException.ERROR);
                                    } 
        finally 
        {
            try {
                ps.close();
            } catch (Exception e) {
                throw new OAException("Custom Exception " + e, OAException.ERROR);
            }
        }

        return iskofaxEnabled;
    }        

    public static final String RCS_ID = "$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/RcvInfoCO.java 1424 2017-07-04 06:57:15Z svnuser $";
    public static final boolean RCS_ID_RECORDED = VersionInfo.recordClassVersion("$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/RcvInfoCO.java 1424 2017-07-04 06:57:15Z svnuser $", "doi.oracle.apps.icx.por.rcv.webui");

}
