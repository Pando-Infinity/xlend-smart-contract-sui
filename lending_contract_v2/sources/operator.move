module lending_contract_v2::operator {
    use std::string::String;
    use sui::coin::Coin;
            
    use lending_contract_v2::{
        version::{Version},
        configuration::{Self, Configuration},
        custodian::Custodian,
        state::{Self, State},
        custodian,
        offer::{Self, OfferKey, Offer},
        loan::{Self, LoanKey, Loan},
    };

    const ENotFoundOfferToCancel: u64 = 1;
    const ELoanNotFound: u64 = 2;

    public struct OperatorCap has key, store {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };

        transfer::transfer(operator_cap, @operator);
    }

    public entry fun init_system<T>(
        _: &OperatorCap,
        version: &Version,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64, 
        hot_wallet: address,
        price_time_threshold: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        configuration::new(
            lender_fee_percent,
            borrower_fee_percent,
            min_health_ratio,
            hot_wallet,
            price_time_threshold,
            ctx,
        );
        state::new(ctx);
        custodian::new<T>(ctx);
    }

    public entry fun update_configuration(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64, 
        hot_wallet: address,
        price_time_threshold: u64,
    ) {
        version.assert_current_version();
        configuration.update(
            lender_fee_percent,
            borrower_fee_percent,
            min_health_ratio,
            hot_wallet,
            price_time_threshold,
        );
    }

    public entry fun add_price_feed_id(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        version.assert_current_version();
        configuration.add_price_feed_id(
            coin_symbol,
            price_feed_id,
        );
    }

    public entry fun update_price_feed_id(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        version.assert_current_version();
        configuration.update_price_feed_id(
            coin_symbol,
            price_feed_id,
        );
    }

    public entry fun remove_price_feed_id(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        coin_symbol: String,
    ) {
        version.assert_current_version();
        configuration.remove_price_feed_id(coin_symbol);
    }
    
    public entry fun system_cancel_offer<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        configuration: &Configuration,
        offer_id: ID,
        lend_coin: Coin<T>,
        waiting_interest: Coin<T>,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let offer_key = offer::new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToCancel);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);
        offer.system_cancel_offer(
            configuration,
            lend_coin,
            waiting_interest,
            ctx,
        );
    }

    public entry fun system_finish_loan<LendCoinType, CollateralCoinType>(
        _: &OperatorCap,
        version: &Version,
        configuration: &Configuration,
        custodian: &mut Custodian<LendCoinType>,
        state: &mut State, 
        loan_id: ID,
        repay_coin: Coin<LendCoinType>,
        waiting_interest: Coin<LendCoinType>,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let loan_key = loan::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);
        
        loan.system_finish_loan<LendCoinType, CollateralCoinType>(
            configuration,
            custodian,
            repay_coin,
            waiting_interest,
            ctx,
        );
    }


    public(package) fun new_operator(
        user_address: address,
        ctx: &mut TxContext,
    ) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };
        transfer::transfer(operator_cap, user_address);
    }
}