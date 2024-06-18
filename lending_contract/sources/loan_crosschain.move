module lending_contract::loan_crosschain {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Balance};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::sui::{SUI};
    use sui::clock::{Clock};
    use std::string::{Self, String};
    use std::vector;

    use lending_contract::state::{Self, State};
    use lending_contract::version::{Self, Version};
    use lending_contract::utils;
    use lending_contract::wormhole;

    use wormhole::emitter::{EmitterCap};
    use wormhole::state::{State as WormholeState};

    struct CollateralCrosschainHolderKey<phantom T> has copy, drop, store {
        offer_id: String,
    }

    struct CollateralCrosschainHolder<phantom T> has key, store {
        id: UID,
        offer_id: String,
        lend_amount: u64,
        duration: u64,
        borrower: address,
        collateral: Balance<SUI>,
    }

    public entry fun confirm_collateral_crosschain<T>(
        version: &Version,
        state: &mut State,
        emitter_cap: &mut EmitterCap,
        wormhole_state: &mut WormholeState,
        coin_metadata: &CoinMetadata<SUI>,
        collateral_coin: Coin<SUI>,
        pyth_collateral_symbol: vector<u8>,
        target_chain: u64,
        target_address: vector<u8>,
        tier_id: vector<u8>,
        offer_id: vector<u8>,
        lend_amount: u64,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        
        let borrower = tx_context::sender(ctx);
        let collateral_amount = coin::value<SUI>(&collateral_coin);
        let collateral_holder_key = new_collateral_crosschain_holder_key<T>(
            string::utf8(offer_id)
        );
        let collateral_holder = new_collateral_crosschain_holder<T>(
            string::utf8(offer_id),
            lend_amount,
            duration,
            borrower,
            collateral_coin,
            ctx,
        );

        state::add<CollateralCrosschainHolderKey<T>, CollateralCrosschainHolder<T>>(
            state,
            collateral_holder_key,
            collateral_holder,
        );

        let message_fee_coin = coin::zero<SUI>(ctx);
        let collateral_decimal = coin::get_decimals<SUI>(coin_metadata);
        let payload = gen_confirm_collateral_crosschain_payload(
            target_chain,
            target_address,
            tier_id,
            offer_id,
            collateral_amount,
            pyth_collateral_symbol,
            collateral_decimal,
        );

        wormhole::send_message(
            emitter_cap,
            wormhole_state,
            payload,
            message_fee_coin,
            clock,
        );
    }

    fun gen_confirm_collateral_crosschain_payload(
        target_chain: u64,
        target_address: vector<u8>,
        tier_id: vector<u8>,
        offer_id: vector<u8>,
        collateral_amount: u64,
        pyth_collateral_symbol: vector<u8>,
        collateral_decimal: u8,
    ): vector<u8> {
        let target_chain_utf8 = utils::u64_to_string(target_chain);
        let collateral_amount_utf8 = utils::u64_to_string(collateral_amount);
        let collateral_decimal_utf8 = utils::u64_to_string((collateral_decimal as u64));
        let payload: vector<u8> = vector[];
        vector::append(&mut payload, target_chain_utf8);
        vector::append(&mut payload, b",");
        vector::append(&mut payload, target_address);
        vector::append(&mut payload, b",");
        vector::append(&mut payload, b"create_loan_offer_crosschain");
        vector::append(&mut payload, b",");
        vector::append(&mut payload, tier_id);
        vector::append(&mut payload, b",");
        vector::append(&mut payload, offer_id);
        vector::append(&mut payload, b",");
        vector::append(&mut payload, collateral_amount_utf8);
        vector::append(&mut payload, b",");
        vector::append(&mut payload, pyth_collateral_symbol);
        vector::append(&mut payload, b",");
        vector::append(&mut payload, collateral_decimal_utf8);

        payload
    }

    fun new_collateral_crosschain_holder_key<T>(
        offer_id: String
    ): CollateralCrosschainHolderKey<T> {
        CollateralCrosschainHolderKey<T> {
            offer_id
        }
    }

    fun new_collateral_crosschain_holder<T>(
        offer_id: String,
        lend_amount: u64,
        duration: u64,
        borrower: address,
        collateral: Coin<SUI>,
        ctx: &mut TxContext,
    ): CollateralCrosschainHolder<T> {
        CollateralCrosschainHolder<T> {
            id: object::new(ctx),
            offer_id,
            lend_amount,
            duration,
            borrower,
            collateral: coin::into_balance<SUI>(collateral),
        }
    }
}