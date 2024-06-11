module lending_contract::loan {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::transfer;
    use std::string::{Self, String};
    use std::option::{Self, Option};

    use lending_contract::offer::{Self, Offer, OfferKey};
    use lending_contract::state::{Self, State};
    use lending_contract::configuration::{Self, Configuration};
    use lending_contract::custodian::{Self, Custodian};
    use lending_contract::version::{Self, Version};

    friend lending_contract::operator;

    const EOfferNotFound: u64 = 1;
    const EOffferIsNotActive: u64 = 2;
    const ECollateralNotValidToMinHealthRatio: u64 = 3;
    const ELoanNotFound: u64 = 4;
    const ESenderIsNotLoanBorrower: u64 = 5;
    const EInvalidLoanStatus: u64 = 6;
    const ENotEnoughBalanceToRepay: u64 = 7;
    const ECanNotRepayExpiredLoan: u64 = 8;
    const ESenderIsInvalid: u64 = 9;

    const MATCHED_STATUS: vector<u8> = b"Matched";
    const FUND_TRANSFERRED_STATUS: vector<u8> = b"FundTransferred";
    const REPAY_STATUS: vector<u8> = b"Repay";
    const BORROWER_PAID_STATUS: vector<u8> = b"BorrowerPaid";
    const FINISHED_STATUS: vector<u8> = b"Finished";

    const DEFAULT_RATE_FACTOR: u64 = 10000;
    const SECOND_IN_YEAR: u64 = 31536000;
    struct Liquidation<phantom T1, phantom T2> has store, drop {
        liquidating_at: u64,
        liquidating_price: u64,
        liquidated_tx: Option<String>,
        liquidated_price: Option<u64>,
    }

    struct LoanKey<phantom T1, phantom T2> has store, copy, drop {
        loan_id: ID,
    }

    struct Loan<phantom T1, phantom T2> has key, store {
        id: UID,
        offer_id: ID,
        interest: u64,
        amount: u64,
        // === seconds ===
        duration: u64,
        collateral: Balance<T2>,
        lender: address,
        borrower: address,
        start_timestamp: u64,
        liquidation: Option<Liquidation<T1,T2>>,
        // === move to hot wallet ===
        repay_balance: Balance<T1>,
        status: String,
    }

    struct RequestLoanEvent has copy, drop {
        loan_id: ID,
        offer_id: ID,
        amount: u64,
        duration: u64,
        collateral_amount: u64, 
        lend_token: String,
        collateral_token: String,
        lender: address,
        borrower: address,
        start_timestamp: u64,
    }

    struct FundTransferredEvent has copy, drop {
        loan_id: ID,
        offer_id: ID,
        amount: u64,
        duration: u64,
        // collateral_amount: u64, 
        lend_token: String,
        collateral_token: String,
        lender: address,
        borrower: address,
        // start_timestamp: u64,
    }

    struct BorrowerPaidEvent has copy, drop {
        loan_id: ID,
        repay_amount: u64,
        collateral_amount: u64, 
        lend_token: String,
        collateral_token: String,
        borrower: address,
    }

    struct FinishedLoanEvent has copy, drop {
        loan_id: ID,
        offer_id: ID,
        repay_to_lender_amount: u64,
        lender: address,
        borrower: address,
    }

    public entry fun take_loan<T1, T2>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        collateral: Coin<T2>,
        lend_token: String,
        collateral_token: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        let current_timestamp = clock::timestamp_ms(clock);
        let borrower = tx_context::sender(ctx);

        let offer_key = offer::new_offer_key<T1>(offer_id);
        assert!(state::contain<OfferKey<T1>, Offer<T1>>(state, offer_key), EOfferNotFound);
        let offer = state::borrow_mut<OfferKey<T1>, Offer<T1>>(state, offer_key);
        assert!(offer::is_available<T1>(offer), EOffferIsNotActive);
        let lender = offer::get_lender<T1>(offer);
        let lend_amount = offer::get_amount<T1>(offer);
        let duration = offer::get_duration<T1>(offer);

        let collateral_amount = coin::value<T2>(&collateral);
    
        assert!(is_valid_collateral(configuration, lend_amount, collateral_amount), ECollateralNotValidToMinHealthRatio);

        let loan = new_loan<T1, T2>(offer, collateral, lender, borrower, current_timestamp, ctx);
        let loan_id = object::id(&loan);
        let loan_key = new_loan_key<T1, T2>(loan_id);


        offer::take_loan(offer);


        state::add<LoanKey<T1, T2>, Loan<T1,T2>>(state, loan_key, loan);
        state::add_loan(state, loan_id, borrower, ctx);

        event::emit(RequestLoanEvent {
            loan_id,
            offer_id,
            amount: lend_amount,
            duration,
            collateral_amount,
            lend_token,
            collateral_token,
            lender,
            borrower,
            start_timestamp: current_timestamp,
        });
    }

    public entry fun fund_transfer<T1, T2>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        loan_id: ID,
        lend_coin: Coin<T1>,
        lend_token: String,
        collateral_token: String,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);

        let sender = tx_context::sender(ctx);
        let hot_wallet = configuration::hot_wallet(configuration);
        assert!(sender == hot_wallet, ESenderIsInvalid);

        let offer_key = offer::new_offer_key<T1>(offer_id);
        assert!(state::contain<OfferKey<T1>, Offer<T1>>(state, offer_key), EOfferNotFound);
        let offer = state::borrow_mut<OfferKey<T1>, Offer<T1>>(state, offer_key);

        let lender = offer::get_lender<T1>(offer);
        let lend_amount = offer::get_amount<T1>(offer);
        let duration = offer::get_duration<T1>(offer);

        let loan_key = new_loan_key<T1, T2>(loan_id);
        assert!(state::contain<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key), ELoanNotFound);
        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);
        assert!(loan.status == string::utf8(MATCHED_STATUS), EInvalidLoanStatus);

        let borrower = loan.borrower;
        transfer::public_transfer(lend_coin, borrower);
        loan.status = string::utf8(FUND_TRANSFERRED_STATUS);

        event::emit(FundTransferredEvent {
            loan_id,
            offer_id,
            amount: lend_amount,
            duration,
            lend_token,
            collateral_token,
            lender,
            borrower,
        });
    }

    public entry fun repay<T1, T2>(
        version: &Version,
        configuration: &Configuration,
        custodian: &mut Custodian<T1>,
        state: &mut State,
        loan_id: ID,
        repay_coin: Coin<T1>,
        lend_token: String,
        collateral_token: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        let current_timestamp = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let hot_wallet = configuration::hot_wallet(configuration); 
        let loan_key = new_loan_key<T1, T2>(loan_id);
        assert!(state::contain<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key), ELoanNotFound);
        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);

        assert!(sender == loan.borrower, ESenderIsNotLoanBorrower);
        assert!(loan.status == string::utf8(FUND_TRANSFERRED_STATUS), EInvalidLoanStatus);
        assert!(loan.start_timestamp + (loan.duration * 1000) > current_timestamp, ECanNotRepayExpiredLoan);

        
        let borrower_fee_percent = configuration::borrower_fee_percent(configuration);
        let borrower_fee_amount = ((loan.amount * borrower_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64 );
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let repay_amount = loan.amount + borrower_fee_amount + interest_amount;
        assert!(coin::value<T1>(&repay_coin) == repay_amount, ENotEnoughBalanceToRepay);

        let repay_balance = coin::into_balance<T1>(repay_coin);
        let borrower_fee_balance = balance::split<T1>(&mut repay_balance, borrower_fee_amount);

        let coin = coin::from_balance(repay_balance, ctx);
        transfer::public_transfer(coin, hot_wallet);
        custodian::add_treasury_balance<T1>(custodian, borrower_fee_balance);

        let collateral_amount = balance::value<T2>(&loan.collateral);
        let collateral_balance = sub_collateral_balance<T1, T2>(loan, collateral_amount);
        transfer::public_transfer(coin::from_balance(collateral_balance, ctx), sender);
        loan.status = string::utf8(BORROWER_PAID_STATUS);

        event::emit(BorrowerPaidEvent {
            loan_id,
            repay_amount,
            collateral_amount,
            lend_token,
            collateral_token,
            borrower: sender,
        });
    }

    public(friend) fun finish_loan<T1, T2>(
        configuration: &Configuration,
        custodian: &mut Custodian<T1>,
        state: &mut State, 
        loan_id: ID,
        repay_coin: Coin<T1>,
        waiting_interest: Coin<T1>,
        ctx: &mut TxContext,
    ) {
        let loan_key = new_loan_key<T1, T2>(loan_id);
        assert!(state::contain<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key), ELoanNotFound);
        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);
        
        let lender_fee_percent = configuration::lender_fee_percent(configuration);
        let lender_fee_amount = ((loan.amount * lender_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64);
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let repay_to_lender_amount = loan.amount + interest_amount - lender_fee_amount;

        assert!(coin::value<T1>(&repay_coin) == repay_to_lender_amount + lender_fee_amount, ENotEnoughBalanceToRepay);

        let lender_fee_coin = coin::split<T1>(&mut repay_coin, lender_fee_amount, ctx);
        let lender_fee_balance = coin::into_balance<T1>(lender_fee_coin);
        coin::join<T1>(&mut repay_coin, waiting_interest);

        transfer::public_transfer(repay_coin, loan.lender);
        custodian::add_treasury_balance<T1>(custodian, lender_fee_balance);
        loan.status = string::utf8(FINISHED_STATUS);

        event::emit(FinishedLoanEvent {
            loan_id,
            offer_id: loan.offer_id,
            repay_to_lender_amount,
            lender: loan.lender,
            borrower: loan.borrower,
        });
    }

    public fun new_loan_key<T1, T2>(
        loan_id: ID,
    ): LoanKey<T1, T2> {
        LoanKey<T1, T2> {
            loan_id
        }
    }

    fun new_loan<T1, T2>(
        offer: &Offer<T1>,
        collateral: Coin<T2>,
        lender: address,
        borrower: address,
        start_timestamp: u64,
        ctx: &mut TxContext,
    ): Loan<T1, T2> {
        Loan<T1, T2> {
            id: object::new(ctx),
            offer_id: offer::get_id<T1>(offer),
            interest: offer::get_interest<T1>(offer),
            amount: offer::get_amount<T1>(offer),
            duration: offer::get_duration<T1>(offer),
            collateral: coin::into_balance<T2>(collateral),
            lender,
            borrower,
            start_timestamp,
            liquidation: option::none<Liquidation<T1, T2>>(),
            repay_balance: balance::zero<T1>(),
            status: string::utf8(MATCHED_STATUS),
        }
    }

    fun add_repay_balance<T1, T2>(
        loan: &mut Loan<T1, T2>,
        repay_balance: Balance<T1>
    ) {
        balance::join<T1>(&mut loan.repay_balance, repay_balance);
    }

    fun sub_repay_balance<T1, T2>(
        loan: &mut Loan<T1, T2>,
        amount: u64,
    ): Balance<T1> {
        balance::split<T1>(&mut loan.repay_balance, amount)
    }

    fun sub_collateral_balance<T1, T2>(
        loan: &mut Loan<T1, T2>,
        amount: u64,
    ): Balance<T2> {
        balance::split<T2>(&mut loan.collateral, amount)
    }

    fun is_valid_collateral(
        configuration: &Configuration,
        lend_amount: u64,
        collateral_amount: u64,
    ): bool {
        //TODO: use price feeds getting price lend token price and collateral token price to check health ratio
        true
    }
}