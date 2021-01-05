//SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import './YetubitToken.sol';

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote)
        external
        view
        returns (ReferenceData memory);
}

contract YetuTokensCrowdsale {
    
        using SafeMath for uint256;
        IStdReference internal ref;
        
        /**
       * Event for YetuTokens purchase logging
       * @param purchaser who paid for the tokens
       * @param beneficiary who got the tokens
       * @param value bnbs paid for purchase
       * @param YetuTokenAmount amount of Yetu tokens purchased
       */
        event TokenPurchase(
            address indexed purchaser,
            address indexed beneficiary,
            uint256 value,
            uint256 YetuTokenAmount
        );
    
       bool public isEnded = false;
    
       event Ended(uint256 totalBNBRaisedInCrowdsale,uint256 unsoldTokensTransferredToOwner);
       
       uint256 public currentYetuTokenUSDPrice;     //YetuTokens in $USD 
       
       YetubitToken public yetu;
       
       uint8 public currentCrowdsaleStage;

      // Yetu Token Distribution
      // =============================
      uint256 public totalYetuTokensForSale = 60000000*(1e18); // 60,000,000 Yetu will be sold during the whole Crowdsale
      // ==============================
      
      // Amount of bnb raised in Crowdsale
      // ==================
      uint256 public totalBNBRaised;
      // ===================
    
      // Crowdsale Stages Details
      // ==================
       mapping (uint256 => uint256) public remainingYetuInStage;
       mapping (uint256 => uint256) public yetuUSDPriceInStages;
      // ===================
    
      // Events
      event BNBTransferred(string text);
      
      //Modifier
        address payable public owner;    
        modifier onlyOwner() {
            require (msg.sender == owner);
            _;
        }
    
      // Constructor
      // ============
      constructor() public       
      {   
          owner = msg.sender;
          currentCrowdsaleStage = 1;
          
          remainingYetuInStage[1] = 5000000*1e18;   // 5,000,000 Yetu will be sold during the Stage 1
          remainingYetuInStage[2] = 20000000*1e18;  // 20,000,000 Yetu will be sold during the Stage 2
          remainingYetuInStage[3] = 20000000*1e18;  // 20,000,000 Yetu will be sold during the Stage 3
          remainingYetuInStage[4] = 10000000*1e18;  // 10,000,000 Yetu will be sold during the Stage 4
          remainingYetuInStage[5] = 5000000*1e18;   // 5,000,000 Yetu will be sold during the Stage 5
          
          yetuUSDPriceInStages[1] = 40000000000000000;    //$0.04
          yetuUSDPriceInStages[2] = 80000000000000000;    //$0.08
          yetuUSDPriceInStages[3] = 200000000000000000;   //$0.2
          yetuUSDPriceInStages[4] = 400000000000000000;   //$0.4
          yetuUSDPriceInStages[5] = 800000000000000000;   //$0.8
        
          currentYetuTokenUSDPrice = yetuUSDPriceInStages[1];       
          
          ref = IStdReference(0xDA7a001b254CD22e46d3eAB04d937489c93174C3);
          yetu = new YetubitToken(owner); // Yetu Token Deployment
      }
      // =============

      // Change Crowdsale Stage. 
      function switchToNextStage() public onlyOwner {
          currentCrowdsaleStage = currentCrowdsaleStage + 1;
          if((currentCrowdsaleStage == 6) || (currentCrowdsaleStage == 0)){
              endCrowdsale();
          }
          currentYetuTokenUSDPrice = yetuUSDPriceInStages[currentCrowdsaleStage]; 
      }
      
       /**
       * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
       * @param _beneficiary Address performing the YetuToken purchase
       */
      function _preValidatePurchase(
        address _beneficiary
      )
        internal pure
      {
        require(_beneficiary != address(0));
      }
    
      /**
       * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
       * @param _beneficiary Address performing the YetuTokens purchase
       * @param _tokenAmount Number of Yetu tokens to be purchased
       */
      function _deliverTokens(
        address _beneficiary,
        uint256 _tokenAmount
      )
        internal
      {
        yetu.transfer(_beneficiary, _tokenAmount);
      }
    
      /**
       * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
       * @param _beneficiary Address receiving the tokens
       * @param _tokenAmount Number of Yetu tokens to be purchased
       */
      function _processPurchase(
        address _beneficiary,
        uint256 _tokenAmount
      )
        internal
      {
        _deliverTokens(_beneficiary, _tokenAmount);
      }
    
      /**
       * @dev Override to extend the way in which bnb is converted to tokens.
       * @param _bnbAmount Value in bnb to be converted into tokens
       * @return Number of tokens that can be purchased with the specified _bnbAmount
       */
      function _getTokenAmount(uint256 _bnbAmount)
        internal view returns (uint256)
      {
        return _bnbAmount.mul(getLatestBNBPrice()).div(currentYetuTokenUSDPrice);
      }
      
      
      // YetuTokens Purchase
      // =========================
      receive() external payable {
          if(isEnded){
              revert(); //Block Incoming BNB Deposits if Crowdsale has ended
          }
          buyYetuTokens(msg.sender);
      }
      
      function buyYetuTokens(address _beneficiary) public payable {
          uint256 bnbAmount = msg.value;
          require(bnbAmount > 0,"Please Send some BNB");
          if(isEnded){
            revert();
          }
          
          _preValidatePurchase(_beneficiary);
          uint256 YetuTokensToBePurchased = _getTokenAmount(bnbAmount);
          if (YetuTokensToBePurchased > remainingYetuInStage[currentCrowdsaleStage]) {
             revert();  //Block Incoming BNB Deposits if tokens to be purchased, exceeds remaining tokens for sale in the current stage
          }
            _processPurchase(_beneficiary, YetuTokensToBePurchased);
            emit TokenPurchase(
              msg.sender,
              _beneficiary,
              bnbAmount,
              YetuTokensToBePurchased
            );
            
          totalBNBRaised = totalBNBRaised.add(bnbAmount);
          remainingYetuInStage[currentCrowdsaleStage] = remainingYetuInStage[currentCrowdsaleStage].sub(YetuTokensToBePurchased);
          
          if(remainingYetuInStage[currentCrowdsaleStage] == 0){
              switchToNextStage();      // Switch to Next Crowdsale Stage when all tokens allocated for current stage are being sold out
          }
          
      }
      
      // Finish: Finalizing the Crowdsale.
      // ====================================================================
    
      function endCrowdsale() public onlyOwner {
          require(!isEnded,"Crowdsale already finalized");   
          uint256 unsoldTokens = yetu.balanceOf(address(this));
                                                              
          if (unsoldTokens > 0) {
              yetu.burn(unsoldTokens);
          }
          for(uint8 i = 1; i<=5; i++){
             remainingYetuInStage[i] = 0;   
          }

          currentCrowdsaleStage = 0;
          emit Ended(totalBNBRaised,unsoldTokens);
          isEnded = true;
      }
      // ===============================
        
      function yetuTokenBalance(address tokenHolder) external view returns(uint256 balance){
          return yetu.balanceOf(tokenHolder);
      }

    /**
     * Returns the latest BNB-USD price
     */
    function getLatestBNBPrice() public view returns (uint256){
        IStdReference.ReferenceData memory data = ref.getReferenceData("BNB","USD");
        return data.rate;
    }

    function withdrawFunds(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance,"Insufficient Funds");
        owner.transfer(amount);
        emit BNBTransferred("Funds Withdrawn to Owner Account");
    }
      
    function transferYetuOwnership(address _newOwner) public onlyOwner{
        return yetu.transferOwnership(_newOwner);
    }
    }