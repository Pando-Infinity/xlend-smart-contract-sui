import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP, CONFIGURATION, STATE } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const NAME = "asset_tier_sui_001";
const AMOUNT = 100000000;
const DURATION = 1209600;

const initAssetTier = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${UPGRADED_PACKAGE}::operator::init_asset_tier`,
        typeArguments: [LEND_COIN_TYPE],
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.object(STATE),
            tx.pure.string(NAME),
            tx.pure.u64(AMOUNT),
            tx.pure.u64(DURATION),
        ]
    })

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Init asset tier');
}

initAssetTier()