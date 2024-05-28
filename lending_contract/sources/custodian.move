module lending_contract::custodian {
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::sui::{SUI};
    use sui::coin::{Self};

    friend lending_contract::admin;
    friend lending_contract::operator;

    struct Custodian<> has key, store {
        id: UID,
        treasury_balance: Balance<SUI>,
    }

    public(friend) fun new(ctx: &mut TxContext) {
        let custodian = Custodian {
            id: object::new(ctx),
            treasury_balance: balance::zero<SUI>(),
        };

        transfer::share_object(custodian);
    }

    public(friend) fun add_treasury_balance(
        custodian: &mut Custodian,
        amount: Balance<SUI>,
    ) {
        balance::join(&mut custodian.treasury_balance, amount);
    }

    #[allow(lint(self_transfer))]
    public(friend) fun withdraw_treasury_balance(
        custodian: &mut Custodian,
        ctx: &mut TxContext,
    ) {
        let receive = tx_context::sender(ctx);
        let balance = balance::withdraw_all(&mut custodian.treasury_balance);
        let coin = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin, receive);
    }
}