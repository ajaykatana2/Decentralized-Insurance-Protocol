
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Insurance Protocol
 * @dev A peer-to-peer insurance system where users pool funds and claims are automatically processed
 * @author Insurance Protocol Team
 */
contract DecentralizedInsuranceProtocol {
    
    // State variables
    address public owner;
    uint256 public totalPoolBalance;
    uint256 public constant PREMIUM_RATE = 100; // 1% premium (100 basis points)
    uint256 public constant CLAIM_PERIOD = 30 days;
    
    // Structs
    struct Policy {
        address policyholder;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool hasClaimed;
    }
    
    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        uint256 timestamp;
        bool isProcessed;
        bool isApproved;
        string description;
    }
    
    // Mappings
    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) public userPolicies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256) public contributions;
    
    // Counters
    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;
    
    // Events
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 coverageAmount);
    event PremiumPaid(uint256 indexed policyId, address indexed policyholder, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, bool approved, uint256 payoutAmount);
    event ContributionMade(address indexed contributor, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyActivePolicyHolder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");
        require(policies[_policyId].isActive, "Policy is not active");
        require(block.timestamp <= policies[_policyId].endTime, "Policy has expired");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Purchase Insurance Policy
     * @param _coverageAmount The amount of coverage desired
     * @param _duration Duration of the policy in days
     */
    function purchasePolicy(uint256 _coverageAmount, uint256 _duration) external payable {
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_duration >= 30 && _duration <= 365, "Duration must be between 30 and 365 days");
        
        // Calculate premium (1% of coverage amount)
        uint256 premium = (_coverageAmount * PREMIUM_RATE) / 10000;
        require(msg.value >= premium, "Insufficient premium payment");
        
        // Create new policy
        Policy memory newPolicy = Policy({
            policyholder: msg.sender,
            coverageAmount: _coverageAmount,
            premiumPaid: msg.value,
            startTime: block.timestamp,
            endTime: block.timestamp + (_duration * 1 days),
            isActive: true,
            hasClaimed: false
        });
        
        policies[nextPolicyId] = newPolicy;
        userPolicies[msg.sender].push(nextPolicyId);
        
        // Add premium to pool
        totalPoolBalance += msg.value;
        
        emit PolicyCreated(nextPolicyId, msg.sender, _coverageAmount);
        emit PremiumPaid(nextPolicyId, msg.sender, msg.value);
        
        nextPolicyId++;
    }
    
    /**
     * @dev Core Function 2: Submit Insurance Claim
     * @param _policyId The ID of the policy to claim against
     * @param _claimAmount The amount being claimed
     * @param _description Description of the claim
     */
    function submitClaim(
        uint256 _policyId, 
        uint256 _claimAmount, 
        string memory _description
    ) external onlyActivePolicyHolder(_policyId) {
        Policy storage policy = policies[_policyId];
        
        require(!policy.hasClaimed, "Policy has already been claimed");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(_claimAmount <= totalPoolBalance, "Insufficient pool balance");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        // Create claim
        Claim memory newClaim = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            timestamp: block.timestamp,
            isProcessed: false,
            isApproved: false,
            description: _description
        });
        
        claims[nextClaimId] = newClaim;
        
        emit ClaimSubmitted(nextClaimId, _policyId, msg.sender, _claimAmount);
        
        nextClaimId++;
    }
    
    /**
     * @dev Core Function 3: Process Insurance Claim
     * @param _claimId The ID of the claim to process
     * @param _approve Whether to approve or deny the claim
     */
    function processClaim(uint256 _claimId, bool _approve) external onlyOwner {
        Claim storage claim = claims[_claimId];
        require(!claim.isProcessed, "Claim already processed");
        require(claim.claimant != address(0), "Invalid claim");
        
        claim.isProcessed = true;
        claim.isApproved = _approve;
        
        if (_approve) {
            require(totalPoolBalance >= claim.claimAmount, "Insufficient pool balance");
            
            // Mark policy as claimed
            policies[claim.policyId].hasClaimed = true;
            
            // Transfer payout
            totalPoolBalance -= claim.claimAmount;
            payable(claim.claimant).transfer(claim.claimAmount);
            
            emit ClaimProcessed(_claimId, true, claim.claimAmount);
        } else {
            emit ClaimProcessed(_claimId, false, 0);
        }
    }
    
    // Additional utility functions
    
    /**
     * @dev Allow users to contribute to the insurance pool
     */
    function contributeToPool() external payable {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        totalPoolBalance += msg.value;
        contributions[msg.sender] += msg.value;
        
        emit ContributionMade(msg.sender, msg.value);
    }
    
    /**
     * @dev Get user's policies
     * @param _user Address of the user
     * @return Array of policy IDs
     */
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    /**
     * @dev Get policy details
     * @param _policyId ID of the policy
     * @return Policy struct
     */
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }
    
    /**
     * @dev Get claim details
     * @param _claimId ID of the claim
     * @return Claim struct
     */
    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }
    
    /**
     * @dev Emergency function to withdraw funds (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
        totalPoolBalance = 0;
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
