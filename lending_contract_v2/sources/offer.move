module lending_contract_v2::offer {
    use sui::{
        coin::{Self, Coin},
        event,
    };
    use std::string::String;
    use lending_contract_v2::{
        version::Version,
        configuration::Configuration,
        state::State,
        asset_tier::{Self, AssetTier, AssetTierKey},
    };

    use fun std::string::utf8 as vector.to_string;

    const EInvalidInterestValue: u64 = 1;
    const ENotFoundAssetTier: u64 = 2;
    const ENotEnoughBalanceToCreateOffer: u64 = 3;
    const ENotFoundOfferToCancel: u64 = 4;
    const ENotFoundOfferToEdit: u64 = 5;
    const EInvalidOfferStatus: u64 = 6;
    const ESenderIsNotOfferOwner: u64 = 7;
    const ESenderIsInvalid: u64 = 8;
    const ELendCoinIsInvalid: u64 = 9;

    const CREATED_STATUS: vector<u8> = b"Created";
    const CANCELLING_STATUS: vector<u8> = b"Cancelling";
    const CANCELLED_STATUS: vector<u8> = b"Cancelled";
    const LOANED_STATUS: vector<u8> = b"Loaned";

    public struct OfferKey<phantom T> has store, copy, drop {
        offer_id: ID,
    } 

    public struct Offer<phantom T> has key, store {
        id: UID,
        asset_tier: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        status: String,
        lender: address,
    }

    public struct NewOfferEvent has copy, drop {
        offer_id: ID,
        asset_tier_id: ID,
        asset_tier_name: String,
        amount: u64,
        duration: u64,
        interest: u64,
        status: String,
        lender: address,
    }

    public struct RequestCancelOfferEvent has copy, drop {
        offer_id: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
    }

    public struct CancelledOfferEvent has copy, drop {
        offer_id: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
    }

    public struct EditedOfferEvent has copy, drop {
        offer_id: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
    }

    public entry fun create_offer<T>(
        version: &Version,
        state: &mut State,
        configuration: &Configuration,
        asset_tier_name: String,
        lend_coin: Coin<T>,
        interest: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let lender = ctx.sender();
        
        assert!(interest > 0, EInvalidInterestValue);

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(asset_tier_name);
        assert!(state.contain<AssetTierKey<T>, AssetTier<T>>(asset_tier_key), ENotFoundAssetTier);
        let asset_tier = state.borrow<AssetTierKey<T>, AssetTier<T>>(asset_tier_key);
        let asset_tier_id = asset_tier.id();
        let lend_amount = asset_tier.amount();
        let duration = asset_tier.duration();

        assert!(lend_coin.value() == lend_amount, ENotEnoughBalanceToCreateOffer);

        let hot_wallet = configuration.hot_wallet();
        transfer::public_transfer(lend_coin, hot_wallet);

        let offer = new_offer<T>(asset_tier_id, lend_amount, duration, interest, lender, ctx);
        let offer_id = object::id(&offer);
        let offer_key = new_offer_key<T>(offer_id);

        state.add<OfferKey<T>, Offer<T>>(offer_key, offer);
        state.add_offer(offer_id, lender, ctx);

        event::emit(NewOfferEvent {
            offer_id,
            asset_tier_id,
            asset_tier_name,
            amount: lend_amount,
            duration,
            interest,
            status: CREATED_STATUS.to_string(),
            lender
        });
    }

    public entry fun request_cancel_offer<T>(
        version: &Version,
        state: &mut State,
        offer_id: ID,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let sender = ctx.sender();
        let offer_key = new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToCancel);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);

        assert!(sender == offer.lender, ESenderIsNotOfferOwner);
        assert!(offer.status == CREATED_STATUS.to_string(), EInvalidOfferStatus);

        offer.status = CANCELLING_STATUS.to_string();

        event::emit(RequestCancelOfferEvent {
            offer_id,
            amount: offer.amount,
            duration: offer.duration,
            interest: offer.interest,
            lender: sender,
        });
    }

    public entry fun edit_offer<T>(
        version: &Version,
        state: &mut State,
        offer_id: ID,
        interest: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let sender = ctx.sender();
        let offer_key = new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToEdit);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);
        
        assert!(sender == offer.lender, ESenderIsNotOfferOwner);
        assert!(offer.status == CREATED_STATUS.to_string(), EInvalidOfferStatus);

        offer.interest = interest;

        event::emit(EditedOfferEvent {
            offer_id,
            amount: offer.amount,
            duration: offer.duration,
            interest: offer.interest,
            lender: sender,
        });
    }

    public(package) fun system_cancel_offer<T>(
        offer: &mut Offer<T>,
        configuration: &Configuration,
        lend_coin: Coin<T>,
        waiting_interest: Coin<T>,
        ctx: &mut TxContext,
    ) {
        let sender = ctx.sender();
        let lend_amount = offer.amount;
        let lender = offer.lender;
        let hot_wallet = configuration.hot_wallet();

        assert!(sender == hot_wallet, ESenderIsInvalid);
        assert!(offer.status == CANCELLING_STATUS.to_string(), EInvalidOfferStatus);
        assert!(lend_coin.value() == lend_amount, ELendCoinIsInvalid);

        let mut refund_coin = coin::zero<T>(ctx);
        refund_coin.join<T>(lend_coin);
        refund_coin.join<T>(waiting_interest);
        transfer::public_transfer(refund_coin, lender);

        offer.status = CANCELLED_STATUS.to_string();

        event::emit(CancelledOfferEvent {
            offer_id: object::id(offer),
            amount: lend_amount,
            duration: offer.duration,
            interest: offer.interest,
            lender: lender,
        });
    }

    public(package) fun take_loan<T>(
        offer: &mut Offer<T>,
    ) {
        offer.status = LOANED_STATUS.to_string();
    }

    public fun new_offer_key<T>(
        offer_id: ID,
    ): OfferKey<T> {
        OfferKey<T> {
            offer_id,
        }
    }

    fun new_offer<T>(
        asset_tier: ID,
        lend_amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
        ctx: &mut TxContext,
    ): Offer<T> {
        Offer<T> {
            id: object::new(ctx),
            asset_tier,
            amount: lend_amount,
            duration,
            interest,
            status: CREATED_STATUS.to_string(),
            lender,
        }
    }

    public fun is_available<T>(
        offer: &Offer<T>
    ): bool {
        offer.status == CREATED_STATUS.to_string()
    }

    public fun amount<T>(
        offer: &Offer<T>
    ): u64 {
        offer.amount
    }

    public fun interest<T>(
        offer: &Offer<T>
    ): u64 {
        offer.interest
    }

    public fun duration<T>(
        offer: &Offer<T>
    ): u64 {
        offer.duration
    }

    public fun lender<T>(
        offer: &Offer<T>
    ): address {
        offer.lender
    }

    public fun asset_tier<T>(
        offer: &Offer<T>
    ): ID {
        offer.asset_tier
    }
}