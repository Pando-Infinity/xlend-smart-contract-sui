import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, OPERATOR_CAP } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const NFT = '';

export const burnNft = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    const functionTarget = `${UPGRADED_PACKAGE}::early_contributor_pass::burn_nft`;
    tx.moveCall({
        target: functionTarget,
        arguments: [
            tx.object(VERSION),
            tx.object(NFT),
        ]
    });

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Burn Nft');
}

burnNft();