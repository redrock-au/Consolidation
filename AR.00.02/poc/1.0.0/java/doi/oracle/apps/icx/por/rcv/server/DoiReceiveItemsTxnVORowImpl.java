package doi.oracle.apps.icx.por.rcv.server;
/* $Header: svn://d02584/consolrepos/branches/AR.00.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveItemsTxnVORowImpl.java 342 2017-05-09 00:40:24Z svnuser $ */
import doi.oracle.apps.util.DoiUtil;
import oracle.apps.fnd.framework.server.OAApplicationModuleImpl;
import oracle.apps.icx.por.rcv.server.ReceiveItemsTxnVORowImpl;
import oracle.jbo.domain.Date;
import oracle.jbo.domain.Number;
import oracle.jbo.server.AttributeDefImpl;
import oracle.jbo.server.ViewDefImpl;

public class DoiReceiveItemsTxnVORowImpl extends ReceiveItemsTxnVORowImpl
{

    public DoiReceiveItemsTxnVORowImpl()
    {
    }

    protected void doiDebug(String s)
    {
        DoiUtil.debug(toString(), s, (OAApplicationModuleImpl)getApplicationModule());
    }

    public Date getReceiptDate()
    {
        return super.getReceiptDate();
    }

    public void setReceiptDate(Date date)
    {
        super.setReceiptDate(date);
    }

    public Date getExpectedReceiptDate()
    {
        return super.getExpectedReceiptDate();
    }

    public void setExpectedReceiptDate(Date date)
    {
        super.setExpectedReceiptDate(date);
    }

    public Number getReceiptQuantity()
    {
        return super.getReceiptQuantity();
    }

    public void setReceiptQuantity(Number number)
    {
        super.setReceiptQuantity(number);
    }

    public String getUnit()
    {
        return super.getUnit();
    }

    public void setUnit(String s)
    {
        super.setUnit(s);
    }

    public String getUnitTl()
    {
        return super.getUnitTl();
    }

    public void setUnitTl(String s)
    {
        super.setUnitTl(s);
    }

    public String getUnitClass()
    {
        return super.getUnitClass();
    }

    public void setUnitClass(String s)
    {
        super.setUnitClass(s);
    }

    public String getSource()
    {
        return super.getSource();
    }

    public void setSource(String s)
    {
        super.setSource(s);
    }

    public Number getSupplierId()
    {
        return super.getSupplierId();
    }

    public void setSupplierId(Number number)
    {
        super.setSupplierId(number);
    }

    public String getItemDescription()
    {
        return super.getItemDescription();
    }

    public void setItemDescription(String s)
    {
        super.setItemDescription(s);
    }

    public Number getItemId()
    {
        return super.getItemId();
    }

    public void setItemId(Number number)
    {
        super.setItemId(number);
    }

    public String getReqNumber()
    {
        return super.getReqNumber();
    }

    public void setReqNumber(String s)
    {
        doiDebug("-> setReqNumber()");
        super.setReqNumber(s);
    }

    public Number getReqLineId()
    {
        return super.getReqLineId();
    }

    public void setReqLineId(Number number)
    {
        super.setReqLineId(number);
    }

    public Number getReqHeaderId()
    {
        return super.getReqHeaderId();
    }

    public void setReqHeaderId(Number number)
    {
        super.setReqHeaderId(number);
    }

    public String getOrderNumber()
    {
        return super.getOrderNumber();
    }

    public void setOrderNumber(String s)
    {
        super.setOrderNumber(s);
    }

    public Number getPoHeaderId()
    {
        return super.getPoHeaderId();
    }

    public void setPoHeaderId(Number number)
    {
        super.setPoHeaderId(number);
    }

    public Number getPoLineLocationId()
    {
        return super.getPoLineLocationId();
    }

    public void setPoLineLocationId(Number number)
    {
        super.setPoLineLocationId(number);
    }

    public Number getPoDistributionId()
    {
        return super.getPoDistributionId();
    }

    public void setPoDistributionId(Number number)
    {
        super.setPoDistributionId(number);
    }

    public Number getOrganizationId()
    {
        return super.getOrganizationId();
    }

    public void setOrganizationId(Number number)
    {
        super.setOrganizationId(number);
    }

    public String getUssglTransactionCode()
    {
        return super.getUssglTransactionCode();
    }

    public void setUssglTransactionCode(String s)
    {
        super.setUssglTransactionCode(s);
    }

    public String getItemComments()
    {
        return super.getItemComments();
    }

    public void setItemComments(String s)
    {
        super.setItemComments(s);
    }

    public String getPackingSlip()
    {
        return super.getPackingSlip();
    }

