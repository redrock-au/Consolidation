package doi.oracle.apps.util;
/* $Header: svn://d02584/consolrepos/branches/AR.03.02/poc/1.0.0/java/doi/oracle/apps/util/DoiUtil.java 347 2017-05-09 06:37:04Z svnuser $ */
import java.sql.SQLException;
import oracle.apps.fnd.framework.server.*;
import oracle.jbo.domain.Number;
import oracle.jdbc.OracleCallableStatement;
import java.sql.Types;

public class DoiUtil
{

    public DoiUtil()
    {
    }

    public static final void debug(String className, String msg, OAApplicationModuleImpl am)
    {
        if("Y".equals(am.getOADBTransaction().getProfile("POC_IPROC_DEBUG")))
        {
            OADBTransactionImpl t = (OADBTransactionImpl)am.getTransaction();
            String sqlCall = "begin doi_oaf_util_pkg.debug(:1,:2); end;";
            OracleCallableStatement ocs = (OracleCallableStatement)t.createCallableStatement(sqlCall, 1);
            boolean flag;
            try
            {
                ocs.setString(1, msg);
                ocs.setString(2, className);
                ocs.execute();
                ocs.close();
            }
            catch(SQLException e)
            {
                flag = false;
            }
        }
    }

   
    public static final String getCmsNumber(Number reqHeaderId, OAApplicationModuleImpl am)
    {
        OADBTransactionImpl t = (OADBTransactionImpl)am.getTransaction();
        String sqlCall = "begin :1 := doi_oaf_util_pkg.get_cms_number(p_req_header_id => :2); end;";
        OracleCallableStatement ocs = (OracleCallableStatement)t.createCallableStatement(sqlCall, 1);
        try
        {
            ocs.registerOutParameter(1, 12, 0, 30);
            ocs.setString(2, reqHeaderId.toString());
            ocs.execute();
            String cmsNumber = ocs.getString(1);
            ocs.close();
            String s = cmsNumber;
            return s;
        }
        catch(SQLException e)
        {
            String s1 = e.getMessage();
            return s1;
        }
    }

  
   // ********************************************************************************************
   // BEGIN : Customisation for ERS Project - MCruzado UXC Red Rock Consulting 25 Feb 2015
   // ********************************************************************************************
   

