module lending_contract::loan {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::transfer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::debug;

    use pyth::price_info::{Self, PriceInfoObject};
    use pyth::state::{State as PythState};
    use pyth::i64::{Self, I64};
    use pyth::pyth::{get_price_no_older_than};
    use pyth::price::{Self, Price};
    use pyth::price_identifier::{Self, PriceIdentifier};

    use lending_contract::offer::{Self, Offer, OfferKey};
    use lending_contract::state::{Self, State};
    use lending_contract::configuration::{Self, Configuration, PriceFeedObject};
    use lending_contract::custodian::{Self, Custodian};
    use lending_contract::version::{Self, Version};
    use lending_contract::price_feed;
    use lending_contract::utils;

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
    const ELiquidationIsNull: u64 = 10;
    const EInvalidCoinInput: u64 = 11;
    const EPriceInfoObjectLendingIsInvalid: u64 = 12;
    const EPriceInfoObjectCollateralIsInvalid: u64 = 13;
    const ECollateralIsInsufficient: u64 = 14;

    const MATCHED_STATUS: vector<u8> = b"Matched";
    const FUND_TRANSFERRED_STATUS: vector<u8> = b"FundTransferred";
    const REPAY_STATUS: vector<u8> = b"Repay";
    const BORROWER_PAID_STATUS: vector<u8> = b"BorrowerPaid";
    const LIQUIDATING_STATUS: vector<u8> = b"Liquidating";
    const LIQUIDATED_STATUS: vector<u8> = b"Liquidated";
    const FINISHED_STATUS: vector<u8> = b"Finished";

    const DEFAULT_RATE_FACTOR: u64 = 10000;
    const SECOND_IN_YEAR: u64 = 31536000;

    const SUI_DECIMALS: u8 = 9; 
    const SUI_NAME: vector<u8> = b"Sui"; 
    const SUI_SYMBOL: vector<u8> = b"SUI";
    
    const USDC_DECIMALS: u8 = 6; 
    const USDC_NAME: vector<u8> = b"USDC"; 
    const USDC_SYMBOL: vector<u8> = b"USDC"; 

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

    struct WithdrawCollateralEvent has copy, drop {
        loan_id: ID,
        borrower: address,
        withdraw_amount: u64,
        remaining_collateral_amount: u64,
        timestamp: u64,
    }

    struct DepositCollateralEvent has copy, drop {
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
    
    struct LiquidatingCollateralEvent has copy, drop {
        loan_id: ID,
        liquidating_price: u64,
        liquidating_at: u64,
    }

    struct LiquidatedCollateralEvent has copy, drop {
        lender: address,
        borrower: address,
        loan_id: ID,
        collateral_swapped_amount: u64,
        status: String,
        liquidated_price: u64,
        liquidated_tx: String,
        remaining_fund_to_borrower: u64,
    }

    public entry fun take_loan<T1, T2>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        offer_id: ID,
        collateral: Coin<T2>,
        lend_coin_metadata: &CoinMetadata<T1>,
        collateral_coin_metadata: &CoinMetadata<T2>,
        pyth_state: &PythState,
        price_info_object_collateral: &PriceInfoObject,
        price_info_object_lending: &PriceInfoObject,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);

        let usdc_name = string::utf8(USDC_NAME);
        let usdc_symbol = string::utf8(USDC_SYMBOL);
        let sui_name = string::utf8(SUI_NAME);
        let sui_symbol = string::utf8(SUI_SYMBOL);

        assert!(is_valid_price_id<T1>(configuration, lend_coin_metadata, price_info_object_lending), EPriceInfoObjectLendingIsInvalid);
        assert!(is_valid_price_id<T2>(configuration, collateral_coin_metadata, price_info_object_collateral), EPriceInfoObjectCollateralIsInvalid);

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
    
        assert!(is_valid_collateral_amount<T1, T2>(
            configuration, 
            lend_amount, 
            collateral_amount, 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            pyth_state, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock,
        ), ECollateralNotValidToMinHealthRatio);

        let loan = new_loan<T1, T2>(offer, collateral, lender, borrower, current_timestamp, ctx);
        let loan_id = object::id(&loan);
        let loan_key = new_loan_key<T1, T2>(loan_id);


