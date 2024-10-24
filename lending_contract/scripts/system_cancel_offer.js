import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP, STATE, CONFIGURATION } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

export const systemCancelOffer = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const functionTarget = `${UPGRADED_PACKAGE}::operator::system_cancel_offer`;
    const tx = new TransactionBlock();

    let coins = [];
    let cursor = null;
    const coinType = LEND_COIN_TYPE;
    let i = 0;
    while (i < 5) {
        const paginatedCoins = await suiClient.getAllCoins({
        owner: '0x465370ebd8b13a08d34d92fc6911fa98869c85931135339ad1f858090022635b',
        cursor,
        });
        cursor = paginatedCoins.nextCursor ? paginatedCoins.nextCursor : null;
        const coinsFiltered = paginatedCoins.data.filter((coin) => coin.coinType === coinType);
        coins.push(...coinsFiltered);
        i++;
    }
    const coinsFiltered = coins.map((coin) => coin.coinObjectId);
    const [destinationCoin, ...restCoin] = coinsFiltered;
    tx.mergeCoins(destinationCoin, restCoin);

    const amounts = [100000000, 0];
    const serializedAmounts = amounts.map(amount => tx.pure.u64(amount));
    const [lendCoin, waitingInterestCoin] = tx.splitCoins(destinationCoin, [...serializedAmounts]);

    tx.moveCall({
        target: functionTarget,
        typeArguments: [LEND_COIN_TYPE],
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.object(STATE),
            tx.object(CONFIGURATION),
            tx.pure.id('0xbd06a5fa10fcd2fb62d87e9d61c9c9eedfead8bd8f6fe7074414ccae2f3a2658'),
            lendCoin,
            waitingInterestCoin,
        ]
    });

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'system submit cancel offer');
}

systemCancelOffer()