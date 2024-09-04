import { decodeSuiPrivateKey } from '@mysten/sui.js/cryptography';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';

export const getSignerByPrivateKey = (privateKey) => {
    const { schema, secretKey } = decodeSuiPrivateKey(privateKey);
    return Ed25519Keypair.fromSecretKey(secretKey, {
        skipValidation: true,
    });
};

export const NFT_NAME = "EnsoFi Early Contributor Pass";
export const NFT_SYMBOL = "ENSO";
export const NFT_DESCRIPTION = "This NFT pass is required for early access to EnsoFi on Sui";
export const NFT_IMAGE_URL = "https://blush-deep-leech-408.mypinata.cloud/ipfs/QmSQVYcwQ8bLGxfqWTgRY3xceAw4CgAn9Fd7iFWD8TcH1M";
export const NFT_ATTRIBUTE_KEYS = [];
export const NFT_ATTRIBUTE_VALUES = [];