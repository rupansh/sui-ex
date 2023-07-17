//! Authority & Claim utilities for the NFTs
module nft::authority {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    friend nft::bomb;

    /// Belongs to the authority 
    struct Authority has key { id: UID }

    /// NFT Claim
    /// validity of a claim must be checked with `authority::valid`
    struct Claim has key {
        id: UID,
        claim_start: u64,
        nft_cnt: u64,
    }

    /// Initializer
    /// caller becomes the authority
    fun init(ctx: &mut TxContext) {
        let owner = Authority { id: object::new(ctx) };
        transfer::transfer(owner, tx_context::sender(ctx));
    }

    /// Transfer authority to another address
    entry fun transfer_authority(owner: Authority, new_owner: address) {
        transfer::transfer(owner, new_owner);
    }

    /// Generate a new claim and grant it to user
    /// claimer - user to grant the claim to
    /// claim_start - time when the user can claim nfts
    /// nft_cnt - number of nfts that can be claimed
    entry fun new_claim(_: &Authority, claimer: address, claim_start: u64, nft_cnt: u64, ctx: &mut TxContext) {
        let claim = Claim {
            id: object::new(ctx),
            claim_start,
            nft_cnt,
        };
        transfer::transfer(claim, claimer);
    }

    /// validate a claim
    public(friend) fun valid(claim: &Claim, clock: &Clock): bool {
        let time = clock::timestamp_ms(clock);
        time >= claim.claim_start
    }

    /// delete a claim
    /// returns the nft_cnt
    public(friend) fun delete_claim(claim: Claim): u64 {
        let Claim { id, claim_start: _, nft_cnt } = claim;
        object::delete(id);

        nft_cnt
    }

    #[test]
    public fun test_scenario_authority() {
        use sui::test_scenario as ts;

        let admin = @0x4D519;
        let claimer = @0x50B;
        let claimer2 = @0x40B;

        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(ts::ctx(scenario));
        };

        let clock_val = clock::create_for_testing(ts::ctx(scenario));

        ts::next_tx(scenario, admin);
        {
            let authority = ts::take_from_sender<Authority>(scenario);
            new_claim(&authority, claimer, 0, 1, ts::ctx(scenario));
            new_claim(&authority, claimer2, clock::timestamp_ms(&clock_val) + 1000, 1, ts::ctx(scenario));
            ts::return_to_sender(scenario, authority);
        };

        ts::next_tx(scenario, claimer);
        {
            let claim = ts::take_from_sender<Claim>(scenario);
            assert!(valid(&claim, &clock_val), 1);
            ts::return_to_sender(scenario, claim);
        };

        ts::next_tx(scenario, claimer2);
        {
            let claim = ts::take_from_sender<Claim>(scenario);
            assert!(!valid(&claim, &clock_val), 1);
            ts::return_to_sender(scenario, claim);
        };

        clock::destroy_for_testing(clock_val);
        ts::end(scenario_val);
    }
}