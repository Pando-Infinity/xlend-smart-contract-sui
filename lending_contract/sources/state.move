module lending_contract::state {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::dynamic_object_field as ofield;


    friend lending_contract::operator;
    friend lending_contract::admin;

    struct State has key, store{
        id: UID
    }

    public(friend) fun new(
        ctx: &mut TxContext,
    ) {
        let state = State {
            id: object::new(ctx),
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
}