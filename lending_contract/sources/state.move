module lending_contract::state {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::dynamic_object_field as ofield;
    use sui::table::{Self, Table};

    friend lending_contract::operator;
    friend lending_contract::admin;
    friend lending_contract::offer;
    friend lending_contract::loan;

    struct State has key, store{
        id: UID,
        offers: Table<address, Table<u64, ID>>, 
        loans: Table<address, Table<u64, ID>>,
    }

    public(friend) fun new(
        ctx: &mut TxContext,
    ) {
        let state = State {
            id: object::new(ctx),
            offers: table::new<address, Table<u64, ID>>(ctx),
            loans: table::new<address, Table<u64, ID>>(ctx),
        };

        transfer::share_object(state);
    }

    public(friend) fun add<K: copy + drop + store, V: key + store>(
        state: &mut State,
        key: K,
        value: V
    ) {
        ofield::add(&mut state.id, key, value);
    }

    public(friend) fun borrow<K: copy + drop + store, V: key + store>(
        state: &State,
        key: K
    ): &V {
        ofield::borrow<K, V>(&state.id, key)
    }

    public(friend) fun borrow_mut<K: copy + drop + store, V: key + store>(
        state: &mut State,
        key: K
    ): &mut V {
        ofield::borrow_mut<K, V>(&mut state.id, key)
    }

    public(friend) fun contain<K: copy + drop + store, V: key + store>(
        state: &State,
        key: K
    ): bool {
        ofield::exists_with_type<K, V>(&state.id, key)
    }

    public(friend) fun add_offer(
        state: &mut State,
        offer_id: ID,
        lender: address,
        ctx: &mut TxContext,
    ) {
        if (!table::contains<address, Table<u64, ID>>(&state.offers, lender)) {
            table::add<address, Table<u64, ID>>(&mut state.offers, lender, table::new<u64,ID>(ctx));
        };
        let offers = table::borrow_mut<address, Table<u64, ID>>(&mut state.offers, lender);
        let length = table::length<u64, ID>(offers);

        table::add<u64, ID>(offers, length + 1, offer_id);
    }

    public(friend) fun add_loan(
        state: &mut State,
        loan_id: ID,
        borrower: address,
        ctx: &mut TxContext,
    ) {
        if (!table::contains<address, Table<u64, ID>>(&state.loans, borrower)) {
            table::add<address, Table<u64, ID>>(&mut state.loans, borrower, table::new<u64,ID>(ctx));
        };
        let loans = table::borrow_mut<address, Table<u64, ID>>(&mut state.loans, borrower);
        let length = table::length<u64, ID>(loans);

        table::add<u64, ID>(loans, length + 1, loan_id);
    }
}