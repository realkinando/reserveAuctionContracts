//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

struct Auction{
    address payable owner;
    uint tokenId;
    uint duration;
    uint reservePrice;
}

struct Bid{
    address payable bidder;
    uint amount;
    uint bidTime;
    uint auctionId;
}

contract ETHZoraReserveAuctions{

    enum AuctionStatus {ReserveUnmet,ReserveMet,Cancelled,Ended}

    mapping(uint => Auction) private _auctions;
    mapping(uint => Bid) private _auctionLastBid;
    mapping(uint => AuctionStatus) private _auctionStatus;

    uint private _auctionCount;

    address public zoraMedia;

    constructor(address _zoraMedia){
        zoraMedia = _zoraMedia;
    }

    function getAuction(uint auctionId) external view returns(Auction memory auction){
        auction = _auctions[auctionId];
    }

    function getLastBid(uint auctionId) external view returns(Bid memory lastBid){
        lastBid = _auctionLastBid[auctionId];
    }

    function getAuctionStatus(uint auctionId) external view returns(AuctionStatus status){
        status =  _auctionStatus[auctionId];
    }

    function getAuctionCount() external view returns(uint auctionCount){
        auctionCount = _auctionCount;
    }

    function createAuction(Auction memory proposed) external{
        require(proposed.owner == msg.sender,"msg.sender not auction owner");
        IERC721(zoraMedia).transferFrom(proposed.owner,address(this),proposed.tokenId);
        _auctions[_auctionCount] = proposed;
        _auctionStatus[_auctionCount] = AuctionStatus.ReserveUnmet;
        _auctionCount++;
        //TO DO : EMIT AN EVENT
    }

    //TO DO : CREATE META TX CREATE AUCTION WHERE MINTFUND CAN PAY GAS

    function cancelAuction(uint auctionId) external{
        require(_auctions[auctionId].owner == msg.sender,"msg.sender not auction owner");
        require(_auctionStatus[auctionId] == AuctionStatus.ReserveUnmet, "reserve price met, no going back");
        _auctionStatus[auctionId] = AuctionStatus.Cancelled;
        IERC721(zoraMedia).transferFrom(address(this),_auctions[auctionId].owner,_auctions[auctionId].tokenId);
        //TO DO : EMIT AN EVENT
    }

    function createBid(Bid memory bid) external payable{
        require(msg.value == bid.amount, "incorrect amount sent");

        if(_auctionStatus[bid.auctionId] == AuctionStatus.ReserveUnmet){
            require(bid.amount > _auctions[bid.auctionId].reservePrice,"Bid below reserve price");
            _auctionLastBid[bid.auctionId] = bid;
            _auctionStatus[bid.auctionId] = AuctionStatus.ReserveMet;
            //TO DO : EMIT AN EVENT
        }

        else if(_auctionStatus[bid.auctionId] == AuctionStatus.ReserveMet){
            require(
                block.timestamp < _auctionLastBid[bid.auctionId].bidTime + _auctions[bid.auctionId].duration,
                "Auction Ended"
                );
            require(bid.amount > _auctionLastBid[bid.auctionId].amount,"Bid below last bid");
            (_auctionLastBid[bid.auctionId].bidder).transfer(_auctionLastBid[bid.auctionId].amount);
            _auctionLastBid[bid.auctionId] = bid;
            //TO DO : EMIT AN EVENT
        }

        else {
            revert("Auction is no longer running");
        }
    }

    function endAuction(uint auctionId) external{
        require(_auctionStatus[auctionId] == AuctionStatus.ReserveMet, "Status != ReserveMet");
        require(
                block.timestamp > _auctionLastBid[auctionId].bidTime + _auctions[auctionId].duration,
                "Auction Still Happening"
                );
        (_auctions[auctionId].owner).transfer(_auctionLastBid[auctionId].amount);
        IERC721(zoraMedia).transferFrom(address(this),_auctionLastBid[auctionId].bidder,_auctions[auctionId].tokenId);
    }

}