   // **************************
   // getPoLineUnitPrice
   // **************************
    public static final Number getPoLineUnitPrice(Number PoLineLocationId, Number ReceiptQuantity, OAApplicationModuleImpl am)
    {

     OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)am.getTransaction();        
     String sqlCall1 = "begin :1 := doi_oaf_util_pkg.get_po_shipment_info(p_attribute_name=> :2,p_line_location_id => :3,p_receipt_quantity => :4); end;";
     OracleCallableStatement ocs1 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall1,1); 
     String UnitPrice;
      try
         {
            ocs1.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs1.setString(2,"PoLineUnitPrice");            
            ocs1.setString(3,PoLineLocationId.toString());   
            ocs1.setString(4,ReceiptQuantity.toString());            
            ocs1.execute();
            UnitPrice= ocs1.getString(1);             
            ocs1.close();
            Number nUnitPrice = new Number(UnitPrice);
            return nUnitPrice;
         } 
            catch (SQLException e) 
         {  
            e.printStackTrace();
            Number n1 = new Number(0);
            return n1;
         }
     } //end getPoLineUnitPrice


   // ****************************
   // getPayOnCode
   // ****************************
    public static final String getPayOnCode(Number PoLineLocationId, Number ReceiptQuantity, OAApplicationModuleImpl am)
    {

     OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)am.getTransaction();        
     String sqlCall2 = "begin :1 := doi_oaf_util_pkg.get_po_shipment_info(p_attribute_name=> :2,p_line_location_id => :3,p_receipt_quantity => :4); end;";
     OracleCallableStatement ocs2 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall2,1); 
     String PayOnCode;
      try
          {
            ocs2.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs2.setString(2,"PayOnCode");            
            ocs2.setString(3,PoLineLocationId.toString());   
            ocs2.setString(4,ReceiptQuantity.toString());            
            ocs2.execute();
            PayOnCode= ocs2.getString(1); 
            ocs2.close();
            return PayOnCode;
          } 
      catch (SQLException e) 
          { 
           e.printStackTrace();
           String s1 = e.getMessage();
           return s1;
          }
     } //end getPayOnCode

 
   // **************************
   // getPoLineTaxName
   // **************************
    public static final String getPoLineTaxName(Number PoLineLocationId, Number ReceiptQuantity, OAApplicationModuleImpl am)
    {

     OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)am.getTransaction();        
     String sqlCall3 = "begin :1 := doi_oaf_util_pkg.get_po_shipment_info(p_attribute_name=> :2,p_line_location_id => :3,p_receipt_quantity => :4); end;";
     
     OracleCallableStatement ocs3 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall3 ,1); 
     String TaxName;
       try
          {
            ocs3.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs3.setString(2,"PoLineTaxName");            
            ocs3.setString(3,PoLineLocationId.toString());   
            ocs3.setString(4,ReceiptQuantity.toString());            
            ocs3.execute();
            TaxName = ocs3.getString(1); 
            ocs3.close();
            return TaxName;
           } 
       catch (SQLException e) 
           { 
            e.printStackTrace();
            String s1 = e.getMessage();
            return s1;
           }
     }//getPoLineTaxName


   // **************************
   // getLineAmtInclTax
   // **************************
    public static final Number getLineAmtInclTax(Number PoLineLocationId, Number ReceiptQuantity, OAApplicationModuleImpl am)
    {

     OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)am.getTransaction();        
     String sqlCall4 = "begin :1 := doi_oaf_util_pkg.get_po_shipment_info(p_attribute_name=> :2,p_line_location_id => :3,p_receipt_quantity => :4); end;";
     OracleCallableStatement ocs4 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall4,1); 
     String LineAmtInclTax;
       try
          {
            ocs4.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs4.setString(2,"LineAmtInclTax");            
            ocs4.setString(3,PoLineLocationId.toString());   
            ocs4.setString(4,ReceiptQuantity.toString());            
            ocs4.execute();
            LineAmtInclTax = ocs4.getString(1);             
            ocs4.close();
            Number nLineAmtInclTax = new Number(LineAmtInclTax);
            return nLineAmtInclTax; 
           } 
       catch (SQLException e) 
           { 
             e.printStackTrace();
             Number n1 = new Number(0);
             return n1;
           }
     }//getLineAmtInclTax


   // **************************
   // getLineAmtExclTax
   // **************************
    public static final Number getLineAmtExclTax(Number PoLineLocationId, Number ReceiptQuantity, OAApplicationModuleImpl am)
    {

     OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)am.getTransaction();        
     String sqlCall5 = "begin :1 := doi_oaf_util_pkg.get_po_shipment_info(p_attribute_name=> :2,p_line_location_id => :3,p_receipt_quantity => :4); end;";
     OracleCallableStatement ocs5 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall5,1); 
     String LineAmtExclTax;
       try
          {
            ocs5.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs5.setString(2,"LineAmtExclTax");            
            ocs5.setString(3,PoLineLocationId.toString());   
            ocs5.setString(4,ReceiptQuantity.toString());            
            ocs5.execute();
            LineAmtExclTax = ocs5.getString(1); 
            ocs5.close();
            Number nLineAmtExclTax  = new Number(LineAmtExclTax);
            return nLineAmtExclTax; 
           } 
       catch (SQLException e) 
           { 
             e.printStackTrace();
            Number n1 = new Number(0);
            return n1;
           }
     }//getLineAmtExclTax



   // **************************
   // getPoLineTaxRate
   // **************************
    public static final Number getPoLineTaxRate(Number PoLineLocationId, Number ReceiptQuantity, OAApplicationModuleImpl am)
    {

     OADBTransaction oadbtransactionimpl = (OADBTransactionImpl)am.getTransaction();        
     String sqlCall3 = "begin :1 := doi_oaf_util_pkg.get_po_shipment_info(p_attribute_name=> :2,p_line_location_id => :3,p_receipt_quantity => :4); end;";
     
     OracleCallableStatement ocs3 = (OracleCallableStatement)oadbtransactionimpl.createCallableStatement(sqlCall3 ,1); 
     String TaxRate;
       try
          {
            ocs3.registerOutParameter(1,Types.VARCHAR, 0, 2000); 
            ocs3.setString(2,"PoLineTaxRate");            
            ocs3.setString(3,PoLineLocationId.toString());   
            ocs3.setString(4,ReceiptQuantity.toString());            
            ocs3.execute();
            TaxRate = ocs3.getString(1); 
            ocs3.close();
            Number nTaxRate   = new Number(TaxRate);
            return nTaxRate;  
           } 
       catch (SQLException e) 
           { 
            e.printStackTrace();
            Number n1 = new Number(0);
            return n1;
           }
     }//getPoLineTaxRate



   // ********************************************************************************************
   // END : Customisation for ERS Project - MCruzado UXC Red Rock Consulting 25 Feb 2015
   // ********************************************************************************************

 
}
