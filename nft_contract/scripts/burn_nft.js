import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, OPERATOR_CAP } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const NFT = "0xc6a763e014483577ef7fb9ffc991a19c08e814953804310660bc858029107eda";
const KIOSK = "0x2252eac4e7365be293d87e415697877d1a69672fc70025e45c2ee6541ef0b719";
const KIOSK_CAP = "0x6d7da80d05ad063f3686992ae25560df031e95fcc7911235d0bafbc61a426aed";


export const burnNft = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    const functionTarget = `${UPGRADED_PACKAGE}::early_contributor_pass::burn_nft_from_kiosk`;
    tx.moveCall({
        target: functionTarget,
        arguments: [
            tx.object(VERSION),
            tx.pure.id(NFT),
            tx.object(KIOSK),
            tx.object(KIOSK_CAP),
        ]
    });

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Burn Nft');
}

burnNft();