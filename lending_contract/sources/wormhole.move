module lending_contract::wormhole {
    use sui::clock::{Clock};
    use sui::object::{Self, UID};
    use sui::coin::{Coin};
    use sui::transfer::{Self};
    use sui::tx_context::{TxContext};
    use sui::sui::{SUI};

    use wormhole::emitter::{Self, EmitterCap};
    use wormhole::state::{Self, State};
    use wormhole::publish_message;

    friend lending_contract::loan_crosschain;
    friend lending_contract::operator;

    struct ProtectedET has key, store {
        id: UID,
        emitter_cap: EmitterCap,
    }

    #[allow(lint(share_owned))]
    public(friend) fun init_emitter(
        wormhole_state: &State,
        ctx: &mut TxContext,
    ) {
        let emitter_cap = emitter::new(wormhole_state, ctx); 
        let protectedET = ProtectedET {
            id: object::new(ctx),
            emitter_cap,
        };
        transfer::public_share_object(protectedET);
    }

    public(friend) fun send_message(
        protectedET: &mut ProtectedET,
        wormhole_state: &mut State,
        payload: vector<u8>,
        message_fee: Coin<SUI>,
        clock: &Clock,
    ): u64 {
        let emitter_cap = &mut protectedET.emitter_cap;
        let message = publish_message::prepare_message(
            emitter_cap,
            0,
            payload
        );

        let sequence = publish_message::publish_message(
            wormhole_state,
            message_fee,
            message,
            clock,
        );

        sequence
    }

    public fun message_fee(
        wormhole_state: &mut State,
    ): u64 {
        state::message_fee(wormhole_state)
    }
}