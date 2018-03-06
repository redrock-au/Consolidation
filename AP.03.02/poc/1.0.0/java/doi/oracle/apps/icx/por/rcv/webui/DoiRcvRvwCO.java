package doi.oracle.apps.icx.por.rcv.webui;

// **********************************************************************
// doi.oracle.apps.icx.por.rcv.webui.DoiRcvRvwCO
//
//
// Joy Pinto 27-APR-2017
//
// Custom version of oracle.apps.icx.por.rcv.webui.RcvRvwCO
//
//
// **********************************************************************
/* $Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvRvwCO.java 1472 2017-07-05 00:35:27Z svnuser $ */
import oracle.apps.fnd.framework.OAApplicationModule;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.fnd.framework.webui.beans.table.OATableBean;
import oracle.jbo.Row;
import oracle.apps.fnd.framework.webui.beans.layout.OAPageLayoutBean;
import oracle.apps.fnd.framework.webui.beans.message.OAMessageStyledTextBean;
import oracle.apps.fnd.framework.OAViewObject;
import oracle.apps.icx.por.rcv.webui.RcvRvwCO;
import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import oracle.apps.fnd.framework.OAException;

public class DoiRcvRvwCO extends RcvRvwCO {

    public void processRequest(OAPageContext oapagecontext, OAWebBean oawebbean) {
        super.processRequest(oapagecontext, oawebbean);
      if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y")) 
       { // Kofax enabled new code starts
       
        String reqLineId        = "0";
        String derivedQty       = "0";
        String lineType         = oapagecontext.getSessionValue("lineType").toString();
        String primaryField     = oapagecontext.getSessionValue("primaryField").toString();
        String secondaryField   = oapagecontext.getSessionValue("secondaryField").toString(); 
        
        OAApplicationModule am                        = (OAApplicationModule)oapagecontext.getApplicationModule(oawebbean);
        OAPageLayoutBean oaPageLayoutBean             = (OAPageLayoutBean) oawebbean;
        OATableBean t                                 = (OATableBean)oaPageLayoutBean.findChildRecursive("ItemDetailsTableRN");
        OAMessageStyledTextBean receiptQuantityCol    = (OAMessageStyledTextBean)t.findChildRecursive("ReceiptQuantity");
        OAMessageStyledTextBean derivedQuantityAmtCol = (OAMessageStyledTextBean)t.findChildRecursive("xx_derived_qty_amt");

        receiptQuantityCol.setPrompt(lineType);
        if (lineType.equalsIgnoreCase("Amount")) 
         {
                derivedQuantityAmtCol.setPrompt("Quantity");               
         } 
       else 
         {
                derivedQuantityAmtCol.setPrompt("Amount");              
         }        

        OAViewObject ReceiveReqItemsVO = (OAViewObject)am.findViewObject("ReceiveReqItemsVO");
        OAViewObject ReceiveItemsTxnVO = (OAViewObject)am.findViewObject("ReceiveItemsTxnVO");  
        
        for (Row row1 = ReceiveReqItemsVO.first(); row1 != null; row1 = ReceiveReqItemsVO.next()) 
          {   
            reqLineId         = row1.getAttribute("ReqLineId").toString();
            derivedQty        = row1.getAttribute("Attribute2").toString();
                   for (Row row2 = ReceiveItemsTxnVO.first(); row2 != null; row2 = ReceiveItemsTxnVO.next())
                   {
                     if(reqLineId.equals(row2.getAttribute("ReqLineId").toString()))
                     {
                       row2.setAttribute("Attribute5", derivedQty);                        
                     }
                   }                  
          }  

        ReceiveReqItemsVO.reset();
        ReceiveItemsTxnVO.reset();
       }   
        
    }

    public void processFormRequest(OAPageContext oapagecontext, OAWebBean oawebbean) {
      if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y")) 
       { // Kofax enabled new code starts
        oapagecontext.putSessionValue("overrideComments","N");
       }
        super.processFormRequest(oapagecontext, oawebbean);
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

        public DoiRcvRvwCO()
    {
    }

}