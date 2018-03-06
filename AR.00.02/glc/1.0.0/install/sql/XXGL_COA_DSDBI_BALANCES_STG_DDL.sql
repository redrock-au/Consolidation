-- $Header :$

CREATE TABLE fmsmgr.xxgl_coa_dsdbi_balances_stg
   (    record_id number,
        name varchar2(500),
        actual_flag varchar2(500),
        period_name varchar2(500),
        code_combination_id number,
        old_segment1 varchar2(500),
        old_segment2 varchar2(500),
        old_segment3 varchar2(500),
        old_segment4 varchar2(500),
        old_segment5 varchar2(500),
        open_balance number,
        debit number,
        credit number,
        net_movement number,
        close_balance number,
        close_balance_dr number,
        close_balance_cr number,
        currency_code varchar2(500),
        status varchar2(500),
        created_by number,
        creation_date date,
        last_updated_by number,
        last_update_date date,
        run_id number,
        run_phase_id number
   );

CREATE SYNONYM xxgl_coa_dsdbi_balances_stg FOR fmsmgr.xxgl_coa_dsdbi_balances_stg;   