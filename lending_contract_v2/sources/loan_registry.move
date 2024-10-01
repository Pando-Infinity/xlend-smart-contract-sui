module enso_lending::loan_registry {
    use sui::{
        balance::{Self, Balance},
        coin::{Coin, CoinMetadata},
        clock::Clock,
        event,
    };
    use std::string::String;
    use pyth::price_info::PriceInfoObject;
    use enso_lending::{
        offer_registry::Offer,
        configuration::Configuration,
        custodian::Custodian,
        utils,
    };

    use fun enso_lending::price_feed::get_value_by_usd as PriceInfoObject.get_value_by_usd;
    use fun enso_lending::price_feed::get_price as PriceInfoObject.get_price;
    use fun std::string::utf8 as vector.to_string;
    use fun sui::coin::from_balance as Balance.to_coin;

    const ECollateralNotValidToMinHealthRatio: u64 = 1;
    const ESenderIsNotLoanBorrower: u64 = 2;
    const EInvalidLoanStatus: u64 = 3;
    const ENotEnoughBalanceToRepay: u64 = 4;
    const ECanNotRepayExpiredLoan: u64 = 5;
    const ELiquidationIsNull: u64 = 7;
    const EInvalidCoinInput: u64 = 8;
    const ECollateralIsInsufficient: u64 = 9;
    const ECanNotLiquidateValidCollateral: u64 = 10;
    const ECanNotLiquidateUnexpiredLoan: u64 = 11;

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
        lend_token: String,
        collateral_token: String,
        lender: address,
        borrower: address,
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
        lend_token: String,
        lender: address,
        loan_offer_id: ID,
        borrower: address,
        collateral_token: String,
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

    public(package) fun new_loan<LendCoinType, CollateralCoinType>(
        configuration: &Configuration,
        collateral: Coin<CollateralCoinType>,
        offer: &Offer<LendCoinType>,
        borrower: address,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        start_timestamp: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Loan<LendCoinType, CollateralCoinType> {
        let collateral_amount = collateral.value<CollateralCoinType>();

        assert!(is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
            configuration,
            offer.amount<LendCoinType>(), 
            collateral.value<CollateralCoinType>(), 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock,
        ), ECollateralNotValidToMinHealthRatio);

        let loan = Loan<LendCoinType, CollateralCoinType> {
            id: object::new(ctx),
            offer_id: object::id(offer),
            interest: offer.interest<LendCoinType>(),
            amount: offer.amount<LendCoinType>(),
            duration: offer.duration<LendCoinType>(),
            collateral: collateral.into_balance<CollateralCoinType>(),
            lender: offer.lender<LendCoinType>(),
            borrower,
            start_timestamp,
            liquidation: option::none<Liquidation<LendCoinType, CollateralCoinType>>(),
            repay_balance: balance::zero<LendCoinType>(),
            status: MATCHED_STATUS.to_string(),
        };

        event::emit(RequestLoanEvent {
            loan_id: object::id(&loan),
            offer_id: object::id(offer),
            amount: offer.amount<LendCoinType>(),
            duration: offer.duration<LendCoinType>(),
            collateral_amount,
            lend_token: utils::get_type<LendCoinType>(),
            collateral_token: utils::get_type<CollateralCoinType>(),
            lender: offer.lender<LendCoinType>(),
            borrower,
            start_timestamp,
        });

        loan
    }

    public(package) fun repay<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        custodian: &mut Custodian<LendCoinType>,
        repay_coin: Coin<LendCoinType>,
        borrower_fee_percent: u64,
        lend_token: String,
        collateral_token: String,
        hot_wallet: address,
        sender: address,
        current_timestamp: u64,
        ctx: &mut TxContext,
    ) {
        assert!(sender == loan.borrower, ESenderIsNotLoanBorrower);
        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);
        assert!(loan.start_timestamp + (loan.duration * 1000) > current_timestamp, ECanNotRepayExpiredLoan);
        
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let borrower_fee_amount = ((interest_amount * borrower_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64 );
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

        event::emit(BorrowerPaidEvent {
            loan_id: object::id(loan),
            repay_amount,
            collateral_amount,
            lend_token,
            collateral_token,
            borrower: sender,
        });
    }

    #[allow(lint(self_transfer))]
    public(package) fun withdraw_collateral<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        configuration: &Configuration,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        withdraw_amount: u64,
        current_timestamp: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);

        let collateral_amount = loan.collateral.value<CollateralCoinType>();
        assert!(collateral_amount >= withdraw_amount, ECollateralIsInsufficient);
        let remaining_collateral_amount = collateral_amount - withdraw_amount;

        assert!(is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
            configuration,
            loan.amount, 
            remaining_collateral_amount, 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock, 
        ), ECollateralNotValidToMinHealthRatio);

        let collateral_balance = loan.collateral.split<CollateralCoinType>(withdraw_amount);
        transfer::public_transfer(collateral_balance.to_coin<CollateralCoinType>(ctx), ctx.sender());

        event::emit(WithdrawCollateralEvent {
            loan_id: object::id(loan),
            borrower: loan.borrower,
            withdraw_amount,
            remaining_collateral_amount,
            timestamp: current_timestamp,
        });
    }

    public(package) fun deposit_collateral<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        deposit_coin: Coin<CollateralCoinType>,
        asset_tier: ID,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        lend_token: String,
        collateral_token: String,
        current_timestamp: u64,
    ) {
        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);

        loan.collateral.join(deposit_coin.into_balance<CollateralCoinType>());
        let total_collateral_amount = loan.collateral.value<CollateralCoinType>();

        event::emit(DepositCollateralEvent {
            tier_id: asset_tier,
            lend_offer_id: loan.offer_id,
            interest: loan.interest,
            borrow_amount: loan.amount,
            lender_fee_percent,
            duration: loan.duration,
            lend_token,
            lender: loan.lender,
            loan_offer_id: object::id(loan),
            borrower: loan.borrower,
            collateral_token,
            collateral_amount: total_collateral_amount,
            status: loan.status,
            borrower_fee_percent,
            timestamp: current_timestamp,
            }
        );
    }

    public(package) fun system_fund_transfer<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        lend_coin: Coin<LendCoinType>,
        lend_token: String,
        collateral_token: String,
        _ctx: &mut TxContext,
    ) {
        assert!(loan.status == MATCHED_STATUS.to_string(), EInvalidLoanStatus);

        let borrower = loan.borrower;
        transfer::public_transfer(lend_coin, borrower);
        loan.status = FUND_TRANSFERRED_STATUS.to_string();

        event::emit(FundTransferredEvent {
            loan_id: object::id(loan),
            offer_id: loan.offer_id,
            amount: loan.amount,
            duration: loan.duration,
            lend_token,
            collateral_token,
            lender: loan.lender,
            borrower,
        });
    }

    public(package) fun system_finish_loan<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        custodian: &mut Custodian<LendCoinType>,
        repay_coin: Coin<LendCoinType>,
        waiting_interest: Coin<LendCoinType>,
        lender_fee_percent: u64,
        ctx: &mut TxContext,
    ) {
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let lender_fee_amount = ((interest_amount * lender_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64);
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

    public(package) fun start_liquidate_loan_offer_health<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        configuration: &Configuration,
        lend_coin_metadata: &CoinMetadata<LendCoinType>,
        collateral_coin_metadata: &CoinMetadata<CollateralCoinType>,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        hot_wallet: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let current_timestamp = clock.timestamp_ms();
        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);
        assert!(!is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
            configuration,
            loan.amount, 
            loan.collateral.value<CollateralCoinType>(), 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock,
        ), ECanNotLiquidateValidCollateral);

        let (liquidating_price, _, _) = price_info_object_collateral.get_price(configuration.max_price_age_seconds(), clock);
        
        loan.start_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
            liquidating_price,
            current_timestamp,
            hot_wallet,
            ctx,
        );
    }

    public(package) fun start_liquidate_loan_offer_expired<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        hot_wallet: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let current_timestamp = clock.timestamp_ms();
        assert!(loan.status == FUND_TRANSFERRED_STATUS.to_string(), EInvalidLoanStatus);
        assert!(loan.is_expired_loan_offer<LendCoinType, CollateralCoinType>(current_timestamp), ECanNotLiquidateUnexpiredLoan);
        
        loan.start_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
            0,
            current_timestamp,
            hot_wallet,
            ctx,
        );
    }

    public(package) fun system_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        remaining_fund_to_borrower: Coin<LendCoinType>,
        borrower_fee_percent: u64,
        collateral_swapped_amount: u64,
        liquidated_price: u64,
        liquidated_tx: String,
    ) {
        assert!(loan.status == LIQUIDATING_STATUS.to_string(), EInvalidLoanStatus);
        assert!(loan.liquidation.is_some(), ELiquidationIsNull );

        let liquidation = loan.liquidation.borrow_mut();
        liquidation.liquidated_price = option::some<u64>(liquidated_price);
        liquidation.liquidated_tx = option::some<String>(liquidated_tx);
    
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let borrower_fee_amount = ((interest_amount * borrower_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64 );
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

    public fun is_valid_collateral_amount<LendCoinType, CollateralCoinType>(
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

        let collateral_value_by_usd = price_info_object_collateral.get_value_by_usd<CollateralCoinType>(
            max_decimals, 
            collateral_amount, 
            collateral_coin_metadata, 
            configuration.max_price_age_seconds(),
            clock
        );
        let lend_value_by_usd = price_info_object_lending.get_value_by_usd<LendCoinType>(
            max_decimals, 
            lend_amount, 
            lend_coin_metadata, 
            configuration.max_price_age_seconds(),
            clock
        );
        let current_health_ratio = (collateral_value_by_usd * (DEFAULT_RATE_FACTOR as u128)) / lend_value_by_usd;

        current_health_ratio >= (configuration.min_health_ratio() as u128)
    }

    public fun is_expired_loan_offer<LendCoinType, CollateralCoinType>(
        loan: &Loan<LendCoinType, CollateralCoinType>,
        current_timestamp: u64,
    ): bool {
        let end_borrowed_loan =  loan.start_timestamp + loan.duration;
        current_timestamp >= end_borrowed_loan
    }

    public fun offer_id<LendCoinType, CollateralCoinType>(
        loan: &Loan<LendCoinType, CollateralCoinType>
    ): ID {
        loan.offer_id
    }

    fun start_liquidate_loan_offer<LendCoinType, CollateralCoinType>(
        loan: &mut Loan<LendCoinType, CollateralCoinType>,
        liquidating_price: u64,
        liquidating_at: u64,
        hot_wallet: address,
        ctx: &mut TxContext,
    ) {
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
}