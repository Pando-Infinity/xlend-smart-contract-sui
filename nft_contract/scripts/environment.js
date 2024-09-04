import * as process from "node:process";
import * as dotenv from "dotenv";
dotenv.config();

export const RPC_URL = process.env.RPC_URL || "_";

export const PACKAGE = process.env.PACKAGE || "_";
export const UPGRADED_PACKAGE = process.env.UPGRADED_PACKAGE || "_";
export const VERSION = process.env.VERSION || "_";
export const OPERATOR_CAP = process.env.OPERATOR_CAP || "_";

export const OPERATOR_PRIVATE_KEY = process.env.OPERATOR_PRIVATE_KEY || "_";

export const DISTRIBUTE_NFTS_CSV_PATH = process.env.DISTRIBUTE_NFTS_CSV_PATH;
export const PER_CHUNK = parseInt(process.env.PER_CHUNK);
