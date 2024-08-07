module lending_contract_v2::loan {
    use sui::{
        balance::{Self, Balance},
        coin::{Coin, CoinMetadata},
        clock::Clock,
        event,
    };
    use std::string::String;
    use pyth::price_info::PriceInfoObject;
    use lending_contract_v2::{
        offer::{Self, Offer, OfferKey},
        state::State,
        configuration::Configuration,
        custodian::Custodian,
        version::Version,
    };

    use fun lending_contract_v2::price_feed::is_valid_price_info_object as PriceInfoObject.is_valid;
    use fun lending_contract_v2::price_feed::get_value_by_usd as PriceInfoObject.get_value_by_usd;
    use fun std::string::utf8 as vector.to_string;
    use fun std::string::from_ascii as std::ascii::String.to_string;
    use fun sui::coin::from_balance as Balance.to_coin;

    const EOfferNotFound: u64 = 1;
    const EOffferIsNotActive: u64 = 2;
    const ECollateralNotValidToMinHealthRatio: u64 = 3;
    const ELoanNotFound: u64 = 4;
    const ESenderIsNotLoanBorrower: u64 = 5;
    const EInvalidLoanStatus: u64 = 6;
    const ENotEnoughBalanceToRepay: u64 = 7;
    const ECanNotRepayExpiredLoan: u64 = 8;
    const ESenderIsInvalid: u64 = 9;
    const ELiquidationIsNull: u64 = 10;
    const EInvalidCoinInput: u64 = 11;
    const EPriceInfoObjectLendingIsInvalid: u64 = 12;
    const EPriceInfoObjectCollateralIsInvalid: u64 = 13;
    const ECollateralIsInsufficient: u64 = 14;

    const MATCHED_STATUS: vector<u8> = b"Matched";
    const FUND_TRANSFERRED_STATUS: vector<u8> = b"FundTransferred";
    const BORROWER_PAID_STATUS: vector<u8> = b"BorrowerPaid";
    const LIQUIDATING_STATUS: vector<u8> = b"Liquidating";
    const LIQUIDATED_STATUS: vector<u8> = b"Liquidated";
    const FINISHED_STATUS: vector<u8> = b"Finished";

    const DEFAULT_RATE_FACTOR: u64 = 10000;
    const SECOND_IN_YEAR: u64 = 31536000;

    public struct Liquidation<phantom T1, phantom T2> has store, drop {
        liquidating_at: u64,
        liquidating_price: u64,
        liquidated_tx: Option<String>,
        liquidated_price: Option<u64>,
    }

    public struct LoanKey<phantom T1, phantom T2> has store, copy, drop {
        loan_id: ID,
    }

    public struct Loan<phantom T1, phantom T2> has key, store {
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

    public struct RequestLoanEvent has copy, drop {
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

    public struct FundTransferredEvent has copy, drop {
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

    public struct BorrowerPaidEvent has copy, drop {
        loan_id: ID,
        repay_amount: u64,
        collateral_amount: u64, 
        lend_token: String,
        collateral_token: String,
        borrower: address,
    }

    public struct FinishedLoanEvent has copy, drop {
        loan_id: ID,
        offer_id: ID,
        repay_to_lender_amount: u64,
        lender: address,
        borrower: address,
    }

    public struct WithdrawCollateralEvent has copy, drop {
        loan_id: ID,
        borrower: address,
        withdraw_amount: u64,
        remaining_collateral_amount: u64,
        timestamp: u64,
    }

    public struct DepositCollateralEvent has copy, drop {
        tier_id: ID,
        lend_offer_id: ID,
        interest: u64,
        borrow_amount: u64,
        lender_fee_percent: u64,
        duration: u64,
        lend_mint_token: String,
        lender: address,
        loan_offer_id: ID,
        borrower: address,
        collateral_mint_token: String,
        collateral_amount: u64,
        status: String,
        borrower_fee_percent: u64,
        timestamp: u64,
    }
    
    public struct LiquidatingCollateralEvent has copy, drop {
        loan_id: ID,
        liquidating_price: u64,
        liquidating_at: u64,
    }

    public struct LiquidatedCollateralEvent has copy, drop {
        lender: address,
        borrower: address,
        loan_id: ID,
        collateral_swapped_amount: u64,
        status: String,
        liquidated_price: u64,
        liquidated_tx: String,
        remaining_fund_to_borrower: u64,
    }

    public entry fun take_loan<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        collateral: Coin<CollateralCoinType>,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let lend_coin_symbol = lend_coin_metadata.get_symbol().to_string();
        let collateral_coin_symbol = collateral_coin_metadata.get_symbol().to_string();

        assert!(price_info_object_lending.is_valid<LendCoinType>(configuration, lend_coin_metadata), EPriceInfoObjectLendingIsInvalid);
        assert!(price_info_object_collateral.is_valid<CollateralCoinType>(configuration, collateral_coin_metadata), EPriceInfoObjectCollateralIsInvalid);

        let current_timestamp = clock.timestamp_ms();
        let borrower = ctx.sender();

        let offer_key = offer::new_offer_key<LendCoinType>(offer_id);
        assert!(state.contain<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key), EOfferNotFound);
        let offer = state.borrow_mut<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key);
        assert!(offer.is_available<LendCoinType>(), EOffferIsNotActive);
        let lender = offer.lender<LendCoinType>();
        let lend_amount = offer.amount<LendCoinType>();
        let duration = offer.duration<LendCoinType>();

        let collateral_amount = collateral.value<CollateralCoinType>();
    
        assert!(is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
            configuration, 
            lend_amount, 
            collateral_amount, 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock,
        ), ECollateralNotValidToMinHealthRatio);

        let loan = new_loan<LendCoinType, CollateralCoinType>(offer, collateral, lender, borrower, current_timestamp, ctx);
        let loan_id = object::id(&loan);
        let loan_key = new_loan_key<LendCoinType, CollateralCoinType>(loan_id);


        offer.take_loan();


        state.add<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType,CollateralCoinType>>(loan_key, loan);
        state.add_loan(loan_id, borrower, ctx);

        event::emit(RequestLoanEvent {
            loan_id,
            offer_id,
            amount: lend_amount,
            duration,
            collateral_amount,
            lend_token: lend_coin_symbol,
            collateral_token: collateral_coin_symbol,
            lender,
            borrower,
            start_timestamp: current_timestamp,
        });
    }

    public entry fun repay<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        custodian: &mut Custodian<LendCoinType>,
        state: &mut State,
        loan_id: ID,
        repay_coin: Coin<LendCoinType>,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        let sender = ctx.sender();
        let hot_wallet = configuration.hot_wallet(); 
        let loan_key = new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        assert!(sender == loan.borrower, ESenderIsNotLoanBorrower);
        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);
        assert!(loan.start_timestamp + (loan.duration * 1000) > current_timestamp, ECanNotRepayExpiredLoan);

        
        let borrower_fee_percent = configuration.borrower_fee_percent();
        let borrower_fee_amount = ((loan.amount * borrower_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64 );
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let repay_amount = loan.amount + borrower_fee_amount + interest_amount;
        assert!(repay_coin.value<LendCoinType>() == repay_amount, ENotEnoughBalanceToRepay);

        let mut repay_balance = repay_coin.into_balance<LendCoinType>();
        let borrower_fee_balance = repay_balance.split<LendCoinType>(borrower_fee_amount);

        transfer::public_transfer(repay_balance.to_coin(ctx), hot_wallet);
        custodian.add_treasury_balance<LendCoinType>(borrower_fee_balance);

        let collateral_amount = loan.collateral.value<CollateralCoinType>();
        let collateral_balance = loan.collateral.split<CollateralCoinType>(collateral_amount);
        transfer::public_transfer(collateral_balance.to_coin(ctx), sender);

        loan.status = BORROWER_PAID_STATUS.to_string();

        let lend_token = lend_coin_metadata.get_symbol<LendCoinType>().to_string();
        let collateral_token = collateral_coin_metadata.get_symbol<CollateralCoinType>().to_string();
        event::emit(BorrowerPaidEvent {
            loan_id,
            repay_amount,
            collateral_amount,
            lend_token,
            collateral_token,
            borrower: sender,
        });
    }

    public entry fun withdraw_collateral_loan_offer<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        withdraw_amount: u64,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        let sender = ctx.sender();
        
        assert!(price_info_object_lending.is_valid<LendCoinType>(configuration, lend_coin_metadata), EPriceInfoObjectLendingIsInvalid);
        assert!(price_info_object_collateral.is_valid<CollateralCoinType>(configuration, collateral_coin_metadata), EPriceInfoObjectCollateralIsInvalid);

        let loan_key = new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);
        
        let lend_amount = loan.amount;
        let collateral_amount = loan.collateral.value<CollateralCoinType>();

        assert!(collateral_amount >= withdraw_amount, ECollateralIsInsufficient);

        let remaining_collateral_amount = collateral_amount - withdraw_amount;

        assert!(is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
            configuration, 
            lend_amount, 
            remaining_collateral_amount, 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock, 
        ), ECollateralNotValidToMinHealthRatio);

        let collateral_balance = loan.collateral.split<CollateralCoinType>(withdraw_amount);
        transfer::public_transfer(collateral_balance.to_coin<CollateralCoinType>(ctx), sender);

        event::emit(WithdrawCollateralEvent {
            loan_id,
            borrower: loan.borrower,
            withdraw_amount,
            remaining_collateral_amount,
            timestamp: current_timestamp,
        });
    }

    public entry fun deposit_collateral_loan_offer<LendCoinType, CollateralCoinType>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        deposit_coin: Coin<CollateralCoinType>,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        clock: &Clock,
    ) {
        version.assert_current_version();

        let current_timestamp = clock.timestamp_ms();
        
        let loan_key = new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let ( offer_id ) = {
            let loan = state.borrow<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);
            loan.offer_id 
        };

        let ( asset_tier ) = {
            let offer_key = offer::new_offer_key<LendCoinType>(offer_id);
            assert!(state.contain<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key), EOfferNotFound);
            let offer = state.borrow<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key);
            offer.asset_tier()
        };

        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);

        let lend_token = lend_coin_metadata.get_symbol<LendCoinType>().to_string();
        let collateral_token = collateral_coin_metadata.get_symbol<CollateralCoinType>().to_string();

        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);

        loan.collateral.join(deposit_coin.into_balance<CollateralCoinType>());
        let total_collateral_amount = loan.collateral.value<CollateralCoinType>();

        event::emit(DepositCollateralEvent {
            tier_id: asset_tier,
            lend_offer_id: loan.offer_id,
            interest: loan.interest,
            borrow_amount: loan.amount,
            lender_fee_percent: configuration.lender_fee_percent(),
            duration: loan.duration,
            lend_mint_token: lend_token,
            lender: loan.lender,
            loan_offer_id: loan_id,
            borrower: loan.borrower,
            collateral_mint_token: collateral_token,
            collateral_amount: total_collateral_amount,
            status: loan.status,
            borrower_fee_percent: configuration.borrower_fee_percent(),
            timestamp: current_timestamp,
            }
        );
    }

    public(package) fun system_fund_transfer<LendCoinType, CollateralCoinType>(
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        loan_id: ID,
        lend_coin: Coin<LendCoinType>,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        _ctx: &mut TxContext,
    ) {
        let sender = _ctx.sender();
        let hot_wallet = configuration.hot_wallet();
        assert!(sender == hot_wallet, ESenderIsInvalid);

        let offer_key = offer::new_offer_key<LendCoinType>(offer_id);
        assert!(state.contain<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key), EOfferNotFound);
        let offer = state.borrow_mut<OfferKey<LendCoinType>, Offer<LendCoinType>>(offer_key);

        let lender = offer.lender<LendCoinType>();
        let lend_amount = offer.amount<LendCoinType>();
        let duration = offer.duration<LendCoinType>();

        let loan_key = new_loan_key<LendCoinType, CollateralCoinType>(loan_id);
        assert!(state.contain<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key), ELoanNotFound);
        let loan = state.borrow_mut<LoanKey<LendCoinType, CollateralCoinType>, Loan<LendCoinType, CollateralCoinType>>(loan_key);
        assert!(loan.status == MATCHED_STATUS.to_string(), EInvalidLoanStatus);

        let borrower = loan.borrower;
        transfer::public_transfer(lend_coin, borrower);
        loan.status = FUND_TRANSFERRED_STATUS.to_string();

        let lend_token = lend_coin_metadata.get_symbol().to_string();
        let collateral_token = collateral_coin_metadata.get_symbol().to_string();
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

    public(package) fun system_finish_loan<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        configuration: &Configuration,
        custodian: &mut Custodian<LendCoinType>,
        repay_coin: Coin<LendCoinType>,
        waiting_interest: Coin<LendCoinType>,
        ctx: &mut TxContext,
    ) {
        
        let lender_fee_percent = configuration.lender_fee_percent();
        let lender_fee_amount = ((loan.amount * lender_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64);
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let repay_to_lender_amount = loan.amount + interest_amount - lender_fee_amount;

        assert!(repay_coin.value<LendCoinType>() == repay_to_lender_amount + lender_fee_amount, ENotEnoughBalanceToRepay);

        let mut repay_balance = repay_coin.into_balance<LendCoinType>();
        let lender_fee_balance = repay_balance.split(lender_fee_amount);
        custodian.add_treasury_balance<LendCoinType>(lender_fee_balance);

        let waiting_interest_balance = waiting_interest.into_balance<LendCoinType>();
        repay_balance.join<LendCoinType>(waiting_interest_balance);

        transfer::public_transfer(repay_balance.to_coin(ctx), loan.lender);
        loan.status = FINISHED_STATUS.to_string();

        event::emit(FinishedLoanEvent {
            loan_id: object::id(loan),
            offer_id: loan.offer_id,
            repay_to_lender_amount,
            lender: loan.lender,
            borrower: loan.borrower,
        });
    }

    public(package) fun start_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        configuration: &Configuration,
        liquidating_price: u64,
        liquidating_at: u64,
        ctx: &mut TxContext,
    ) {
        let hot_wallet = configuration.hot_wallet();

        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);

        if (loan.liquidation.is_none()) {
            loan.liquidation = option::some<Liquidation<LendCoinType, CollateralCoinType>>(Liquidation {
                liquidating_at,
                liquidating_price,
                liquidated_tx: option::none<String>(),
                liquidated_price: option::none<u64>(),
            });
        } else {
            let liquidation = loan.liquidation.borrow_mut();
            liquidation.liquidating_at = liquidating_at;
            liquidation.liquidating_price = liquidating_price;
        };

        let collateral_amount = loan.collateral.value<CollateralCoinType>();
        let collateral_coin = loan.collateral.split<CollateralCoinType>(collateral_amount).to_coin(ctx);
        transfer::public_transfer(collateral_coin, hot_wallet);

        loan.status = LIQUIDATING_STATUS.to_string();

        event::emit(LiquidatingCollateralEvent {
            loan_id: object::id(loan),
            liquidating_price,
            liquidating_at,
        });
    }

    public(package) fun system_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        configuration: &Configuration,
        remaining_fund_to_borrower: Coin<LendCoinType>,
        collateral_swapped_amount: u64,
        liquidated_price: u64,
        liquidated_tx: String,
    ) {
        assert!(loan.status == LIQUIDATING_STATUS.to_string(), EInvalidLoanStatus);
        assert!(loan.liquidation.is_some(), ELiquidationIsNull );

        let liquidation = loan.liquidation.borrow_mut();
        liquidation.liquidated_price = option::some<u64>(liquidated_price);
        liquidation.liquidated_tx = option::some<String>(liquidated_tx);
        
        let borrower_fee_percent = configuration.borrower_fee_percent();
        let borrower_fee_amount = ((loan.amount * borrower_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64 );
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let repay_amount = loan.amount + borrower_fee_amount + interest_amount;
        let remain_amount = collateral_swapped_amount - repay_amount;

        assert!(remaining_fund_to_borrower.value<LendCoinType>() == remain_amount, EInvalidCoinInput);

        transfer::public_transfer(remaining_fund_to_borrower, loan.borrower);

        loan.status = LIQUIDATED_STATUS.to_string();

        event::emit(LiquidatedCollateralEvent {
            lender: loan.lender,
            borrower: loan.borrower,
            loan_id: object::id(loan),
            collateral_swapped_amount,
            status: loan.status,
            liquidated_price,
            liquidated_tx,
            remaining_fund_to_borrower: remain_amount,
        });
    }

    public fun new_loan_key<LendCoinType, CollateralCoinType>(
        loan_id: ID,
    ): LoanKey<LendCoinType, CollateralCoinType> {
        LoanKey<LendCoinType, CollateralCoinType> {
            loan_id
        }
    }

    fun new_loan<LendCoinType, CollateralCoinType>(
        offer: &Offer<LendCoinType>,
        collateral: Coin<CollateralCoinType>,
        lender: address,
        borrower: address,
        start_timestamp: u64,
        ctx: &mut TxContext,
    ): Loan<LendCoinType, CollateralCoinType> {
        Loan<LendCoinType, CollateralCoinType> {
            id: object::new(ctx),
            offer_id: object::id(offer),
            interest: offer.interest<LendCoinType>(),
            amount: offer.amount<LendCoinType>(),
            duration: offer.duration<LendCoinType>(),
            collateral: collateral.into_balance<CollateralCoinType>(),
            lender,
            borrower,
            start_timestamp,
            liquidation: option::none<Liquidation<LendCoinType, CollateralCoinType>>(),
            repay_balance: balance::zero<LendCoinType>(),
            status: MATCHED_STATUS.to_string(),
        }
    }

    fun is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
        configuration: &Configuration,
        lend_amount: u64,
        collateral_amount: u64,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        clock: &Clock,
    ): bool {
        let lend_decimals = lend_coin_metadata.get_decimals<LendCoinType>();
        let collateral_decimals = collateral_coin_metadata.get_decimals<CollateralCoinType>();
        let max_decimals: u64;

        if (lend_decimals > collateral_decimals) {
            max_decimals = (lend_decimals as u64);
        } else  {
            max_decimals = (collateral_decimals as u64);
        };

        let time_threshold = configuration.price_time_threshold();
        let collateral_value_by_usd = price_info_object_collateral.get_value_by_usd<CollateralCoinType>(
            max_decimals, 
            collateral_amount, 
            collateral_coin_metadata, 
            time_threshold,
            clock
        );
        let lend_value_by_usd = price_info_object_lending.get_value_by_usd<LendCoinType>(
            max_decimals, 
            lend_amount, 
            lend_coin_metadata, 
            time_threshold,
            clock
        );
        let current_health_ratio = (collateral_value_by_usd * (DEFAULT_RATE_FACTOR as u128)) / lend_value_by_usd;
        let min_health_ratio = configuration.min_health_ratio();

        current_health_ratio >= (min_health_ratio as u128)
    }
}