## Deploy

- Must have Foundry installed

- add values to the env file

- source .env

- deploy crate implementation

  - forge create --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $BASESCAN_KEY --verify --chain-id $CHAIN_ID src/crate/Crate.sol:Crate
  - grab newly deployed contract address from console output

- deploy crate registry
  - forge create --rpc-url $BASE_SEPOLIA_RPC_URL --constructor-args <CRATE IMPL ADDRESS> --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $BASESCAN_KEY --verify --chain-id $CHAIN_ID src/crate/CrateRegistry.sol:CrateRegistry
 
## Guide
overview 


Terms to know before hand 

`Crate` - an onchain list 

`Record` - a list item in a crate

`Application` - a proposed list item that has not been added to the list yet.

`Poll Registry` -  a voting contract used to resolve disputes around what should be listed in a crate 

`Curation Token` - erc20 token that grants access to help curate to a list. (this can be any erc20)

`Affinity` - contract to help manage the level of affection for a crate onchain (decentralized likes)

CRATE 

`create`
    Whether youre deploying the crate manually or via our free to use crate factory, you will need to initialize the contract. Here is a quick rundown of the neccesary parameters to get you going. 
    
        _crateInfo crate metadata string (i.e. ipfs://<hash>)
        _token erc20 address that will serve as the gate for curators on this crate (curation token)
        _voting poll registry address for resolving disputes (default address is and can be used by anyone creating a new crate)
        _minDeposit the minimum number of tokens needed to propose a record
        _owner crate owner address for admin updates

`propose`
    the propose function is how we add items to a list.
    
        _recordHash keccak256 hash of a record identifier
        _amount the amount of tokens to stake for this record (must be at least minimum deposit)
        _data metadata string for this record.
            - i.e. ipfs://<hash> or pointer to where to get record metadata. 
            - if metadata string resolves to an object, the object should have an `id` attribute where the value is the raw(unhashed) record identifier
        _signature oracle signature (will be ignored if no verifier address is set on crate)
        _isPrivate this indicates whether record has been encrypted off chain (should be false for public records) 

    Depending on the what the application duration for a crate is, it will either add the record to our crate or create an Application that is not listed until the app duration has expired 
    without a challenge. The default behavior is immedietely list a record without any application but can be updated by an admin. 

`resolveApplication`

  used to resolve applications that have passed the application time period without any challenges from other curators of this crate. 
    once triggered it will move the record from application state to listed state

`removeRecord`

  whether a record or an application, the proposer can call this to remove the listing from the contract and reclaim their staked tokens. listing cannot be in challenged state. 

`challenge` 

  A challenge is how curators can refine a crate. When a record or application is proposed that another curator doesnt think should be on the list, the challenger can stake tokens 
    to trigger a community vote (only token holders can vote). This invokes the poll registry and immedietely starts a voting period. once voting has concluded, a challenge can be resolved. 

`resolveChallenge`

  resolving a challenge gets the results of a poll and reacts based on what the commuinity decided for this specific record. If a poll has passed, that means the challenge failed and the original proposer
    gets the challenger's staked deposit and the record stays on the list. If a poll has failed, the challenger gets the proposer's staked deposit and the record or application is removed. 


Admin and other features: 

  - sortability
  
  - pausible
  
  - private  
  
  - seal crate 
  
  - max length
  
  - app duration 
  
  - list duration 
  
  - ERC20 token address
  
  - crate info 
  
  - oracle address
  
  - affinity



POLL REGISTRY

`createPoll`

  this function creates a poll and immedietely opens vote committing. Function takes a few parameters 
      - the curationToken address to gate who can vote (only token holders)
      - the original proposer address for the record being voted on 
      - the address of the person challenging this record 

`commitVote`

  once a poll is created, the commit period begins immedietely and lasts for the commit duration (a constant variable set on the poll registry contract). 
  Voters will submit a hashed vote in this step which is a keccak256 hash of the vote (true or false) + a random number.
  Voters will also submit a number of tokens greater than zero to indicate how strongly they stand behind their vote.  
  In order to encourage voters to vote accurately, instead of going along with the majority, voting is done in a 2 steps and votes are not tallied until after the reveal step. 

`revealVote`

  once the commit period has concluded, the reveal period immedietely begins. The reveal duration is also a const value set on the poll registry contract. 
  Voters who committed a vote can now come reveal their vote so that it can be tallied. To reveal a vote, 
  users must provide the original vote and random number used to commit the vote. The contract will verify and then tally the vote and amount. 
  Users who commit a vote but dont reveal, forfit their staked amount

`resolvePoll` 

  once the reveal period has concluded, this function can be called to determine if a poll has passed or failed and sets the correct winning state and winner address.
  vote quorum is a constant set on the contract and determines how many votes are needed for the Poll to pass. our deployed default has qurom set to 50. 
  this function can be called directly from the crates contract using the resolveChallenge function.

`withdrawBalance` 

  once a poll has ended, winning voters can begin to withdraw their staked tokens + reward tokens. The reward pool is all staked tokens by the losing voters. Winners will earn 
  their cut of the reward tokens based on how much tokens they staked from the winner pool. Example: If I voted for the winner and I staked about 50% of the total staked by all winning voters, 
  then my reward amount would be 50% of the losing voters total staked amount (aka the reward pool)

REWARD

  reward is a small implementation contract that implements one function rewardPoolShare. 
  This function is used by the Poll registry to calculate what voter earnings are based on the reward pool and the percentage of the winner pool that a user staked. 

AFFINITY

  the Affinity contract is used to link an 1155 contract and token id to a crate. This allows for all clients surfacing the crate to use the same mechanism for tracking popularity.
  This also allows clients to tap into already established infrastructure around token balances to easily surface which crates are "going viral". The way its architectured allows for crates to not have "affinity" set up but if it is set up, it can be called directly from the crate contract. 

  the 2 function that make the Affinity contract are: 
  
  - showLove -  runs logic to indicate a "like" (should ideally be an 1155 mint to the caller address)
  - haveLove -  indicates whether affinity has been set up for a crate or not. 


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
