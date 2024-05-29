module lending_contract::loan {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use std::string::{Self, String};
    use std::option::{Self, Option};

    use lending_contract::offer::{Self, Offer, OfferKey};
    use lending_contract::state::{Self, State};
    use lending_contract::configuration::{Self, Configuration};

    const ENotFoundOffer: u64 = 1;
    const EOfferCanNotBeTakeLoan: u64 = 2;
    const ECollateralNotValidToMinHealthRatio: u64 = 3;

    const MATCHED_STATUS: vector<u8> = b"Matched";
    const FUND_TRANSFERRED_STATUS: vector<u8> = b"FundTransferred";
    const REPAY_STATUS: vector<u8> = b"Repay";
    const BORROWER_PAID_STATUS: vector<u8> = b"BorrowerPaid";

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
        duration: u64,
        collateral: Balance<T2>,
        lender: address,
        borrower: address,
        start_timestamp: u64,
        liquidation: Option<Liquidation<T1,T2>>,
        status: String,
    }

    struct FundTransferredEvent has copy, drop {
        loan_id: ID,
        offer_id: ID,
        amount: u64,
        duration: u64,
        collateral: u64, 
        lend_token: String,
        collateral_token: String,
        lender: address,
        borrower: address,
        start_timestamp: u64,
    }

    public entry fun take_loan<T1, T2>(
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        collateral: Coin<T2>,
        lend_token: String,
        collateral_token: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let current_timestamp = clock::timestamp_ms(clock);
        let borrower = tx_context::sender(ctx);

        let offer_key = offer::new_offer_key<T1>(offer_id);
        assert!(state::contain<OfferKey<T1>, Offer<T1>>(state, offer_key), ENotFoundOffer);
        let offer = state::borrow_mut<OfferKey<T1>, Offer<T1>>(state, offer_key);
        assert!(offer::can_be_take_loan<T1>(offer), EOfferCanNotBeTakeLoan);
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

        event::emit(FundTransferredEvent {
            loan_id,
            offer_id,
            amount: lend_amount,
            duration,
            collateral: collateral_amount,
            lend_token,
            collateral_token,
            lender,
            borrower,
            start_timestamp: current_timestamp,
        })
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
            status: string::utf8(FUND_TRANSFERRED_STATUS),
        }
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