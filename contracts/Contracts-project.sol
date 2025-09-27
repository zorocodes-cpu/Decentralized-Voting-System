// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Voting System
 * @dev A transparent and secure voting platform on the blockchain
 * @author Your Name
 */
contract Project {
    
    // Structure to represent a candidate
    struct Candidate {
        uint256 id;
        string name;
        string description;
        uint256 voteCount;
        bool exists;
    }
    
    // Structure to represent a voting session
    struct VotingSession {
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 totalVotes;
    }
    
    // State variables
    address public owner;
    VotingSession public currentSession;
    uint256 public candidateCount;
    
    // Mappings
    mapping(uint256 => Candidate) public candidates;
    mapping(address => bool) public hasVoted;
    mapping(address => bool) public registeredVoters;
    
    // Events
    event VotingSessionCreated(string title, uint256 startTime, uint256 endTime);
    event CandidateAdded(uint256 candidateId, string name);
    event VoteCast(address voter, uint256 candidateId);
    event VoterRegistered(address voter);
    event VotingSessionEnded(uint256 totalVotes);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(registeredVoters[msg.sender], "You are not a registered voter");
        _;
    }
    
    modifier votingActive() {
        require(currentSession.isActive, "No active voting session");
        require(block.timestamp >= currentSession.startTime, "Voting has not started yet");
        require(block.timestamp <= currentSession.endTime, "Voting has ended");
        _;
    }
    
    modifier hasNotVoted() {
        require(!hasVoted[msg.sender], "You have already voted");
        _;
    }
    
    /**
     * @dev Constructor sets the contract deployer as owner
     */
    constructor() {
        owner = msg.sender;
        candidateCount = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new voting session with candidates
     * @param _title Title of the voting session
     * @param _description Description of what the vote is about
     * @param _durationInMinutes How long the voting should last
     * @param _candidateNames Array of candidate names
     * @param _candidateDescriptions Array of candidate descriptions
     */
    function createVotingSession(
        string memory _title,
        string memory _description,
        uint256 _durationInMinutes,
        string[] memory _candidateNames,
        string[] memory _candidateDescriptions
    ) public onlyOwner {
        require(_candidateNames.length > 0, "At least one candidate required");
        require(_candidateNames.length == _candidateDescriptions.length, "Mismatched candidate data");
        require(_durationInMinutes > 0, "Duration must be greater than 0");
        
        // End any existing session
        if (currentSession.isActive) {
            currentSession.isActive = false;
        }
        
        // Reset voting data
        _resetVotingData();
        
        // Create new session
        currentSession = VotingSession({
            title: _title,
            description: _description,
            startTime: block.timestamp,
            endTime: block.timestamp + (_durationInMinutes * 1 minutes),
            isActive: true,
            totalVotes: 0
        });
        
        // Add candidates
        for (uint256 i = 0; i < _candidateNames.length; i++) {
            candidateCount++;
            candidates[candidateCount] = Candidate({
                id: candidateCount,
                name: _candidateNames[i],
                description: _candidateDescriptions[i],
                voteCount: 0,
                exists: true
            });
            
            emit CandidateAdded(candidateCount, _candidateNames[i]);
        }
        
        emit VotingSessionCreated(_title, currentSession.startTime, currentSession.endTime);
    }
    
    /**
     * @dev Core Function 2: Cast a vote for a candidate
     * @param _candidateId The ID of the candidate to vote for
     */
    function castVote(uint256 _candidateId) public 
        onlyRegisteredVoter 
        votingActive 
        hasNotVoted 
    {
        require(_candidateId > 0 && _candidateId <= candidateCount, "Invalid candidate ID");
        require(candidates[_candidateId].exists, "Candidate does not exist");
        
        // Record the vote
        hasVoted[msg.sender] = true;
        candidates[_candidateId].voteCount++;
        currentSession.totalVotes++;
        
        emit VoteCast(msg.sender, _candidateId);
        
        // Auto-end session if time has passed
        if (block.timestamp > currentSession.endTime) {
            _endVotingSession();
        }
    }
    
    /**
     * @dev Core Function 3: Register a voter (simplified - in production, this would have more verification)
     */
    function registerVoter() public {
        require(!registeredVoters[msg.sender], "Already registered");
        
        registeredVoters[msg.sender] = true;
        emit VoterRegistered(msg.sender);
    }
    
    /**
     * @dev Get voting results - returns candidate with most votes
     * @return winnerName Name of the winning candidate
     * @return winnerVotes Number of votes the winner received
     * @return totalVotes Total votes cast in the session
     */
    function getVotingResults() public view returns (
        string memory winnerName,
        uint256 winnerVotes,
        uint256 totalVotes
    ) {
        require(candidateCount > 0, "No voting session found");
        
        uint256 winningVoteCount = 0;
        uint256 winningCandidateId = 0;
        
        // Find candidate with most votes
        for (uint256 i = 1; i <= candidateCount; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winningCandidateId = i;
            }
        }
        
        if (winningCandidateId > 0) {
            return (
                candidates[winningCandidateId].name,
                winningVoteCount,
                currentSession.totalVotes
            );
        } else {
            return ("No votes cast", 0, 0);
        }
    }
    
    /**
     * @dev Get candidate details
     * @param _candidateId ID of the candidate
     * @return name Candidate name
     * @return description Candidate description  
     * @return voteCount Number of votes received
     */
    function getCandidate(uint256 _candidateId) public view returns (
        string memory name,
        string memory description,
        uint256 voteCount
    ) {
        require(_candidateId > 0 && _candidateId <= candidateCount, "Invalid candidate ID");
        require(candidates[_candidateId].exists, "Candidate does not exist");
        
        Candidate memory candidate = candidates[_candidateId];
        return (candidate.name, candidate.description, candidate.voteCount);
    }
    
    /**
     * @dev End current voting session manually (owner only)
     */
    function endVotingSession() public onlyOwner {
        require(currentSession.isActive, "No active voting session");
        _endVotingSession();
    }
    
    /**
     * @dev Internal function to end voting session
     */
    function _endVotingSession() private {
        currentSession.isActive = false;
        emit VotingSessionEnded(currentSession.totalVotes);
    }
    
    /**
     * @dev Internal function to reset voting data for new session
     */
    function _resetVotingData() private {
        // Reset candidate data
        for (uint256 i = 1; i <= candidateCount; i++) {
            delete candidates[i];
        }
        candidateCount = 0;
        
        // Note: In a production system, you'd need a more efficient way to reset hasVoted mapping
        // This is a simplified version for demonstration
    }
    
    /**
     * @dev Get current session information
     */
    function getCurrentSession() public view returns (
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 totalVotes
    ) {
        return (
            currentSession.title,
            currentSession.description,
            currentSession.startTime,
            currentSession.endTime,
            currentSession.isActive,
            currentSession.totalVotes
        );
    }
    
    /**
     * @dev Check if address has voted in current session
     */
    function hasAddressVoted(address _voter) public view returns (bool) {
        return hasVoted[_voter];
    }
    
    /**
     * @dev Get total number of candidates in current session
     */
    function getTotalCandidates() public view returns (uint256) {
        return candidateCount;
    }
}
