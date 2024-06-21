module lending_contract::configuration {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use sui::event;

    friend lending_contract::admin;
    friend lending_contract::operator;
    friend lending_contract::price_feed;
    friend lending_contract::loan;

    const EKeyAlreadyExisted: u64 = 1;
    const EKeyIsNotExisted: u64 = 2;

    struct PriceFeedObject has store, drop {
        price_feed_id: String,
    }

    struct Configuration has key, store {
        id: UID,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        price_time_threshold: u64,
        price_feed_ids:  Table<String, PriceFeedObject>,
    }

    public(friend) fun new(
        wallet: address,
        ctx: &mut TxContext,
    ) {
        let configuration = Configuration {
            id: object::new(ctx),
            lender_fee_percent: 0,
            borrower_fee_percent: 0,
            min_health_ratio: 0,
            hot_wallet: wallet,
            price_time_threshold: 60,
            price_feed_ids: table::new<String, PriceFeedObject>(ctx),
        };
        transfer::share_object(configuration);
    }

    public(friend) fun update(
        configuration: &mut Configuration,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        price_time_threshold: u64,
    ) {
        configuration.lender_fee_percent = lender_fee_percent;
        configuration.borrower_fee_percent = borrower_fee_percent;
        configuration.min_health_ratio = min_health_ratio; 
        configuration.hot_wallet = hot_wallet;
        configuration.price_time_threshold = price_time_threshold;
    }

    public fun lender_fee_percent(
        configuration: &Configuration
    ): u64 {
        configuration.lender_fee_percent
    }

    public fun borrower_fee_percent(
        configuration: &Configuration
    ): u64 {
        configuration.borrower_fee_percent
    }

    public fun hot_wallet(
        configuration: &Configuration
    ): address {
        configuration.hot_wallet
    }

    public fun min_health_ratio(
        configuration: &Configuration
    ): u64 {
        configuration.min_health_ratio
    }

    public fun price_time_threshold (
        configuration: &Configuration
    ): u64 {
        configuration.price_time_threshold
    }
    
    public(friend) fun add_price_id(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        assert!(!table::contains<String, PriceFeedObject>(&configuration.price_feed_ids, coin_symbol), EKeyAlreadyExisted);
        let price_feed_object = PriceFeedObject {
            price_feed_id: price_feed_id,
        };
        table::add<String, PriceFeedObject>(&mut configuration.price_feed_ids, coin_symbol, price_feed_object);
    }

    public(friend) fun update_price_id(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        assert!(table::contains<String, PriceFeedObject>(&configuration.price_feed_ids, coin_symbol), EKeyIsNotExisted);
        let price_feed_object = table::borrow_mut<String, PriceFeedObject>(&mut configuration.price_feed_ids, coin_symbol);
        price_feed_object.price_feed_id = price_feed_id;
    }

    public(friend) fun remove_price_id(
        configuration: &mut Configuration,
        coin_symbol: String,
    ) {
        assert!(table::contains<String, PriceFeedObject>(&configuration.price_feed_ids, coin_symbol), EKeyIsNotExisted);
        let price_feed_object = table::remove<String, PriceFeedObject>(&mut configuration.price_feed_ids, coin_symbol);
    }

    public(friend) fun get_price_id_by_coin(
        configuration: &Configuration,
        coin_symbol: String
    ): &PriceFeedObject {
         table::borrow<String, PriceFeedObject>(&configuration.price_feed_ids, coin_symbol)
    }

    public(friend) fun price_feed_id(
        configuration: &Configuration,
        coin_symbol: String,
    ): String {
        let price_feed_object = table::borrow<String, PriceFeedObject>(&configuration.price_feed_ids, coin_symbol);
        price_feed_object.price_feed_id
    }
}