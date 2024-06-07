module lending_contract::operator {
    use sui::tx_context::{TxContext};
    use std::string::{String};
    use sui::object::{Self, UID, ID};
    use sui::transfer::{Self};
    use sui::coin::{Coin};

    use wormhole::state::{State as WormholeState};

    use lending_contract::state::{Self, State};
    use lending_contract::asset_tier::{Self, AssetTier, AssetTierKey};
    use lending_contract::version::{Self, Version};
    use lending_contract::configuration::{Self, Configuration};
    use lending_contract::loan;
    use lending_contract::custodian::{Self, Custodian};
    use lending_contract::wormhole;

    friend lending_contract::admin;

    struct OperatorCap has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };

        transfer::transfer(operator_cap, @operator);
    }

    public(friend) fun new_operator(
        user_address: address,
        ctx: &mut TxContext,
    ) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };
        transfer::transfer(operator_cap, user_address);
    }

    public entry fun init_system<T>(
        _: &OperatorCap,
        version: &Version,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);

        custodian::new<T>(ctx);
        configuration::new(ctx);
        state::new(ctx);
    }

    public entry fun init_wormhole_emitter(
        _: &OperatorCap,
        version: &Version,
        wormhole_state: &WormholeState,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);

        wormhole::init_emitter(wormhole_state, ctx);
    }

    public entry fun create_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
        amount: u64,
        duration: u64,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);

        let asset_tier = asset_tier::new<T>(
            name,
            amount,
            duration,
            ctx,
        );
        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        state::add<AssetTierKey<T>, AssetTier<T>>(state, asset_tier_key, asset_tier);
    }

    public entry fun update_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
        amount: u64,
        duration: u64,
    ) {
        version::assert_current_version(version);
        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        let asset_tier = state::borrow_mut<AssetTierKey<T>, AssetTier<T>>(state, asset_tier_key);

        asset_tier::update<T>(
            asset_tier,
            amount,
            duration,
        );
    }

    public entry fun update_configuration(
        version: &Version,
        _: &OperatorCap,
        configuration: &mut Configuration,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64, 
    ) {
        version::assert_current_version(version);
        configuration::update(
            configuration,
            lender_fee_percent,
            borrower_fee_percent,
            min_health_ratio,
        );
    }

    public entry fun finish_loan<T1, T2>(
        _: &OperatorCap,
        version: &Version,
        configuration: &Configuration,
        custodian: &mut Custodian<T1>,
        state: &mut State, 
        loan_id: ID,
        waiting_interest: Coin<T1>,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        loan::finish_loan<T1, T2>(
            configuration,
            custodian,
            state,
            loan_id,
            waiting_interest,
            ctx,
        );
    }
}