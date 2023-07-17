module nft::bomb {
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::event;
    use std::string::{utf8, String};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::package;
    use sui::display;
    use nft::authority;

    /// errors
    const EInvalClaim: u64 = 1;
    const EExplodeTooSoon: u64 = 2;
    const ENotOwner: u64 = 3;

    /// A bomb
    /// num is the bomb number
    /// explode_prefix is "explosion" if exploded
    /// minter is the address of the first owner
    struct BombNft has key, store {
        id: UID,
        num: u64,
        explode_prefix: String,
        minter: address,
    }

    struct BombState has key {
        id: UID,
        cnt: u64,
        bomb_ticker: u64,
    }

    /// OTW
    struct BOMB has drop {}

    /// events

    /// when a bomb is claimed
    struct BombClaimed has copy, drop {
        num: u64,
    }

    /// when bomb has exploded
    struct BombExploded has copy, drop {
        num: u64,
    }

    /// Initializer
    /// otw - One time witness
    /// explode_time_ms - time at which users can explode their bombs
    fun init(otw: BOMB, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"first_owner"),
        ];
        let values = vector[
            utf8(b"BOMB #{num}"),
            utf8(b"https://bombs.randomxyz/bomb/{explode_prefix}{num}.png"),
            utf8(b"signed by {minter}"),
        ];

        let state = BombState {
            id: object::new(ctx),
            cnt: 0,
            bomb_ticker: 0,
         };
         transfer::share_object(state);

        let publisher = package::claim(otw, ctx);
        let display = display::new_with_fields<BombNft>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    entry fun set_explode_time(state: &mut BombState, _: &authority::Authority, new_time: u64, _ctx: &mut TxContext) {
        state.bomb_ticker = new_time;
    }

    entry fun claim_nfts(state: &mut BombState, clk: &Clock, claim: authority::Claim, ctx: &mut TxContext) {
        assert!(authority::valid(&claim, clk), EInvalClaim);
        let nft_cnt = authority::delete_claim(claim); 

        let i = 0;
        while (i < nft_cnt) {
            state.cnt = state.cnt + 1;
            let nft = BombNft {
                id: object::new(ctx),
                num: state.cnt,
                explode_prefix: utf8(b""),
                minter: tx_context::sender(ctx),
            };
            event::emit(BombClaimed { num: state.cnt });
            transfer::public_transfer(nft, tx_context::sender(ctx));
            i = i + 1;
        };
    }

    entry fun explode(state: &mut BombState, clk: &Clock, nft: &mut BombNft, _ctx: &mut TxContext) {
        assert!(clock::timestamp_ms(clk) >= state.bomb_ticker, EExplodeTooSoon);
        nft.explode_prefix = utf8(b"exploded/");
        event::emit(BombExploded { num: nft.num });
    }
}