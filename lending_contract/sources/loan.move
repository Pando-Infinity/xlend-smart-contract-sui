module lending_contract::loan {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use std::string::{Self, String};
    use std::option::{Self, Option};

    struct Liquidation has store, drop {
        liquidating_at: u64,
        liquidating_price: u64,
        liquidated_tx: Option<String>,
        liquidated_price: Option<u64>,
    }

    struct Loan<phantom T> has key, store {
        id: UID,
        offer: ID,
        interest: u64,
        amount: u64,
        duration: u64,
        collateral: Balance<T>,
        lender: address,
        borrower: address,
        start_timestamp: u64,
        liquidation: Option<Liquidation>,
        status: String,
    }

    
}