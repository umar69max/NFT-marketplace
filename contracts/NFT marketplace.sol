// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace {
    using SafeMath for uint256;

    address public owner;
    uint256 public listingFee;
    
    struct Listing {
        address seller;
        uint256 price;
        bool isSold;
    }

    mapping(address => mapping(uint256 => Listing)) public listings; // NFT contract -> tokenId -> Listing
    mapping(address => uint256[]) public userNFTs; // user -> list of owned NFT IDs

    event Listed(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed seller);
    event Purchased(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed buyer);
    event ListingFeeUpdated(uint256 newFee);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    modifier notListed(address _nftContract, uint256 _tokenId) {
        require(listings[_nftContract][_tokenId].seller == address(0), "NFT already listed");
        _;
    }

    modifier isListed(address _nftContract, uint256 _tokenId) {
        require(listings[_nftContract][_tokenId].seller != address(0), "NFT not listed");
        _;
    }

    constructor(uint256 _listingFee) {
        owner = msg.sender;
        listingFee = _listingFee;
    }

    // List NFT for sale
    function listNFT(address _nftContract, uint256 _tokenId, uint256 _price) external notListed(_nftContract, _tokenId) {
        IERC721 nft = IERC721(_nftContract);
        address ownerOfNFT = nft.ownerOf(_tokenId);
        
        require(ownerOfNFT == msg.sender, "You are not the owner of this NFT");
        require(_price > 0, "Price must be greater than 0");
        
        nft.transferFrom(msg.sender, address(this), _tokenId);
        
        listings[_nftContract][_tokenId] = Listing({
            seller: msg.sender,
            price: _price,
            isSold: false
        });

        emit Listed(_nftContract, _tokenId, _price, msg.sender);
    }

    // Purchase listed NFT
    function purchaseNFT(address _nftContract, uint256 _tokenId) external payable isListed(_nftContract, _tokenId) {
        Listing storage listing = listings[_nftContract][_tokenId];
        require(msg.value >= listing.price.add(listingFee), "Insufficient funds to purchase this NFT");
        
        address seller = listing.seller;
        uint256 price = listing.price;
        
        // Mark the NFT as sold
        listing.isSold = true;
        listings[_nftContract][_tokenId].seller = address(0);

        // Transfer the NFT to the buyer
        IERC721(_nftContract).transferFrom(address(this), msg.sender, _tokenId);
        
        // Transfer the sale amount to the seller
        payable(seller).transfer(price);
        
        emit Purchased(_nftContract, _tokenId, price, msg.sender);
    }

    // Update the listing fee
    function updateListingFee(uint256 _newFee) external onlyOwner {
        listingFee = _newFee;
        emit ListingFeeUpdated(_newFee);
    }

    // Withdraw funds (only for the contract owner)
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
