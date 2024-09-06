This is the NFT contract for the Ensofi Project.

## Development

### Prerequisites

- `sui` cli

### Deployment checklist

- [ ] Switch to desired env (dev or prod)

```bash
cp .env.prod .env
cp Move.prod.toml Move.toml
```

- [ ] Check SUI enviroment

#### To check active env

```bash
sui client active-env
```

#### To activate mainnet

```bash
sui client switch --env mainnet
```

- [ ] Check deployer address

#### To check active address

```bash
sui client active-address
```

#### To activate address

```bash
sui client switch --address <address>
```

#### To import new wallet (private key with scheme is ed25519)

```bash
sui keytool import <private_key> ed25519 --alias <alias>
```

- [ ] Check Admin and Operator address (Move.toml)

```bash
admin="0xdfda63ad61f8ad5176c1107cb4a8377e3da14221221c3890d7f5a71a800dbbff"
operator="0x21ff4b83eb1bcabe4f470addf4dab5be10177df2f2658925c517eceb55e48785"
```

- [ ] Publish

```bash
./scripts/bash/publish.sh
```

- [ ] Update env (package)

```bash
PACKAGE=''
UPGRADED_PACKAGE=''
OPERATOR_CAP=''
VERSION=''
```
