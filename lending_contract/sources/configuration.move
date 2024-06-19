module lending_contract::configuration {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::transfer;

    friend lending_contract::admin;
    friend lending_contract::operator;
    friend lending_contract::price_feed;

    struct Configuration has key, store {
        id: UID,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        price_time_threshold: u64,
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
}