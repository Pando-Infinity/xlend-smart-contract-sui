module lending_contract_v2::configuration {
    use sui::table::{Self, Table};
    use std::string::String;

    const EPriceFeedIdAlreadyExisted: u64 = 1;
    const EPriceFeedIdIsNotExisted: u64 = 2;

    public struct Configuration has key, store {
        id: UID,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        price_time_threshold: u64,
        price_feed_ids:  Table<String, String>,
    }

    public(package) fun new(
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        price_time_threshold: u64,
        ctx: &mut TxContext,
    ) {
        let configuration = Configuration {
            id: object::new(ctx),
            lender_fee_percent,
            borrower_fee_percent,
            min_health_ratio,
            hot_wallet,
            price_time_threshold,
            price_feed_ids: table::new<String, String>(ctx),
        };
        transfer::public_share_object(configuration);
    }

    public(package) fun update(
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

    public(package) fun add_price_feed_id(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        assert!(!configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdAlreadyExisted);
        configuration.price_feed_ids.add(coin_symbol, price_feed_id);
    }

    public(package) fun update_price_feed_id(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        assert!(configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdIsNotExisted);
        let old_price_feed_id = configuration.price_feed_ids.borrow_mut(coin_symbol);
        *old_price_feed_id = price_feed_id;
    }

    public(package) fun remove_price_feed_id(
        configuration: &mut Configuration,
        coin_symbol: String,
    ) {
        assert!(configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdIsNotExisted);
        configuration.price_feed_ids.remove(coin_symbol);
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

    public fun price_feed_id(
        configuration: &Configuration,
        coin_symbol: String,
    ): String {
        assert!(configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdIsNotExisted);
        *configuration.price_feed_ids.borrow(coin_symbol)
    }

    public fun contains_price_feed_id(
        configuration: &Configuration,
        coin_symbol: String,
    ): bool {
        configuration.price_feed_ids.contains(coin_symbol)
    }
}