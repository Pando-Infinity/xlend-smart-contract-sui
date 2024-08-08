module lending_contract_v2::offer_registry {
    use sui::{
        coin::{Self, Coin},
        event,
    };
    use std::string::String;
    
    use fun std::string::utf8 as vector.to_string;

    const EInvalidOfferStatus: u64 = 1;
    const ESenderIsNotOfferOwner: u64 = 2;
    const ESenderIsInvalid: u64 = 3;
    const ELendCoinIsInvalid: u64 = 4;


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

    
    public(package) fun new_offer<T>(
        asset_tier: ID,
        asset_tier_name: String,
        lend_amount: u64,
        duration: u64,
        interest: u64,
        lender: address,
        ctx: &mut TxContext,
    ): Offer<T> {
        let offer = Offer<T> {
            id: object::new(ctx),
            asset_tier,
            amount: lend_amount,
            duration,
            interest,
            status: CREATED_STATUS.to_string(),
            lender,
        };

        event::emit(NewOfferEvent {
            offer_id: object::id(&offer),
            asset_tier_id: asset_tier,
            asset_tier_name,
            amount: lend_amount,
            duration,
            interest,
            status: CREATED_STATUS.to_string(),
            lender
        });

        offer
    }

    public(package) fun cancel_offer<T>(
        offer: &mut Offer<T>,
        sender: address,
    ) {
        assert!(sender == offer.lender, ESenderIsNotOfferOwner);
        assert!(offer.status == CREATED_STATUS.to_string(), EInvalidOfferStatus);

        offer.status = CANCELLING_STATUS.to_string();

        event::emit(RequestCancelOfferEvent {
            offer_id: object::id(offer),
            amount: offer.amount,
            duration: offer.duration,
            interest: offer.interest,
            lender: sender,
        });
    }

    public(package) fun edit_offer<T>(
        offer: &mut Offer<T>,
        interest: u64,
        sender: address,
    ) {
        assert!(sender == offer.lender, ESenderIsNotOfferOwner);
        assert!(offer.status == CREATED_STATUS.to_string(), EInvalidOfferStatus);

        offer.interest = interest;

        event::emit(EditedOfferEvent {
            offer_id: object::id(offer),
            amount: offer.amount,
            duration: offer.duration,
            interest: offer.interest,
            lender: sender,
        });
    }

    public(package) fun system_cancel_offer<T>(
        offer: &mut Offer<T>,
        lend_coin: Coin<T>,
        waiting_interest: Coin<T>,
        hot_wallet: address,
        ctx: &mut TxContext,
    ) {
        let sender = ctx.sender();
        let lend_amount = offer.amount;
        let lender = offer.lender;

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