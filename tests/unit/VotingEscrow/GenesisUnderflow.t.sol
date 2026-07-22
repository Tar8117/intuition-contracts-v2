// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console2 } from "forge-std/src/Test.sol";
import { stdError } from "forge-std/src/StdError.sol";

interface IVotingEscrowView {
    function point_history(uint256 idx) external view returns (int128 bias, int128 slope, uint256 ts, uint256 blk);
    function totalSupplyAtT(uint256 t) external view returns (uint256);
    function balanceOfAtT(address addr, uint256 t) external view returns (uint256);
}

contract GenesisUnderflowTest is Test {
    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;

    function setUp() external {
        vm.createSelectFork("intuition");
    }

    function test_totalSupplyAtT_revertsForTimestampBeforeGenesisCheckpoint() external {
        IVotingEscrowView ve = IVotingEscrowView(TRUST_BONDING_PROXY);

        (,, uint256 genesisTs,) = ve.point_history(0);
        assertGt(genesisTs, 0, "genesis checkpoint must exist");

        // t_i - last_point.ts runs in uint256 before the int256 cast in
        // _supply_at, so asking for a time before genesis underflows
        // instead of returning 0
        vm.expectRevert(stdError.arithmeticError);
        ve.totalSupplyAtT(genesisTs - 1);

        // works fine right at genesis
        uint256 supplyAtGenesis = ve.totalSupplyAtT(genesisTs);
        console2.log("supply at genesis timestamp:", supplyAtGenesis);

        // balanceOfAtT casts each side to int256 first, so same input here is fine
        uint256 bal = ve.balanceOfAtT(address(0xdead), genesisTs - 1);
        assertEq(bal, 0, "balanceOfAtT should safely return 0, not revert");
    }
}