        offer::take_loan(offer);


        state::add<LoanKey<T1, T2>, Loan<T1,T2>>(state, loan_key, loan);
        state::add_loan(state, loan_id, borrower, ctx);

        let lend_token_ascii = coin::get_symbol<T1>(lend_coin_metadata);
        let lend_token = string::from_ascii(lend_token_ascii);
        let collateral_token_ascii = coin::get_symbol<T2>(collateral_coin_metadata);
        let collateral_token = string::from_ascii(collateral_token_ascii);
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
        lend_coin_metadata: &CoinMetadata<T1>,
        collateral_coin_metadata: &CoinMetadata<T2>,
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

        let lend_token_ascii = coin::get_symbol<T1>(lend_coin_metadata);
        let lend_token = string::from_ascii(lend_token_ascii);
        let collateral_token_ascii = coin::get_symbol<T2>(collateral_coin_metadata);
        let collateral_token = string::from_ascii(collateral_token_ascii);
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
        lend_coin_metadata: &CoinMetadata<T1>,
        collateral_coin_metadata: &CoinMetadata<T2>,
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

        let lend_token_ascii = coin::get_symbol<T1>(lend_coin_metadata);
        let lend_token = string::from_ascii(lend_token_ascii);
        let collateral_token_ascii = coin::get_symbol<T2>(collateral_coin_metadata);
        let collateral_token = string::from_ascii(collateral_token_ascii);
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

    fun add_collateral_balance<T1, T2>(
        loan: &mut Loan<T1, T2>,
        deposit_balance: Balance<T2>
    ) {
        balance::join<T2>(&mut loan.collateral, deposit_balance);
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

    fun is_valid_collateral_amount<T1, T2>(
        configuration: &Configuration,
        lend_amount: u64,
        collateral_amount: u64,
        lend_coin_metadata: &CoinMetadata<T1>,
        collateral_coin_metadata: &CoinMetadata<T2>,
        pyth_state: &PythState,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        clock: &Clock,
    ): bool {
        let lend_decimals = coin::get_decimals<T1>(lend_coin_metadata);
        let collateral_decimals = coin::get_decimals<T2>(collateral_coin_metadata);
        let max_decimals: u64;

        if (lend_decimals > collateral_decimals) {
            max_decimals = (lend_decimals as u64);
        } else  {
            max_decimals = (collateral_decimals as u64);
        };

        let collateral_value_by_usd = price_feed::get_value_by_usd<T2>(
            configuration, 
            max_decimals, 
            collateral_amount, 
            collateral_coin_metadata, 
            pyth_state, 
            price_info_object_collateral, 
            clock
        );
        let lend_value_by_usd = price_feed::get_value_by_usd<T1>(
            configuration, 
            max_decimals, 
            lend_amount, 
            lend_coin_metadata, 
            pyth_state, 
            price_info_object_lending, 
            clock
        );
        let current_health_ratio = (collateral_value_by_usd * (DEFAULT_RATE_FACTOR as u128)) / lend_value_by_usd;
        let min_health_ratio = configuration::min_health_ratio(configuration);

        current_health_ratio >= (min_health_ratio as u128)
    }

    fun is_valid_price_id<T>(
        configuration: &Configuration,
        coinMetadata: &CoinMetadata<T>,
        price_info_object: &PriceInfoObject,
    ): bool {
        let price_info = price_info::get_price_info_from_price_info_object(price_info_object);
        let price_id = price_identifier::get_bytes(&price_info::get_price_identifier(&price_info));
        let price_id_validate = utils::vector_to_hex_char(price_id);
        
        let coin_symbol_ascii = coin::get_symbol<T>(coinMetadata);
        let coin_symbol = string::from_ascii(coin_symbol_ascii);
        let price_feed_id = configuration::price_feed_id(configuration, coin_symbol);

        price_id_validate == price_feed_id
    }

     public entry fun withdraw_collateral_loan_offer<T1, T2>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        withdraw_amount: u64,
        lend_coin_metadata: &CoinMetadata<T1>,
        collateral_coin_metadata: &CoinMetadata<T2>,
        pyth_state: &PythState,
        price_info_object_lending: &PriceInfoObject,
        price_info_object_collateral: &PriceInfoObject,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        
        let usdc_name = string::utf8(USDC_NAME);
        let usdc_symbol = string::utf8(USDC_SYMBOL);
        let sui_name = string::utf8(SUI_NAME);
        let sui_symbol = string::utf8(SUI_SYMBOL);

        assert!(is_valid_price_id<T1>(configuration, lend_coin_metadata, price_info_object_lending), EPriceInfoObjectLendingIsInvalid);
        assert!(is_valid_price_id<T2>(configuration, collateral_coin_metadata, price_info_object_collateral), EPriceInfoObjectCollateralIsInvalid);

        let loan_key = new_loan_key<T1, T2>(loan_id);
        let current_timestamp = clock::timestamp_ms(clock);
        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);