    public void setPackingSlip(String s)
    {
        super.setPackingSlip(s);
    }

    public String getWaybillAirbillNum()
    {
        return super.getWaybillAirbillNum();
    }

    public void setWaybillAirbillNum(String s)
    {
        super.setWaybillAirbillNum(s);
    }

    public String getOrderTypeCode()
    {
        return super.getOrderTypeCode();
    }

    public void setOrderTypeCode(String s)
    {
        super.setOrderTypeCode(s);
    }

    public Number getKeyId()
    {
        return super.getKeyId();
    }

    public void setKeyId(Number number)
    {
        super.setKeyId(number);
    }

    public String getItemNumber()
    {
        return super.getItemNumber();
    }

    public void setItemNumber(String s)
    {
        super.setItemNumber(s);
    }

    public String getReceiptComments()
    {
        return super.getReceiptComments();
    }

    public void setReceiptComments(String s)
    {
        super.setReceiptComments(s);
    }

    public Number getSupplierSiteId()
    {
        return super.getSupplierSiteId();
    }

    public void setSupplierSiteId(Number number)
    {
        super.setSupplierSiteId(number);
    }

    public Boolean getDateWarned()
    {
        return super.getDateWarned();
    }

    public void setDateWarned(Boolean boolean1)
    {
        super.setDateWarned(boolean1);
    }

    public String getRequestorId()
    {
        return super.getRequestorId();
    }

    public void setRequestorId(String s)
    {
        super.setRequestorId(s);
    }

    public String getMatchingBasis()
    {
        return super.getMatchingBasis();
    }

    public void setMatchingBasis(String s)
    {
        super.setMatchingBasis(s);
    }

    public Number getOperatingUnitId()
    {
        return super.getOperatingUnitId();
    }

    public void setOperatingUnitId(Number number)
    {
        super.setOperatingUnitId(number);
    }

    public Boolean getIsAmountBased()
    {
        return super.getIsAmountBased();
    }

    public void setIsAmountBased(Boolean boolean1)
    {
        super.setIsAmountBased(boolean1);
    }


   // **********************************************************************
   // BEGIN Updates for ERS Project MCruzado UXC Red Rock Consulting 28Jan15
   // **********************************************************************


   // ************************************* 
   // getAttrInvokeAccessor
   // ************************************* 
    protected Object getAttrInvokeAccessor(int i, AttributeDefImpl attributedefimpl)
        throws Exception
    {
          if (i == CMSCONTRACTNUMBER)
              {
              return getCmsContractNumber();
              }
     else if (i == PAYONCODE)
              {
              return getPayOnCode();
              }
     else if (i == POLINEUNITPRICE)
              {
              return getPoLineUnitPrice();
              }
     else if (i == LINEAMTEXCLTAX)
              {
              return getLineAmtExclTax();
              }
     else if (i == LINEAMTINCLTAX)
              {
              return getLineAmtInclTax();
              }
     else if (i == POLINETAXNAME)
              {
              return getPoLineTaxName();
              }
     else if (i == POLINETAXRATE)
              {
              return getPoLineTaxRate();
              }
     else  
              return super.getAttrInvokeAccessor(i, attributedefimpl);
     }


   // ************************************* 
   // setAttrInvokeAccessor
   // ************************************* 
    protected void setAttrInvokeAccessor(int i, Object obj, AttributeDefImpl attributedefimpl)
        throws Exception
    {
       if (i == CMSCONTRACTNUMBER)
              { 
               setCmsContractNumber((String)obj);
               return;
               }
   else if(i == PAYONCODE)
              {
                setPayOnCode((String)obj);
                return;
              }
   else if (i == POLINEUNITPRICE)
              {
                setPoLineUnitPrice((Number)obj);
                return;
              }
   else if (i == LINEAMTEXCLTAX)
              {
                setLineAmtExclTax((Number)obj);
                return;
              }
   else if (i == LINEAMTINCLTAX)
             {
                setLineAmtInclTax((Number)obj);
                return;
              }
   else if (i == POLINETAXNAME)
              {
                setPoLineTaxName((String)obj);
                return;
              }
   else if (i == POLINETAXRATE)
             {
                setPoLineTaxRate((Number)obj);
                return;
              }
   else
        {
            super.setAttrInvokeAccessor(i, obj, attributedefimpl);
            return;
        }
    }


   // ************************************* 
   // getCmsContractNumber
   // ************************************* 

    public String getCmsContractNumber()
    {
        doiDebug("-> getCmsContractNumber()");
        return DoiUtil.getCmsNumber(getPoHeaderId(), (OAApplicationModuleImpl)getApplicationModule());
    }

