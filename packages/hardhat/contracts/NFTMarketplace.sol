// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is IERC721Receiver, Ownable {
    
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }
    
    struct Sale {
        uint256 saleId;
        address seller;
        address buyer;
        uint256 price;
        uint256 fee;
    }
    
    IERC721 private _nftContract;
    uint256 private _feePercentage;
    uint256 private _saleIdCounter;
    
    mapping(uint256 => Listing) private _listings;
    mapping(uint256 => Sale) private _sales;

    event ListingCreated(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ListingUpdated(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ListingRemoved(uint256 indexed tokenId);
    event NFTSold(uint256 indexed saleId, uint256 indexed tokenId, address indexed seller, address buyer, uint256 price, uint256 fee);
    
    constructor(address nftContractAddress, uint256 feePercentage) {
        require(nftContractAddress != address(0), "Invalid NFT contract address");
        require(feePercentage <= 100, "Invalid fee percentage");
        _nftContract = IERC721(nftContractAddress);
        _feePercentage = feePercentage;
        _saleIdCounter = 1;
    }
    
    function listNFT(uint256 tokenId, uint256 price) external {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "You can only list your own NFT");
        require(price > 0, "Price must be greater than zero");
        require(!_listings[tokenId].active, "NFT is already listed");
        
        _listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit ListingCreated(tokenId, msg.sender, price);
    }
    
    function updateListing(uint256 tokenId, uint256 price) external {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "You can only update your own listing");
        require(price > 0, "Price must be greater than zero");
        require(_listings[tokenId].active, "NFT is not listed");
        
        _listings[tokenId].price = price;
        
        emit ListingUpdated(tokenId, msg.sender, price);
    }
    
    function removeListing(uint256 tokenId) external {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "You can only remove your own listing");
        require(_listings[tokenId].active, "NFT is not listed");
        
        delete _listings[tokenId];
        
        emit ListingRemoved(tokenId);
    }
    
    function buyNFT(uint256 tokenId) external payable {
        require(_listings[tokenId].active, "NFT is not listed");
        require(msg.value >= _listings[tokenId].price, "Insufficient payment");
        
        Listing memory listing = _listings[tokenId];
        address seller = listing.seller;
        uint256 price = listing.price;
        
        _nftContract.safeTransferFrom(seller, msg.sender, tokenId);
        
        uint256 fee = (price * _feePercentage) / 100;
        uint256 sellerAmount = price - fee;
        
        _sales[_saleIdCounter] = Sale({
            saleId: _saleIdCounter,
            seller: seller,
            buyer: msg.sender,
            price: price,
            fee: fee
        });
        
        _saleIdCounter++;
        _listings[tokenId].active = false;
        
        address payable sellerPayable = payable(seller);
        sellerPayable.transfer(sellerAmount);
        
        emit NFTSold(_saleIdCounter - 1, tokenId, seller, msg.sender, price, fee);
    }
    
    function setFeePercentage(uint256 feePercentage) external onlyOwner {
        require(feePercentage <= 100, "Invalid fee percentage");
        _feePercentage = feePercentage;
    }
    
    function getFeePercentage() external view returns (uint256) {
        return _feePercentage;
    }
    
    function getListing(uint256 tokenId) external view returns (address seller, uint256 price, bool active) {
        Listing memory listing = _listings[tokenId];
        return (listing.seller, listing.price, listing.active);
    }
    
    function getSale(uint256 saleId) external view returns (address seller, address buyer, uint256 price, uint256 fee) {
        Sale memory sale = _sales[saleId];
        return (sale.seller, sale.buyer, sale.price, sale.fee);
    }
    
    // Function required by IERC721Receiver interface
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}