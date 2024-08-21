# Crate Protocol



## Summary 
#### TL;DR - A customizable [Token Curated Registry(TCR)](https://education.district0x.io/general-topics/understanding-ethereum/token-curated-registry/) to manage shared lists onchain

#### Description
Capture the collective mind set of a community with a curated list powered by Crate Protocol. Crate protocol is a collection of smart contracts that can be leveraged to manage onchain lists of anything. 
The list is token gated so contributions can only come from token holders. This enables an inherit tier system for a given user’s influence over the list. 
For example: if the crate is set up to stake 10 $DEGEN in order to add a record, a person with 50 $DEGEN will have significantly less influence on the list than a person with 1000 $DEGEN. 
This works well in situations where a community would like to limit the contribution amount for a user before issuing them larger influence on the list. 

There’s an opt in voting mechanism that can be utilized to resolve disputes and can also be used to gain reputation by casting your vote and earning community tokens for voting correctly. 

There’s other customizations that can be made in order to fit the needs of any list maker: 
- Sortability 
    - Lists are unordered by default but community has ability to order list item (its possible to only have part of the list ordered)
    - Sortability can be toggled on or off by crate admin. 

- App / List / Vote / Reveal durations are completely customizable. Admins can set the durations for:
    - Applications so that records aren’t immediately added to a list
    - Listings to determine how long an item will stay on the list
    - Voting to determine the window of time users have to cast their votes
    - Vote Reveals to determine the window of time users have to reveal their casted votes
 
- Quorum and Reward structure
    - The vote quorum is defined on the voting contract used by your crate. We have a deployed voting contract that all new crates could leverage where the vote quorum is set to 50.
    - Reward distribution can be customized to define the perfect payout structure for winning voters
	
- List length
    - Limit the number of records that can be added to the crate 
- Pausable
    - Temporarily pause record additions or removals for a crate
- Sealable
    - Permanently lock the list as is.  Locks the current records and any defined sort order foreverrrr
- Private listing
    - Crates are entirely managed on chain but with Crate Protocol there is a way to add private records. This involves an off chain element to encrypt the data going on chain but the protocol does offer functionality to “reveal” a private listing.
    - In the crate world list metadata is never private but individual list items can be. This means it is possible to have some public and some private records in one crate.
- Affinity
    - This is a customizable extension that can be defined to customize how “likes” are managed onchain. This would enable any clients surfacing your list can track how popular something is in the same way. 
    - Example: You can customize a crate’s affinity module to mint a dedicated Zora token when “liked”
    - This does not have to be defined. 

Why onchain?
- Multiple clients
    - Stop migrating lists and start sharing them. Clients can tap into any on chain list and build their own ideal ui on top of it. Changes will be surfaced everywhere 
- Reputation tracing 
    - Track a users reputation by being able to trace which items they have added to a list, which of those items have stayed on the list and if their voting record aligns with the community’s. 
- Shared affinity management
    - One way to track a crate’s success regardless of what client is surfacing / facilitating it
- Community ID
    - ERC20s give users the power to trustlessly identify themselves as community members. Crate protocol taps into this to power the entire protocol. 
- List integrity 
    - The protocol inherently flushes out bad actors or contributors not in line with the community mindset. This means over time the contributors constantly voting correctly and without challenges to their own added records will gain more influence over the list. 
- Access control
    - Decide how you would like to distribute contributor tokens as this is the gate to be a curator on a crate. 

Crate Protocol has some added functionality to help manage the perfect list. A lot of the features are opt in for complete customization. Here are a few key points: 

- Users stake ERC20 tokens to add a record(list item) to a crate(list). 
- User’s can reclaim their tokens by removing the added record from the list. 
- Contributors can challenge a list to trigger a community vote
- List items must be unique and can represent anything as its is just storing metadata about the record onchain. 
- Inherently tiered contribution levels
- Scalable to manage lists for one user or many. 
- Flexible. Complete customizable to fit any list’s needs
- Portable. Anyone can build their own client to surface crate list items
- Transparency. Reputations for any contributor can be tracked via onchain crate activity.  
- Attach a custom onchain “like” mechanism using an Affinity module
- Public or private records can be added to any crate


#### Some example use cases: 
- Friends with Benefits can create a crate for the community to stake $FWB and build an artist wishlist for next years FWB fest. 
- ETH Denver organizers can create a free-to-claim erc20 for promoters to add their event to a shared list of ETH Denver satellite events
- Labels can create a crate with $USDC as the token, so that artists can apply to drop an NFT under the label’s banner
- Onchain music NFT playlists (check out [gatefold.xyz](https://dev.gatefold.xyz))

## Protocol fees
#### Crate Protocol is proudly a [Hyperstructure](https://zine.zora.co/issue/intergenerational-dynamics/hyperstructures-redux). This means that creating and managing crates will be free and open foreverrr.

## Deployed crate factory contract 
#### You can create your own onchain list by hitting our deployed factory contracts. See below for deployed factory addresses or deploy your own factory. 

Deployed Addresses: 

Base Sepolia

Crate Factory - 0xAbaD0Cb44c4185fE02007Ee9F10E2C46748AE3fb

Poll Registry - 0x96faD698e93fA5A06Bd4c5d60A4f4df3930A9d62

Base Mainnet 

Soon....

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