    public void setCmsContractNumber(String s)
    {
        setAttributeInternal(CMSCONTRACTNUMBER, s);
    }

 
   // **************************
   // getPayOnCode
   // **************************
   public String getPayOnCode()
    {
       //return (String)getAttributeInternal(PAYONCODE);  
       doiDebug("-> getPayOnCode()");
       return DoiUtil.getPayOnCode(getPoLineLocationId(), getReceiptQuantity(),(OAApplicationModuleImpl)getApplicationModule());           
    }

    public void setPayOnCode(String s)
    {
        setAttributeInternal(PAYONCODE, s);
    }
 

   // **************************
   // getPoLineUnitPrice
   // **************************
   public Number getPoLineUnitPrice()
    {
       //return (Number)getAttributeInternal(POLINEUNITPRICE);
       doiDebug("-> getPoLineUnitPrice()");
       return (Number) DoiUtil.getPoLineUnitPrice(getPoLineLocationId(), getReceiptQuantity(),(OAApplicationModuleImpl)getApplicationModule());
    }
    public void setPoLineUnitPrice(Number number)
    {
        setAttributeInternal(POLINEUNITPRICE, number);
    }

   // **************************
   // getLineAmtExclTax
   // **************************
    public Number getLineAmtExclTax()
    {
        //return (Number)getAttributeInternal(LINEAMTEXCLTAX);
       doiDebug("-> getLineAmtExclTax()");
       return (Number) DoiUtil.getLineAmtExclTax(getPoLineLocationId(), getReceiptQuantity(),(OAApplicationModuleImpl)getApplicationModule());
    }

    public void setLineAmtExclTax(Number number)
    {
        setAttributeInternal(LINEAMTEXCLTAX, number);
    }


   // **************************
   // getLineAmtInclTax
   // **************************
    public Number getLineAmtInclTax()
    {
        //return (Number)getAttributeInternal(LINEAMTINCLTAX);
       doiDebug("-> getLineAmtInclTax()");
       return (Number) DoiUtil.getLineAmtInclTax(getPoLineLocationId(), getReceiptQuantity(),(OAApplicationModuleImpl)getApplicationModule());
    }

    public void setLineAmtInclTax(Number number)
    {
        setAttributeInternal(LINEAMTINCLTAX, number);
    }

   // **************************
   // getPoLineTaxName
   // **************************
    public String getPoLineTaxName()
    {
        //return (String)getAttributeInternal(POLINETAXNAME);
       doiDebug("-> getPoLineTaxName()");
       return DoiUtil.getPoLineTaxName(getPoLineLocationId(), getReceiptQuantity(),(OAApplicationModuleImpl)getApplicationModule());
    }

    public void setPoLineTaxName(String s)
    {
        setAttributeInternal(POLINETAXNAME, s);
    }

   // **************************
   // getPoLineTaxRate
   // **************************
    public Number getPoLineTaxRate()
    {
       //return (Number)getAttributeInternal(POLINETAXRATE);
       doiDebug("-> getPoLineTaxRate()");
       return (Number) DoiUtil.getPoLineTaxRate(getPoLineLocationId(), getReceiptQuantity(),(OAApplicationModuleImpl)getApplicationModule());
    }

    public void setPoLineTaxRate(Number number)
    {
        setAttributeInternal(POLINETAXRATE, number);
    }

   
   // **********************************************************************
   // Attribute Index Declaration : MCruzado UXC Red Rock Consulting 28Jan15
   // **********************************************************************
    protected static final int MAXATTRCONST;
    protected static final int CMSCONTRACTNUMBER;
    protected static final int PAYONCODE;
    protected static final int POLINEUNITPRICE;
    protected static final int LINEAMTEXCLTAX;
    protected static final int LINEAMTINCLTAX;
    protected static final int POLINETAXNAME;
    protected static final int POLINETAXRATE;


    static 
    {
        MAXATTRCONST = ViewDefImpl.getMaxAttrConst("oracle.apps.icx.por.rcv.server.ReceiveItemsTxnVO");
        CMSCONTRACTNUMBER = MAXATTRCONST;
        PAYONCODE = MAXATTRCONST + 1;
        POLINEUNITPRICE = MAXATTRCONST + 2;
        LINEAMTEXCLTAX = MAXATTRCONST + 3;
        LINEAMTINCLTAX = MAXATTRCONST + 4;
        POLINETAXNAME = MAXATTRCONST + 5;
        POLINETAXRATE = MAXATTRCONST + 6;

    }

   // **********************************************************************
   // END Updates for ERS Project MCruzado UXC Red Rock Consulting 28Jan15
   // **********************************************************************


}
