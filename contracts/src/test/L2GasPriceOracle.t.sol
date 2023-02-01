// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { DSTestPlus } from "solmate/test/utils/DSTestPlus.sol";
import { WETH } from "solmate/tokens/WETH.sol";

import { L1BlockContainer } from "../L2/predeploys/L1BlockContainer.sol";
import { L2GasPriceOracle } from "../L2/predeploys/L2GasPriceOracle.sol";

contract L2GasPriceOracleTest is DSTestPlus {
  uint256 private constant PRECISION = 1e9;
  uint256 private constant MAX_OVERHEAD = 30000000 / 16;
  uint256 private constant MAX_SCALE = 1000 * PRECISION;

  L2GasPriceOracle private oracle;
  L1BlockContainer private container;

  function setUp() public {
    container = new L1BlockContainer(address(0), address(0));
    oracle = new L2GasPriceOracle(address(this), address(container));
  }

  function testSetOverhead(uint256 _overhead) external {
    _overhead = bound(_overhead, 0, MAX_OVERHEAD);

    // call by non-owner, should revert
    hevm.startPrank(address(1));
    hevm.expectRevert("caller is not the owner");
    oracle.setOverhead(_overhead);
    hevm.stopPrank();

    // overhead is too large
    hevm.expectRevert("exceed maximum overhead");
    oracle.setOverhead(MAX_OVERHEAD + 1);

    // call by owner, should succeed
    assertEq(oracle.overhead(), 0);
    oracle.setOverhead(_overhead);
    assertEq(oracle.overhead(), _overhead);
  }

  function testSetScalar(uint256 _scalar) external {
    _scalar = bound(_scalar, 0, MAX_SCALE);

    // call by non-owner, should revert
    hevm.startPrank(address(1));
    hevm.expectRevert("caller is not the owner");
    oracle.setScalar(_scalar);
    hevm.stopPrank();

    // scale is too large
    hevm.expectRevert("exceed maximum scale");
    oracle.setScalar(MAX_SCALE + 1);

    // call by owner, should succeed
    assertEq(oracle.scalar(), 0);
    oracle.setScalar(_scalar);
    assertEq(oracle.scalar(), _scalar);
  }

  function testGetL1GasUsed(uint256 _overhead, bytes memory _data) external {
    _overhead = bound(_overhead, 0, MAX_OVERHEAD);

    oracle.setOverhead(_overhead);

    uint256 _gasUsed = _overhead + 68 * 16;
    for (uint256 i = 0; i < _data.length; i++) {
      if (_data[i] == 0) _gasUsed += 4;
      else _gasUsed += 16;
    }

    assertEq(oracle.getL1GasUsed(_data), _gasUsed);
  }

  function testGetL1Fee(
    uint256 _baseFee,
    uint256 _overhead,
    uint256 _scalar,
    bytes memory _data
  ) external {
    _overhead = bound(_overhead, 0, MAX_OVERHEAD);
    _scalar = bound(_scalar, 0, MAX_SCALE);
    _baseFee = bound(_baseFee, 0, 1e9 * 20000); // max 20k gwei

    oracle.setOverhead(_overhead);
    oracle.setScalar(_scalar);
    container.initialize(address(0), bytes32(0), 0, 0, uint128(_baseFee), bytes32(0));

    uint256 _gasUsed = _overhead + 68 * 16;
    for (uint256 i = 0; i < _data.length; i++) {
      if (_data[i] == 0) _gasUsed += 4;
      else _gasUsed += 16;
    }

    assertEq(oracle.getL1Fee(_data), (_gasUsed * _baseFee * _scalar) / PRECISION);
  }
}