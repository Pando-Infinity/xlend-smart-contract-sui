module lending_contract::offer {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Balance};
    use std::string::{String};

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

    struct NewOfferEvent has store, drop {
        id: ID,
        asset_tier: ID,
        amount: u64,
        duration: u64,
        interest: u64,
        status: String,
        lender: address,
    }
}