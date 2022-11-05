// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PlastikToken.sol";


// 35714285714285714 = MAX Burn per year =   ((Total PLASTIK supply) / (Years to meet plastic neutrallity))
// 1Kg PRG burns =   ((Total PLASTIK supply) / (Years to meet plastic neutrallity)) / (Yearly Plastic production in KG) PLASTIK
// Total PLASTIK supply = 1.000.000.000 PLASTIK
// Years to meet plastic neutrallity = 28
// MAX Burn per year = 35.714.285 PLASTIK
// Yearly Plastic production in KG = (will vary every year, but for now) 300.000.000.000 KG
// 1KG PRG burns (until MAX Burn per year is achieve) -> 0.000119047 PLASTIK (edited) 

contract PlastikBurner is Ownable {

    PlastikToken plastikToken;

    uint96 year = 2022;

    uint256 maxBurnYear = 35714285714285714;
    uint256 plasticProduction = 300000000000;  // 300 bil
    uint256 burnPerKg = 119047; // 0.000119047 PLASTIK per Kg

    event PlastikBurned(address indexed sender, uint256 quantity, uint96 indexed year);

    constructor(address plastikTokenAddress, uint96 _year, uint256 _plasticProduction, uint256 _maxBurnYear) {
        plastikToken = PlastikToken(plastikTokenAddress);
        year = _year;
        plasticProduction = _plasticProduction;
        require(_plasticProduction > 0, "plasticProduction must be bigger than 0");
        require(_maxBurnYear > 0, "maxBurnYear must be bigger than 0");
        maxBurnYear = _maxBurnYear;
        burnPerKg = _maxBurnYear / _plasticProduction;
    }

    //Burn Rate per Kg
    function currentBurnRate() public view returns (uint256) {
        uint256 balance = plastikToken.balanceOf(address(this));
        if(balance < maxBurnYear) {
            return burnPerKg;
        }
        return 0;
    }

    function getBalance() external view returns (uint256){
        return plastikToken.balanceOf(address(this));
    }

    function setPlasticProduction(uint256 quantity) onlyOwner public returns (bool) {
        require(quantity > 0, "plasticProduction must be bigger than 0");
        plasticProduction = quantity;
        burnPerKg = maxBurnYear / plasticProduction;
        return true;
    }

    function setMaxBurnYear(uint256 quantity) onlyOwner public returns (bool) {
        require(quantity > 0, "maxBurnYear must be bigger than 0");
        maxBurnYear = quantity;
        burnPerKg = maxBurnYear / plasticProduction;
        return true;
    }

}
