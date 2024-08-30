module lending_contract_v2::loan {
    use sui::{
        coin::{Coin, CoinMetadata},
        clock::Clock,
    };
    use lending_contract_v2::{
        offer_registry::{Self, Offer, OfferKey},
        state::State,
        configuration::Configuration,
        custodian::Custodian,
        version::Version,
        loan_registry::{Self, Loan, LoanKey},
        price_info::PriceInfoObject,
        utils,
    };

    use fun lending_contract_v2::price_feed::is_valid_price_info_object as PriceInfoObject.is_valid;

    const EOfferNotFound: u64 = 1;
    const EOffferIsNotActive: u64 = 2;
    const ELoanNotFound: u64 = 3;
    const EPriceInfoObjectLendingIsInvalid: u64 = 4;
    const EPriceInfoObjectCollateralIsInvalid: u64 = 5;

    public entry fun take_loan<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        collateral: Coin<CollateralCoinType>,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject<LendCoinType>,
        price_info_object_collateral: &PriceInfoObject<CollateralCoinType>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        let borrower = ctx.sender();

        assert!(price_info_object_lending.is_valid<LendCoinType>(configuration, lend_coin_metadata), EPriceInfoObjectLendingIsInvalid);
        assert!(price_info_object_collateral.is_valid<CollateralCoinType>(configuration, collateral_coin_metadata), EPriceInfoObjectCollateralIsInvalid);
        
        let offer_key = offer_registry::new_offer_key<LendCoinType>(offer_id);
        assert!(state.contain<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key), EOfferNotFound);
        let offer = { state.borrow_mut<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key) };
        assert!(offer.is_available<LendCoinType>(), EOffferIsNotActive);

        let loan = loan_registry::new_loan(
            configuration,
            collateral,
            offer,
            borrower,
            lend_coin_metadata,
            collateral_coin_metadata,
            price_info_object_lending,
            price_info_object_collateral,
            current_timestamp,
            clock,
            ctx,
        );

        let loan_id = object::id(&loan);
        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);

        offer.take_loan();
        state.add<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType,CollateralCoinType>>(loan_key, loan);
        state.add_loan(loan_id, borrower, ctx);
    }

    public entry fun repay<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        custodian: &mut Custodian<LendCoinType>,
        state: &mut State,
        loan_id: ID,
        repay_coin: Coin<LendCoinType>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        let lend_token = utils::get_type<LendCoinType>();
        let collateral_token = utils::get_type<CollateralCoinType>();

        loan.repay(
            custodian,
            repay_coin,
            configuration.borrower_fee_percent(),
            lend_token,
            collateral_token,
            configuration.hot_wallet(),
            ctx.sender(),
            current_timestamp,
            ctx,
        );
    }

    public entry fun withdraw_collateral_loan_offer<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        withdraw_amount: u64,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject<LendCoinType>,
        price_info_object_collateral: &PriceInfoObject<CollateralCoinType>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        
        assert!(price_info_object_lending.is_valid<LendCoinType>(configuration, lend_coin_metadata), EPriceInfoObjectLendingIsInvalid);
        assert!(price_info_object_collateral.is_valid<CollateralCoinType>(configuration, collateral_coin_metadata), EPriceInfoObjectCollateralIsInvalid);

        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        loan.withdraw_collateral<LendCoinType, CollateralCoinType>(
            configuration,
            lend_coin_metadata,
            collateral_coin_metadata,
            price_info_object_lending,
            price_info_object_collateral,
            withdraw_amount,
            current_timestamp,
            clock,
            ctx,
        );
    }

    public entry fun deposit_collateral_loan_offer<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        deposit_coin: Coin<CollateralCoinType>,
        clock: &Clock,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        let lend_token = utils::get_type<LendCoinType>();
        let collateral_token = utils::get_type<CollateralCoinType>();
        
        let loan_key = loan_registry::new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        let ( offer_id ) = {
            assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
            let loan = state.borrow<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);
            loan.offer_id()
        };

        let ( asset_tier ) = {
            let offer_key = offer_registry::new_offer_key<LendCoinType>(offer_id);
            assert!(state.contain<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key), EOfferNotFound);
            let offer = state.borrow<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key);
            offer.asset_tier()
        };

        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);
        loan.deposit_collateral(
            deposit_coin,
            asset_tier,
            configuration.lender_fee_percent(),
            configuration.borrower_fee_percent(),
            lend_token,
            collateral_token,
            current_timestamp,
        );
    }
}