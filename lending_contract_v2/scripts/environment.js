import * as process from "node:process";
import * as dotenv from "dotenv";
dotenv.config();

export const RPC_URL = process.env.RPC_URL || "_";

export const PACKAGE = process.env.PACKAGE || "_";
export const UPGRADED_PACKAGE = process.env.UPGRADED_PACKAGE || "_";
export const UPGRADE_CAP = process.env.UPGRADE_CAP || "_";
export const VERSION_CAP = process.env.VERSION_CAP || "_";
export const OPERATOR_CAP = process.env.OPERATOR_CAP || "_";
export const ADMIN_CAP = process.env.ADMIN_CAP || "_";
export const VERSION = process.env.VERSION || "_";
export const CONFIGURATION = process.env.CONFIGURATION || "_";
export const STATE = process.env.STATE || "_";
export const CUSTODIAN = process.env.CUSTODIAN || "_";

export const LEND_COIN_TYPE = process.env.LEND_COIN_TYPE || "_";
export const SUI_COLLATERAL_COIN_TYPE =
  process.env.SUI_COLLATERAL_COIN_TYPE || "_";

export const OPERATOR_PRIVATE_KEY = process.env.OPERATOR_PRIVATE_KEY || "_";

export const USDC_TOKEN_PACKAGE = process.env.USDC_TOKEN_PACKAGE || "_";
export const USDC_TOKEN_TREASURY_CAP =
  process.env.USDC_TOKEN_TREASURY_CAP || "_";
export const MINT_USDC_PRIVATE_KEY = process.env.MINT_USDC_PRIVATE_KEY || "_";
export const HOT_WALLET_ADDRESS = process.env.HOT_WALLET_ADDRESS || "_";
export const MIN_HEALTH_RATIO = process.env.MIN_HEALTH_RATIO || 12000; // 120%
export const PRICE_TIME_THRESHOLD = process.env.PRICE_TIME_THRESHOLD || 90; // 90 seconds

export const USDC_PRICE_FEED_ID = process.env.USDC_PRICE_FEED_ID || "_";
export const SUI_PRICE_FEED_ID = process.env.SUI_PRICE_FEED_ID || "_";

export const LENDER_FEE_PERCENT = 500;
export const BORROWER_FEE_PERCENT = 500;
export const MAX_OFFER_INTEREST = 20000; //200%
