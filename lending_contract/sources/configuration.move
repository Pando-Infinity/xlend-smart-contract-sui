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

    struct PriceFeedObject has store {
        price_feed_id: String,
    }

    struct Configuration has key, store {
        id: UID,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        price_time_threshold: u64,
        price_id:  Table<String, PriceFeedObject>
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
            price_id: table::new<String, PriceFeedObject>(ctx),
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
        coin_metadata: String,
        price_feed_id: String,
    ) {
        let price_feed_object = PriceFeedObject {
            price_feed_id: price_feed_id,
        };
        table::add<String, PriceFeedObject>(&mut configuration.price_id, coin_metadata, price_feed_object);
    }

    public(friend) fun borrow(
        configuration: &Configuration,
        coin_metadata: String
    ): &PriceFeedObject {
         table::borrow<String, PriceFeedObject>(&configuration.price_id, coin_metadata)
    }
}