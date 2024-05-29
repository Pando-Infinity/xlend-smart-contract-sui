module lending_contract::offer {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::transfer;
    use std::string::{Self, String};

    use lending_contract::state::{Self, State};
    use lending_contract::asset_tier::{Self, AssetTier, AssetTierKey};

    friend lending_contract::loan;

    const EInvalidInterestValue: u64 = 1;
    const ENotFoundAssetTier: u64 = 2;
    const ENotEnoughBalanceToCreateOffer: u64 = 3;
    const ENotFoundOfferToCancel: u64 = 4;
    const EInvalidOfferStatus: u64 = 5;
    const ESenderIsNotOfferOwner: u64 = 6;

    const CREATED_STATUS: vector<u8> = b"Created";
    const CANCELLING_STATUS: vector<u8> = b"Cancelling";
    const CANCELLED_STATUS: vector<u8> = b"Cancelled";
    const LOANED_STATUS: vector<u8> = b"Loaned";

    struct OfferKey<phantom T> has store, copy, drop {
        offer_id: ID,
    } 

    struct Offer<phantom T> has key, store {
        id: UID,
        asset_tier: ID,
        amount: Balance<T>,
        duration: u64,
        interest: u64,
        status: String,
        lender: address,
    }

    struct NewOfferEvent has copy, drop {
        offer_id: ID,
        asset_tier_id: ID,
        asset_tier_name: String,
        amount: u64,
        duration: u64,
        interest: u64,
        status: String,
        lender: address,
    }

    struct CancelledOfferEvent has copy, drop {
        offer_id: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
    }

    struct EditedOfferEvent has copy, drop {
        offer_id: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
    }

    public entry fun create_offer<T>(
        state: &mut State,
        asset_tier_name: String,
        lend_coin: Coin<T>,
        interest: u64,
        ctx: &mut TxContext,
    ) {
        let lender = tx_context::sender(ctx);
        
        assert!(interest > 0, EInvalidInterestValue);

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(asset_tier_name);
        assert!(state::contain<AssetTierKey<T>, AssetTier<T>>(state, asset_tier_key), ENotFoundAssetTier);
        let asset_tier = state::borrow<AssetTierKey<T>, AssetTier<T>>(state, asset_tier_key);
        let asset_tier_id = asset_tier::get_id(asset_tier);
        let lend_amount = asset_tier::amount(asset_tier);
        let duration = asset_tier::duration(asset_tier);

        assert!(coin::value(&lend_coin) == lend_amount, ENotEnoughBalanceToCreateOffer);

        let offer = new_offer<T>(asset_tier_id, lend_coin, duration, interest, lender, ctx);
        let offer_id = object::id(&offer);
        let offer_key = new_offer_key<T>(offer_id);

        state::add<OfferKey<T>, Offer<T>>(state, offer_key, offer);
        state::add_offer(state, offer_id, lender, ctx);

        event::emit(NewOfferEvent {
            offer_id,
            asset_tier_id,
            asset_tier_name,
            amount: lend_amount,
            duration,
            interest,
            status: string::utf8(CREATED_STATUS),
            lender
        })
    }

    public entry fun cancel_offer<T>(
        state: &mut State,
        offer_id: ID,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let offer_key = new_offer_key<T>(offer_id);
        assert!(state::contain<OfferKey<T>, Offer<T>>(state, offer_key), ENotFoundOfferToCancel);
        let offer = state::borrow_mut<OfferKey<T>, Offer<T>>(state, offer_key);
        
        assert!(sender == offer.lender, ESenderIsNotOfferOwner);
        assert!(offer.status == string::utf8(CREATED_STATUS), EInvalidOfferStatus);

        let refund_coin = coin::zero<T>(ctx);
        //TODO: update this value 
        let waiting_interest = coin::zero<T>(ctx);
        let lend_amount = balance::value<T>(&offer.amount);
        let lend_balance = balance::split<T>(&mut offer.amount, lend_amount);

        coin::join<T>(&mut refund_coin, coin::from_balance<T>(lend_balance, ctx));
        coin::join<T>(&mut refund_coin, waiting_interest);

        transfer::public_transfer(refund_coin, sender);

        offer.status = string::utf8(CANCELLED_STATUS);

        event::emit(CancelledOfferEvent {
            offer_id,
            amount: lend_amount,
            duration: offer.duration,
            interest: offer.interest,
            lender: sender,
        })
    }       

    public entry fun edit_offer<T>(
        state: &mut State,
        offer_id: ID,
        interest: u64,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let offer_key = new_offer_key<T>(offer_id);
        assert!(state::contain<OfferKey<T>, Offer<T>>(state, offer_key), ENotFoundOfferToCancel);
        let offer = state::borrow_mut<OfferKey<T>, Offer<T>>(state, offer_key);
        
        assert!(sender == offer.lender, ESenderIsNotOfferOwner);
        assert!(offer.status == string::utf8(CREATED_STATUS), EInvalidOfferStatus);

        offer.interest = interest;

        event::emit(EditedOfferEvent {
            offer_id,
            amount: balance::value<T>(&offer.amount),
            duration: offer.duration,
            interest: offer.interest,
            lender: sender,
        })
    }


    public(friend) fun take_loan<T>(
        offer: &mut Offer<T>,
    ) {
        offer.status = string::utf8(LOANED_STATUS);
    }

    public fun can_be_take_loan<T>(
        offer: &Offer<T>
    ): bool {
        if (offer.status != string::utf8(CREATED_STATUS)) {
            false
        } else {
            true
        }
    }

    public fun new_offer_key<T>(
        offer_id: ID,
    ): OfferKey<T> {
        OfferKey<T> {
            offer_id,
        }
    }

    public fun get_id<T>(
        offer: &Offer<T>
    ): ID {
        object::id(offer)
    }

    public fun get_amount<T>(
        offer: &Offer<T>
    ): u64 {
        balance::value<T>(&offer.amount)
    }

    public fun get_interest<T>(
        offer: &Offer<T>
    ): u64 {
        offer.interest
    }

    public fun get_duration<T>(
        offer: &Offer<T>
    ): u64 {
        offer.duration
    }

    public fun get_lender<T>(
        offer: &Offer<T>
    ): address {
        offer.lender
    }

    fun new_offer<T>(
        asset_tier: ID,
        lend_coin: Coin<T>,
        duration: u64,
        interest: u64,
        lender: address,
        ctx: &mut TxContext,
    ): Offer<T> {
        Offer<T> {
            id: object::new(ctx),
            asset_tier,
            amount: coin::into_balance<T>(lend_coin),
            duration,
            interest,
            status: string::utf8(CREATED_STATUS),
            lender,
        }
    }
}