module lending_contract_v2::operator {
    use std::string::String;
    use sui::coin::{Coin, CoinMetadata};
    use sui::clock::Clock;

    use pyth::price_info::PriceInfoObject;    
    use lending_contract_v2::{
        version::{Version},
        configuration::{Self, Configuration},
        custodian::Custodian,
        state::{Self, State},
        custodian,
        asset_tier::{Self, AssetTierKey, AssetTier},
        offer_registry::{Self, OfferKey, Offer},
        loan_registry::{Self, Loan, LoanKey},
        utils,
    };
    use fun lending_contract_v2::price_feed::is_valid_price_info_object as PriceInfoObject.is_valid;

    const ENotFoundOfferToCancel: u64 = 1;
    const ELoanNotFound: u64 = 2;
    const EPriceInfoObjectLendingIsInvalid: u64 = 3;
    const EPriceInfoObjectCollateralIsInvalid: u64 = 4;
    const ELendCoinIsInvalid: u64 = 5;
    const ECollateralCoinIsInvalid: u64 = 6;

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
        max_offer_interest: u64,
        min_health_ratio: u64, 
        hot_wallet: address,
        price_time_threshold: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        configuration::new(
            lender_fee_percent,
            borrower_fee_percent,
            max_offer_interest,
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
        max_offer_interest: u64,
        min_health_ratio: u64, 
        hot_wallet: address,
        price_time_threshold: u64,
    ) {
        version.assert_current_version();
        configuration.update(
            lender_fee_percent,
            borrower_fee_percent,
            max_offer_interest,
            min_health_ratio,
            hot_wallet,
            price_time_threshold,
        );
    }

    public entry fun add_configuration_token<T>(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
        is_lend_token: bool,
    ) {
        version.assert_current_version();
        configuration.add_token<T>(
            coin_symbol,
            price_feed_id,
            is_lend_token,
        );
    }

    public entry fun remove_configuration_token<T>(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        coin_symbol: String,
    ) {
        version.assert_current_version();
        configuration.remove_token<T>(coin_symbol);
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

    public entry fun init_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
        amount: u64,
        duration: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let lend_token = utils::get_type<T>();
        let asset_tier = asset_tier::new<T>(
            name,
            amount,
            duration,
            lend_token,
            ctx,
        );
        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        state.add<AssetTierKey<T>, AssetTier<T>>(asset_tier_key, asset_tier);
    }

    public entry fun update_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
        amount: u64,
        duration: u64,
    ) {
        version.assert_current_version();

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        let asset_tier = state.borrow_mut<AssetTierKey<T>, AssetTier<T>>(asset_tier_key);

        asset_tier.update<T>(
            amount,
            duration,
        );
    }

    public entry fun delete_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
    ) {
        version.assert_current_version();

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        let asset_tier = state.remove<AssetTierKey<T>, AssetTier<T>>(asset_tier_key);

        asset_tier.delete();
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

        let offer_key = offer_registry::new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToCancel);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);
        offer.system_cancel_offer(
            lend_coin,
            waiting_interest,
            ctx,
        );
    }

    public entry fun system_fund_transfer<LendCoinType, CollateralCoinType>(
        _: &OperatorCap,
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        lend_coin: Coin<LendCoinType>,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        
        let lend_token = utils::get_type<LendCoinType>();
        let collateral_token = utils::get_type<CollateralCoinType>();

        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        loan.system_fund_transfer<LendCoinType, CollateralCoinType>(
            lend_coin,
            lend_token,
            collateral_token,
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

        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);
        
        loan.system_finish_loan<LendCoinType, CollateralCoinType>(
            custodian,
            repay_coin,
            waiting_interest,
            configuration.lender_fee_percent(),
            ctx,
        );
    }

    public entry fun start_liquidate_loan_offer_health<LendCoinType, CollateralCoinType>(
        _: &OperatorCap,
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        assert!(configuration.is_valid_lend_coin<LendCoinType>(), ELendCoinIsInvalid);
        assert!(configuration.is_valid_collateral_coin<CollateralCoinType>(), ECollateralCoinIsInvalid);
        assert!(price_info_object_lending.is_valid<LendCoinType>(configuration, lend_coin_metadata), EPriceInfoObjectLendingIsInvalid);
        assert!(price_info_object_collateral.is_valid<CollateralCoinType>(configuration, collateral_coin_metadata), EPriceInfoObjectCollateralIsInvalid);

        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        loan.start_liquidate_loan_offer_health<LendCoinType, CollateralCoinType>(
            configuration,
            lend_coin_metadata,
            collateral_coin_metadata,
            price_info_object_lending,
            price_info_object_collateral,
            configuration.hot_wallet(),
            clock,
            ctx,
        );
    }

    public entry fun start_liquidate_loan_offer_expired<LendCoinType, CollateralCoinType>(
        _: &OperatorCap,
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);      

        loan.start_liquidate_loan_offer_expired<LendCoinType, CollateralCoinType>(
            configuration.hot_wallet(),
            clock,
            ctx
        );
    }

    public entry fun system_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
        _: &OperatorCap,
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        remaining_fund_to_borrower: Coin<LendCoinType>,
        collateral_swapped_amount: u64,
        liquidated_price: u64,
        liquidated_tx: String,
    ) {
        version.assert_current_version();

        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        loan.system_liquidate_loan_offer(
            remaining_fund_to_borrower,
            configuration.borrower_fee_percent(),
            collateral_swapped_amount,
            liquidated_price,
            liquidated_tx,
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