        assert!(loan.status == string::utf8(FUND_TRANSFERRED_STATUS), EInvalidLoanStatus);
        
        let offer_id = loan.offer_id;
        let lend_amount = loan.amount;

        let sender = tx_context::sender(ctx);
        let collateral_amount = balance::value<T2>(&loan.collateral);

        assert!(collateral_amount >= withdraw_amount, ECollateralIsInsufficient);

        let remaining_collateral_amount = collateral_amount - withdraw_amount;

        assert!(is_valid_collateral_amount<T1, T2>(
            configuration, 
            lend_amount, 
            remaining_collateral_amount, 
            lend_coin_metadata, 
            collateral_coin_metadata, 
            pyth_state, 
            price_info_object_lending, 
            price_info_object_collateral, 
            clock, 
        ), ECollateralNotValidToMinHealthRatio);

        let collateral_balance = sub_collateral_balance<T1, T2>(loan, withdraw_amount);
        transfer::public_transfer(coin::from_balance(collateral_balance, ctx), sender);

        event::emit(WithdrawCollateralEvent {
            loan_id,
            borrower: loan.borrower,
            withdraw_amount,
            remaining_collateral_amount,
            timestamp: current_timestamp,
        });
    }

    public entry fun deposit_collateral_loan_offer<T1, T2>(
        version: &Version,
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        deposit_amount: Coin<T2>,
        lend_coin_metadata: &CoinMetadata<T1>,
        collateral_coin_metadata: &CoinMetadata<T2>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        
        let loan_key = new_loan_key<T1, T2>(loan_id);
        assert!(state::contain<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key), ELoanNotFound);
        let ( offer_id ) = {
            let loan = state::borrow<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);
            loan.offer_id 
        };

        let ( asset_tier ) = {
            let offer_key = offer::new_offer_key<T1>(offer_id);
            assert!(state::contain<OfferKey<T1>, Offer<T1>>(state, offer_key), EOfferNotFound);
            let offer = state::borrow<OfferKey<T1>, Offer<T1>>(state, offer_key);
            offer::get_asset_tier(offer)
        };

        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);

        let lend_fee_percentage = configuration::lender_fee_percent(configuration);
        let borrow_fee_percentage = configuration::borrower_fee_percent(configuration);

        let lend_token_ascii = coin::get_symbol<T1>(lend_coin_metadata);
        let lend_token = string::from_ascii(lend_token_ascii);
        let collateral_token_ascii = coin::get_symbol<T2>(collateral_coin_metadata);
        let collateral_token = string::from_ascii(collateral_token_ascii);

        let current_timestamp = clock::timestamp_ms(clock);
        assert!(loan.status == string::utf8(FUND_TRANSFERRED_STATUS), EInvalidLoanStatus);

        let deposit_amount_value = coin::value<T2>(&deposit_amount);
        let deposit_balance = coin::into_balance<T2>(deposit_amount);

        add_collateral_balance<T1, T2>(loan, deposit_balance);

        let total_collateral_amount = balance::value<T2>(&loan.collateral);

        event::emit(DepositCollateralEvent {
            tier_id: asset_tier,
            lend_offer_id: loan.offer_id,
            interest: loan.interest,
            borrow_amount: loan.amount,
            lender_fee_percent: lend_fee_percentage,
            duration: loan.duration,
            lend_mint_token: lend_token,
            lender: loan.lender,
            loan_offer_id: loan_id,
            borrower: loan.borrower,
            collateral_mint_token: collateral_token,
            collateral_amount: total_collateral_amount,
            status: loan.status,
            borrower_fee_percent: borrow_fee_percentage,
            timestamp: current_timestamp,
            }
        );

    }

    public (friend) fun start_liquidate_loan_offer<T1, T2>(
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        liquidating_price: u64,
        liquidating_at: u64,
        ctx: &mut TxContext,
    ) {

        let hot_wallet = configuration::hot_wallet(configuration);

        let loan_key = new_loan_key<T1, T2>(loan_id);
        assert!(state::contain<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key), ELoanNotFound);
        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);

        assert!(loan.status == string::utf8(FUND_TRANSFERRED_STATUS), EInvalidLoanStatus);

        // Update liquidation field
        if (option::is_none(&loan.liquidation)) {
            // Initialize the liquidation field if it is None
            loan.liquidation = option::some<Liquidation<T1, T2>>(Liquidation {
                liquidating_at,
                liquidating_price,
                liquidated_tx: option::none<String>(),
                liquidated_price: option::none<u64>(),
            });
        } else {
            // Borrow the current liquidation structure and update its fields
            let liquidation = option::borrow_mut(&mut loan.liquidation);
            liquidation.liquidating_at = liquidating_at;
            liquidation.liquidating_price = liquidating_price;
            // You can also update other fields if necessary
        };

        let collateral_amount = balance::value<T2>(&loan.collateral);
        let collateral_balance = sub_collateral_balance<T1, T2>(loan, collateral_amount);
        let collateral_coin = coin::from_balance<T2>(collateral_balance, ctx);
        transfer::public_transfer(collateral_coin, hot_wallet);

        loan.status = string::utf8(LIQUIDATING_STATUS);

        event::emit(LiquidatingCollateralEvent {
            loan_id,
            liquidating_price,
            liquidating_at,
        });
    }

    public (friend) fun system_liquidate_loan_offer<T1, T2>(
        configuration: &Configuration,
        state: &mut State,
        loan_id: ID,
        remaining_fund_to_borrower: Coin<T1>,
        collateral_swapped_amount: u64,
        liquidated_price: u64,
        liquidated_tx: String,
        ctx: &mut TxContext,
    ) {

        let loan_key = new_loan_key<T1, T2>(loan_id);
        assert!(state::contain<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key), ELoanNotFound);
        let loan = state::borrow_mut<LoanKey<T1, T2>, Loan<T1, T2>>(state, loan_key);

        assert!(loan.status == string::utf8(LIQUIDATING_STATUS), EInvalidLoanStatus);
        assert!(option::is_some(&loan.liquidation), ELiquidationIsNull );

        let lender = loan.lender;
        let borrower = loan.borrower;
        // Borrow the current liquidation structure and update its fields
        let liquidation = option::borrow_mut(&mut loan.liquidation);
        liquidation.liquidated_price = option::some<u64>(liquidated_price);
        liquidation.liquidated_tx = option::some<String>(liquidated_tx);
        // You can also update other fields if necessary
        
        let borrower_fee_percent = configuration::borrower_fee_percent(configuration);
        let borrower_fee_amount = ((loan.amount * borrower_fee_percent as u128) / (DEFAULT_RATE_FACTOR as u128) as u64 );
        let interest_amount = ((loan.amount * loan.interest / DEFAULT_RATE_FACTOR * loan.duration as u128) / (SECOND_IN_YEAR as u128) as u64);
        let repay_amount = loan.amount + borrower_fee_amount + interest_amount;
        let remain_amount = collateral_swapped_amount - repay_amount;

        assert!(coin::value<T1>(&remaining_fund_to_borrower) == remain_amount, EInvalidCoinInput );

        transfer::public_transfer(remaining_fund_to_borrower, borrower);

        loan.status = string::utf8(LIQUIDATED_STATUS);

        event::emit(LiquidatedCollateralEvent {
            lender,
            borrower,
            loan_id,
            collateral_swapped_amount,
            status: loan.status,
            liquidated_price,
            liquidated_tx,
            remaining_fund_to_borrower: remain_amount,
        });
    }
}